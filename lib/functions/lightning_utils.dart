import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_wallet_design/id_wallet_design.dart';
import 'package:provider/provider.dart';

Future<Map<String, dynamic>> createAccount() async {
  var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/create'), body: {});
  var decoded = jsonDecode(res.body);
  return decoded;
}

Future<String?> getLnAuthToken(String login, String password) async {
  var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/auth'),
      body: {'login': login, 'password': password});
  if (res.statusCode == 200) {
    var decodedResponse = jsonDecode(res.body);
    var lnAuthToken = decodedResponse['access_token'];
    return lnAuthToken;
  } else {
    throw Exception('cant get access token for lndhub');
  }
}

Future<int> getBalance(String lnAuthToken) async {
  var res = await get(Uri.https('ln.pixeldev.eu', 'lndhub/balance'),
      headers: {'Authorization': 'Bearer $lnAuthToken'});
  var decodedResponse = jsonDecode(res.body) as Map;
  return decodedResponse['BTC']['AvailableBalance'];
}

Future<Map<String, dynamic>> decodeInvoice(
    String invoice, String lnAuthToken) async {
  var res = await get(
      Uri.https(
        'ln.pixeldev.eu',
        'lndhub/decodeinvoice',
        {'invoice': invoice},
      ),
      headers: {
        'Authorization': 'Bearer $lnAuthToken',
        'Content-Type': 'application/json'
      });

  if (res.statusCode == 200) {
    var decoded = jsonDecode(res.body);
    return decoded;
  } else {
    throw Exception('cant decode invoice: ${res.body}');
  }
}

Future<bool> payInvoice(String invoice, String lnAuthToken) async {
  var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/payinvoice'),
      body: {'invoice': invoice},
      headers: {'Authorization': 'Bearer $lnAuthToken'});
  if (res.statusCode == 200) {
    return true;
  } else {
    return false;
  }
}

Future<Map<String, dynamic>> createInvoice(int amtSatoshis, String lnAuthToken,
    [String memo = '']) async {
  var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/addinvoice'),
      body: {'amt': amtSatoshis.toString(), 'memo': memo},
      headers: {'Authorization': 'Bearer $lnAuthToken'});
  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  } else {
    throw Exception('Cant create invoice');
  }
}

Future<List> getUserInvoice(String index, String lnAuthToken) async {
  var res = await get(
      Uri.https(
        'ln.pixeldev.eu',
        'lndhub/getuserinvoices',
        {
          'limit': 1.toString(),
          'offset': index,
        },
      ),
      headers: {
        'Authorization': 'Bearer $lnAuthToken',
        'Content-Type': 'application/json'
      });
  if (res.statusCode == 200) {
    return jsonDecode(res.body) as List;
  } else {
    throw Exception('Cant get invoice with index $index');
  }
}

Future<bool> isInvoicePaid(String index, String lnAuthToken) async {
  var invoiceList = await getUserInvoice(index, lnAuthToken);
  return invoiceList.first['ispaid'];
}

void payInvoiceInteraction(String invoice) async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);
  var decoded = await decodeInvoice(invoice, wallet.lnAuthToken!);
  String toPay = decoded['num_satoshis'] ?? '';
  var description = decoded['description'];
  showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      context: navigatorKey.currentContext!,
      builder: (context) {
        return ModalDismissWrapper(
          child: PaymentIntent(
            amount: CurrencyDisplay(
                amount: toPay, symbol: '€', mainFontSize: 35, centered: true),
            memo: description,
            onPaymentAccepted: () async {
              var success = await payInvoice(invoice, wallet.lnAuthToken!);
              if (success) {
                wallet.storePayment('-$toPay',
                    description == '' ? 'Lightning Invoice' : description);
              }
              showModalBottomSheet(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  context: context,
                  builder: (context) {
                    return ModalDismissWrapper(
                      child: PaymentFinished(
                        headline: success
                            ? 'Zahlung erfolgreich'
                            : 'Zahlung fehlgeschlagen',
                        success: success,
                        amount: CurrencyDisplay(
                            amount: toPay,
                            symbol: '€',
                            mainFontSize: 35,
                            centered: true),
                      ),
                    );
                  });
            },
          ),
        );
      });
}
