import 'package:dart_ssi/credentials.dart';
import 'package:flutter/widgets.dart';
import 'package:xml/xml.dart';

class HtmlWidget extends StatefulWidget {
  final String html;
  final VerifiableCredential credential;

  const HtmlWidget({super.key, required this.html, required this.credential});

  @override
  HtmlWidgetState createState() => HtmlWidgetState();
}

class HtmlWidgetState extends State<HtmlWidget> {
  String basic = 'container';
  List<Widget> childs = [];

  @override
  void initState() {
    final document = XmlDocument.parse(widget.html);
    basic = document.childElements.first.name.toString();
    for (var element in document.childElements.first.childElements) {
      childs.add(
          HtmlWidget(html: element.toString(), credential: widget.credential));
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    switch (basic) {
      case 'column':
        return Column(
          children: childs,
        );
      case 'row':
        return Row(
          children: childs,
        );
      case 'text':
        return RichText(text: TextSpan(children: childs.cast<InlineSpan>()));
      default:
        return Container(
          child: childs.first,
        );
    }
  }
}
