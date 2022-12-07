import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:json_schema2/json_schema2.dart';
import 'package:json_schema_form/json_schema_form.dart';

class SelfIssueList extends StatelessWidget {
  const SelfIssueList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StyledScaffoldTitle(
        title: 'Selbstaustellbare Credentials',
        scanOnTap: () {},
        child: Column(
          children: [
            ElevatedButton(
                onPressed: () {}, child: const Text('E-Mail Adresse'))
          ],
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
