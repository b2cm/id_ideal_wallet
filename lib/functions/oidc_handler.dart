import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:base_codecs/base_codecs.dart';
import 'package:cbor/cbor.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/oid.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:id_ideal_wallet/provider/mdoc_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/ausweis_view.dart';
import 'package:id_ideal_wallet/views/credential_offer_new.dart';
import 'package:id_ideal_wallet/views/presentation_request.dart';
import 'package:id_ideal_wallet/views/web_view.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:json_path/json_path.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:provider/provider.dart';
import 'package:sd_jwt/sd_jwt.dart' as sd_jwt;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:x509b/x509.dart' as x509;

import '../l10n/app_localizations.dart';

String removeTrailingSlash(String base64Input) {
  while (base64Input.endsWith('/')) {
    base64Input = base64Input.substring(0, base64Input.length - 1);
  }
  return base64Input;
}

Map<String, dynamic> findClaims(Map? claimsDescription) {
  var claims = <String, dynamic>{};
  claimsDescription ??= {};

  for (var key in claimsDescription.keys) {
    var value = claimsDescription[key];
    if (value is CredentialSubjectMetadata) {
      var displayList = value.display ?? <OidDisplayObject>[];
      var locale =
          AppLocalizations.of(navigatorKey.currentContext!)!.localeName;
      String? defaultName, localName, localeDes, defaultDes;
      for (var d in displayList) {
        if (d.locale != null && d.locale!.startsWith('en')) {
          defaultName = d.name;
          defaultDes = d.description;
        }
        if (d.locale != null && d.locale!.startsWith(locale)) {
          localName = d.name;
          localeDes = d.description;
        }
      }
      claims[localName ?? defaultName ?? key] = localeDes ?? defaultDes ?? '';
    } else if (value is Map) {
      claims.addAll(findClaims(value));
    } else if (value is List) {
      for (var v in value) {
        claims.addAll(findClaims(v));
      }
    }
  }

  logger.d(claims);
  return claims;
}

Map<String, dynamic> getClaimsFromDescriptionObject(
    List<ClaimsDescriptionObject> description) {
  var claims = <String, dynamic>{};
  for (var d in description) {
    logger.d(claims);
    d.path.setValueAtPath(
        d.display?.first.description ?? d.display?.first.name ?? '', claims);
  }

  return claims;
}

Future<void> handleOfferOid(String offerUri) async {
  var offer = OidCredentialOffer.fromUri(offerUri);

  var issuerString = removeTrailingSlash(offer.credentialIssuer);
  logger.d('$issuerString/.well-known/openid-credential-issuer');

  // get metadata
  Response issuerMetaReq;
  try {
    issuerMetaReq = await get(
        Uri.parse('$issuerString/.well-known/openid-credential-issuer'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20), onTimeout: () {
      return Response('Timeout', 400);
    });

    if (issuerMetaReq.statusCode != 200) {
      logger.d(
          'Bad Status code: ${issuerMetaReq.statusCode} /${issuerMetaReq.body}');
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.oidMetadataError,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .oidMetadataErrorNote);
      return;
    }
  } catch (e) {
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.oidMetadataError,
        AppLocalizations.of(navigatorKey.currentContext!)!
            .oidMetadataErrorNote);
    return;
  }

  CredentialIssuerMetaData issuerMetadata;
  try {
    issuerMetadata = CredentialIssuerMetaData.fromJson(issuerMetaReq.body);
  } catch (e) {
    logger.d('Failed parsing issuer metadata: $e');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.oidMetadataError,
        AppLocalizations.of(navigatorKey.currentContext!)!
            .oidMetadataErrorNote);
    return;
  }

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
  for (var s in issuerMetadata.credentialsSupported.values) {
    logger.d(s.toJson());
  }
  for (String t in credentialToRequest) {
    var credConfig = issuerMetadata.credentialsSupported[t];

    if (credConfig == null) {
      logger.d('credential without config');
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.oidMetadataError,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .oidMetadataErrorNote);
      return;
    }
    credConfig.credentialId ??= t;
    offeredCredentials.add(credConfig);
  }

  logger.d(offeredCredentials);

  dynamic res = true;
  res = await Future.delayed(const Duration(seconds: 1), () async {
    return await showCupertinoModalPopup(
      context: navigatorKey.currentContext!,
      barrierColor: Colors.white,
      builder: (BuildContext context) => CredentialOfferDialogNew(
          oidcIssuer: issuerString,
          isOid: true,
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
                  issuer: {'OidEndpoint': issuerString, 'id': issuerString},
                  credentialSubject: e.claimDescriptions != null
                      ? getClaimsFromDescriptionObject(e.claimDescriptions!)
                      : findClaims(e.claims),
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
      // get MetaData
      Map? authServerMetaData;
      Map? clientMetaData = knownAuthServer[authserver.trim()];
      logger.d('authServer: ${knownAuthServer.keys}');
      if (clientMetaData == null) {
        logger.d('no client metadata for $authserver');
        showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
            .unknownAuthServer);
        return;
      }

      var state = const Uuid().v4();
      String pkceCodeVerifier =
          '${const Uuid().v4().toString()}-${const Uuid().v4().toString()}';
      String pkceCodeChallenge = removePaddingFromBase64(
          base64UrlEncode(sha256.process(utf8.encode(pkceCodeVerifier))));

      var configMap = {};
      for (var c in offeredCredentials) {
        configMap[c.credentialId] = c.toJson();
      }
      logger.d(configMap);
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
          .storeConfig(
              state,
              jsonEncode({
                'offer': offer.toJson(),
                'authServer': authserver,
                'credentials': configMap,
                'codeVerifier': pkceCodeVerifier
              }));

      String clientId = clientMetaData['client_id'];
      String redirectUri =
          clientMetaData['redirect_uri'] ?? 'https://wallet.bccm.dev/redirect';

      String authServerQuery = 'response_type=code&client_id=$clientId';
      authServerQuery +=
          '&redirect_uri=${Uri.encodeQueryComponent(redirectUri)}';
      authServerQuery += '&state=$state';
      authServerQuery += '&code_challenge=$pkceCodeChallenge';
      authServerQuery += '&code_challenge_method=S256';

      authServerMetaData = await getAuthServerMetaData(authserver);
      if (authServerMetaData == null) {
        // without config we assume standard endpoint
        launchUrl(Uri.parse('$authserver/authorize?$authServerQuery'));
        logger.d('$authserver without config');
        return;
      }

      String authIssuer = authServerMetaData['issuer'];
      if (authIssuer != authserver) {
        logger.d('$authIssuer != $authserver');
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.oidMetadataError,
            AppLocalizations.of(navigatorKey.currentContext!)!
                .oidMetadataErrorNote);
        return;
      }

      // can we do pushed authorization requests?
      var parEndpoint =
          authServerMetaData['pushed_authorization_request_endpoint'];
      if (parEndpoint != null) {
        if (offeredCredentials.length == 1 &&
            offeredCredentials.first.scope != null) {
          authServerQuery +=
              '&scope=${Uri.encodeQueryComponent(offeredCredentials.first.scope!)}';
        } else {
          List<Map> authDetails = [];
          for (var entry in offeredCredentials) {
            var details = AuthorizationDetailsObject(
                format: entry.format,
                credentialConfigurationId: entry.credentialId,
                credentialType: entry.credentialType);
            authDetails.add(details.toJson());
          }
          authServerQuery +=
              '&authorization_details=${Uri.encodeQueryComponent(jsonEncode(authDetails))}';
        }
        logger.d(authServerQuery);

        var parResponse = await post(Uri.parse(parEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: authServerQuery);

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
          if (clientMetaData['pidIssuer'] != null &&
              clientMetaData['pidIssuer']) {
            navigateClassic(const AusweisView());
            Provider.of<AusweisProvider>(navigatorKey.currentContext!,
                    listen: false)
                .startProgress(authRequest, true);
          } else {
            navigateClassic(WebViewWindow(
              webViewData: AboData(
                  AppLocalizations.of(navigatorKey.currentContext!)!
                      .authorization,
                  authRequest,
                  '',
                  '',
                  '',
                  null),
              isSecure: false,
            ));
          }
          //launchUrl(Uri.parse(authRequest));
          return;
        } else {
          showErrorMessage(
              AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
              AppLocalizations.of(navigatorKey.currentContext!)!
                  .oidAuthFailedNote);
          logger.d(
              'Par request failed: ${parResponse.statusCode} / ${parResponse.body}');
          return;
        }
      } else {
        // if not, use redirect and authorization endpoint
        var authEndpoint = authServerMetaData['authorization_endpoint'];
        if (authEndpoint != null) {
          launchUrl(Uri.parse('$authEndpoint?$authServerQuery'));
          return;
        } else {
          showErrorMessage(
              AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
              AppLocalizations.of(navigatorKey.currentContext!)!
                  .oidAuthFailedNote);
        }
      }
    } else if (offer.grants != null &&
        offer.grants!.containsKey(GrantType.preAuthType)) {
      var authServerMeta = await getAuthServerMetaData(authserver);

      var tokenEndpoint =
          authServerMeta?['token_endpoint'] ?? '$authserver/token';

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
        logger.d(jsonDecode(tokenRes.body));
        OidTokenResponse tokenResponse =
            OidTokenResponse.fromJson(tokenRes.body);

        logger.d('Access-Token : ${tokenResponse.accessToken}');

        for (var credMetadata in offeredCredentials) {
          getCredential(issuerString, issuerMetadata, credMetadata,
              tokenResponse, null, null, null, null);
        }
      } else {
        logger.d(tokenRes.statusCode);
        logger.d(tokenRes.body);

        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!
                .oidAuthFailedNote);
        return;
      }
    } else {
      logger.d('Unbekannte Authentifizierungsmethode');
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
          AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailedNote);
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
        'status OidConfig $authServer: ${oidConfigRes.statusCode} / ${oidConfigRes.body}');
    var oauthConfigRes = await get(
        Uri.parse('$authServer/.well-known/oauth-authorization-server'));
    if (oauthConfigRes.statusCode == 200) {
      return jsonDecode(oauthConfigRes.body);
    } else {
      return null;
    }
  }
}

