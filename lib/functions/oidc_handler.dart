import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/oidc.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
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

      var jwt = await signStringOrJson(wallet.wallet, credentialDid, payload,
          jwsHeader: header, detached: false);

      var credentialRequest = {
        'format': 'ldp_vc',
        'types': offer.credentials.first['types'],
        'proof': {'proof_type': 'jwt', 'jwt': jwt}
      };

      logger.d(credentialRequest);

      var credentialResponse =
          await post(Uri.parse(metaData.credentialEndpoint),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'BEARER ${tokenResponse.accessToken}'
                  },
                  body: jsonEncode(credentialRequest))
              .timeout(const Duration(seconds: 20), onTimeout: () {
        return Response('Timeout', 400);
      });

      if (credentialResponse.statusCode == 200) {
        var credential = jsonDecode(credentialResponse.body)['credential'];

        logger.d(jsonDecode(credential));

        var verified = await verifyCredential(credential,
            loadDocumentFunction: loadDocumentFast);

        logger.d(verified);
        if (verified) {
          var credDid = getHolderDidFromCredential(credential);
          var storageCred = wallet.getCredential(credDid);
          if (storageCred == null) {
            throw Exception(
                'No hd path for credential found. Sure we control it?');
          }

          wallet.storeCredential(jsonEncode(credentialDid), storageCred.hdPath);

          showModalBottomSheet(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              context: navigatorKey.currentContext!,
              builder: (context) {
                return ModalDismissWrapper(
                  child: PaymentFinished(
                    headline: "Credential empfangen",
                    success: true,
                    amount: CurrencyDisplay(
                        amount: credential['type'],
                        symbol: '',
                        mainFontSize: 35,
                        centered: true),
                  ),
                );
              });
        }
      } else {
        logger.d(credentialResponse.statusCode);
      }
    } else {
      logger.d(tokenRes.statusCode);
    }
  }
}

Widget buildOfferCredentialDialogOidc(
    BuildContext context, List<dynamic> credentials) {
  List<Widget> contentData = [];

  for (var d in credentials) {
    var type =
        d['types'].firstWhere((element) => element != 'VerifiableCredential');

    var title = Text(type,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    contentData.add(const SizedBox(
      height: 10,
    ));

    contentData.add(ExpansionTile(
      title: title,
    ));
  }

  return SafeArea(
      child: Material(
          child:
              // rounded corners on the top
              Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Padding(
                      // padding only left and right
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CredentialOfferDialog(
                        credential: Column(
                          children: contentData,
                        ),
                        receipt: null,
                      )))));
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
      var type =
          vc.type.firstWhere((element) => element != 'VerifiableCredential');
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
    if (filtered.isNotEmpty) {
      Navigator.of(navigatorKey.currentContext!).push(MaterialPageRoute(
          builder: (context) => PresentationRequestDialog(
                otherEndpoint: clientId,
                receiverDid: clientId,
                myDid: 'myDid',
                results: filtered,
                isOidc: true,
                nonce: requestObject.nonce,
              )));
    } else {
      await showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => AlertDialog(
                title: const Text('Keine Credentials gefunden'),
                content: const Text(
                    'Sie besitzen keine Credentials, die der Anfrage entsprechen'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Ok'))
                ],
              ));
    }
  } catch (e, stack) {
    logger.e(e, ['', stack]);
    await showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
              title: const Text('Keine Credentials gefunden'),
              content: Text(
                  'Sie besitzen keine Credentials, die der Anfrage entsprechen ($e)'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Ok'))
              ],
            ));
  }
}
