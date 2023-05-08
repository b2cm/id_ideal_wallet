import 'dart:convert';

import 'package:dart_ssi/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_intent.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

Future<void> createLNWallet(String paymentId) async {
  var id = const Uuid().v4();
  var res = await post(Uri.parse('https://payments.pixeldev.eu/create_user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"username": id, 'wallet_name': id}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    // everything ok = store to wallet
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    wallet.storeLnAccount(paymentId, answer);
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<SatoshiAmount> getBalance(String inKey) async {
  var res = await post(Uri.parse('https://payments.pixeldev.eu/wallet_details'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inkey': inKey}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer);
    return SatoshiAmount.fromUnitAndValue(answer['balance'], SatoshiUnit.msat);
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
    throw Exception(answer['detail']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<Map<String, dynamic>> createInvoice(String inKey, SatoshiAmount amount,
    {String? memo}) async {
  var res = await post(Uri.parse('https://payments.pixeldev.eu/create_invoice'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'inkey': inKey,
        'amount': amount.toSat().ceil(),
        'memo': memo ?? ''
      }));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer);
    return answer;
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
    throw Exception(answer['detail']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<String> payInvoice(String adminKey, String invoice) async {
  var res = await post(Uri.parse('https://payments.pixeldev.eu/pay_invoice'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'adminkey': adminKey, 'invoice': invoice}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    return answer['payment_hash'];
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
    throw Exception(answer['detail']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<Invoice> decodeInvoice(String inKey, String invoice) async {
  var res = await post(Uri.parse('https://payments.pixeldev.eu/decode_invoice'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inkey': inKey, 'invoice': invoice}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    return Invoice.fromJson(answer);
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
    throw Exception(answer['detail']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<bool> isInvoicePaid(String inKey, String paymentHash) async {
  var res = await post(Uri.parse('https://payments.pixeldev.eu/get_payment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inkey': inKey, 'payment_hash': paymentHash}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer);
    return answer['paid'];
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
    return false;
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

void payInvoiceInteraction(String invoice) async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  // TODO: Select paymentMethod (user)
  var paymentMethods = wallet.getSuitablePaymentCredentials(invoice);
  String paymentId = paymentMethods.first.id!;
  var lnInKey = wallet.getLnInKey(paymentId);
  var lnAdminKey = wallet.getLnAdminKey(paymentId);
  if (lnInKey == null || lnAdminKey == null) {
    throw Exception('Cant pay: lnInkey or lnAdminKey null. Fatal Error');
    //TODO: show to user
  }

  var decoded = await decodeInvoice(lnInKey, invoice);
  SatoshiAmount toPay = decoded.amount;
  logger.d(toPay.toMSat());
  var description = decoded.description;

  Future.delayed(const Duration(seconds: 0), () {
    showModalBottomSheet(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        context: navigatorKey.currentContext!,
        builder: (context) {
          return ModalDismissWrapper(
            child: PaymentIntent(
              amount: CurrencyDisplay(
                  amount: toPay.toEuro().toString(),
                  symbol: '€',
                  mainFontSize: 35,
                  centered: true),
              memo: description,
              onPaymentAccepted: () async {
                bool paid = false;
                var paymentHash = '';
                try {
                  paymentHash = await payInvoice(lnAdminKey, invoice);
                  paid = true;
                } catch (_) {
                  paid = false;
                }

                bool success = false;
                if (paid) {
                  while (!success) {
                    int x = await Future.delayed(const Duration(seconds: 1),
                        () async {
                      try {
                        success = await isInvoicePaid(lnInKey, paymentHash);
                        return 0;
                      } catch (_) {
                        return -1;
                      }
                    });
                    if (x == -1) {
                      success = false;
                      break;
                    }
                  }
                }

                if (success) {
                  wallet.storePayment('paymentId', '-${toPay.toEuro()}',
                      description == '' ? 'Lightning Invoice' : description);
                }

                showModalBottomSheet(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    context: navigatorKey.currentContext!,
                    builder: (context) {
                      return ModalDismissWrapper(
                        child: PaymentFinished(
                          headline: success
                              ? AppLocalizations.of(context)!.paymentSuccessful
                              : AppLocalizations.of(context)!.paymentFailed,
                          success: success,
                          amount: CurrencyDisplay(
                              amount: toPay.toEuro().toString(),
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
  });
}

class Invoice {
  String paymentHash;
  SatoshiAmount amount;
  String description;
  DateTime date;
  int expirySeconds;

  Invoice(this.amount, this.description, this.date, this.expirySeconds,
      this.paymentHash);

  factory Invoice.fromJson(dynamic jsonData) {
    var data = credentialToMap(jsonData);

    return Invoice(
        SatoshiAmount.fromUnitAndValue(data['amount_msat'], SatoshiUnit.msat),
        data['description'],
        DateTime.fromMillisecondsSinceEpoch(data['date'] * 1000),
        data['expiry'],
        data['payment_hash']);
  }
}

class SatoshiAmount {
  int milliSatoshi;

  SatoshiAmount(this.milliSatoshi);

  factory SatoshiAmount.fromUnitAndValue(int value, SatoshiUnit unit) {
    if (unit == SatoshiUnit.sat) {
      return SatoshiAmount(value * 1000);
    } else {
      return SatoshiAmount(value);
    }
  }

  int toMSat() => milliSatoshi;

  double toSat() => milliSatoshi / 1000;

  double toEuro() => double.parse((milliSatoshi / 100000).toStringAsFixed(2));
}

enum SatoshiUnit { sat, msat }