Future<void> handleRedirect(String uri, [String? dpopNonce]) async {
  // Provider.of<NavigationProvider>(navigatorKey.currentContext!, listen: false)
  //     .goBack();
  Navigator.of(navigatorKey.currentContext!).popUntil((route) => route.isFirst);
  logger.d('redirected uri: $uri');
  var asUri = Uri.parse(uri);
  var state = asUri.queryParameters['state'];
  var code = asUri.queryParameters['code'];
  logger.d('state: $state');
  if (state == null) {
    logger.d('Prozess nicht auffindbar');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailedNote);
    return;
  }
  if (code == null) {
    logger.d('Keinen Auth-Code empfangen');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailedNote);
    return;
  }

  var storedData =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false)
          .getConfig(state);

  if (storedData == null) {
    logger.d('Prozess nicht auffindbar');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailedNote);
    return;
  }

  var parsed = jsonDecode(storedData);
  String authServer = parsed['authServer'];
  String codeVerifier = parsed['codeVerifier'];
  OidCredentialOffer offer = OidCredentialOffer.fromJson(parsed['offer']);
  List<CredentialsSupportedObject> credentialMetadata =
      (parsed['credentials'] as Map)
          .map((k, e) {
            var encoded = CredentialsSupportedObject.fromJson(e);
            encoded.credentialId = k;
            return MapEntry(k, encoded);
          })
          .values
          .toList();

  logger.d('authServer: $authServer, codeVerifier: $codeVerifier');

  Map? clientMetaData = knownAuthServer[authServer];
  if (clientMetaData == null) {
    showErrorMessage(
      AppLocalizations.of(navigatorKey.currentContext!)!.unknownAuthServer,
    );
    return;
  }

  String clientId = clientMetaData['client_id'];
  String redirectUri =
      clientMetaData['redirect_uri'] ?? 'https://wallet.bccm.dev/redirect';

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

  var headers = <String, String>{
    'Content-Type': 'application/x-www-form-urlencoded'
  };

  String? dpopDid, dpopJti;
  if (clientMetaData['dpop'] ?? false) {
    // generate Dpop header
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    dpopDid = await wallet.newCredentialDid(KeyType.p256);
    var dpopJwk = multibaseKeyToJwk(dpopDid.replaceAll('did:key:', ''));
    dpopJti = const Uuid().v4();

    var dpopPayload = {
      'jti': dpopJti,
      'htm': 'POST',
      'htu': tokenEndpoint,
      'nonce': dpopNonce
    };
    var jwt =
        sd_jwt.Jwt(additionalClaims: dpopPayload, issuedAt: DateTime.now());
    var dpopJws = await jwt.sign(
        signer: WalletCryptoProviderForSdJwt(wallet.wallet, dpopDid),
        header: sd_jwt.JwsJoseHeader(
            algorithm: sd_jwt.SigningAlgorithm.ecdsaSha256Prime,
            jsonWebKey: sd_jwt.Jwk.fromJson(dpopJwk),
            type: 'dpop+jwt'));
    logger.d(dpopPayload);

    headers['DPoP'] = dpopJws.toCompactSerialization();
  }

  var tokenRes =
      await post(Uri.parse(tokenEndpoint), headers: headers, body: parameter)
          .timeout(const Duration(seconds: 20), onTimeout: () {
    return Response('Timeout', 400);
  });

  if (tokenRes.statusCode == 200) {
    logger.d(
        'successful token request: ${jsonDecode(tokenRes.body).keys.toList()}');
    var decoded = OidTokenResponse.fromJson(tokenRes.body);
    logger.d(tokenRes.headers);
    // var payload = decoded.accessToken!.split('.')[1];
    // logger.d(
    //     'decodedPayload: ${jsonDecode(utf8.decode((base64Decode(addPaddingToBase64(payload)))))}');
    getCredential(
        removeTrailingSlash(offer.credentialIssuer),
        null,
        credentialMetadata.first,
        decoded,
        clientId,
        dpopDid,
        dpopJti,
        tokenRes.headers['dpop-nonce']);
  } else {
    logger.d('Error token request: ${tokenRes.statusCode} / ${tokenRes.body}');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailed,
        AppLocalizations.of(navigatorKey.currentContext!)!.oidAuthFailedNote);
  }
}

Future<(String, dynamic, KeyType)> buildJwt(
    List<String> algValues,
    List<String> bindingMethods,
    WalletProvider wallet,
    String? cNonce,
    String credentialIssuer,
    String? clientId,
    [KeyStore keystore = KeyStore.software]) async {
  String credentialDid, alg, crv;
  KeyType keyType;
  if (algValues.contains('ES256')) {
    credentialDid =
        await wallet.newCredentialDid(KeyType.p256, keystore, <String, dynamic>{
      'attestationChallenge': 'abc',
      //'userAuthenticationRequired': true
    });
    alg = 'ES256';
    crv = 'P-256';
    keyType = KeyType.p256;
  } else if (algValues.contains('ES384')) {
    credentialDid = await wallet.newCredentialDid(KeyType.p384, keystore);
    alg = 'ES384';
    crv = 'P-384';
    keyType = KeyType.p384;
  } else if (algValues.contains('ES512')) {
    credentialDid = await wallet.newCredentialDid(KeyType.p521, keystore);
    alg = 'ES512';
    crv = 'P-521';
    keyType = KeyType.p521;
  } else {
    credentialDid = await wallet.newCredentialDid();
    alg = 'EdDSA';
    crv = 'Ed25519';
    keyType = KeyType.ed25519;
  }
  // create JWT
  var ddo = resolveDidKey(credentialDid).convertAllKeysToJwk().resolveKeyIds();
  var jwk = ddo.verificationMethod!.first.publicKeyJwk!;
  jwk.remove('kid');
  var header = <String, dynamic>{
    'typ': 'openid4vci-proof+jwt',
    'alg': alg,
    'crv': crv,
    // 'kid': credentialDid,
    // 'kid':
    //     'did:jwk:${removePaddingFromBase64(base64UrlEncode(utf8.encode(jsonEncode(jwk))))}#0',
    //'jwk': ddo.verificationMethod!.first.publicKeyJwk
    //#${credentialDid.split(':').last
  };

  logger.d('binding methods: $bindingMethods');

  if (bindingMethods.isEmpty || bindingMethods.contains('did:key')) {
    header['kid'] = credentialDid;
  } else if (bindingMethods.contains('jwk') ||
      bindingMethods.contains('cose_key')) {
    header['jwk'] = ddo.verificationMethod!.first.publicKeyJwk;
  } else if (bindingMethods.contains('did:jwk')) {
    header['kid'] =
        'did:jwk:${removePaddingFromBase64(base64UrlEncode(utf8.encode(jsonEncode(jwk))))}#0';
  } else {
    showErrorMessage(
      AppLocalizations.of(navigatorKey.currentContext!)!
          .credentialDownloadFailed,
    );
    throw Exception('unsupported binding method');
  }
  logger.d(header);
  logger.d(credentialDid);
  var headerParsed = sd_jwt.JoseHeader.fromJson(header);
  var jwt = sd_jwt.Jwt(
      audience: credentialIssuer,
      issuedAt: DateTime.now(),
      issuer: clientId,
      additionalClaims: cNonce != null ? {'nonce': cNonce} : null);
  var keyId = keystore == KeyStore.software
      ? credentialDid
      : wallet.getOsKeyStoreIdForDid(credentialDid);
  var jws = await jwt.sign(
      signer: WalletCryptoProviderForSdJwt(wallet.wallet, keyId!),
      header: headerParsed as sd_jwt.JwsJoseHeader);

  return (credentialDid, jws.toCompactSerialization(), keyType);
}

