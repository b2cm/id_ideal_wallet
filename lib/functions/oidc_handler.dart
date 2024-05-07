import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/oidc.dart';
import 'package:dart_ssi/util.dart';
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
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

    Map metaData = jsonDecode(issuerMetaReq.body);

    var authserver = issuerString;
    if (metaData.containsKey('authorization_servers')) {
      var authServerData =
          (metaData['authorization_servers'] as List).cast<String>();
      authserver = authServerData.first;
    }

    if (offer.grants != null &&
        offer.grants!.containsKey('authorization_code')) {
      launchUrl(Uri.parse(
          '$authserver/authorize?response_type=code&client_id=hidy&redirect_uri=${Uri.encodeQueryComponent('https://wallet.bccm.dev')}'));
    }

    var authMetaReq = await get(
        Uri.parse('$authserver/.well-known/oauth-authorization-server'),
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

        if (offer.credentials.first['format'] == 'iso-mdl') {
          var data = IssuerSignedObject.fromCbor(base64Decode(credential));
          var verified = await verifyMso(data);
          if (verified) {
            var signedData =
                MobileSecurityObject.fromCbor(data.issuerAuth.payload);
            logger.d(signedData.deviceKeyInfo.deviceKey);
            var did = coseKeyToDid(signedData.deviceKeyInfo.deviceKey);
            logger.d(did);
            var credSubject = <String, dynamic>{'id': did};
            data.items.forEach((key, value) {
              for (var i in value) {
                credSubject[i.dataElementIdentifier] = i.dataElementValue;
              }
            });

            var vc = VerifiableCredential(
                context: [
                  credentialsV1Iri,
                  'schema.org'
                ],
                type: [
                  'IsoMdlCredential',
                  signedData.docType
                ],
                issuer: {
                  'name': 'IsoMdlIssuer',
                  'certificate':
                      base64UrlEncode(data.issuerAuth.unprotected.x509chain!)
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

          var verified = false;
          try {
            verified = await verifyCredential(credential,
                loadDocumentFunction: loadDocumentFast);
          } catch (e) {
            showErrorMessage('Credential nicht verifizierbar');
            return;
          }

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
                      headline:
                          AppLocalizations.of(context)!.credentialReceived,
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
  String? nonce, responseUri;
  ClientMetaData? clientMetaData;

  nonce = asUri.queryParameters['nonce'];
  var redirectUri = asUri.queryParameters['redirect_uri'];
  var requestUri = asUri.queryParameters['request_uri'];
  var clientId = asUri.queryParameters['client_id'];
  var presDef = asUri.queryParameters['presentation_definition'];
  var presDefUri = asUri.queryParameters['presentation_definition_uri'];
  var state = asUri.queryParameters['state'];
  var responseMode = asUri.queryParameters['response_mode'];
  logger.d('State: $state');

  if (clientId == null) {
    throw Exception('client id null');
  }

  if (presDef != null) {
    // Case 1: Every relevant information is in original query-parameters
    logger.d(presDef);
    definition = PresentationDefinition.fromJson(presDef);
  } else if (presDefUri != null) {
    // Case 2: presentation definition must be fetched
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
    // Case 3: the total request must be fetched
    logger.d(requestUri);
    logger.d(clientId);

    if (requestUri == null) {
      throw Exception('requestUri null');
    }
    logger.d(requestUri);
    var requestRaw = await get(Uri.parse(requestUri), headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    });
    logger.d(requestRaw.statusCode);
    logger.d(requestRaw.headers);
    logger.d(requestRaw.body);

    RequestObject requestObject;
    if (isRawJson(requestRaw.body)) {
      logger.d('raw json');
      requestObject = RequestObject.fromJson(requestRaw.body);
    } else {
      // it is a jwt/jws (as normally expected)
      logger.d('jwt');
      var payload = requestRaw.body.split('.')[1];
      logger.d(
          jsonDecode(utf8.decode(base64Decode(addPaddingToBase64(payload)))));
      requestObject = RequestObject.fromJson(
          utf8.decode(base64Decode(addPaddingToBase64(payload))));
    }

    if (requestObject.clientMetaDataUri != null) {
      var metaDataResponse =
          await get(Uri.parse(requestObject.clientMetaDataUri!));
      if (metaDataResponse.statusCode == 200) {
        clientMetaData = ClientMetaData.fromJson(metaDataResponse.body);
      }
    } else {
      clientMetaData = requestObject.clientMetaData;
    }

    logger.d(requestObject.nonce);
    logger.d(requestObject.presentationDefinition);
    logger.d(requestObject.responseMode);
    redirectUri = requestObject.redirectUri;
    logger.d(redirectUri);
    definition = requestObject.presentationDefinition;
    nonce = requestObject.nonce;
    responseMode = requestObject.responseMode;
    responseUri = requestObject.responseUri;
    state = requestObject.state;
  }

  if (nonce == null) {
    throw Exception('nonce null');
  }

  logger.d('Response Mode: $responseMode');

  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var allCreds = wallet.allCredentials();
  var isoCreds = wallet.isoMdocCredentials;
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

  for (var cred in isoCreds) {
    var data = IssuerSignedObject.fromCbor(
        base64Decode(cred.plaintextCredential.replaceAll('isoData:', '')));
    var subject = <String, dynamic>{};
    data.items.forEach((key, value) {
      var nameSpaceData = <String, dynamic>{};
      for (var i in value) {
        nameSpaceData[i.dataElementIdentifier] = i.dataElementValue;
      }
      subject[key] = nameSpaceData;
    });

    var w3c = VerifiableCredential.fromJson(cred.w3cCredential);
    subject['id'] = w3c.credentialSubject['id'];

    logger.d(subject);

    var vc = VerifiableCredential(
        context: w3c.context,
        type: w3c.type,
        issuer: w3c.issuer,
        credentialSubject: subject,
        issuanceDate: w3c.issuanceDate);

    logger.d(vc.toJson());
    creds.add(vc);
  }

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
          otherEndpoint: responseUri ?? redirectUri ?? clientId,
          receiverDid: clientId,
          myDid: 'myDid',
          results: filtered,
          isOidc: true,
          nonce: nonce,
          oidcState: state,
          oidcResponseMode: responseMode,
          oidcClientMetadata: clientMetaData,
        ),
      ),
    );
  } catch (e) {
    logger.e(e);
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
  }
}

bool isRawJson(String json) {
  try {
    jsonDecode(json);
    return true;
  } catch (e) {
    return false;
  }
}

String coseKeyToDid(CoseKey coseKey) {
  var crvInt = coseKey.crv;

  List<int> prefix;
  if (crvInt == 6) {
    prefix = [237, 1];
  } else {
    throw Exception('Unknown KeyType');
  }

  List<int>? keyBytes = coseKey.x;

  return 'did:key:z${base58BitcoinEncode(Uint8List.fromList(prefix + keyBytes!))}';
}
