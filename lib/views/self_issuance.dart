import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:dart_ssi/credentials.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:json_schema2/json_schema2.dart';
import 'package:json_schema_form/json_schema_form.dart';
import 'package:provider/provider.dart';

final emailSchema = JsonSchema.createSchema({
  'type': 'object',
  'properties': {
    'email': {'type': 'string', 'description': 'E-Mail Adresse'}
  }
});

final socialMediaSchema = JsonSchema.createSchema({
  'type': 'object',
  'properties': {
    'network': {
      'type': 'string',
      'enum': [
        'Facebook',
        'Telegram',
        'Instagram',
        'TikTok',
        'Matrix',
        'Mastodon',
        'LinkedIn',
        'Xing'
      ]
    },
    'username': {
      'type': 'string',
      'description': 'Nutzername im gewählten Netzwerk'
    }
  }
});

class SelfIssueList extends StatelessWidget {
  const SelfIssueList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: 'Selbstausstellbare Credentials',
        scanOnTap: () {},
        child: Column(
          children: [
            ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => FixedSelfIssue(
                        schema: emailSchema, type: 'EMailCredential'))),
                child: const Text('E-Mail Adresse')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => FixedSelfIssue(
                        schema: socialMediaSchema,
                        type: 'SocialMediaAccountCredential'))),
                child: const Text('Social Media Account')),
            ElevatedButton(
                onPressed: () async {
                  JsonSchema deviceInfoSchema;
                  var deviceInfo = DeviceInfoPlugin();
                  if (Platform.isAndroid) {
                    var info = await deviceInfo.androidInfo;
                    var androidAidPlugin = const AndroidId();
                    deviceInfoSchema = JsonSchema.createSchema({
                      'type': 'object',
                      'properties': {
                        'deviceId': {
                          'type': 'string',
                          'const': await androidAidPlugin.getId()
                        },
                        'deviceModel': {'type': 'string', 'const': info.model},
                        'deviceManufacturer': {
                          'type': 'string',
                          'const': info.manufacturer
                        },
                      }
                    });
                  } else if (Platform.isIOS) {
                    var info = await deviceInfo.iosInfo;
                    deviceInfoSchema = JsonSchema.createSchema({
                      'type': 'object',
                      'properties': {
                        'deviceId': {
                          'type': 'string',
                          'const': info.identifierForVendor
                        },
                        'deviceModel': {'type': 'string', 'const': info.model},
                        'deviceManufacturer': {
                          'type': 'string',
                          'const': 'Apple'
                        },
                      }
                    });
                  } else {
                    throw Exception(
                        'This should never happen. Unknown Platform');
                  }

                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => FixedSelfIssue(
                          schema: deviceInfoSchema,
                          type: 'DeviceInformation')));
                },
                child: const Text('Geräteinformationen'))
          ],
        ));
  }
}

class FixedSelfIssue extends StatelessWidget {
  final JsonSchema schema;
  final String type;

  const FixedSelfIssue({Key? key, required this.schema, required this.type})
      : super(key: key);

  void afterValidation(Map<dynamic, dynamic> result) async {
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);

    var credentialDid = await wallet.newCredentialDid();
    result['id'] = credentialDid;
    var credential = VerifiableCredential(
        context: [
          'https://www.w3.org/2018/credentials/v1',
          'https://schema.org'
        ],
        type: [
          'VerifiableCredential',
          type
        ],
        issuer: credentialDid,
        credentialSubject: result,
        issuanceDate: DateTime.now());

    var signed = await signCredential(wallet.wallet, credential.toJson());

    var storageCred = wallet.getCredential(credentialDid);

    wallet.storeCredential(signed, storageCred!.hdPath);
    wallet.storeExchangeHistoryEntry(
        credentialDid, DateTime.now(), 'issue', credentialDid);

    Navigator.pop(navigatorKey.currentContext!);
    Navigator.pop(navigatorKey.currentContext!);
    showModalBottomSheet(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        context: navigatorKey.currentContext!,
        builder: (context) {
          return ModalDismissWrapper(
            child: PaymentFinished(
              headline: "Credential gespeichert",
              success: true,
              amount: CurrencyDisplay(
                  amount: type, symbol: '', mainFontSize: 35, centered: true),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: 'Selbstausstellung: $type',
        scanOnTap: () {},
        child: JsonSchemaForm(
          schema: schema,
          controller: SchemaFormController(schema),
          afterValidation: afterValidation,
        ));
  }
}

class CredentialSelfIssue extends StatefulWidget {
  final List<InputDescriptorConstraints> input;

  const CredentialSelfIssue({Key? key, required this.input}) : super(key: key);

  @override
  State<StatefulWidget> createState() => CredentialSelfIssueState();
}

class CredentialSelfIssueState extends State<CredentialSelfIssue> {
  late JsonSchema schema;
  late SchemaFormController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    for (var i in widget.input) {
      if (i.fields != null) {
        for (var field in i.fields!) {
          if (field.path
              .where(
                  (element) => element.toString().contains('credentialSubject'))
              .isNotEmpty) {
            var givenSchema = field.filter?.toJson();
            if (givenSchema != null) {
              schema = JsonSchema.createSchema(jsonDecode(givenSchema));
              logger.d(schema);
              controller = SchemaFormController(schema);
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: 'Selbstausstellung',
        scanOnTap: () {},
        child: JsonSchemaForm(
          schema: schema,
          controller: controller,
        ));
  }
}