Future<void> getCredential(
    String credentialIssuer,
    CredentialIssuerMetaData? metadata,
    CredentialsSupportedObject credentialMetadata,
    OidTokenResponse tokenResponse,
    String? clientId,
    String? dpopDid,
    String? dpopJti,
    String? dpopNonce) async {
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
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.oidMetadataError,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .oidMetadataErrorNote);
      return;
    }

    metadata = CredentialIssuerMetaData.fromJson(issuerMetaReq.body);
  }

  if (tokenResponse.cNonce == null) {
    logger.d('need new c_nonce');
    if (metadata.nonceEndpoint != null) {
      var nonceResponse = await post(Uri.parse(metadata.nonceEndpoint!));
      if (nonceResponse.statusCode == 200 || nonceResponse.statusCode == 201) {
        try {
          tokenResponse.cNonce = jsonDecode(nonceResponse.body)['c_nonce'];
        } catch (e) {
          logger.d('Keine nonce: $e');
          showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .credentialDownloadFailed,
          );
          return;
        }
      } else {
        showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!
              .credentialDownloadFailed,
        );
        return;
      }
    } else {
      // send false cred request to get cNonce
      var credentialRequest = OidCredentialRequest(
        format: credentialMetadata.format,
        credentialType: credentialMetadata.credentialType,
      );

      var credentialResponse =
          await post(Uri.parse(metadata.credentialEndpoint),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${tokenResponse.accessToken}'
                  },
                  body: credentialRequest.toString())
              .timeout(const Duration(seconds: 20), onTimeout: () {
        return Response('Timeout', 400);
      });

      if (credentialResponse.statusCode != 200) {
        try {
          tokenResponse.cNonce = jsonDecode(credentialResponse.body)['c_nonce'];
        } catch (e) {
          logger.d('Keine nonce: $e');
          showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!
                .credentialDownloadFailed,
          );
          return;
        }
      }
    }
  }

  logger.d('c_nonce: ${tokenResponse.cNonce}');
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  String proofType;
  String credentialDid;
  dynamic proofValue;
  KeyType keyType;
  KeyStore k = KeyStore.software;

  if (credentialMetadata.format == OidCredentialFormat.msoMdoc &&
      credentialMetadata.credentialType != null &&
      credentialMetadata.credentialType!
          .contains(MobileDriversLicense.docType)) {
    k = KeyStore.system;
    logger.d('other keystore');
  }

  if (credentialMetadata.proofTypesSupported == null) {
    proofType = 'jwt';
    (credentialDid, proofValue, keyType) = await buildJwt([],
        credentialMetadata.cryptographicBindingMethods ?? [],
        wallet,
        tokenResponse.cNonce,
        credentialIssuer,
        clientId,
        k);
  } else if (credentialMetadata.proofTypesSupported!.containsKey('jwt')) {
    proofType = 'jwt';
    (credentialDid, proofValue, keyType) = await buildJwt(
        credentialMetadata
                .proofTypesSupported?['jwt']?.signingAlgValuesSupported
                .cast<String>() ??
            [],
        credentialMetadata.cryptographicBindingMethods ?? [],
        wallet,
        tokenResponse.cNonce,
        credentialIssuer,
        clientId,
        k);
  } else if (credentialMetadata.proofTypesSupported!.containsKey('ldp_vp')) {
    proofType = 'ldp_vp';
    credentialDid = await wallet.newCredentialDid();
    // create VP
    var presentation = VerifiablePresentation(holder: credentialDid);
    var (signer, type) = await getCredentialSigningStuff(wallet, credentialDid);
    await presentation.addProof(signer, type,
        challenge: tokenResponse.cNonce, domain: credentialIssuer);
    // end VP creation
    proofValue = presentation.toJson();
    keyType = KeyType.ed25519;
  } else {
    logger.d('Proof type nicht unterstützt');
    showErrorMessage(
      AppLocalizations.of(navigatorKey.currentContext!)!
          .credentialDownloadFailed,
    );
    return;
  }

  var credentialRequest = OidCredentialRequest(
      format: credentialMetadata.format,
      credentialType: credentialMetadata.credentialType,
      context: credentialMetadata.context,
      credentialConfigurationId: credentialMetadata.credentialId,
      proof: [
        CredentialRequestProof(proofType: proofType, proofValue: proofValue)
      ]);

  logger.d(credentialRequest);

  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>? decryptionKey;
  if (metadata.credentialResponseEncryptionRequired ?? false) {
    var alg = metadata.credentialResponseEncryptionAlgSupported!;
    if (alg.contains('RSA-OAEP-256')) {
      var rsaKeyGen = pc.RSAKeyGenerator();
      final rsaParams =
          pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64);
      final paramsWithRnd =
          pc.ParametersWithRandom(rsaParams, getSecureRandom());
      rsaKeyGen.init(paramsWithRnd);
      decryptionKey = rsaKeyGen.generateKeyPair();
      credentialRequest.responseEncryptionAlg = 'RSA-OAEP-256';
      var jwk = {
        'alg': 'RSA-OAEP-256',
        'kty': 'RSA',
        'use': 'enc',
        'e': removePaddingFromBase64(base64UrlEncode(x509
            .bigIntToByteData(decryptionKey.publicKey.exponent!)
            .buffer
            .asUint8List())),
        'n': removePaddingFromBase64(base64UrlEncode(x509
            .bigIntToByteData(decryptionKey.publicKey.modulus!)
            .buffer
            .asUint8List()))
      };
      credentialRequest.responseEncryptionJwk = jwk;
      credentialRequest.responseEncryptionEnc =
          metadata.credentialResponseEncryptionEncSupported!.first;
    }
  }

  logger.d(credentialRequest.toJson());

  logger.d('credential Endpoint: ${metadata.credentialEndpoint}');

  var headers = <String, String>{
    'Content-Type': 'application/json',
  };
  if (dpopDid != null && dpopJti != null) {
    headers['Authorization'] = 'DPoP ${tokenResponse.accessToken}';
    var dpopPayload = {
      'jti': dpopJti,
      'htm': 'POST',
      'htu': metadata.credentialEndpoint,
      'nonce': dpopNonce,
      'ath': removePaddingFromBase64(base64UrlEncode(
          sha256.process(ascii.encode(tokenResponse.accessToken!))))
    };
    var jwt =
        sd_jwt.Jwt(additionalClaims: dpopPayload, issuedAt: DateTime.now());
    var dpopJwk = multibaseKeyToJwk(dpopDid.replaceAll('did:key:', ''));
    var dpopJws = await jwt.sign(
        signer: WalletCryptoProviderForSdJwt(wallet.wallet, dpopDid),
        header: sd_jwt.JwsJoseHeader(
            algorithm: sd_jwt.SigningAlgorithm.ecdsaSha256Prime,
            jsonWebKey: sd_jwt.Jwk.fromJson(dpopJwk),
            type: 'dpop+jwt'));
    logger.d(dpopPayload);

    headers['DPoP'] = dpopJws.toCompactSerialization();

    logger.d(dpopPayload);
  } else {
    headers['Authorization'] = 'Bearer ${tokenResponse.accessToken}';
  }

  var credentialResponse = await post(Uri.parse(metadata.credentialEndpoint),
          headers: headers, body: credentialRequest.toString())
      .timeout(const Duration(seconds: 20), onTimeout: () {
    return Response('Timeout', 400);
  });

  if (credentialResponse.statusCode == 200) {
    OidCredentialResponse decodedCredentialResponse;
    logger.d(credentialResponse.body);
    if (decryptionKey != null) {
      try {
        decodedCredentialResponse =
            decryptResponse(decryptionKey, credentialResponse.body);
      } catch (e) {
        logger.d(e);
        logger.d('Fehler beim Entschlüsseln');
        showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!
              .credentialDownloadFailed,
        );
        return;
      }
    } else {
      decodedCredentialResponse =
          OidCredentialResponse.fromJson(credentialResponse.body);
    }
    var format = credentialMetadata.format;

    if (decodedCredentialResponse.transactionId != null) {
      // deferred flow
      if (metadata.deferredCredentialEndpoint == null) {
        logger.d('No deferred endpoint');
        showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
            .credentialDownloadFailed);
        return;
      }
      logger.d('deferred request after 3 seconds');
      Timer(
          const Duration(seconds: 3),
          () => sendDeferredRequest(
              format,
              credentialDid,
              wallet,
              keyType,
              credentialIssuer,
              tokenResponse.accessToken!,
              metadata!.deferredCredentialEndpoint!,
              decodedCredentialResponse.transactionId!,
              decryptionKey));
    } else {
      try {
        storeCredential(
            format,
            decodedCredentialResponse.credential ??
                decodedCredentialResponse.credentials?.first.credential,
            credentialDid,
            wallet,
            credentialIssuer);
      } catch (e) {
        showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
            .credentialDownloadFailed);
      }
    }
  } else {
    logger.d(credentialResponse.statusCode);
    logger.d(credentialResponse.headers);
    logger.d(credentialResponse.body);
  }
}

