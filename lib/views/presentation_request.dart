import 'dart:convert';
import 'dart:io' as io
    show HttpClient, Platform, SecurityContext, TlsProtocolVersion;
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:dart_ssi/did.dart';
import 'package:dart_ssi/didcomm.dart';
import 'package:dart_ssi/oidc.dart';
import 'package:dart_ssi/util.dart';
import 'package:dart_ssi/wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/basicUi/standard/issuance_info.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/basicUi/standard/requester_info.dart';
import 'package:id_ideal_wallet/basicUi/standard/secured_widget.dart';
import 'package:id_ideal_wallet/constants/kaprion_context.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/oidc_handler.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:id_ideal_wallet/provider/mdoc_provider.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/credential_page.dart';
import 'package:id_ideal_wallet/views/self_issuance.dart';
import 'package:iso_mdoc/iso_mdoc.dart';
import 'package:json_path/json_path.dart';
import 'package:provider/provider.dart';
import 'package:sd_jwt/sd_jwt.dart' as sd_jwt;
import 'package:url_launcher/url_launcher.dart';
import 'package:x509b/x509.dart';

import '../functions/didcomm_message_handler.dart';

class PresentationRequestDialog extends StatefulWidget {
  final List<FilterResult> results;
  final String? name, purpose;
  final String myDid;
  final String otherEndpoint;
  final String receiverDid;
  final String definitionHash;
  final RequestPresentation? message;
  final bool isOidc, askForBackground, isIso;
  final String? nonce, oidcState, oidcResponseMode, oidcRedirectUri;
  final String? lnInvoice;
  final Map<String, dynamic>? lnInvoiceRequest;
  final List<VerifiableCredential>? paymentCards;
  final X509Certificate? requesterCert;
  final ClientMetaData? oidcClientMetadata;
  final PresentationDefinition definition;

  const PresentationRequestDialog(
      {super.key,
      required this.results,
      required this.receiverDid,
      required this.myDid,
      required this.otherEndpoint,
      required this.definitionHash,
      required this.definition,
      this.askForBackground = false,
      this.name,
      this.purpose,
      this.message,
      this.isOidc = false,
      this.isIso = false,
      this.nonce,
      this.lnInvoice,
      this.lnInvoiceRequest,
      this.paymentCards,
      this.requesterCert,
      this.oidcResponseMode,
      this.oidcState,
      this.oidcClientMetadata,
      this.oidcRedirectUri});

  @override
  PresentationRequestDialogState createState() =>
      PresentationRequestDialogState();
}

class PresentationRequestDialogState extends State<PresentationRequestDialog> {
  //'Database' for Checkboxes
  Map<String, bool> selectedCredsPerResult = {};
  bool dataEntered = true;
  bool send = false;
  bool fulfillable = true;
  bool backgroundAllow = true;
  String amount = '';

  @override
  initState() {
    super.initState();
    int outerPos = 0;
    int innerPos = 0;
    for (var res in widget.results) {
      innerPos = 0;
      for (var _ in res.isoMdocCredentials ?? []) {
        if (innerPos == 0) {
          selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
        } else {
          if (res.submissionRequirement?.min != null &&
              innerPos < res.submissionRequirement!.min!) {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
          } else {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = false;
          }
        }
        innerPos++;
      }
      for (var _ in res.credentials ?? []) {
        if (innerPos == 0) {
          selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
        } else {
          if (res.submissionRequirement?.min != null &&
              innerPos < res.submissionRequirement!.min!) {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
          } else {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = false;
          }
        }
        innerPos++;
      }
      for (var _ in res.sdJwtCredentials ?? []) {
        if (innerPos == 0) {
          selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
        } else {
          if (res.submissionRequirement?.min != null &&
              innerPos < res.submissionRequirement!.min!) {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = true;
          } else {
            selectedCredsPerResult['o${outerPos}i$innerPos'] = false;
          }
        }
        innerPos++;
      }

      outerPos++;
    }

    getAmount();
  }

