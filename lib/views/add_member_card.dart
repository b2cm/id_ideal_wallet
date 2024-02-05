import 'package:barcode_widget/barcode_widget.dart' as barcode;
import 'package:flutter/material.dart';
import 'package:id_ideal_wallet/basicUi/standard/footer_buttons.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

class AddMemberCard extends StatefulWidget {
  final String initialNumber;
  final String initialBarcodeType;

  const AddMemberCard(
      {super.key,
      required this.initialNumber,
      required this.initialBarcodeType});

  @override
  AddMemberCardState createState() => AddMemberCardState();
}

class AddMemberCardState extends State<AddMemberCard> {
  var formKey = GlobalKey<FormState>();
  var numberController = TextEditingController();
  var nameController = TextEditingController();
  barcode.BarcodeType currentType = barcode.BarcodeType.QrCode;

  @override
  void initState() {
    super.initState();
    numberController.text = widget.initialNumber;
    if (widget.initialBarcodeType == BarcodeFormat.aztec.name) {
      currentType = barcode.BarcodeType.Aztec;
    } else if (widget.initialBarcodeType == BarcodeFormat.dataMatrix.name) {
      currentType = barcode.BarcodeType.DataMatrix;
    } else if (widget.initialBarcodeType == BarcodeFormat.code39.name) {
      currentType = barcode.BarcodeType.Code39;
    } else if (widget.initialBarcodeType == BarcodeFormat.ean13.name) {
      currentType = barcode.BarcodeType.CodeEAN13;
    } else if (widget.initialBarcodeType == BarcodeFormat.code128.name) {
      currentType = barcode.BarcodeType.Code128;
    } else if (widget.initialBarcodeType == BarcodeFormat.codebar.name) {
      currentType = barcode.BarcodeType.Codabar;
    } else if (widget.initialBarcodeType == BarcodeFormat.code93.name) {
      currentType = barcode.BarcodeType.Code93;
    } else if (widget.initialBarcodeType == BarcodeFormat.ean8.name) {
      currentType = barcode.BarcodeType.CodeEAN8;
    } else if (widget.initialBarcodeType == BarcodeFormat.itf.name) {
      currentType = barcode.BarcodeType.Itf;
    } else if (widget.initialBarcodeType == BarcodeFormat.upcA.name) {
      currentType = barcode.BarcodeType.CodeUPCA;
    } else if (widget.initialBarcodeType == BarcodeFormat.upcE.name) {
      currentType = barcode.BarcodeType.CodeUPCE;
    } else if (widget.initialBarcodeType == BarcodeFormat.pdf417.name) {
      currentType = barcode.BarcodeType.PDF417;
    }
  }

  @override
  dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }

  Future<void> storeCard() async {
    if (formKey.currentState!.validate()) {
      Provider.of<WalletProvider>(context, listen: false).addMemberCard({
        'name': nameController.text,
        'barcodeType': currentType.name,
        'number': numberController.text
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Kartentyp',
                  ),
                  controller: nameController,
                  // The validator receives the text that the user has entered.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                DropdownButtonFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Barcodeformat',
                  ),
                  value: currentType,
                  items: barcode.BarcodeType.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value != null) {
                        currentType = value;
                      }
                    });
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Kundennummer',
                  ),
                  controller: numberController,

                  // The validator receives the text that the user has entered.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                barcode.BarcodeWidget(
                    data: numberController.text,
                    barcode: barcode.Barcode.fromType(currentType))
              ],
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
        FooterButtons(
          positiveFunction: storeCard,
          positiveText: 'Ok',
        )
      ],
    );
  }
}