OidCredentialResponse decryptResponse(
    pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey> decryptionKey,
    String data) {
  logger.d('decryption');
  var split = data.split('.');
  logger.d('length: ${split.length}');
  var header =
      jsonDecode(utf8.decode(base64Decode(addPaddingToBase64(split.first))));
  logger.d(header);
  var encryptedKey = base64Decode(addPaddingToBase64(split[1]));
  var iv = base64Decode(addPaddingToBase64(split[2]));
  var cipher = base64Decode(addPaddingToBase64(split[3]));
  var tag = base64Decode(addPaddingToBase64(split[4]));

  var decrypt = pc.OAEPEncoding.withSHA256(pc.RSAEngine());
  decrypt.init(false,
      pc.PrivateKeyParameter<pc.RSAPrivateKey>(decryptionKey.privateKey));
  var decrypted = decrypt.process(encryptedKey);

  logger.d(iv);

  Uint8List decrypted2;
  var enc = header['enc'];
  if (enc == 'A128GCM' || enc == 'A192GCM' || enc == 'A256GCM') {
    var algorithm = pc.GCMBlockCipher(pc.AESEngine());
    algorithm.init(
        false,
        pc.AEADParameters(
          pc.KeyParameter(decrypted),
          128,
          iv,
          ascii.encode(split.first),
        ));
    decrypted2 = algorithm.process(Uint8List.fromList(cipher + tag));
  } else {
    int macLength, blockLength;
    pc.Digest digest;
    if (enc == 'A128CBC-HS256') {
      macLength = 16;
      blockLength = 64;
      digest = pc.SHA256Digest();
    } else if (enc == 'A192CBC-HS384') {
      macLength = 24;
      blockLength = 64;
      digest = pc.SHA384Digest();
    } else if (enc == 'A256CBC-HS512') {
      digest = pc.SHA512Digest();
      blockLength = 128;
      macLength = 32;
    } else {
      throw Exception('Unknown algorithm $enc');
    }

    var mac = pc.HMac(digest, blockLength);
    var al = ascii.encode(split.first).length * 8;
    var alHex = al.toRadixString(16).padLeft(16, '0');
    mac.init(pc.KeyParameter(decrypted.sublist(0, macLength)));
    var computedMac = mac.process(Uint8List.fromList(
        ascii.encode(split.first) + iv + cipher + hexDecode(alHex)));

    logger.d('tag: $tag');
    logger.d('computed: $computedMac');
    if (!listEquals(computedMac.sublist(0, macLength), tag)) {
      throw Exception('Invalid tag');
    }

    var algorithm = pc.PaddedBlockCipher('AES/CBC/PKCS7');
    algorithm.init(
        false,
        pc.PaddedBlockCipherParameters(
            pc.ParametersWithIV(
                pc.KeyParameter(decrypted.sublist(macLength)), iv),
            null));
    decrypted2 = algorithm.process(Uint8List.fromList(cipher));
  }
  logger.d(utf8.decode(decrypted2));
  return OidCredentialResponse.fromJson(utf8.decode(decrypted2));
}

sendDeferredRequest(
    String format,
    String credentialDid,
    WalletProvider wallet,
    KeyType keyType,
    String credentialIssuer,
    String authToken,
    String endpoint,
    String transactionId,
    pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>?
        decryptionKey) async {
  var credentialResponse = await post(Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken'
          },
          body: jsonEncode({'transaction_id': transactionId}))
      .timeout(const Duration(seconds: 20), onTimeout: () {
    return Response('Timeout', 400);
  });

  if (credentialResponse.statusCode == 200) {
    OidCredentialResponse decodedCredentialResponse;

    if (decryptionKey != null) {
      try {
        decodedCredentialResponse =
            decryptResponse(decryptionKey, credentialResponse.body);
      } catch (e) {
        showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
            .credentialDownloadFailed);
        return;
      }
    } else {
      decodedCredentialResponse =
          OidCredentialResponse.fromJson(credentialResponse.body);
    }
    storeCredential(format, decodedCredentialResponse.credential, credentialDid,
        wallet, credentialIssuer);
  } else {
    logger.d('${credentialResponse.statusCode} / ${credentialResponse.body}');
    var parsedBody = jsonDecode(credentialResponse.body);
    var error = parsedBody['error'];
    if (error == 'issuance_pending') {
      int interval = parsedBody['interval'] ?? 5;
      Timer(
          Duration(seconds: interval),
          () => sendDeferredRequest(
              format,
              credentialDid,
              wallet,
              keyType,
              credentialIssuer,
              authToken,
              endpoint,
              transactionId,
              decryptionKey));
    } else {
      showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
          .credentialDownloadFailed);
    }
  }
}

