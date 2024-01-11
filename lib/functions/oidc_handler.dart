import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/oidc.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:id_ideal_wallet/views/credential_offer.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:provider/provider.dart';

String removeTrailingSlash(String base64Input) {
  while (base64Input.endsWith('/')) {
    base64Input = base64Input.substring(0, base64Input.length - 1);
  }
  return base64Input;
}

Future<void> handleOfferOidc(String offerUri) async {
  var offer = OidcCredentialOffer.fromUri(offerUri);
  logger.d(offer.credentials.first);
  List<String> credentialToRequest = [];
  for (var c in offer.credentials) {
    if (c is String) {
      credentialToRequest.add(c);
    } else {
      credentialToRequest.addAll(c['types']?.cast<String>() ?? []);
    }
  }

  var issuerString = removeTrailingSlash(offer.credentialIssuer);

  dynamic res = true;
  res = await Future.delayed(const Duration(seconds: 1), () async {
    return await showCupertinoModalPopup(
      context: navigatorKey.currentContext!,
      barrierColor: Colors.white,
      builder: (BuildContext context) => CredentialOfferDialog(
          oidcIssuer: issuerString,
          requestOidcTan:
              offer.userPinRequired != null && offer.userPinRequired!,
          credentials: [
            VerifiableCredential(
                context: [credentialsV1Iri],
                type: credentialToRequest,
                issuer: {'name': issuerString},
                credentialSubject: <String, dynamic>{},
                issuanceDate: DateTime.now())
          ]),
    );
  });

  if (res is String || res) {
    logger.d(res);
    logger.d(issuerString);
    logger.d(offer.credentials);
    var issuerMetaReq = await get(
        Uri.parse('$issuerString/.well-known/openid-credential-issuer'),
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

    var metaData = jsonDecode(issuerMetaReq.body);

    var authMetaReq = await get(
        Uri.parse('$issuerString/.well-known/oauth-authorization-server'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (authMetaReq.statusCode != 200) {
      throw Exception(
          'Bad Status code: ${authMetaReq.statusCode} / ${authMetaReq.body}');
    }

    var jsonBody = jsonDecode(authMetaReq.body);
    var tokenEndpoint = jsonBody['token_endpoint'];

    logger.d(tokenEndpoint);

    //send token Request
    var preAuthCode = offer.preAuthCode;

    logger.d(preAuthCode);
    logger.d('Token-Endpoint: $tokenEndpoint');

    var tokenRes = await post(Uri.parse(tokenEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code&pre-authorized_code=$preAuthCode${offer.userPinRequired != null && offer.userPinRequired! ? '&user_pin=$res' : ''}')
        .timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (tokenRes.statusCode == 200) {
      var tokenResponse = OidcTokenResponse.fromJson(tokenRes.body);

      logger.d('Access-Token : ${tokenResponse.accessToken}');

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
      var presentation = VerifiablePresentation(
          context: [credentialsV1Iri, ed25519ContextIri],
          type: ['VerifiablePresentation'],
          holder: credentialDid);
      var signer = EdDsaSigner(loadDocumentFast);
      var p = await signer.buildProof(
          presentation.toJson(), wallet.wallet, credentialDid,
          challenge: tokenResponse.cNonce,
          domain: offer.credentialIssuer,
          proofPurpose: 'authentication');
      presentation.proof = [LinkedDataProof.fromJson(p)];
      // end VP creation

      var credentialRequest = {
        'format': 'ldp_vc',
        'types': credentialToRequest,
        'proof': {'proof_type': 'jwt', 'jwt': jwt}
      };

      var credentialRequestLdp = {
        'format': 'ldp_vc',
        'types': credentialToRequest,
        'proof': {'proof_type': 'ldp_vp', 'vp': presentation.toJson()}
      };

      logger.d(credentialRequest);
      logger.d(credentialRequestLdp);

      var credentialResponse =
          await post(Uri.parse(metaData['credential_endpoint']),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${tokenResponse.accessToken}'
                  },
                  body: jsonEncode(credentialRequestLdp))
              .timeout(const Duration(seconds: 20), onTimeout: () {
        return Response('Timeout', 400);
      });

      if (credentialResponse.statusCode == 200) {
        logger.d(jsonDecode(credentialResponse.body));
        var credential = jsonDecode(credentialResponse.body)['credential'];

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
          wallet.storeExchangeHistoryEntry(
              credDid, DateTime.now(), 'issue', offer.credentialIssuer);

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
                    headline: AppLocalizations.of(context)!.credentialReceived,
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
      } else {
        logger.d(credentialResponse.statusCode);
        logger.d(credentialResponse.body);

        showErrorMessage('Credential kann nicht runtergeladen werden');
      }
    } else {
      logger.d(tokenRes.statusCode);
      logger.d(tokenRes.body);

      showErrorMessage('Authentifizierung fehlgeschlagen');
    }
  }
}

Future<void> handlePresentationRequestOidc(String request) async {
  var asUri = Uri.parse(request);
  PresentationDefinition? definition;
  String? nonce;

  nonce = asUri.queryParameters['nonce'];
  var redirectUri = asUri.queryParameters['redirect_uri'];
  var requestUri = asUri.queryParameters['request_uri'];
  var clientId = asUri.queryParameters['client_id'];
  var presDef = asUri.queryParameters['presentation_definition'];
  var presDefUri = asUri.queryParameters['presentation_definition_uri'];

  if (clientId == null) {
    throw Exception('client id null');
  }

  if (presDef != null) {
    logger.d(presDef);
    definition = PresentationDefinition.fromJson(presDef);
  } else if (presDefUri != null) {
    logger.d(presDefUri);
    var res = await get(Uri.parse(presDefUri), headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    });
    if (res.statusCode == 200) {
      definition = PresentationDefinition.fromJson(res.body);
    } else {
      throw Exception('no presentation definition found at $presDefUri');
    }
  } else {
    logger.d(requestUri);
    logger.d(clientId);

    if (requestUri == null) {
      throw Exception('requestUri null');
    }

    var requestRaw = await get(Uri.parse(requestUri), headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    });
    logger.d(requestRaw.statusCode);
    logger.d(requestRaw.body);

    var requestObject = RequestObject.fromJson(requestRaw.body);

    logger.d(requestObject.nonce);
    logger.d(requestObject.presentationDefinition);
    definition = requestObject.presentationDefinition;
    nonce = requestObject.nonce;
  }

  if (nonce == null) {
    throw Exception('nonce null');
  }
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
          definitionHash: '',
          otherEndpoint: redirectUri ?? clientId,
          receiverDid: clientId,
          myDid: 'myDid',
          results: filtered,
          isOidc: true,
          nonce: nonce,
        ),
      ),
    );
  } catch (e, stack) {
    logger.e(e, stackTrace: stack);
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
  }
}
