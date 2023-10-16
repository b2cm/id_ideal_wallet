import 'dart:convert';

import 'package:cbor_test/cbor_test.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/oidc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:provider/provider.dart';

Future<void> handleOfferOidc(String offerUri) async {
  var offer = OidcCredentialOffer.fromUri(offerUri);

  var res = true;
  //await showCupertinoModalPopup(
  //     context: navigatorKey.currentContext!,
  //     barrierColor: Colors.white,
  //     builder: (BuildContext context) =>
  //         buildOfferCredentialDialogOidc(context, offer.credentials));

  if (res) {
    print(offer.credentialIssuer);
    logger.d(offer.credentials);
    var issuerMetaReq = await get(
        Uri.parse(
            '${offer.credentialIssuer}/.well-known/openid-credential-issuer'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (issuerMetaReq.statusCode != 200) {
      throw Exception('Bad Status code: ${issuerMetaReq.statusCode}');
    }

    logger.d(issuerMetaReq.body);

    var metaData = CredentialIssuerMetaData.fromJson(issuerMetaReq.body);

    var authMetaReq = await get(
        Uri.parse(
            '${offer.credentialIssuer}/.well-known/oauth-authorization-server'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (authMetaReq.statusCode != 200) {
      throw Exception('Bad Status code');
    }

    var jsonBody = jsonDecode(authMetaReq.body);
    var tokenEndpoint = jsonBody['token_endpoint'];

    print(tokenEndpoint);

    //send token Request
    var preAuthCode =
        offer.grants!['urn:ietf:params:oauth:grant-type:pre-authorized_code']
            ['pre-authorized_code'];

    print(preAuthCode);
    logger.d('Token-Endpoint: $tokenEndpoint');

    var tokenRes = await post(Uri.parse(tokenEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code&pre-authorized_code=$preAuthCode')
        .timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (tokenRes.statusCode == 200) {
      var tokenResponse = OidcTokenResponse.fromJson(tokenRes.body);

      print('Access-Token : ${tokenResponse.accessToken}');

      var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
          listen: false);

      var credentialDid = await wallet.newCredentialDid();
      logger.d(credentialDid);

      // create JWT
      var header = {
        'typ': 'openid4vci-proof+jwt',
        'alg': 'EdDSA',
        'crv': 'Ed25519',
        'kid': '$credentialDid#${credentialDid.split(':').last}'
      };

      var payload = {
        'aud': offer.credentialIssuer,
        'iat': DateTime.now().millisecondsSinceEpoch,
        'nonce': tokenResponse.cNonce
      };

      var jwt = await signStringOrJson(
          wallet: wallet.wallet,
          didToSignWith: credentialDid,
          toSign: payload,
          jwsHeader: header,
          detached: false);
      //end JWT creation

      // create VP
      var signed = await buildPresentation(
          [], wallet.wallet, tokenResponse.cNonce!,
          holder: credentialDid, domain: offer.credentialIssuer);
      // end VP creation

      var credentialRequest = {
        'format': 'ldp_vc',
        'types':
            offer.credentials.first['type'] ?? offer.credentials.first['types'],
        'proof': {'proof_type': 'jwt', 'jwt': jwt}
      };

      var credentialRequestLdp = {
        'format': 'ldp_vc',
        'types':
            offer.credentials.first['type'] ?? offer.credentials.first['types'],
        'proof': {'proof_type': 'ldp_vp', 'vp': jsonDecode(signed)}
      };

      logger.d(credentialRequest);
      logger.d(credentialRequestLdp);

      var credentialResponse =
          await post(Uri.parse(metaData.credentialEndpoint),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${tokenResponse.accessToken}'
                  },
                  body: jsonEncode(credentialRequestLdp))
              .timeout(const Duration(seconds: 20), onTimeout: () {
        return Response('Timeout', 400);
      });

      if (credentialResponse.statusCode == 200) {
        var credential = jsonDecode(credentialResponse.body)['credential'];

        if (offer.credentials.first['format'] == 'iso-mdl') {
          var data = IssuerSignedObject.fromCbor(base64Decode(credential));
          var verified = verifyMso(data);
          if (verified) {
            var signedData =
                MobileSecurityObject.fromCbor(data.issuerAuth.payload);
            logger.d(signedData.deviceKeyInfo.deviceKey);
            var did = coseKeyToDid(signedData.deviceKeyInfo.deviceKey);
            logger.d(did);
            var credSubject = {'id': did};
            data.items.forEach((key, value) {
              for (var i in value) {
                credSubject[i.dataElementIdentifier] = i.dataElementValue;
              }
            });

            var vc = VerifiableCredential(
                context: [
                  'schema.org'
                ],
                type: [
                  'IsoMdlCredential',
                  signedData.docType
                ],
                issuer: {
                  'name': 'IsoMdlIssuer',
                  'certificate': base64UrlEncode(
                      data.issuerAuth.unprotected[33].cast<int>())
                },
                credentialSubject: credSubject,
                issuanceDate: signedData.validityInfo.validFrom,
                expirationDate: signedData.validityInfo.validUntil);

            var storageCred = wallet.getCredential(did);

            if (storageCred == null) {
              throw Exception(
                  'No hd path for credential found. Sure we control it?');
            }

            wallet.storeCredential(vc.toString(), storageCred.hdPath,
                isoMdlData: 'isoData:$credential');

            showModalBottomSheet(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10)),
                ),
                context: navigatorKey.currentContext!,
                builder: (context) {
                  return ModalDismissWrapper(
                    child: PaymentFinished(
                      headline: "Credential empfangen",
                      success: true,
                      amount: CurrencyDisplay(
                          amount: signedData.docType,
                          symbol: '',
                          mainFontSize: 35,
                          centered: true),
                    ),
                  );
                });
          }
        } else {
          logger.d(credential);

          var verified = await verifyCredential(credential,
              loadDocumentFunction: loadDocumentFast);

          logger.d(verified);
          if (verified) {
            var credDid = getHolderDidFromCredential(credential);
            logger.d(credDid);
            var storageCred = wallet.getCredential(credDid.split('#').first);
            if (storageCred == null) {
              throw Exception(
                  'No hd path for credential found. Sure we control it?');
            }

            wallet.storeCredential(jsonEncode(credential), storageCred.hdPath);

            showModalBottomSheet(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10)),
                ),
                context: navigatorKey.currentContext!,
                builder: (context) {
                  return ModalDismissWrapper(
                    child: PaymentFinished(
                      headline: "Credential empfangen",
                      success: true,
                      amount: CurrencyDisplay(
                          amount: credential['type'].first,
                          symbol: '',
                          mainFontSize: 35,
                          centered: true),
                    ),
                  );
                });
          }
        }
      } else {
        logger.d(credentialResponse.statusCode);
        logger.d(credentialResponse.body);
      }
    } else {
      logger.d(tokenRes.statusCode);
      logger.d(tokenRes.body);
    }
  }
}