storeCredential(String format, dynamic credential, String credentialDid,
    WalletProvider wallet, String credentialIssuer) async {
  if (format == OidCredentialFormat.msoMdoc) {
    printWrapped(credential);
    logger.d(cborDecode(base64Decode(addPaddingToBase64(credential))));
    var data = IssuerSignedObject.fromCbor(
        base64Decode(addPaddingToBase64(credential)));
    var doc = data;
    var verified = await verifyMso(doc);
    if (verified) {
      var signedData = MobileSecurityObject.fromCbor(doc.issuerAuth.payload);
      logger.d(signedData.deviceKeyInfo.deviceKey);
      var did = coseKeyToDid(signedData.deviceKeyInfo.deviceKey);
      logger.d('$did == $credentialDid');
      if (did != credentialDid) {
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
            AppLocalizations.of(navigatorKey.currentContext!)!
                .wrongCredentialNote2);
        return;
      }
      logger.d(wallet.getOsKeyStoreIdForDid(did));
      var credSubject = <String, dynamic>{'id': credentialDid};
      doc.items.forEach((key, value) {
        for (var i in value) {
          credSubject[i.dataElementIdentifier] = i.dataElementValue.toString();
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
                base64UrlEncode(doc.issuerAuth.unprotected.x509chain!.first)
          },
          credentialSubject: credSubject,
          issuanceDate: signedData.validityInfo.validFrom,
          expirationDate: signedData.validityInfo.validUntil);

      logger.d(vc.toJson());

      // var storageCred = wallet.getCredential(credentialDid);
      //
      // if (storageCred == null) {
      //   showErrorMessage(
      //       AppLocalizations.of(navigatorKey.currentContext!)!.saveError,
      //       AppLocalizations.of(navigatorKey.currentContext!)!.saveErrorNote);
      //   return;
      // }

      wallet.storeCredential(
        vc,
        credentialDid,
        isoMdlData: '$isoPrefix:${base64Encode(doc.toEncodedCbor())}',
      );
      wallet.storeExchangeHistoryEntry(
          credentialDid, DateTime.now(), 'issue', credentialIssuer);

      showSuccessMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.credentialReceived,
          signedData.docType);
    } else {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .wrongCredentialNote);
    }
  } else if (format == OidCredentialFormat.sdJwt ||
      format == OidCredentialFormat.sdJwtDc) {
    sd_jwt.SdJws parsed;
    try {
      parsed = sd_jwt.SdJws.fromCompactSerialization(credential);
    } catch (e) {
      showErrorMessage(AppLocalizations.of(navigatorKey.currentContext!)!
          .credentialDownloadFailed);
      return;
    }
    logger.d(parsed.jsonContent());
    var iss = parsed.jsonContent()['payload']['iss'];
    var issMetaUrl = '$iss/.well-known/jwt-vc-issuer';

    logger.d(issMetaUrl);

    var metaRes = await get(Uri.parse(issMetaUrl));
    if (metaRes.statusCode != 200) {
      logger.d('Kein Public Key, Verifikation nicht möglich');
      showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
      );
      return;
    }

    var data = jsonDecode(metaRes.body);
    var jwks = data['jwks'];
    logger.d(jwks);
    List keys = jwks['keys'];
    logger.d(keys);
    Map k = keys.first;
    var jwk = sd_jwt.Jwk.fromJson(
        k.map((key, value) => MapEntry(key as String, value)));
    var sd = sd_jwt.SdJwt.fromSdJws(parsed);
    var verified = await sd.verify(
        parsed,
        jwk.key is sd_jwt.EcPublicKey
            ? sd_jwt.PointyCastleCryptoProvider(jwk.key as sd_jwt.EcPublicKey)
            : sd_jwt.Ed25519EdwardsCryptoProvider(
                jwk.key as sd_jwt.EdPublicKey));

    if (!verified) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .wrongCredentialNote);
      return;
    }

    var cnf = sd.confirmation!.toJson();
    logger.d(cnf['jwk']);
    var multibase = jwkToMultiBase(cnf['jwk']);
    logger.d('$credentialDid, did:key:$multibase');
    var restoredDid = 'did:key:$multibase';
    if (restoredDid != credentialDid) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
          AppLocalizations.of(navigatorKey.currentContext!)!
              .wrongCredentialNote2);
      return;
    }

    var claims = sd.additionalClaims ?? {};
    var type = claims.remove('vct');
    claims['id'] = restoredDid;

    var vc = VerifiableCredential(
        id: restoredDid,
        context: [credentialsV1Iri, schemaOrgIri],
        type: ['VerifiableCredential', type],
        issuer: {
          'id': credentialIssuer,
          if (jwk.x509CertificateChain != null)
            'certificate': jwk.x509CertificateChain!.first
        },
        credentialSubject: claims,
        issuanceDate: sd.issuedAt,
        expirationDate: sd.expirationTime);

    // var storageCred = wallet.getCredential(restoredDid);
    // if (storageCred == null) {
    //   showErrorMessage(
    //       AppLocalizations.of(navigatorKey.currentContext!)!.saveError,
    //       AppLocalizations.of(navigatorKey.currentContext!)!.saveErrorNote);
    //   return;
    // }

    wallet.storeCredential(vc, restoredDid,
        isoMdlData: '$sdPrefix:$credential');
    wallet.storeExchangeHistoryEntry(
        credentialDid, DateTime.now(), 'issue', credentialIssuer);

    showSuccessMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.credentialReceived,
        type);
    return;
  } else {
    logger.d(credential);
    var asVc = VerifiableCredential.fromJson(credential);

    var verified = false;
    try {
      verified = await asVc.verify(loadDocument: loadDocumentFast);
    } catch (e) {
      showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
        AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredentialNote,
      );
      return;
    }

    logger.d(verified);
    if (verified) {
      var credDid = asVc.credentialSubject['id'];
      logger.d(credDid);

      wallet.storeCredential(asVc, credDid);
      wallet.storeExchangeHistoryEntry(
          credDid, DateTime.now(), 'issue', credentialIssuer);

      showSuccessMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.credentialReceived,
          getTypeToShow(asVc.type));
    } else {
      showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredential,
        AppLocalizations.of(navigatorKey.currentContext!)!.wrongCredentialNote,
      );
      return;
    }
  }
}

sendErrorResponse(String responseUri, String mode, String errorCode) {
  if (mode.startsWith('direct_post')) {
    post(Uri.parse(responseUri),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'error=$errorCode');
  } else {
    launchUrl(Uri.parse('$responseUri?error=$errorCode'),
        mode: LaunchMode.externalApplication);
  }
}