  Future<void> getAmount() async {
    if (widget.lnInvoice != null && widget.paymentCards != null) {
      var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
          listen: false);
      var paymentId = widget.paymentCards!.first.id!;
      var lnInKey = wallet.getLnInKey(paymentId);
      var i = await decodeInvoice(lnInKey!, widget.lnInvoice!);
      amount = i.amount.toSat().toStringAsFixed(2);
      logger.d(amount);
      setState(() {});
    }
  }

  List<Widget> buildChilds() {
    List<Widget> childList = [];
    int outerPos = 0;
    int innerPos = 0;
    fulfillable = true;

    //overall name
    if (widget.name != null) {
      childList.add(
        Text(
          widget.name!,
          style: Theme.of(context).primaryTextTheme.headlineLarge,
        ),
      );
      childList.add(const SizedBox(
        height: 10,
      ));
    }

    // Requesting entity
    if (!inOidcTest) {
      childList.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: RequesterInfo(
            requesterUrl: widget.otherEndpoint,
            requesterCert: widget.requesterCert,
            followingText:
                ' ${AppLocalizations.of(navigatorKey.currentContext!)!.noteGetInformation}:',
          ),
        ),
      );
      childList.add(const SizedBox(
        height: 10,
      ));
    }

    if (widget.askForBackground) {
      childList.add(CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.backgroundPresentation),
          subtitle: Text(AppLocalizations.of(context)!
              .backgroundPresentationNote(widget.otherEndpoint)),
          value: backgroundAllow,
          onChanged: (newValue) {
            if (newValue != null) {
              backgroundAllow = newValue;
              setState(() {});
            }
          }));
      childList.add(const SizedBox(
        height: 10,
      ));
    }

    for (var result in widget.results) {
      var outerTileChildList = <Widget>[];
      var outerTileExpanded = false;

      if (result.selfIssuable != null && result.selfIssuable!.isNotEmpty) {
        var pos = outerPos;
        dataEntered = false;
        if ((result.credentials != null && result.credentials!.isNotEmpty) ||
            (result.isoMdocCredentials != null &&
                result.isoMdocCredentials!.isNotEmpty)) {
          dataEntered = true;
        }
        for (var i in result.selfIssuable!) {
          outerTileExpanded = true;
          outerTileChildList.add(
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              child: ElevatedButton(
                onPressed: () async {
                  Map res;
                  int index;
                  var target = CredentialSelfIssue(
                    input: [i],
                    outerPos: pos,
                  );
                  (res, index) = await navigateClassic(target);
                  if (res.isNotEmpty) {
                    var wallet = Provider.of<WalletProvider>(
                        navigatorKey.currentContext!,
                        listen: false);
                    var did = await wallet.newCredentialDid();

                    var credSubject = <dynamic, dynamic>{'id': did};
                    credSubject.addAll(res);
                    var cred = VerifiableCredential(
                        context: [
                          credentialsV1Iri,
                          'https://schema.org',
                          ed25519ContextIri
                        ],
                        type: [
                          'VerifiableCredential',
                          'SelfIssuedCredential'
                        ],
                        id: did,
                        issuer: did,
                        credentialSubject: credSubject,
                        issuanceDate: DateTime.now());
                    var signed = await signCredential(wallet.wallet, cred);
                    logger.d(signed);
                    widget.results[index].selfIssuable!.remove(i);
                    if (widget.results[index].selfIssuable!.isEmpty) {
                      widget.results[index].selfIssuable = null;
                    }
                    var cList = widget.results[index].credentials ?? [];
                    cList.add(VerifiableCredential.fromJson(signed));
                    widget.results[index].credentials = cList;
                    logger.d(widget.results);
                    selectedCredsPerResult[
                            'o${pos}i${widget.results[index].credentials!.length - 1}'] =
                        true;
                    dataEntered = true;
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                ),
                child: Text(AppLocalizations.of(navigatorKey.currentContext!)!
                    .enterData),
              ),
            ),
          );
        }

        if (result.credentials != null && result.credentials!.isNotEmpty) {
          outerTileChildList.add(const Text(
            'oder',
            style: TextStyle(fontWeight: FontWeight.bold),
          ));
        }
      }
      int credCount = result.selfIssuable?.length ?? 0;
      var selectedCredNames = <String>[];
      innerPos = 0;

      // iso credentials
      for (var v in result.isoMdocCredentials ?? <IssuerSignedObject>[]) {
        var mso = MobileSecurityObject.fromCbor(v.issuerAuth.payload);
        Map<String, dynamic> subject = {};
        for (var k in v.items.keys) {
          //namespaces
          var items = v.items[k];
          for (var i in items!) {
            subject[i.dataElementIdentifier] = i.dataElementValue;
          }
        }
        var key = 'o${outerPos}i$innerPos';
        logger.d(key);
        if (selectedCredsPerResult[key]!) {
          credCount++;
          selectedCredNames.add(mso.docType);
        }
        outerTileChildList.add(
          ExpansionTile(
            leading: Checkbox(
                activeColor: Colors.greenAccent.shade700,
                onChanged: (bool? newValue) {
                  setState(() {
                    if (newValue != null) {
                      selectedCredsPerResult[key] = newValue;
                    }
                  });
                },
                value: selectedCredsPerResult[key]),
            title: Text(mso.docType),
            children: buildCredSubject(subject),
          ),
        );
        innerPos++;
      }

      // w3c VCDM
      for (var v in result.credentials ?? []) {
        var key = 'o${outerPos}i$innerPos';
        logger.d(key);
        if (selectedCredsPerResult[key]!) {
          credCount++;
          selectedCredNames.add(getTypeToShow(v.type));
        }
        outerTileChildList.add(
          ExpansionTile(
            leading: Checkbox(
                activeColor: Colors.greenAccent.shade700,
                onChanged: (bool? newValue) {
                  setState(() {
                    if (newValue != null) {
                      selectedCredsPerResult[key] = newValue;
                    }
                  });
                },
                value: selectedCredsPerResult[key]),
            title: Text(getTypeToShow(v.type)),
            children: buildCredSubject(v.credentialSubject),
          ),
        );
        innerPos++;
      }

      // sd Jwt
      for (var v in result.sdJwtCredentials ?? <sd_jwt.SdJws>[]) {
        var sd = v.unverified();
        Map<String, dynamic> subject = sd.claims;

        var type = subject.remove('vct');
        var key = 'o${outerPos}i$innerPos';

        logger.d(key);
        if (selectedCredsPerResult[key]!) {
          credCount++;
          selectedCredNames.add(type);
        }
        outerTileChildList.add(
          ExpansionTile(
            leading: Checkbox(
                activeColor: Colors.greenAccent.shade700,
                onChanged: (bool? newValue) {
                  setState(() {
                    if (newValue != null) {
                      selectedCredsPerResult[key] = newValue;
                    }
                  });
                },
                value: selectedCredsPerResult[key]),
            title: Text(type),
            children: buildCredSubject(subject),
          ),
        );
        innerPos++;
      }

      if (!result.fulfilled) {
        logger.d('entirely not');
        fulfillable = false;
      }

      var minCount = result.submissionRequirement?.min ??
          result.submissionRequirement?.count ??
          1;
      if (credCount < minCount) {
        logger.d('less creds: $credCount < $minCount');
        fulfillable = false;
      }

      if (!fulfillable) {
        outerTileExpanded = true;
        outerTileChildList.add(IssuanceInfo(
            definition: widget.definition,
            descriptorIds: result.matchingDescriptorIds));
      }

      var outerTile = ExpansionTile(
        initiallyExpanded: outerTileExpanded,
        title: SizedBox(
          child: RichText(
            text: TextSpan(
                style: Theme.of(context).primaryTextTheme.bodyMedium,
                children: [
                  TextSpan(
                      text:
                          '${credCount - (result.selfIssuable?.length ?? 0)} / $minCount ',
                      style: Theme.of(context)
                          .primaryTextTheme
                          .bodyMedium!
                          .copyWith(
                            color: result.fulfilled
                                ? Colors.greenAccent.shade700
                                : Colors.red,
                          )),
                  TextSpan(
                      text: result.submissionRequirement?.name ??
                          selectedCredNames.toSet().join(', '))
                ]),
          ),
        ),
        subtitle: result.submissionRequirement?.purpose != null
            ? Text(
                result.submissionRequirement!.purpose!,
                style: Theme.of(context).primaryTextTheme.bodySmall,
              )
            : null,
        children: outerTileChildList,
      );
      childList.add(outerTile);
      outerPos++;
    }

    // overall purpose
    if (widget.purpose != null) {
      childList.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: RequesterInfo(
                  requesterUrl: widget.otherEndpoint,
                  followingText:
                      ' ${AppLocalizations.of(context)!.notePresentationPurpose}:\n${widget.purpose}'),
            ),
          ),
        ),
      );
    }

    if (widget.lnInvoice != null) {
      childList.add(const SizedBox(
        height: 10,
      ));
      childList.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade200,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).primaryTextTheme.titleMedium,
                children: [
                  TextSpan(
                    text: AppLocalizations.of(navigatorKey.currentContext!)!
                        .paymentInformation,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  WidgetSpan(
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 1,
                        bottom: 5,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 18,
                        // color: Colors.redAccent.shade700,
                      ),
                    ),
                  ),
                  TextSpan(
                      text:
                          '\n${AppLocalizations.of(navigatorKey.currentContext!)!.paymentInformationDetail}',
                      style: Theme.of(context).primaryTextTheme.bodySmall),
                  TextSpan(
                      text: '$amount sat',
                      style: Theme.of(context).primaryTextTheme.titleLarge),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    if (widget.lnInvoiceRequest != null) {
      childList.add(const SizedBox(
        height: 10,
      ));
      childList.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade200,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).primaryTextTheme.titleMedium,
                children: [
                  const TextSpan(
                    text: 'Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                      text:
                          '\n${AppLocalizations.of(navigatorKey.currentContext!)!.funding1}',
                      style: Theme.of(context).primaryTextTheme.bodySmall),
                  TextSpan(
                      text: ' ${widget.lnInvoiceRequest?['amount']} sat ',
                      style: Theme.of(context).primaryTextTheme.titleLarge),
                  TextSpan(
                      text: AppLocalizations.of(navigatorKey.currentContext!)!
                          .funding2,
                      style: Theme.of(context).primaryTextTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    return childList;
  }

  Future<dynamic> sendAnswer() async {
    setState(() {
      send = true;
    });

    var wallet = Provider.of<WalletProvider>(context, listen: false);
    if (widget.askForBackground && backgroundAllow) {
      wallet.addAuthorizedApp(widget.otherEndpoint, widget.definitionHash);
    }

    List<FilterResult> finalSend = [];
    Set<String> issuerDids = {};
    int outerPos = 0;
    int innerPos = 0;
    for (var result in widget.results) {
      List<VerifiableCredential> credList = [];
      List<IssuerSignedObject> credListIso = [];
      List<sd_jwt.SdJws> credListSd = [];

      innerPos = 0;

      for (var cred in result.isoMdocCredentials ?? []) {
        if (selectedCredsPerResult['o${outerPos}i$innerPos']!) {
          credListIso.add(cred);
        }
        innerPos++;
      }

      for (var cred in result.credentials ?? []) {
        if (selectedCredsPerResult['o${outerPos}i$innerPos']!) {
          credList.add(cred);

          issuerDids.add(getIssuerDidFromCredential(cred.toJson()));
        }
        innerPos++;
      }

      for (var cred in result.sdJwtCredentials ?? []) {
        if (selectedCredsPerResult['o${outerPos}i$innerPos']!) {
          credListSd.add(cred);
        }
        innerPos++;
      }

      outerPos++;

      finalSend.add(FilterResult(
          credentials: credList,
          isoMdocCredentials: credListIso,
          sdJwtCredentials: credListSd,
          matchingDescriptorIds: result.matchingDescriptorIds,
          presentationDefinitionId: result.presentationDefinitionId,
          submissionRequirement: result.submissionRequirement));
    }

    if (widget.isIso) {
      return finalSend;
    }

    if (widget.isOidc) {
      logger.d('is oidc');
      List<dynamic> vp = [];
      PresentationSubmission? submission;
      VerifiablePresentation? casted;
      String? mdocGeneratedNonce;

      String definitionId = '';
      List<InputDescriptorMappingObject> descriptorMap = [];

      for (FilterResult entry in finalSend) {
        definitionId = entry.presentationDefinitionId;

        if (entry.isoMdocCredentials != null &&
            entry.isoMdocCredentials!.isNotEmpty) {
          logger.d('handle mdoc');
          var handover = OID4VPHandover.fromValues(
              widget.receiverDid, widget.otherEndpoint, widget.nonce!);
          mdocGeneratedNonce = handover.mdocGeneratedNonce;
          List<Document> docs = [];

          for (var cred in entry.isoMdocCredentials!) {
            var mso = MobileSecurityObject.fromCbor(cred.issuerAuth.payload);
            var did = coseKeyToDid(mso.deviceKeyInfo.deviceKey);

            var private = await wallet.getPrivateKeyForCredentialDid(did);
            if (private == null) {
              logger.d('Kein privater schlüssel');
              throw Exception();
            }
            var privateKey = await didToCosePublicKey(did);
            privateKey.d = hexDecode(private);

            var transcript = SessionTranscript(handover: handover);
            var ds = await generateDeviceSignature({}, mso.docType, transcript,
                signer: SignatureGenerator.get(privateKey));
            docs.add(Document(
                docType: mso.docType, issuerSigned: cred, deviceSigned: ds));
          }

          var res = DeviceResponse(status: 0, documents: docs);

          descriptorMap.add(InputDescriptorMappingObject(
              id: entry.matchingDescriptorIds.first,
              format: OidcCredentialFormat.msoMdoc,
              path: JsonPath(r'$')));

          vp.add(removePaddingFromBase64(base64UrlEncode(res.toEncodedCbor())));
        }

        if (entry.credentials != null && entry.credentials!.isNotEmpty) {
          logger.d('handle w3c');
          vp.add(await buildPresentation(
              finalSend, wallet.wallet, widget.nonce!,
              loadDocumentFunction: loadDocumentFast));
          casted = VerifiablePresentation.fromJson(vp.last);
          submission = casted.presentationSubmission!;
          logger.d(await verifyPresentation(vp.last, widget.nonce!,
              loadDocumentFunction: loadDocumentFast));

          logger.d(vp);
        }

        int arrayIndex = 0;
        if (entry.sdJwtCredentials != null &&
            entry.sdJwtCredentials!.isNotEmpty) {
          logger.d('handle sd jwt');
          for (var s in entry.sdJwtCredentials!) {
            var sd = s.unverified();

            var cnf = sd.confirmation!.toJson();
            logger.d(cnf['jwk']);
            var multibase = jwkToMultiBase(cnf['jwk']);
            var restoredDid = 'did:key:$multibase';

            var private = await wallet.wallet
                .getPrivateKeyForCredentialDidAsJwk(restoredDid);
            if (private == null) {
              logger.d('no private key found for $restoredDid');
              throw Exception();
            }
            private['x'] = cnf['jwk']['x'];
            private['y'] = cnf['jwk']['y'];
            logger.d(private);

            var jwk = sd_jwt.Jwk.fromJson(private);
            logger.d(jwk.toJson());
            sd_jwt.SigningAlgorithm? algorithm;
            if (private['crv'] == 'P-256') {
              algorithm = sd_jwt.SigningAlgorithm.ecdsaSha256Prime;
            } else if (private['crv'] == 'P-384') {
              algorithm = sd_jwt.SigningAlgorithm.ecdsaSha384Prime;
            } else if (private['crv'] == 'P-221') {
              algorithm = sd_jwt.SigningAlgorithm.ecdsaSha512Prime;
            }

            var signed = s.bind(
                jsonWebKey: jwk,
                audience: widget.otherEndpoint,
                issuedAt: DateTime.now(),
                nonce: widget.nonce!,
                signingAlgorithm: algorithm);

            logger.d(signed);

            vp.add(signed.toCompactSerialization());

            descriptorMap.add(InputDescriptorMappingObject(
                id: entry.matchingDescriptorIds.first,
                format: OidcCredentialFormat.sdJwt,
                path: JsonPath(
                    '\$${vp.isEmpty && entry.sdJwtCredentials!.length == 1 ? '' : '[${arrayIndex + vp.length}]'}')));
            arrayIndex++;
          }
        }
      }
      submission = PresentationSubmission(
          presentationDefinitionId: definitionId, descriptorMap: descriptorMap);

      logger.d('send presentation to ${widget.otherEndpoint}');
      Response res;
      String vpAnswer = vp.length == 1
          ? vp.first is String
              ? vp.first
              : jsonEncode(vp.first)
          : jsonEncode(vp);
      if (widget.oidcResponseMode == 'direct_post') {
        res = await post(Uri.parse(widget.otherEndpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'presentation_submission=${submission.toString()}&vp_token=$vpAnswer${widget.oidcState != null ? '&state=${widget.oidcState!}' : ''}');
      } else if (widget.oidcResponseMode == 'direct_post.jwt') {
        if (widget.oidcClientMetadata == null) {
          throw Exception('no client metadata');
        }
        if (widget.oidcClientMetadata?.authEncryptedResponseAlg != null &&
            widget.oidcClientMetadata?.authEncryptedResponseEnc != null) {
          // we should build jwe
          List<Map<String, dynamic>>? jwks;
          if (widget.oidcClientMetadata!.jwksUri != null) {
            var res = await get(Uri.parse(widget.oidcClientMetadata!.jwksUri!));
            if (res.statusCode == 200) {
              var body = jsonDecode(res.body);

              var keys = (body['keys'] as List).cast<Map>();
              jwks = keys
                  .map((e) =>
                      e.map((key, value) => MapEntry(key as String, value)))
                  .toList();
            }
          } else {
            jwks = widget.oidcClientMetadata!.jwks;
          }
          if (jwks == null) {
            throw Exception('no keys');
          }
          var readerKey =
              jwks.firstWhere((element) => element['alg'] == 'ECDH-ES');
          var crv = readerKey['crv'];

          logger.d(readerKey);
          KeyType walletKeyType;
          if (crv == 'P-256') {
            walletKeyType = KeyType.p256;
          } else if (crv == 'X25519') {
            walletKeyType = KeyType.x25519;
          } else if (crv == 'P-384') {
            walletKeyType = KeyType.p384;
          } else if (crv == 'P521') {
            walletKeyType = KeyType.p521;
          } else {
            walletKeyType = KeyType.secp256k1;
          }
          var cDid = await wallet.newConnectionDid(walletKeyType);
          var myJwk =
              await wallet.wallet.getPrivateKeyForConnectionDidAsJwk(cDid);
          logger.d(myJwk);
          var myJwkPub = resolveDidKey(cDid)
              .convertAllKeysToJwk()
              .resolveKeyIds()
              .verificationMethod!
              .first
              .publicKeyJwk;

          var enc = widget.oidcClientMetadata!.authEncryptedResponseEnc!;

          var header = {
            'alg': widget.oidcClientMetadata!.authEncryptedResponseAlg,
            'enc': enc,
            'kid': readerKey['kid'],
            'apv': base64Encode(utf8.encode(widget.nonce!)),
            'apu': mdocGeneratedNonce,
            'epk': myJwkPub
          };

          logger.d(header);

          if (header['alg'] == 'ECDH-ES') {
            var sharedSecret = ecdhES(myJwk, readerKey, header['alg'], enc,
                apu: header['apu'], apv: header['apv']);

            logger.d('$sharedSecret, ${sharedSecret.length}');
            // direct mode
            var key = SymmetricKey(keyValue: Uint8List.fromList(sharedSecret));
            // build aad ( ASCII(BASE64URL(UTF8(JWE Protected Header))) )
            var aad = ascii.encode(removePaddingFromBase64(
                base64UrlEncode(utf8.encode(jsonEncode(header)))));

            //data
            var data = {
              'vp_token': vp.length == 1 ? vp.first : vp,
              'presentation_submission': submission,
            };
            if (widget.oidcState != null) {
              data['state'] = widget.oidcState;
            }

            Encrypter e;
            if (enc == 'A128CBC-HS256') {
              e = key.createEncrypter(
                  algorithms.encryption.aes.cbcWithHmac.sha256);
            } else if (enc == 'A192CBC-HS384') {
              e = key.createEncrypter(
                  algorithms.encryption.aes.cbcWithHmac.sha384);
            } else if (enc == 'A256CBC-HS512') {
              e = key.createEncrypter(
                  algorithms.encryption.aes.cbcWithHmac.sha512);
            } else if (enc == 'A128GCM' ||
                enc == 'A192GCM' ||
                enc == 'A256GCM') {
              e = key.createEncrypter(algorithms.encryption.aes.gcm);
            } else {
              throw Exception('Unknown enc $enc');
            }

            //6) encrypt and get tag
            var encrypted = e.encrypt(
                Uint8List.fromList(utf8.encode(jsonEncode(data))),
                additionalAuthenticatedData: aad);

            var jwe =
                '${removePaddingFromBase64(base64UrlEncode(utf8.encode(jsonEncode(header))))}..${removePaddingFromBase64(base64UrlEncode(encrypted.initializationVector!))}.${removePaddingFromBase64(base64UrlEncode(encrypted.data))}.${removePaddingFromBase64(base64UrlEncode(encrypted.authenticationTag!))}';

            logger.d('jwe: $jwe');
            var httpClient = io.HttpClient();
            var request =
                await httpClient.postUrl(Uri.parse(widget.otherEndpoint));
            request.headers
                .set('Content-Type', 'application/x-www-form-urlencoded');
            request.write(
                'response=${Uri.encodeQueryComponent(jwe)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}');

            var response = await request.close();
            res = Response(await response.transform(utf8.decoder).join(),
                response.statusCode);
            // res = await post(Uri.parse(widget.otherEndpoint),
            //     headers: {'content-type': 'application/x-www-form-urlencoded'},
            //     body:
            //         'response=${Uri.encodeQueryComponent(jwe)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}');
            if (widget.oidcRedirectUri != null) {
              launchUrl(Uri.parse(widget.oidcRedirectUri!),
                  mode: LaunchMode.externalApplication);
            }
          } else {
            throw Exception('Unsupported alg ${header['alg']}');
          }
        } else {
          throw Exception('signing not supported');
        }
      } else {
        logger.d(
            '${widget.otherEndpoint}?presentation_submission=${Uri.encodeQueryComponent(submission.toString())}&vp_token=${Uri.encodeQueryComponent(vpAnswer)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}');

        var r = await launchUrl(
            Uri.parse(
                '${widget.otherEndpoint}?presentation_submission=${Uri.encodeQueryComponent(submission.toString())}&vp_token=${Uri.encodeQueryComponent(vpAnswer)}${widget.oidcState != null ? '&state=${Uri.encodeQueryComponent(widget.oidcState!)}' : ''}'),
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
            wallet.storeExchangeHistoryEntry(
                getHolderDidFromCredential(cred.toJson()),
                DateTime.now(),
                'present',
                widget.otherEndpoint);

            type += '${getTypeToShow(cred.type)}, \n';
          }
          logger.d(type);

          for (var cred in entry.isoMdocCredentials ?? <IssuerSignedObject>[]) {
            var mso = MobileSecurityObject.fromCbor(cred.issuerAuth.payload);

            var did = coseKeyToDid(mso.deviceKeyInfo.deviceKey);
            wallet.storeExchangeHistoryEntry(
                did, DateTime.now(), 'present', widget.otherEndpoint);

            type += '${mso.docType}, \n';
          }
          logger.d(type);

          for (var cred in entry.sdJwtCredentials ?? <sd_jwt.SdJws>[]) {
            var sdJwt = cred.unverified();

            var cnf = sdJwt.confirmation!.toJson();
            logger.d(cnf['jwk']);
            var multibase = jwkToMultiBase(cnf['jwk']);
            var restoredDid = 'did:key:$multibase';
            wallet.storeExchangeHistoryEntry(
                restoredDid, DateTime.now(), 'present', widget.otherEndpoint);

            var vct = sdJwt.claims['vct'];
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
                      amount: type,
                      symbol: '',
                      mainFontSize: 18,
                      centered: true),
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
        if (casted != null) {
          for (var cred in casted.verifiableCredential!) {
            wallet.storeExchangeHistoryEntry(
                getHolderDidFromCredential(cred.toJson()),
                DateTime.now(),
                'present failed',
                widget.otherEndpoint);
          }
        }

        await showModalBottomSheet(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10))),
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
      return casted;
    } else {
      var vp = await buildPresentation(
          finalSend,
          wallet.wallet,
          widget.message?.presentationDefinition.first.challenge ??
              widget.nonce ??
              '',
          loadDocumentFunction: loadDocumentKaprion);
      if (widget.message != null) {
        var presentationMessage = Presentation(
            replyUrl: '$relay/buffer/${widget.myDid}',
            returnRoute: ReturnRouteValue.thread,
            to: [widget.receiverDid],
            from: widget.myDid,
            verifiablePresentation: [VerifiablePresentation.fromJson(vp)],
            threadId: widget.message!.threadId ?? widget.message!.id,
            parentThreadId: widget.message!.parentThreadId);
        logger.d(widget.lnInvoiceRequest);
        logger.d(widget.paymentCards);
        if (widget.lnInvoiceRequest != null && widget.paymentCards != null) {
          logger.d('generate invoice');
          var paymentId = widget.paymentCards!.first.id!;
          var lnInKey = wallet.getLnInKey(paymentId);
          var invoice = await createInvoice(
              lnInKey!,
              SatoshiAmount.fromUnitAndValue(
                  widget.lnInvoiceRequest!['amount'], SatoshiUnit.sat),
              memo: widget.lnInvoiceRequest!['memo'] ?? '');
          var index = invoice['checking_id'];
          logger.d(index);
          wallet.newPayment(
            paymentId,
            index,
            widget.lnInvoiceRequest!['memo'] ?? '',
            SatoshiAmount.fromUnitAndValue(
                widget.lnInvoiceRequest!['amount'], SatoshiUnit.sat),
          );

          var paymentAtt = Attachment(
              format: 'lnInvoice',
              data: AttachmentData(json: {
                'type': 'lnInvoice',
                'lnInvoice': invoice['payment_request']
              }));

          presentationMessage.attachments?.add(paymentAtt);
        }
        sendMessage(widget.myDid, widget.otherEndpoint, wallet,
            presentationMessage, widget.receiverDid,
            lnInvoice: widget.lnInvoice, paymentCards: widget.paymentCards);
      }

      for (var cred
          in VerifiablePresentation.fromJson(vp).verifiableCredential ?? []) {
        wallet.storeExchangeHistoryEntry(
            getHolderDidFromCredential(cred.toJson()),
            DateTime.now(),
            'present',
            widget.otherEndpoint);
      }

      // Navigator.of(context).pop();
      return VerifiablePresentation.fromJson(vp);
    }
  }

  void reject() async {
    logger.d('user declined presentation');
    if (widget.message != null) {
      var problem = ProblemReport(
          replyUrl: '$relay/buffer/${widget.myDid}',
          returnRoute: ReturnRouteValue.thread,
          to: [widget.receiverDid],
          from: widget.myDid,
          parentThreadId: widget.message!.threadId ?? widget.message!.id,
          code: 'e.p.user.decline');

      // TODO sendMessage(
      //     widget.myDid,
      //     widget.otherEndpoint,
      //     Provider.of<WalletProvider>(navigatorKey.currentContext!,
      //         listen: false),
      //     problem,
      //     widget.receiverDid);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SecuredWidget(
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: buildChilds(),
                ),
              ),
            ),
          ),
          persistentFooterButtons: [
            if (!dataEntered)
              FooterErrorText(
                  errorMessage: AppLocalizations.of(context)!.missingDataNote,
                  reject: reject)
            else if (!fulfillable)
              FooterErrorText(
                  errorMessage:
                      AppLocalizations.of(context)!.errorNotEnoughCredentials,
                  reject: reject)
            else
              FooterButtons(
                positiveText: widget.lnInvoice != null
                    ? AppLocalizations.of(context)!.orderWithPayment
                    : null,
                negativeFunction: reject,
                positiveFunction: () async {
                  // expected return values
                  // oidc_handler 1123: nothing
                  // present_proof 181: nothing
                  // mdoc_provider 586: null or List<FilterResult>
                  // web_view 422: VerifiablePresentation or null
                  dynamic vp;
                  try {
                    vp = await Future.delayed(
                        const Duration(milliseconds: 50), sendAnswer);
                    Navigator.of(context).pop(vp);
                  } catch (e) {
                    logger.d(e);
                    Navigator.of(context).pop();
                    showErrorMessage(
                        AppLocalizations.of(navigatorKey.currentContext!)!
                            .sendFailed);
                  }
                },
              )
          ],
        ),
        if (send)
          const Opacity(
            opacity: 0.8,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
        if (send)
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                ),
                const SizedBox(
                  height: 10,
                ),
                DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    child: Text(
                      '${AppLocalizations.of(context)!.waiting}\n${AppLocalizations.of(context)!.waitingSendPresentation}',
                    ))
              ],
            ),
          ),
      ],
    );
  }
}

class FooterErrorText extends StatelessWidget {
  final void Function() reject;
  final String errorMessage;

  const FooterErrorText(
      {super.key, required this.errorMessage, required this.reject});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).primaryTextTheme.titleMedium,
              children: [
                TextSpan(
                  text: AppLocalizations.of(context)!.attention,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                WidgetSpan(
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 1,
                      bottom: 5,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Colors.redAccent.shade700,
                    ),
                  ),
                ),
                TextSpan(
                    text: '\n$errorMessage',
                    style: Theme.of(context).primaryTextTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        ElevatedButton(
            onPressed: reject,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(45),
            ),
            child: Text(AppLocalizations.of(context)!.cancel))
      ],
    );
  }
}
