import 'dart:convert';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_json_schema_form/controller/flutter_json_schema_form_controller.dart';
import 'package:flutter_json_schema_form/flutter_json_schema_form.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:json_schema_document/json_schema_document.dart' as jsd;

class CredentialSelfIssue extends StatefulWidget {
  final List<InputDescriptorConstraints> input;

  const CredentialSelfIssue({Key? key, required this.input}) : super(key: key);

  @override
  State<StatefulWidget> createState() => CredentialSelfIssueState();
}

class CredentialSelfIssueState extends State<CredentialSelfIssue> {
  late jsd.JsonSchema schema;
  late FlutterJsonSchemaFormController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    for (var i in widget.input) {
      if (i.fields != null) {
        for (var field in i.fields!) {
          var givenSchema = field.filter?.toJson();
          if (givenSchema != null) {
            schema = jsd.JsonSchema.fromMap(jsonDecode(givenSchema));
            logger.d(schema);
            controller = FlutterJsonSchemaFormController(jsonSchema: schema);
          }
        }
      }
    }
  }

  void submit() {
    print(controller.data);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterJsonSchemaForm(
      jsonSchema: schema,
      controller: controller,
      onSubmit: submit,
      buttonText: 'Fertig',
    );
  }
}
