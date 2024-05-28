import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:crypto/crypto.dart';
import 'package:crypto_keys/crypto_keys.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/oidc.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
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
import 'package:id_ideal_wallet/provider/navigation_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_offer.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:x509b/x509.dart' as x509;

String removeTrailingSlash(String base64Input) {
  while (base64Input.endsWith('/')) {
    base64Input = base64Input.substring(0, base64Input.length - 1);
  }
  return base64Input;
}

Future<void> handleOfferOidc(String offerUri) async {
  var offer = OidcCredentialOffer.fromUri(offerUri);

  var issuerString = removeTrailingSlash(offer.credentialIssuer);

  // get metadata
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

  var issuerMetadata = CredentialIssuerMetaData.fromJson(issuerMetaReq.body);

  logger.d(offer.credentials);
  List<String> credentialToRequest = offer.credentialConfigurationIds ?? [];
  List<CredentialsSupportedObject> offeredCredentials = [];

  for (var c in offer.credentials ?? []) {
    if (c is String) {
      // type from credentialsSupported
      credentialToRequest.add(c);
    } else {
      c as CredentialsSupportedObject;
      offeredCredentials.add(c);
    }
  }
  for (String t in credentialToRequest) {
    var credConfig = issuerMetadata.credentialsSupported[t];
    offeredCredentials.add(credConfig!);
  }

  dynamic res = true;
  res = await Future.delayed(const Duration(seconds: 1), () async {
    return await showCupertinoModalPopup(
      context: navigatorKey.currentContext!,
      barrierColor: Colors.white,
      builder: (BuildContext context) => CredentialOfferDialog(
          oidcIssuer: issuerString,
          requestOidcTan: offer.grants != null &&
              offer.grants!.containsKey(GrantType.preAuthType) &&
              (offer.grants![GrantType.preAuthType] as PreAuthCodeGrant)
                      .txCode !=
                  null &&
              (offer.grants![GrantType.preAuthType] as PreAuthCodeGrant)
                  .txCode!,
          credentials: offeredCredentials
              .map((e) => VerifiableCredential(
                  context: [credentialsV1Iri],
                  type: e.credentialType ?? [],
                  issuer: {'name': issuerString},
                  credentialSubject: <String, dynamic>{},
                  issuanceDate: DateTime.now()))
              .toList()),
    );
  });

  if (res is String || res) {
    logger.d(res);
    logger.d(issuerString);
    logger.d(offer.credentials);

    var authserver = issuerString;
    if (issuerMetadata.authorizationServer != null &&
        issuerMetadata.authorizationServer!.isNotEmpty) {
      authserver = issuerMetadata.authorizationServer!.first;
    }

    if (offer.grants != null &&
        offer.grants!.containsKey('authorization_code')) {
      var authGrant =
          offer.grants![GrantType.authType] as AuthorizationCodeGrant;
      if (authGrant.authorizationServer != null) {
        authserver = authGrant.authorizationServer!;
      }

      authserver = removeTrailingSlash(authserver);

      logger.d('auth server: $authserver');

      var state = const Uuid().v4();
      String pkceCodeVerifier =
          '${const Uuid().v4().toString()}-${const Uuid().v4().toString()}';
      String pkceCodeChallenge = removePaddingFromBase64(
          base64UrlEncode(sha256.convert(utf8.encode(pkceCodeVerifier)).bytes));

      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
          .storeConfig(
              state,
              jsonEncode({
                'offer': offer.toJson(),
                'authServer': authserver,
                'credentials':
                    offeredCredentials.map((e) => e.toJson()).toList(),
                'codeVerifier': pkceCodeVerifier
              }));

      // get MetaData
      Map? authServerMetaData;
      Map? clientMetaData = knownAuthServer[authserver.trim()];
      logger.d('authServer: ${knownAuthServer.keys}');
      if (clientMetaData == null) {
        showErrorMessage('Unbekannter Authorization Server');
        return;
      }

      String clientId = clientMetaData['client_id'];
      String redirectUri =
          clientMetaData['redirect_uri'] ?? 'https:/wallet.bccm.dev/redirect';

      authServerMetaData = await getAuthServerMetaData(authserver);
      if (authServerMetaData == null) {
        // without config we assume standard endpoint
        launchUrl(Uri.parse(
            '$authserver/authorize?response_type=code&client_id=$clientId&redirect_uri=${Uri.encodeQueryComponent(redirectUri)}&state=$state&code_challenge=$pkceCodeChallenge&code_challenge_method=S256'));
        logger.d('$authserver without config');
        return;
      }

      String authIssuer = authServerMetaData['issuer'];
      if (authIssuer != authserver) {
        logger.d('$authIssuer != $authserver');
        showErrorMessage('Falsche Metadaten erhalten');
        return;
      }

      // can we do pushed authorization requests?
      var parEndpoint =
          authServerMetaData['pushed_authorization_request_endpoint'];
      if (parEndpoint != null) {
        String body =
            'client_id=$clientId&redirect_uri=${Uri.encodeQueryComponent(redirectUri)}&response_type=code&state=$state';
        body += '&code_challenge_method=S256';
        body += '&code_challenge=$pkceCodeChallenge';
        if (offeredCredentials.length == 1 &&
            offeredCredentials.first.scope != null) {
          body += '&scope=${offeredCredentials.first.scope}';
        } else {
          List<Map> authDetails = [];
          for (var entry in offeredCredentials) {
            var details = AuthorizationDetailsObject(
                format: entry.format,
                credentialConfigurationId: entry.credentialId,
                credentialType: entry.credentialType);
            authDetails.add(details.toJson());
          }
          body +=
              '&authorization_details=${Uri.encodeQueryComponent(jsonEncode(authDetails))}';
        }
        logger.d(body);

        var parResponse = await post(Uri.parse(parEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body);
        if (parResponse.statusCode == 201 || parResponse.statusCode == 200) {
          logger.d(parResponse.body);
          var decoded = jsonDecode(parResponse.body);
          var requestUri = decoded['request_uri'];
          String authRequest = authServerMetaData['authorization_endpoint'] ??
              '$authserver/authorize';
          authRequest +=
              '?client_id=$clientId&redirect_uri=${Uri.encodeQueryComponent(redirectUri)}';
          authRequest +=
              '&request_uri=${Uri.encodeQueryComponent(requestUri)}&state=$state&response_type=code';
          authRequest += '&nonce=abcdefg';
          if (offeredCredentials.length == 1 &&
              offeredCredentials.first.scope != null) {
            authRequest += '&scope=${offeredCredentials.first.scope}';
          }
          logger.d(authRequest);
          Provider.of<NavigationProvider>(navigatorKey.currentContext!,
                  listen: false)
              .changePage([5], webViewUrl: authRequest);
          //launchUrl(Uri.parse(authRequest));
          return;
        } else {
          showErrorMessage('Authorization Request fehlgeschlagen');
          logger.d(
              'Par request failed: ${parResponse.statusCode} / ${parResponse.body}');
          return;
        }
      } else {
        // if not, use redirect and authorization endpoint
        var authEndpoint = authServerMetaData['authorization_endpoint'];
        if (authEndpoint != null) {
          launchUrl(Uri.parse(
              '$authEndpoint?response_type=code&state$state&client_id=$clientId&redirect_uri=${Uri.encodeQueryComponent(redirectUri)}&code_challenge=$pkceCodeChallenge&code_challenge_method=S256'));
          return;
        } else {
          showErrorMessage('Authentifizierung nicht durchführbar',
              'Keinen Endpunkt gefunden');
        }
      }
    } else if (offer.grants != null &&
        offer.grants!.containsKey(GrantType.preAuthType)) {
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

      var preAuthGrant =
          offer.grants![GrantType.preAuthType] as PreAuthCodeGrant;
      //send token Request
      var preAuthCode = preAuthGrant.preAuthCode;

      logger.d(preAuthCode);
      logger.d('Token-Endpoint: $tokenEndpoint');

      var tokenRes = await post(Uri.parse(tokenEndpoint),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body:
                  'grant_type=${GrantType.preAuthType}&pre-authorized_code=$preAuthCode${preAuthGrant.txCode != null && preAuthGrant.txCode! ? '&user_pin=$res' : ''}')
          .timeout(const Duration(seconds: 20), onTimeout: () {
        return Response('Timeout', 400);
      });
      if (tokenRes.statusCode == 200) {
        OidcTokenResponse tokenResponse =
            OidcTokenResponse.fromJson(tokenRes.body);

        logger.d('Access-Token : ${tokenResponse.accessToken}');

        for (var credMetadata in offeredCredentials) {
          getCredential(
              issuerString, issuerMetadata, credMetadata, tokenResponse);
        }
      } else {
        logger.d(tokenRes.statusCode);
        logger.d(tokenRes.body);

        showErrorMessage('Authentifizierung fehlgeschlagen');
        return;
      }
    } else {
      showErrorMessage('Unbekannte Authentifizierungsmethode');
      return;
    }
  }
}

Future<Map?> getAuthServerMetaData(String authServer) async {
  var oidConfigRes =
      await get(Uri.parse('$authServer/.well-known/openid-configuration'));
  if (oidConfigRes.statusCode == 200) {
    return jsonDecode(oidConfigRes.body);
  } else {
    logger.d(
        'status oidConfig $authServer: ${oidConfigRes.statusCode} / ${oidConfigRes.body}');
    var oauthConfigRes = await get(
        Uri.parse('$authServer/.well-known/oauth-authorization-server'));
    if (oauthConfigRes.statusCode == 200) {
      return jsonDecode(oauthConfigRes.body);
    } else {
      return null;
    }
  }
}

Future<void> handleRedirect(String uri) async {
  Provider.of<NavigationProvider>(navigatorKey.currentContext!, listen: false)
      .goBack();
  logger.d('redirected uri: $uri');
  var asUri = Uri.parse(uri);
  var state = asUri.queryParameters['state'];
  var code = asUri.queryParameters['code'];
  logger.d('state: $state');
  if (state == null) {
    showErrorMessage('Prozess nicht auffindbar');
    return;
  }
  if (code == null) {
    showErrorMessage('Keinen Auth-Code empfangen');
    return;
  }

  var storedData =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
          .getConfig(state);

  if (storedData == null) {
    showErrorMessage('Prozess nicht auffindbar');
    return;
  }

  var parsed = jsonDecode(storedData);
  String authServer = parsed['authServer'];
  String codeVerifier = parsed['codeVerifier'];
  OidcCredentialOffer offer = OidcCredentialOffer.fromJson(parsed['offer']);
  List<CredentialsSupportedObject> credentialMetadata =
      (parsed['credentials'] as List)
          .map((e) => CredentialsSupportedObject.fromJson(e))
          .toList();
  logger.d('authServer: $authServer, codeVerifier: $codeVerifier');

  Map? clientMetaData = knownAuthServer[authServer];
  if (clientMetaData == null) {
    showErrorMessage('Unbekannter Authorization Server');
    return;
  }

  String clientId = clientMetaData['client_id'];
  String redirectUri =
      clientMetaData['redirect_uri'] ?? 'https:/wallet.bccm.dev/redirect';

  var authServerMetaData = await getAuthServerMetaData(authServer);
  String tokenEndpoint =
      authServerMetaData?['token_endpoint'] ?? '$authServer/token';
  logger.d('tokenEndpoint: $tokenEndpoint');

  String parameter = 'grant_type=authorization_code';
  parameter += '&code=$code';
  parameter += '&client_id=$clientId';
  parameter += '&redirect_uri=$redirectUri';
  parameter += '&state=$state';
  parameter += '&code_verifier=$codeVerifier';

  var tokenRes = await post(Uri.parse(tokenEndpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: parameter)
      .timeout(const Duration(seconds: 20), onTimeout: () {
    return Response('Timeout', 400);
  });

  if (tokenRes.statusCode == 200) {
    logger.d(
        'sucessful token request: ${jsonDecode(tokenRes.body).keys.toList()}');
    var decoded = OidcTokenResponse.fromJson(tokenRes.body);
    var payload = decoded.accessToken!.split('.')[1];
    logger.d(
        'decodedPayload: ${jsonDecode(utf8.decode((base64Decode(addPaddingToBase64(payload)))))}');
    getCredential(removeTrailingSlash(offer.credentialIssuer), null,
        credentialMetadata.first, decoded);
  } else {
    logger.d('Error token request: ${tokenRes.statusCode} / ${tokenRes.body}');
  }
}

Future<(String, dynamic)> buildJwt(List<String> algValues,
    WalletProvider wallet, String? cNonce, String credentialIssuer) async {
  String credentialDid, alg, crv;
  if (algValues.contains('ES256')) {
    credentialDid = await wallet.newCredentialDid(KeyType.p256);
    alg = 'ES256';
    crv = 'P-256';
  } else if (algValues.contains('ES384')) {
    credentialDid = await wallet.newCredentialDid(KeyType.p384);
    alg = 'ES384';
    crv = 'P-384';
  } else if (algValues.contains('ES512')) {
    credentialDid = await wallet.newCredentialDid(KeyType.p521);
    alg = 'ES512';
    crv = 'P-521';
  } else {
    credentialDid = await wallet.newCredentialDid();
    alg = 'EdDSA';
    crv = 'Ed25519';
  }
  // create JWT
  var header = {
    'typ': 'openid4vci-proof+jwt',
    'alg': alg,
    'crv': crv,
    'kid': '$credentialDid' //#${credentialDid.split(':').last
  };

  var payload = {
    'aud': credentialIssuer,
    'iat': DateTime.now().millisecondsSinceEpoch,
  };
  if (cNonce != null) {
    payload['nonce'] = cNonce;
  }
  logger.d(credentialDid);
  var jwt = await signStringOrJson(
      wallet: wallet.wallet,
      didToSignWith: credentialDid,
      toSign: payload,
      jwsHeader: header,
      detached: false);
  //end JWT creation

  return (credentialDid, jwt);
}

Future<void> getCredential(
    String credentialIssuer,
    CredentialIssuerMetaData? metadata,
    CredentialsSupportedObject credentialMetadata,
    OidcTokenResponse tokenResponse) async {
  if (metadata == null) {
    // get metadata
    var issuerMetaReq = await get(
        Uri.parse('$credentialIssuer/.well-known/openid-credential-issuer'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (issuerMetaReq.statusCode != 200) {
      showErrorMessage('Keine Issuer Metadaten');
      return;
    }

    metadata = CredentialIssuerMetaData.fromJson(issuerMetaReq.body);
  }

  if (tokenResponse.cNonce == null) {
    // send false cred request to get cNonce
    var credentialRequest = OidcCredentialRequest(
      format: credentialMetadata.format,
      credentialType: credentialMetadata.credentialType,
    );

    var credentialResponse = await post(Uri.parse(metadata.credentialEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${tokenResponse.accessToken}'
            },
            body: credentialRequest.toString())
        .timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (credentialResponse.statusCode != 200) {
      tokenResponse.cNonce = jsonDecode(credentialResponse.body)['c_nonce'];
    }
  }
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  String proofType;
  String credentialDid;
  dynamic proofValue;

  if (credentialMetadata.proofTypesSupported == null) {
    proofType = 'jwt';
    (credentialDid, proofValue) =
        await buildJwt([], wallet, tokenResponse.cNonce, credentialIssuer);
  } else if (credentialMetadata.proofTypesSupported!.containsKey('ldp_vp')) {
    proofType = 'ldp_vp';
    credentialDid = await wallet.newCredentialDid();
    // create VP
    var presentation = VerifiablePresentation(
        context: [credentialsV1Iri, ed25519ContextIri],
        type: ['VerifiablePresentation'],
        holder: credentialDid);
    var signer = EdDsaSigner(loadDocumentFast);
    var p = await signer.buildProof(
        presentation.toJson(), wallet.wallet, credentialDid,
        challenge: tokenResponse.cNonce,
        domain: credentialIssuer,
        proofPurpose: 'authentication');
    presentation.proof = [LinkedDataProof.fromJson(p)];
    // end VP creation
    proofValue = presentation.toJson();
  } else if (credentialMetadata.proofTypesSupported!.containsKey('jwt')) {
    proofType = 'jwt';
    (credentialDid, proofValue) = await buildJwt(
        credentialMetadata.proofTypesSupported?['jwt'] ?? [],
        wallet,
        tokenResponse.cNonce,
        credentialIssuer);
  } else {
    showErrorMessage('Proof type nicht unterstützt');
    return;
  }

  var credentialRequest = OidcCredentialRequest(
      format: credentialMetadata.format,
      credentialType: credentialMetadata.credentialType,
      context: credentialMetadata.context,
      proof:
          CredentialRequestProof(proofType: proofType, proofValue: proofValue));

  // var credentialRequest = {
  //   'format': credentialMetadata.format,
  //   'doctype': credentialMetadata.credentialType!.first,
  //   'types': credentialMetadata.credentialType,
  //   'proof': {'proof_type': 'jwt', 'jwt': jwt}
  // };
  //
  // var credentialRequestLdp = {
  //   'format': credentialMetadata.format,
  //   'types': credentialMetadata.credentialType,
  //   'proof': {'proof_type': 'ldp_vp', 'vp': presentation.toJson()}
  // };
  //
  // logger.d(credentialRequest);
  // logger.d(credentialRequestLdp);
  KeyPair? decryptionKey;
  if (metadata.credentialResponseEncryptionRequired ?? false) {
    var alg = metadata.credentialResponseEncryptionAlgSupported!;
    if (alg.contains('RSA-OAEP-256')) {
      credentialRequest.responseEncryptionAlg = 'RSA-OAEP-256';
      decryptionKey = KeyPair.generateRsa();
      var jwk = {
        'alg': 'RSA-OAEP-256',
        'kty': 'RSA',
        'use': 'enc',
        'e': removePaddingFromBase64(base64UrlEncode(x509
            .bigIntToByteData(
                (decryptionKey.publicKey as RsaPublicKey).exponent)
            .buffer
            .asUint8List())),
        'n': removePaddingFromBase64(base64UrlEncode(x509
            .bigIntToByteData((decryptionKey.publicKey as RsaPublicKey).modulus)
            .buffer
            .asUint8List()))
      };
      credentialRequest.responseEncryptionJwk = jwk;
      credentialRequest.responseEncryptionEnc =
          metadata.credentialResponseEncryptionEncSupported!.first;
    }
  }

  logger.d(credentialRequest.toJson());

  var credentialResponse = await post(Uri.parse(metadata.credentialEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${tokenResponse.accessToken}'
          },
          body: credentialRequest.toString())
      .timeout(const Duration(seconds: 20), onTimeout: () {
    return Response('Timeout', 400);
  });

  if (credentialResponse.statusCode == 200) {
    logger.d(credentialResponse.body);
    if (decryptionKey != null) {
      logger.d('decryption');
      var split = credentialResponse.body.split('.');
      logger.d('length: ${split.length}');
      var header = jsonDecode(
          utf8.decode(base64Decode(addPaddingToBase64(split.first))));
      logger.d(header);
      var encryptedKey = base64Decode(addPaddingToBase64(split[1]));
      var iv = base64Decode(addPaddingToBase64(split[2]));
      var cipher = base64Decode(addPaddingToBase64(split[3]));
      var tag = base64Decode(addPaddingToBase64(split[4]));

      var encryptor = decryptionKey.privateKey!
          .createEncrypter(algorithms.encryption.rsa.oaep256);
      var decrypted = encryptor.decrypt(EncryptionResult(encryptedKey));

      return;
    }
    var credential = jsonDecode(credentialResponse.body)['credential'];
    var format = credentialMetadata.format;

    if (format == 'iso-mdl') {
      var data = IssuerSignedObject.fromCbor(base64Decode(credential));
      var verified = await verifyMso(data);
      if (verified) {
        var signedData = MobileSecurityObject.fromCbor(data.issuerAuth.payload);
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
                  topLeft: Radius.circular(10), topRight: Radius.circular(10)),
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
        showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .wrongCredentialNote,
        );
        return;
      }

      logger.d(verified);
      if (verified) {
        var credDid = getHolderDidFromCredential(credential);
        logger.d(credDid);
        var storageCred = wallet.getCredential(credDid.split('#').first);
        if (storageCred == null) {
          showErrorMessage(
              AppLocalizations.of(navigatorKey.currentContext!)!.saveError,
              AppLocalizations.of(navigatorKey.currentContext!)!.saveErrorNote);
          return;
        }

        wallet.storeCredential(jsonEncode(credential), storageCred.hdPath);
        wallet.storeExchangeHistoryEntry(
            credDid, DateTime.now(), 'issue', credentialIssuer);

        var asVC = VerifiableCredential.fromJson(credential);

        showModalBottomSheet(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            context: navigatorKey.currentContext!,
            builder: (context) {
              return ModalDismissWrapper(
                child: PaymentFinished(
                  headline: AppLocalizations.of(context)!.credentialReceived,
                  success: true,
                  amount: CurrencyDisplay(
                      amount: getTypeToShow(asVC.type),
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

    showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
        .credentialDownloadFailed);
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
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    logger.d('client id null');
    return;
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
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.downloadFailed,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .downloadFailedExplanation);
      logger.d('no presentation definition found at $presDefUri');
      return;
    }
  } else {
    // Case 3: the total request must be fetched
    logger.d(requestUri);
    logger.d(clientId);

    if (requestUri == null) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.downloadFailed,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .downloadFailedExplanation);
      logger.d('requestUri null');
      return;
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
    logger.d('no nonce');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    return;
  }

  logger.d('Response Mode: $responseMode');

  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var allCreds = wallet.allCredentials();
  var isoCreds = wallet.isoMdocCredentials;
  List<VerifiableCredential> creds = [];
  List<IssuerSignedObject> isoCredsParsed = [];
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
    isoCredsParsed.add(IssuerSignedObject.fromCbor(
        base64Decode(cred.plaintextCredential.replaceAll('isoData:', ''))));
  }

  if (definition == null) {
    logger.d('No presentation definition');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    return;
  }

  try {
    logger.d(isoCredsParsed.length);
    var filtered = searchCredentialsForPresentationDefinition(definition,
        credentials: creds, isoMdocCredentials: isoCredsParsed);
    logger.d(
        'successfully filtered: isoLength: ${filtered.first.isoMdocCredentials?.length}');

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