Future<void> handlePresentationRequestOidc(String request) async {
  var asUri = Uri.parse(request);

  var requestUri = asUri.queryParameters['request_uri'];
  var clientId = asUri.queryParameters['client_id'];
  logger.d(requestUri);
  logger.d(clientId);

  if (requestUri == null || clientId == null) {
    throw Exception('clientId or requestUri');
  }

  var requestRaw = await get(Uri.parse(requestUri), headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  });
  logger.d(requestRaw.statusCode);
  logger.d(requestRaw.body);

  var requestObject = RequestObject.fromJson(requestRaw.body);

  //var def = PresentationDefinition.fromJson(requestRaw.body);

  logger.d(requestObject.nonce);
  logger.d(requestObject.presentationDefinition);

  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var allCreds = wallet.allCredentials();
  List<VerifiableCredential> creds = [];
  allCreds.forEach((key, value) {
    if (value.w3cCredential != '') {
      var vc = VerifiableCredential.fromJson(value.w3cCredential);
      var type = getTypeToShow(vc.type);
      if (type != 'PaymentReceipt') {
        creds.add(vc);
      }
    }
  });
  var definition = requestObject.presentationDefinition;

  if (definition == null) {
    logger.d('No presentation definition');
    throw Exception('No presentation definition');
  }

  try {
    var filtered =
        searchCredentialsForPresentationDefinition(creds, definition);
    logger.d('successfully filtered');

    Navigator.of(navigatorKey.currentContext!).push(
      MaterialPageRoute(
        builder: (context) => PresentationRequestDialog(
          otherEndpoint: clientId,
          receiverDid: clientId,
          myDid: 'myDid',
          results: filtered,
          isOidc: true,
          nonce: requestObject.nonce,
        ),
      ),
    );
  } catch (e, stack) {
    logger.e(e, ['', stack]);
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
  }
}