Future<void> handlePresentationRequestOid(String request) async {
  var asUri = Uri.parse(request);
  RequestObject requestData;

  try {
    if (asUri.queryParameters.containsKey('request_uri')) {
      // fetch request
      var method = asUri.queryParameters['request_uri_method'] ?? 'get';
      logger.d('${asUri.queryParameters['request_uri']!} / $method');
      Response requestRaw;
      if (method == 'get') {
        requestRaw = await get(Uri.parse(asUri.queryParameters['request_uri']!),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            });
      } else if (method == 'post') {
        var walletMetadata = AuthorizationServerMetadata(
          vpFormatsSupported: VpFormats(
              ldp: VpFormatLdp(proofTypeValues: [
                LdpProofType.ed25519Signature2020.value,
                LdpProofType.jsonWebSignature2020.value
              ]),
              sdJwt: VpFormatSdJwt(
                  sdJwtAlgValues: ['ES256', 'ES384', 'ES512', 'EdDSA'],
                  kbJwtAlgValues: ['ES256', 'ES384', 'ES512', 'EdDSA']),
              msoMdoc: VpFormatMsoMdoc(issuerAuthAlgValues: [
                CoseAlgorithm.es256,
                CoseAlgorithm.es384,
                CoseAlgorithm.es512,
                CoseAlgorithm.edDSA,
                -9,
                -52,
                -51,
                -19
              ], deviceAuthAlgValues: [
                CoseAlgorithm.es256,
                CoseAlgorithm.es384,
                CoseAlgorithm.es512,
                CoseAlgorithm.edDSA,
                -9,
                -52,
                -51,
                -19
              ])),
        );
        requestRaw = await post(
            Uri.parse(asUri.queryParameters['request_uri']!),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/oauth-authz-req+jwt'
            },
            body:
                'wallet_metadata=${Uri.encodeQueryComponent(walletMetadata.toString())}');
      } else {
        logger.d('Unknown requestUriMethod $method');
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.downloadFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!
                .downloadFailedExplanation);
        return;
      }
      logger.d(requestRaw.statusCode);
      if (requestRaw.statusCode != 200) {
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.downloadFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!
                .downloadFailedExplanation);
        logger.d('Request nicht gefunden');
        return;
      }
      logger.d(requestRaw.headers);
      logger.d(requestRaw.body);

      if (isRawJson(requestRaw.body)) {
        logger.d('raw json');
        requestData = RequestObject.fromJson(requestRaw.body);
      } else {
        // it is a jwt/jws (as normally expected)
        logger.d('jwt');
        var payload = requestRaw.body.split('.')[1];
        logger.d(
            jsonDecode(utf8.decode(base64Decode(addPaddingToBase64(payload)))));
        requestData = RequestObject.fromJson(
            utf8.decode(base64Decode(addPaddingToBase64(payload))));
      }

      if (requestData.clientMetaDataUri != null) {
        var metaDataResponse =
            await get(Uri.parse(requestData.clientMetaDataUri!), headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        });
        if (metaDataResponse.statusCode == 200) {
          requestData.clientMetaData =
              ClientMetaData.fromJson(metaDataResponse.body);
        }
      }
    } else {
      requestData = RequestObject.fromJson(asUri.queryParameters);
    }
  } catch (e) {
    logger.d(e);
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    return;
  }

  if (requestData.presentationDefinitionUri != null) {
    var presDefResponse =
        await get(Uri.parse(requestData.presentationDefinitionUri!));
    if (presDefResponse.statusCode == 200) {
      requestData.presentationDefinition =
          PresentationDefinition.fromJson(presDefResponse.body);
    }
  }

  logger.d('Response Mode: ${requestData.responseMode}');

  if (requestData.clientId == null) {
    logger.d('no clientId');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);

    if (requestData.responseUri != null || requestData.redirectUri != null) {
      sendErrorResponse(requestData.responseUri ?? requestData.redirectUri!,
          requestData.responseMode!, 'invalid_request');
    }
    return;
  }

  if (requestData.nonce == null) {
    logger.d('no nonce');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    sendErrorResponse(
        requestData.responseUri ??
            requestData.redirectUri ??
            requestData.clientId!,
        requestData.responseMode!,
        'invalid_request');
    return;
  }

  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var allCreds = wallet.w3cCredentials;
  var isoCreds = wallet.isoMdocCredentials;
  List<VerifiableCredential> creds = [];
  List<IssuerSignedObject> isoCredsParsed = [];
  List<sd_jwt.SdJws> sdJwtCredentials = [];

  for (var vc in allCreds) {
    var type = getTypeToShow(vc.type);
    if (type != 'PaymentReceipt') {
      creds.add(vc);
    }
  }

  for (var cred in isoCreds) {
    var iso = IssuerSignedObject.fromCbor(
        base64Decode(cred.metadata.replaceAll('$isoPrefix:', '')));
    var mso = MobileSecurityObject.fromCbor(iso.issuerAuth.payload);
    if (mso.validityInfo.validUntil.isAfter(DateTime.now())) {
      isoCredsParsed.add(iso);
    }
  }

  for (var c in wallet.sdJwtCredentials) {
    sdJwtCredentials.add(sd_jwt.SdJws.fromCompactSerialization(
        c.metadata.replaceAll('$sdPrefix:', '')));
  }

  List<FilterResult> filtered;
  if (requestData.presentationDefinition != null) {
    filtered = searchCredentialsForPresentationDefinition(
        requestData.presentationDefinition!,
        credentials: creds,
        isoMdocCredentials: isoCredsParsed,
        sdJwtCredentials: sdJwtCredentials);
    logger.d(
        'successfully filtered: sdLength: ${filtered.first.sdJwtCredentials?.length}');
  } else if (requestData.dcqlQuery != null) {
    filtered = await searchCredentialsForDcqlQuery(requestData.dcqlQuery!,
        w3cCredentials: creds,
        mdocCredentials: isoCredsParsed,
        sdJwtCredentials: sdJwtCredentials);
  } else {
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    sendErrorResponse(
        requestData.responseUri ??
            requestData.redirectUri ??
            requestData.clientId!,
        requestData.responseMode!,
        'access_denied');
    return;
  }

  try {
    logger.d(isoCredsParsed.length);

    var target = PresentationRequestDialog(
      definition: requestData.presentationDefinition ??
          PresentationDefinition(inputDescriptors: []),
      otherEndpoint: requestData.responseUri ??
          requestData.redirectUri ??
          requestData.clientId!,
      results: filtered,
    );

    var (_, toSend) = await navigateClassic(target);
    if (toSend != null) {
      sendPresentationResponse(toSend, requestData);
    } else {
      sendErrorResponse(
          requestData.responseUri ??
              requestData.redirectUri ??
              requestData.clientId!,
          requestData.responseMode!,
          'access_denied');
    }
  } catch (e) {
    logger.e(e);
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsTitle,
        AppLocalizations.of(navigatorKey.currentContext!)!.noCredentialsNote);
    sendErrorResponse(
        requestData.responseUri ??
            requestData.redirectUri ??
            requestData.clientId!,
        requestData.responseMode!,
        'access_denied');
  }
}

Future<(dynamic, PresentationSubmission, String?)> buildAnswer(
    List<FilterResult> finalSend,
    WalletProvider wallet,
    RequestObject requestData) async {
  dynamic vp;
  List<InputDescriptorMappingObject> descriptorMap = [];
  String definitionId = '';
  bool hasW3C = false;
  String? mdocGeneratedNonce;
  var responseUri = requestData.responseUri ??
      requestData.redirectUri ??
      requestData.clientId!;

  logger.d((requestData.toJson()));
  vp = requestData.presentationDefinition != null ? [] : <String, dynamic>{};
  logger.d(vp.runtimeType);

  for (FilterResult entry in finalSend) {
    definitionId = entry.presentationDefinitionId;

    if (entry.nestedResults != null && entry.nestedResults!.isNotEmpty) {
      var (vpIn, sub, mnonce) =
          await buildAnswer(entry.nestedResults!, wallet, requestData);
      vp.addAll(vpIn);
      descriptorMap.addAll(sub.descriptorMap);
    } else {
      if (entry.isoMdocCredentials != null &&
          entry.isoMdocCredentials!.isNotEmpty) {
        logger.d('handle mdoc');
        var handover = OID4VPHandover.fromValues(
            requestData.clientId!, responseUri, requestData.nonce!);
        mdocGeneratedNonce = handover.mdocGeneratedNonce;
        List<Document> docs = [];

        for (var cred in entry.isoMdocCredentials!) {
          var mso = MobileSecurityObject.fromCbor(cred.issuerAuth.payload);
          var did = coseKeyToDid(mso.deviceKeyInfo.deviceKey);
          int? alg = getCoseAlgorithmForDid(did);
          if (alg == null) {
            throw Exception('no algorithm');
          }

          var transcript = SessionTranscript(handover: handover);
          var ds = await generateDeviceSignature({}, mso.docType, transcript,
              signer: WalletSigner(wallet, did, alg));
          docs.add(Document(
              docType: mso.docType, issuerSigned: cred, deviceSigned: ds));
        }

        var res = DeviceResponse(status: 0, documents: docs);

        descriptorMap.add(InputDescriptorMappingObject(
            id: entry.matchingDescriptorIds.first,
            format: OidCredentialFormat.msoMdoc,
            path: JsonPath(r'$')));

        if (requestData.presentationDefinition != null) {
          vp.add(removePaddingFromBase64(base64UrlEncode(res.toEncodedCbor())));
        } else {
          dynamic existing = vp[entry.matchingDescriptorIds.first];
          dynamic toAdd;
          if (existing is List) {
            existing.add(
                removePaddingFromBase64(base64UrlEncode(res.toEncodedCbor())));
            toAdd = existing;
          } else if (existing is String) {
            toAdd = [
              existing,
              removePaddingFromBase64(base64UrlEncode(res.toEncodedCbor()))
            ];
          } else {
            toAdd =
                removePaddingFromBase64(base64UrlEncode(res.toEncodedCbor()));
          }
          vp[entry.matchingDescriptorIds.first] = toAdd;
        }
      }

      if (entry.credentials != null && entry.credentials!.isNotEmpty) {
        logger.d('handle w3c');

        if (requestData.presentationDefinition != null) {
          hasW3C = true;
        } else {
          var vpW3c =
              VerifiablePresentation(verifiableCredential: entry.credentials);
          int index = 0;
          for (var vc in vpW3c.verifiableCredential!) {
            var did = vc.credentialSubject['id'];
            if (did == null || did == '') continue;
            var (signer, proofType) =
                await getCredentialSigningStuff(wallet, did);
            await vpW3c.addProof(signer, proofType,
                challenge: requestData.nonce, loadDocument: loadDocumentFast);
            if (requestData.presentationDefinition != null) {
              for (var descriptorId in entry.matchingDescriptorIds) {
                descriptorMap.add(InputDescriptorMappingObject(
                    id: descriptorId,
                    format: OidCredentialFormat.ldpVc,
                    path: JsonPath(
                        '\$${entry.sdJwtCredentials != null && entry.sdJwtCredentials!.isNotEmpty ? '[${vp.length}]' : ''}.verifiableCredential[$index]')));
                index++;
              }
            }
          }
          dynamic existing = vp[entry.matchingDescriptorIds.first];
          dynamic toAdd;
          if (existing is List) {
            existing.add(vpW3c);
            toAdd = existing;
          } else if (existing is Map) {
            toAdd = [existing, vpW3c];
          } else {
            toAdd = vpW3c;
          }
          vp[entry.matchingDescriptorIds.first] = toAdd;
        }
      }

      int arrayIndex = 0;
      if (entry.sdJwtCredentials != null &&
          entry.sdJwtCredentials!.isNotEmpty) {
        logger.d('handle sd jwt');
        List sdJwtCreds = [];
        for (var s in entry.sdJwtCredentials!) {
          var sd = s.toSdJwt();

          var cnf = sd.confirmation!.toJson();
          logger.d(cnf['jwk']);
          var multibase = jwkToMultiBase(cnf['jwk']);
          var restoredDid = 'did:key:$multibase';

          sd_jwt.SigningAlgorithm? algorithm;
          if (restoredDid.startsWith('did:key:zQ3s')) {
            algorithm = sd_jwt.SigningAlgorithm.ecdsaSha256Koblitz;
          } else if (restoredDid.startsWith('did:key:zDn')) {
            algorithm = sd_jwt.SigningAlgorithm.ecdsaSha256Prime;
          } else if (restoredDid.startsWith('did:key:z82')) {
            algorithm = sd_jwt.SigningAlgorithm.ecdsaSha384Prime;
          } else if (restoredDid.startsWith('did:key:z2J9')) {
            algorithm = sd_jwt.SigningAlgorithm.ecdsaSha512Prime;
          } else if (restoredDid.startsWith('did:key:z6Mk')) {
            algorithm = sd_jwt.SigningAlgorithm.eddsa25519Sha512;
          }

          var signed = await s.bind(
              signer: WalletCryptoProviderForSdJwt(wallet.wallet, restoredDid),
              audience: requestData.clientId!,
              issuedAt: DateTime.now(),
              nonce: requestData.nonce!,
              signingAlgorithm: algorithm!);

          logger.d(signed);
          printWrapped(signed.toCompactSerialization());
          var kbJwtParsed = signed.keyBindingJws!.toKbJwt();
          logger.d(base64.encode(signed.digest) ==
              base64.encode(kbJwtParsed.sdHash));

          sdJwtCreds.add(signed.toCompactSerialization());

          descriptorMap.add(InputDescriptorMappingObject(
              id: entry.matchingDescriptorIds.first,
              format: OidCredentialFormat.sdJwtDc,
              path: JsonPath(
                  '\$${vp.isEmpty && entry.sdJwtCredentials!.length == 1 ? '' : '[${arrayIndex + vp.length - 1}]'}')));
          arrayIndex++;
        }

        if (requestData.presentationDefinition != null) {
          vp.addAll(sdJwtCreds);
        } else {
          dynamic existing = vp[entry.matchingDescriptorIds.first];
          dynamic toAdd;
          if (existing is List) {
            existing.addAll(sdJwtCreds);
            toAdd = existing;
          } else if (existing is String) {
            toAdd = [existing, ...sdJwtCreds];
          } else {
            toAdd = sdJwtCreds.length == 1 ? sdJwtCreds.first : sdJwtCreds;
          }
          vp[entry.matchingDescriptorIds.first] = toAdd;
        }
      }
    }
  }

  if (hasW3C) {
    logger.d('build w3c from filter result');
    var vpW3C = VerifiablePresentation.fromFilterResults(finalSend);
    for (var vc in vpW3C.verifiableCredential!) {
      var did = vc.credentialSubject['id'];
      if (did == null || did == '') continue;
      var (signer, proofType) = await getCredentialSigningStuff(wallet, did);
      await vpW3C.addProof(signer, proofType,
          challenge: requestData.nonce, loadDocument: loadDocumentFast);
    }
    vp.add(vpW3C.toJson());
    descriptorMap = vpW3C.presentationSubmission!.descriptorMap;
    definitionId = vpW3C.presentationSubmission!.presentationDefinitionId;
    logger.d(vpW3C.toJson());
    logger.d(vp);
  }

  return (
    vp,
    PresentationSubmission(
        presentationDefinitionId: definitionId, descriptorMap: descriptorMap),
    mdocGeneratedNonce
  );
}

