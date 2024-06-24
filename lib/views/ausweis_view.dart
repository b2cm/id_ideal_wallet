import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/ausweis_data.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/enter_can.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/enter_pin.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/enter_puk.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/errro_page.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/insert_card.dart';
import 'package:id_ideal_wallet/basicUi/ausweis/main_content.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/ausweis_provider.dart';
import 'package:provider/provider.dart';

class AusweisView extends StatefulWidget {
  const AusweisView({super.key});

  @override
  AusweisViewState createState() => AusweisViewState();
}

class AusweisViewState extends State<AusweisView> {
  @override
  void initState() {
    super.initState();
    Provider.of<AusweisProvider>(context, listen: false).startListening();
  }

  Widget getBody(AusweisProvider ausweis) {
    if (ausweis.screen == AusweisScreen.enterPin) {
      return const EnterPin();
    } else if (ausweis.screen == AusweisScreen.insertCard) {
      return const InsertCard();
    } else if (ausweis.screen == AusweisScreen.start) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            ausweis.startProgress();
          },
          child: Text('Ausweisdaten in Credential umwandeln'),
        ),
      );
    } else if (ausweis.screen == AusweisScreen.finish) {
      return const AusweisData();
    } else if (ausweis.screen == AusweisScreen.enterCan) {
      return const EnterCan();
    } else if (ausweis.screen == AusweisScreen.enterPuk) {
      return const EnterPuk();
    } else if (ausweis.screen == AusweisScreen.error) {
      return const ErrorPage();
    } else {
      return const MainContent();
    }
  }

  @override
  void dispose() {
    Provider.of<AusweisProvider>(navigatorKey.currentContext!, listen: false)
        .reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AusweisProvider>(builder: (context, ausweis, child) {
      return Scaffold(
        body: SafeArea(child: getBody(ausweis)),
      );
    });
  }
}
