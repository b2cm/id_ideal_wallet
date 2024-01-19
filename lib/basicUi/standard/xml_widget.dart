import 'dart:typed_data';

import 'package:dart_ssi/credentials.dart';
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/functions/util.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

class XmlWidget extends StatelessWidget {
  final String xml;
  final VerifiableCredential credential;
  final Color overlayColor;
  final double aspectRatioInverse = 195 / 335;
  String basic = 'container';
  List<Widget> childs = [];
  Map attributes = {};
  String? text;
  Uint8List? imageData;

  XmlWidget(
      {super.key,
      required this.xml,
      required this.credential,
      this.overlayColor = Colors.black}) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(xml);
    } catch (_) {
      basic = 'error';
      return;
    }
    basic = document.childElements.first.name.toString();
    if (basic == 'text') {
      var text = document.children.first.firstChild.toString();
      var textList = text.split(' ');
      var newText = textList.map((e) {
        if (e.startsWith('\$')) {
          if (e.contains('%')) {
            var split = e.split('%');
            var value = credential
                    .credentialSubject[split.first.replaceAll('\$', '')] ??
                '';
            if (split.last == 'date') {
              value = DateFormat('dd.MM.yyyy').format(DateTime.parse(value));
            }
            return value;
          } else {
            return credential.credentialSubject[e.replaceAll('\$', '')] ?? '';
          }
        } else {
          return e;
        }
      });
      this.text = newText.join(' ');
      attributes = document.childElements.first.attributes
          .asMap()
          .map((key, value) => MapEntry(value.name.toString(), value.value));
    } else if (basic == 'image') {
      attributes = document.childElements.first.attributes
          .asMap()
          .map((key, value) => MapEntry(value.name.toString(), value.value));
      try {
        var text = document.children.first.firstChild.toString();
        var value = credential.credentialSubject[text.replaceAll('\$', '')];
        imageData = UriData.fromUri(Uri.parse(value)).contentAsBytes();
      } catch (_) {
        basic = 'container';
        childs.add(const SizedBox(
          height: 0,
        ));
      }
    } else {
      attributes = document.childElements.first.attributes
          .asMap()
          .map((key, value) => MapEntry(value.name.toString(), value.value));
      for (var element in document.childElements.first.childElements) {
        childs.add(XmlWidget(xml: element.toString(), credential: credential));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (basic) {
      case 'column':
        return Column(
          mainAxisAlignment: mainAxis[attributes['mainAxisAlignment']] ??
              MainAxisAlignment.start,
          crossAxisAlignment: crossAxis[attributes['crossAxisAlignment']] ??
              CrossAxisAlignment.start,
          children: childs,
        );
      case 'row':
        return Row(
          mainAxisAlignment: mainAxis[attributes['mainAxisAlignment']] ??
              MainAxisAlignment.start,
          crossAxisAlignment: crossAxis[attributes['crossAxisAlignment']] ??
              CrossAxisAlignment.start,
          children: childs,
        );
      case 'text':
        return Text(
          text ?? '',
          style: TextStyle(
              fontSize: attributes.containsKey('fontsize')
                  ? double.parse(attributes['fontsize'])
                  : null,
              color: attributes.containsKey('color')
                  ? HexColor.fromHex(attributes['color'])
                  : overlayColor,
              fontWeight: attributes.containsKey('fontweight')
                  ? fontWeight[attributes['fontweight']]
                  : null),
        );
      case 'image':
        return Image.memory(
          imageData!,
          height: attributes.containsKey('height')
              ? (attributes['height'] as String).endsWith('%')
                  ? (MediaQuery.of(context).size.width - 27) *
                      aspectRatioInverse *
                      double.parse(attributes['height'].replaceAll('%', '')) /
                      100
                  : double.parse(
                      (attributes['height'] as String).replaceAll('px', ''))
              : null,
        );
      case 'error':
        return const SizedBox();
      default:
        return Container(
          decoration: BoxDecoration(
              color: attributes.containsKey('color')
                  ? HexColor.fromHex(attributes['color'])
                  : null,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(
                    double.parse(attributes['radiusBottomLeft'] ?? '0.0')),
                bottomRight: Radius.circular(
                    double.parse(attributes['radiusBottomRight'] ?? '0.0')),
                topRight: Radius.circular(
                    double.parse(attributes['radiusTopRight'] ?? '0.0')),
                topLeft: Radius.circular(
                    double.parse(attributes['radiusTopLeft'] ?? '0.0')),
              )),
          padding: EdgeInsets.only(
              left: double.parse(attributes['padLeft'] ?? '0.0'),
              bottom: double.parse(attributes['padBottom'] ?? '0.0'),
              right: double.parse(attributes['padRight'] ?? '0.0'),
              top: double.parse(attributes['padTop'] ?? '0.0')),
          height: attributes.containsKey('height')
              ? (attributes['height'] as String).endsWith('%')
                  ? (MediaQuery.of(context).size.width - 27) *
                      aspectRatioInverse *
                      double.parse(attributes['height'].replaceAll('%', '')) /
                      100
                  : double.parse(
                      (attributes['height'] as String).replaceAll('px', ''))
              : null,
          child: childs.first,
        );
    }
  }
}

final mainAxis = <String, MainAxisAlignment>{
  'end': MainAxisAlignment.end,
  'start': MainAxisAlignment.start,
  'spaceBetween': MainAxisAlignment.spaceBetween,
  'spaceEvenly': MainAxisAlignment.spaceEvenly,
  'spaceAround': MainAxisAlignment.spaceAround,
  'center': MainAxisAlignment.center
};

final crossAxis = <String, CrossAxisAlignment>{
  'end': CrossAxisAlignment.end,
  'start': CrossAxisAlignment.start,
  'baseline': CrossAxisAlignment.baseline,
  'stretch': CrossAxisAlignment.stretch,
  'center': CrossAxisAlignment.center
};

final fontWeight = <String, FontWeight>{'bold': FontWeight.bold};