sendPresentationResponse(
    List<FilterResult> finalSend, RequestObject requestData) async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var responseUri = requestData.responseUri ??
      requestData.redirectUri ??
      requestData.clientId!;

  dynamic vp;
  PresentationSubmission submission;
  String? mdocGeneratedNonce;

  try {
    (vp, submission, mdocGeneratedNonce) =
        await buildAnswer(finalSend, wallet, requestData);
  } catch (e) {
    logger.d('build answer failed: $e');
    sendErrorResponse(
        responseUri, requestData.responseMode ?? 'query', 'server_error');
    showErrorMessage(
        AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
        AppLocalizations.of(navigatorKey.currentContext!)!.sendFailedNote);
    return;
  }

  logger.d('send presentation to $responseUri');
  Response res;

  if (requestData.responseMode == 'direct_post') {
    String vpAnswer = vp is List && vp.length == 1
        ? vp.first is String
            ? vp.first
            : jsonEncode(vp.first)
        : jsonEncode(vp);
    var uriString = 'vp_token=${Uri.encodeQueryComponent(vpAnswer)}';
    if (requestData.presentationDefinition != null) {
      uriString +=
          '&presentation_submission=${Uri.encodeQueryComponent(submission.toString())}';
    }
    if (requestData.state != null) {
      uriString += '&state=${Uri.encodeQueryComponent(requestData.state!)}';
    }
    res = await post(Uri.parse(responseUri),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: uriString);
  } else if (requestData.responseMode == 'direct_post.jwt') {
    if (requestData.clientMetaData?.authEncryptedResponseAlg != null &&
        requestData.clientMetaData?.authEncryptedResponseEnc != null) {
      // we should build jwe
      List<Map<String, dynamic>>? jwks;
      if (requestData.clientMetaData?.jwksUri != null) {
        var res = await get(Uri.parse(requestData.clientMetaData!.jwksUri!));
        if (res.statusCode == 200) {
          var body = jsonDecode(res.body);

          var keys = (body['keys'] as List).cast<Map>();
          jwks = keys
              .map((e) => e.map((key, value) => MapEntry(key as String, value)))
              .toList();
        }
      } else {
        jwks = requestData.clientMetaData?.jwks;
      }
      if (jwks == null) {
        logger.d('no jwks found');
        sendErrorResponse(responseUri, requestData.responseMode ?? 'query',
            'invalid_request');
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!.sendFailedNote);
        return;
      }
      Map<String, dynamic> readerKey;
      try {
        readerKey = jwks.firstWhere((element) =>
            element['alg'] ==
            requestData.clientMetaData!.authEncryptedResponseAlg);
      } catch (e) {
        logger.d('no suitableKey');
        sendErrorResponse(responseUri, requestData.responseMode ?? 'query',
            'invalid_request');
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!.sendFailedNote);
        return;
      }
      var crv = readerKey['crv'];

      logger.d(readerKey);
      KeyType walletKeyType;
      if (crv == 'P-256') {
        walletKeyType = KeyType.p256;
      } else if (crv == 'X25519') {
        walletKeyType = KeyType.x25519;
      } else if (crv == 'P-384') {
        walletKeyType = KeyType.p384;
      } else if (crv == 'P-521') {
        walletKeyType = KeyType.p521;
      } else {
        walletKeyType = KeyType.secp256k1;
      }
      var cDid = await wallet.newConnectionDid(walletKeyType);

      var myJwkPub = resolveDidKey(cDid)
          .convertAllKeysToJwk()
          .resolveKeyIds()
          .verificationMethod!
          .first
          .publicKeyJwk;

      var enc = requestData.clientMetaData!.authEncryptedResponseEnc!;

      var header = {
        'alg': requestData.clientMetaData!.authEncryptedResponseAlg,
        'enc': enc,
        'kid': readerKey['kid'],
        'apv': base64Encode(utf8.encode(requestData.nonce!)),
        'apu': mdocGeneratedNonce,
        'epk': myJwkPub
      };

      logger.d(header);

      if (header['alg'] == 'ECDH-ES') {
        var sharedSecret = await ecdhES(
            WalletKeyAgreementGenerator(wallet.wallet, cDid),
            readerKey,
            header['alg'],
            enc,
            apu: header['apu'],
            apv: header['apv']);

        logger.d('$sharedSecret, ${sharedSecret.length}');

        // build aad ( ASCII(BASE64URL(UTF8(JWE Protected Header))) )
        var aad = ascii.encode(removePaddingFromBase64(
            base64UrlEncode(utf8.encode(jsonEncode(header)))));

        //data
        var data = {
          'vp_token': vp is List && vp.length == 1 ? vp.first : vp,
        };
        logger.d(vp);

        if (requestData.presentationDefinition != null) {
          logger.d(submission);
          data['presentation_submission'] = submission;
        }
        if (requestData.state != null) {
          data['state'] = requestData.state;
        }

        //4) Generate IV
        var iv = getSecureRandom().nextBytes(16);

        Uint8List encrypted2, tag;
        if (enc == 'A128GCM' || enc == 'A192GCM' || enc == 'A256GCM') {
          var algorithm = pc.GCMBlockCipher(pc.AESEngine());
          algorithm.init(
              true,
              pc.AEADParameters(
                pc.KeyParameter(Uint8List.fromList(sharedSecret)),
                128,
                iv,
                aad,
              ));
          var res = algorithm
              .process(Uint8List.fromList(utf8.encode(jsonEncode(data))));
          encrypted2 = res.sublist(0, res.length - 16);
          tag = res.sublist(res.length - 16);
        } else {
          int macLength, blockLength;
          pc.Digest digest;
          if (enc == 'A128CBC-HS256') {
            macLength = 16;
            blockLength = 64;
            digest = pc.SHA256Digest();
          } else if (enc == 'A192CBC-HS384') {
            macLength = 24;
            blockLength = 64;
            digest = pc.SHA384Digest();
          } else if (enc == 'A256CBC-HS512') {
            digest = pc.SHA512Digest();
            blockLength = 128;
            macLength = 32;
          } else {
            logger.d('Unsupported enc $enc');
            sendErrorResponse(responseUri, requestData.responseMode ?? 'query',
                'server_error');
            showErrorMessage(
                AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
                AppLocalizations.of(navigatorKey.currentContext!)!
                    .sendFailedNote);
            return;
          }

          var algorithm = pc.PaddedBlockCipher('AES/CBC/PKCS7');
          algorithm.init(
              true,
              pc.PaddedBlockCipherParameters(
                  pc.ParametersWithIV(
                      pc.KeyParameter(
                          Uint8List.fromList(sharedSecret.sublist(macLength))),
                      iv),
                  null));
          encrypted2 = algorithm
              .process(Uint8List.fromList(utf8.encode(jsonEncode(data))));

          var mac = pc.HMac(digest, blockLength);
          var al = aad.length * 8;
          var alHex = al.toRadixString(16).padLeft(16, '0');
          mac.init(pc.KeyParameter(
              Uint8List.fromList(sharedSecret.sublist(0, macLength))));
          var computedMac = mac.process(
              Uint8List.fromList(aad + iv + encrypted2 + hexDecode(alHex)));
          tag = computedMac.sublist(0, macLength);
        }

        var jwe =
            '${removePaddingFromBase64(base64UrlEncode(utf8.encode(jsonEncode(header))))}..${removePaddingFromBase64(base64UrlEncode(iv))}.${removePaddingFromBase64(base64UrlEncode(encrypted2))}.${removePaddingFromBase64(base64UrlEncode(tag))}';

        logger.d('jwe: $jwe');
        var httpClient = io.HttpClient();
        var request = await httpClient.postUrl(Uri.parse(responseUri));
        request.headers
            .set('Content-Type', 'application/x-www-form-urlencoded');
        request.write(
            'response=${Uri.encodeQueryComponent(jwe)}${requestData.state != null ? '&state=${Uri.encodeQueryComponent(requestData.state!)}' : ''}');

        var response = await request.close();
        res = Response(
            await response.transform(utf8.decoder).join(), response.statusCode);
        // res = await post(Uri.parse(widget.otherEndpoint),
        //     headers: {'content-type': 'application/x-www-form-urlencoded'},
        //     body:
        //         'response=${Uri.encodeQueryComponent(jwe)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}');
        if (requestData.redirectUri != null) {
          launchUrl(Uri.parse(requestData.redirectUri!),
              mode: LaunchMode.externalApplication);
        }
      } else {
        logger.d('Unsupported alg ${header['alg']}');
        sendErrorResponse(
            responseUri, requestData.responseMode ?? 'query', 'server_error');
        showErrorMessage(
            AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
            AppLocalizations.of(navigatorKey.currentContext!)!.sendFailedNote);
        return;
      }
    } else {
      logger.d('jwt requested but no enc and alg given');
      sendErrorResponse(
          responseUri, requestData.responseMode ?? 'query', 'invalid_request');
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.sendFailed,
          AppLocalizations.of(navigatorKey.currentContext!)!.sendFailedNote);
      return;
    }
  } else {
    String vpAnswer = vp.length == 1
        ? vp.first is String
            ? vp.first
            : jsonEncode(vp.first)
        : jsonEncode(vp);
    var uriString =
        '$responseUri?vp_token=${Uri.encodeQueryComponent(vpAnswer)}';
    if (requestData.presentationDefinition != null) {
      uriString +=
          '&presentation_submission=${Uri.encodeQueryComponent(submission.toString())}';
    }
    if (requestData.state != null) {
      uriString += '&state=${Uri.encodeQueryComponent(requestData.state!)}';
    }
    logger.d(uriString);

    var r = await launchUrl(Uri.parse(uriString),
        mode: LaunchMode.externalApplication);
    if (r) {
      res = Response('', 200);
    } else {
      res = Response('', 400);
    }
  }

  logger.d(res.statusCode);
  logger.d(res.body);
  if ((res.statusCode == 200 || res.statusCode == 201)) {
    String type = '';

    for (var entry in finalSend) {
      for (var cred in entry.credentials ?? <VerifiableCredential>[]) {
        wallet.storeExchangeHistoryEntry(cred.credentialSubject['id'],
            DateTime.now(), 'present', responseUri);

        type += '${getTypeToShow(cred.type)}, \n';
      }
      logger.d(type);

      for (var cred in entry.isoMdocCredentials ?? <IssuerSignedObject>[]) {
        var mso = MobileSecurityObject.fromCbor(cred.issuerAuth.payload);

        var did = coseKeyToDid(mso.deviceKeyInfo.deviceKey);
        wallet.storeExchangeHistoryEntry(
            did, DateTime.now(), 'present', responseUri);

        type += '${mso.docType}, \n';
      }
      logger.d(type);

      for (var cred in entry.sdJwtCredentials ?? <sd_jwt.SdJws>[]) {
        var sdJwt = cred.toSdJwt();

        var cnf = sdJwt.confirmation!.toJson();
        logger.d(cnf['jwk']);
        var multibase = jwkToMultiBase(cnf['jwk']);
        var restoredDid = 'did:key:$multibase';
        wallet.storeExchangeHistoryEntry(
            restoredDid, DateTime.now(), 'present', responseUri);

        var vct = sdJwt.additionalClaims?['vct'] ?? '';
        type += '$vct, \n';
      }
    }

    if (type.length >= 3) {
      type = type.substring(0, type.length - 3);
    }
    logger.d(type);

    await showModalBottomSheet(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), topRight: Radius.circular(10)),
        ),
        context: navigatorKey.currentContext!,
        builder: (context) {
          return ModalDismissWrapper(
            child: PaymentFinished(
              headline: AppLocalizations.of(navigatorKey.currentContext!)!
                  .presentationSuccessful,
              success: true,
              amount: CurrencyDisplay(
                  amount: type, symbol: '', mainFontSize: 18, centered: true),
            ),
          );
        });

    //Navigator.of(context).pop();

    try {
      Map bodyData = jsonDecode(res.body);
      if (bodyData.containsKey('redirect_uri')) {
        launchUrl(Uri.parse(bodyData['redirect_uri']),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      logger.d('no json response: $e');
    }
  } else {
    await showModalBottomSheet(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10), topRight: Radius.circular(10))),
        context: navigatorKey.currentContext!,
        builder: (context) {
          return ModalDismissWrapper(
            closeSeconds: 4,
            child: PaymentFinished(
              headline: AppLocalizations.of(navigatorKey.currentContext!)!
                  .presentationFailed,
              success: false,
              amount: const CurrencyDisplay(
                  width: 350,
                  amount: '',
                  symbol: '',
                  mainFontSize: 18,
                  centered: true),
            ),
          );
        });
    // Navigator.of(context).pop();
  }
}
