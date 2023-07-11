import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/styled_scaffold_title.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/payment_utils.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';

import 'imageData.dart';

class AddContextCredential extends StatefulWidget {
  const AddContextCredential({super.key});

  @override
  AddContextCredentialState createState() => AddContextCredentialState();
}

class AddContextCredentialState extends State<AddContextCredential> {
  bool initialised = false;
  String errorMessage = '';
  Map<String, String> availableCredentials = {};

  List<int> checkedItems = [];

  @override
  initState() {
    super.initState();
    getAvailableContexts();
  }

  getAvailableContexts() async {
    var contextRequest = await get(Uri.parse(contextEndpoint));
    var contextList = jsonDecode(contextRequest.body);
    if (contextList is! List) {
      errorMessage = 'No List';
      return;
    }

    for (var entry in contextList) {
      availableCredentials[entry['id'].toString()] = entry['name'];
    }

    setState(() {
      initialised = true;
    });
  }

  void store(String id) async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);

    if (id == '2') {
      issueLNTestNetContext(wallet);
    } else {
      var infoRequest = await get(Uri.parse('$contextEndpoint?contextid=$id'));
      var contextInfo = jsonDecode(infoRequest.body);
      logger.d(contextInfo);
      issueContext(wallet, contextInfo);
    }

    Navigator.pop(navigatorKey.currentContext!);
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        // footerButtons: [
        //   TextButton(
        //       onPressed: store,
        //       child: Text(AppLocalizations.of(context)!.create))
        // ],
        title: AppLocalizations.of(context)!.contextCredentialTitle,
        child: initialised
            ? ListView.builder(
                itemCount: availableCredentials.length,
                itemBuilder: (context, index) {
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: ElevatedButton(
                          onPressed: () =>
                              store(availableCredentials.keys.toList()[index]),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50), // NEW
                          ),
                          child: Text(
                              availableCredentials.values.toList()[index])));
                })
            : const Center(
                child: CircularProgressIndicator(),
              ));
  }
}

Future<void> issueContext(
    WalletProvider wallet, Map<String, dynamic> content) async {
  var did = await wallet.newCredentialDid();

  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: ['VerifiableCredential', 'ContextCredential'],
      issuer: did,
      id: did,
      credentialSubject: {'id': did, ...content},
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}

Future<void> issueLNDWContextDresden(WalletProvider wallet) async {
  var did = await wallet.newCredentialDid();

  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: ['VerifiableCredential', 'ContextCredential'],
      issuer: did,
      id: did,
      credentialSubject: {
        'id': did,
        'name': 'Lange Nacht der Wissenschaften - Dresden',
        'groupedTypes': [
          'ChallengeSolvedCredential',
          'JuniorDiplom',
          'Losticket'
        ],
        'backgroundImage': backgroundDD,
        'buttons': [
          {
            'buttonText': 'Rallye absolvieren ',
            'webViewTitle': 'Rallye',
            'url': 'https://lndw84b9dcfb0e65.id-ideal.de/lndw/#/',
            'backgroundColor': '#00B200'
          }
        ]
      },
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}

Future<void> issueLNDWContextMittweida(WalletProvider wallet) async {
  var did = await wallet.newCredentialDid();
  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: ['VerifiableCredential', 'ContextCredential'],
      issuer: did,
      id: did,
      credentialSubject: {
        'id': did,
        'name': 'Lange Nacht der Wissenschaften - Mittweida',
        'groupedTypes': ['ChallengeSolvedCredentialMW'],
        'buttons': [
          {
            'buttonText': 'Karte anzeigen',
            'webViewTitle': 'Karte',
            'url': 'maps.google.com',
            'backgroundColor': '#4C4CFF'
          },
          {
            'buttonText': 'Fragen beantworten',
            'webViewTitle': 'Quiz',
            'url': 'maps.google.com',
            'backgroundColor': '#00B200'
          },
          {
            'buttonText': 'Verlosung',
            'webViewTitle': 'Verlosung',
            'url': 'maps.google.com',
            'backgroundColor': '#00B200'
          }
        ]
      },
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}

Future<void> issueLNTestNetContext(WalletProvider wallet) async {
  var did = await wallet.newCredentialDid();
  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: ['VerifiableCredential', 'ContextCredential', 'PaymentContext'],
      issuer: did,
      id: did,
      credentialSubject: {
        'id': did,
        'name': 'Lightning Testnet Account',
        'paymentType': 'LightningTestnetPayment'
      },
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  await createLNWallet(did);

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}

Future<void> issueSimulatePaymentContext(WalletProvider wallet) async {
  var did = await wallet.newCredentialDid();
  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: ['VerifiableCredential', 'ContextCredential', 'PaymentContext'],
      issuer: did,
      id: did,
      credentialSubject: {
        'id': did,
        'name': 'Spielgeld',
        'paymentType': 'SimulatedPayment'
      },
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  wallet.createFakePayment(did);

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}

Future<void> issueMemberCardContext(WalletProvider wallet) async {
  var did = await wallet.newCredentialDid();
  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: [
        'VerifiableCredential',
        'ContextCredential',
      ],
      issuer: did,
      id: did,
      credentialSubject: {
        'id': did,
        'name': 'Kundenkarten',
        'groupedTypes': ['MemberCard'],
      },
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}

Future<void> issueSSITestServiceContext(WalletProvider wallet) async {
  var did = await wallet.newCredentialDid();

  var contextCred = VerifiableCredential(
      context: [credentialsV1Iri, schemaOrgIri],
      type: ['VerifiableCredential', 'ContextCredential'],
      issuer: did,
      id: did,
      credentialSubject: {
        'id': did,
        'name': 'SSI Test-Services',
        'groupedTypes': [
          'IdCard',
          'EventTicket',
          'ALG2Bescheid',
          'DriversLicense',
          'KinderzuschlagBescheid',
          'PictureArt',
          'StudentCard',
          'WohngeldBescheid'
        ],
        'buttons': [
          {
            'buttonText': 'Demo-Ausstellservice',
            'webViewTitle': 'Ausstellservice',
            'url': 'http://167.235.195.132:8081',
            'backgroundColor': '#4C4CFF'
          },
          {
            'buttonText': 'Ticketshop',
            'webViewTitle': 'Ticketshop',
            'url': 'https://167.235.195.132:8082',
            'backgroundColor': '#00B200'
          }
        ]
      },
      issuanceDate: DateTime.now());

  var signed = await signCredential(wallet.wallet, contextCred.toJson());

  var storageCred = wallet.getCredential(did);

  wallet.storeCredential(signed, storageCred!.hdPath);
  wallet.storeExchangeHistoryEntry(did, DateTime.now(), 'issue', did);
}
