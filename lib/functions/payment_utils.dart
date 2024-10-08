import 'dart:convert';

import 'package:bech32/bech32.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_ssi/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:http/http.dart';
import 'package:id_ideal_wallet/basicUi/standard/currency_display.dart';
import 'package:id_ideal_wallet/basicUi/standard/modal_dismiss_wrapper.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_finished.dart';
import 'package:id_ideal_wallet/basicUi/standard/payment_intent.dart';
import 'package:id_ideal_wallet/constants/server_address.dart';
import 'package:id_ideal_wallet/functions/didcomm_message_handler.dart';
import 'package:id_ideal_wallet/provider/wallet_provider.dart';
import 'package:id_ideal_wallet/views/lnurl_amount_selector.dart';
import 'package:id_ideal_wallet/views/payment_method_selection.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

class LightningException implements Exception {
  String message;

  LightningException(this.message);
}

Future<void> createLNWallet(String paymentId) async {
  var id = const Uuid().v4();
  var res = await post(Uri.parse('$lnMainnetEndpoint/create_user'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"username": id, 'wallet_name': id}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    // everything ok = store to wallet
    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!,
        listen: false);
    wallet.storeLnAccount(paymentId, answer, isMainnet: true);
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<SatoshiAmount> getBalance(String inKey) async {
  var res = await post(Uri.parse('$lnMainnetEndpoint/wallet_details'),
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
  var res = await post(Uri.parse('$lnMainnetEndpoint/create_invoice'),
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
    String m = answer['detail'] ?? answer['message'];
    if (m.contains('exceeds limit')) {
      m = AppLocalizations.of(navigatorKey.currentContext!)!.invoiceLimit;
    }
    throw LightningException(m);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<String> payInvoice(String adminKey, String invoice) async {
  var res = await post(Uri.parse('$lnMainnetEndpoint/pay_invoice'),
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
  var res = await post(Uri.parse('$lnMainnetEndpoint/decode_invoice'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'inkey': inKey, 'invoice': invoice}));

  if (res.statusCode == 200) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    return Invoice.fromJson(answer);
  } else if (res.statusCode == 400) {
    Map<String, dynamic> answer = jsonDecode(res.body);
    logger.d(answer['detail'] ?? answer['message']);
    showErrorMessage('Invoice ungültig');
    throw Exception(answer['detail']);
  } else {
    logger.d('Something went wrong : ${res.statusCode}; ${res.body}');
    throw Exception('Something went wrong : ${res.statusCode}; ${res.body}');
  }
}

Future<bool> isInvoicePaid(String inKey, String paymentHash) async {
  var res = await post(Uri.parse('$lnMainnetEndpoint/get_payment'),
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

void payInvoiceInteraction(String invoice,
    {String? descriptionHash, int? mSatAmount}) async {
  var wallet =
      Provider.of<WalletProvider>(navigatorKey.currentContext!, listen: false);

  var paymentMethods = wallet.paymentCredentials;
  if (paymentMethods.isEmpty) {
    Future.delayed(const Duration(seconds: 1), () {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.noPaymentMethod,
          AppLocalizations.of(navigatorKey.currentContext!)!.noPaymentNote);
    });
    return;
  }

  String paymentId;
  if (paymentMethods.length > 1) {
    int? selectedIndex =
        await Future.delayed(const Duration(seconds: 1), () async {
      return await Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
              builder: (context) =>
                  PaymentMethodSelector(paymentMethods: paymentMethods)));
    });
    logger.d(selectedIndex);
    if (selectedIndex == null) {
      return;
    } else {
      paymentId = paymentMethods[selectedIndex].id!;
    }
  } else {
    paymentId = paymentMethods.first.id!;
  }

  var lnInKey = wallet.getLnInKey(paymentId);
  var lnAdminKey = wallet.getLnAdminKey(paymentId);
  if (lnInKey == null || lnAdminKey == null) {
    throw Exception('Cant pay: lnInkey or lnAdminKey null. Fatal Error');
    //TODO: show to user
  }

  var decoded = await decodeInvoice(lnInKey, invoice);
  SatoshiAmount toPay = decoded.amount;
  logger.d(toPay.toMSat());
  logger.d(lnAdminKey);
  logger.d(lnInKey);
  logger.d(invoice);
  var description = decoded.description;

  if (descriptionHash != null) {
    if (descriptionHash != decoded.descriptionHash) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.hashNotMatch,
          AppLocalizations.of(navigatorKey.currentContext!)!.hashNotMatchNote);
      return;
    }
  }

  if (mSatAmount != null) {
    if (mSatAmount != decoded.amount.milliSatoshi) {
      showErrorMessage(
          AppLocalizations.of(navigatorKey.currentContext!)!.otherValue,
          AppLocalizations.of(navigatorKey.currentContext!)!.otherValueNote);
      return;
    }
  }

  Future.delayed(const Duration(seconds: 0), () {
    showModalBottomSheet(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), topRight: Radius.circular(10)),
        ),
        context: navigatorKey.currentContext!,
        builder: (context) {
          return ModalDismissWrapper(
            closeSeconds: -1,
            child: PaymentIntent(
              amount: CurrencyDisplay(
                  amount: toPay.toSat().toString(),
                  symbol: 'sat',
                  mainFontSize: 35,
                  centered: true),
              memo: description ?? '',
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
                logger.d(paid);
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
                    logger.d(x);
                    if (x == -1) {
                      success = false;
                      // break;
                    } else {
                      success = true;
                    }
                  }
                }

                if (success) {
                  wallet.storePayment(
                      paymentId,
                      '-${toPay.toSat()}',
                      description == '' || description == null
                          ? 'Lightning Invoice'
                          : description);
                }

                showModalBottomSheet(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10)),
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
                              amount: toPay.toSat().toString(),
                              symbol: 'sat',
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

Future<void> handleLnurl(String lnurl) async {
  var decoded = const Bech32Codec().decode(lnurl, lnurl.length);
  var url = utf8.decode(fromWords(decoded.data));
  Map parsed;
  try {
    var dataResponse = await get(Uri.parse(url));
    if (dataResponse.statusCode != 200) {
      logger.d(dataResponse.body);
      showErrorMessage('Fehlerhafte LNURL');
      return;
    }
    parsed = jsonDecode(dataResponse.body);
  } catch (e) {
    logger.d(e);
    showErrorMessage('Ungültige Lnurl', testBuild ? '$e' : '');
    return;
  }

  if (parsed['status'] == 'ERROR') {
    showErrorMessage('Keine lnurl', parsed['reason']);
    return;
  }

  if (parsed['tag'] == 'payRequest') {
    var callback = parsed['callback'];
    int minAmount = parsed['minSendable'];
    int maxAmount = parsed['maxSendable'];
    List metadata = jsonDecode(parsed['metadata']);
    logger.d(sha256.convert(utf8.encode(parsed['metadata'])));
    List descriptionEntry = metadata.firstWhere(
        (element) => element is List && element.first == 'text/plain',
        orElse: () => ['', '']);
    String description = descriptionEntry.last;
    logger.d(maxAmount);
    logger.d(minAmount);
    var amountToSend = minAmount;
    var target = AmountSelection(
                    minAmount: minAmount,
                    maxAmount: maxAmount,
                    description: description,
                  );
    if (maxAmount != minAmount) {
      var a = await Navigator.of(navigatorKey.currentContext!)
          .push(
            Platform.isIOS
            ? CupertinoPageRoute(builder: (context) => target)
            : MaterialPageRoute(builder: (context) => target)
          );
      if (a == null) {
        return;
      } else {
        amountToSend = a;
      }
    }

    var invoiceResponse =
        await get(Uri.parse('$callback?amount=$amountToSend'));
    var invoiceParsed = jsonDecode(invoiceResponse.body);
    logger.d(invoiceParsed);

    if (invoiceParsed['status'] == 'ERROR') {
      showErrorMessage('Keine Invoice', invoiceParsed['reason']);
      return;
    }

    var invoice = invoiceParsed['pr'];
    payInvoiceInteraction(invoice);
  } else if (parsed['tag'] == 'withdrawRequest') {
    String? callback = parsed['callback'];
    int minAmount = parsed['minWithdrawable'];
    int maxAmount = parsed['maxWithdrawable'];
    String description = parsed['defaultDescription'] ?? '';
    String? k1 = parsed['k1'];

    if (k1 == null) {
      showErrorMessage('Wallet identifier fehlt');
      return;
    }
    if (callback == null) {
      showErrorMessage('Kein Callback');
      return;
    }

    var amountToSend = minAmount;
    var target = AmountSelection(
                    minAmount: minAmount,
                    maxAmount: maxAmount,
                    description: description,
                  );
    if (maxAmount != minAmount) {
      var a = await Navigator.of(navigatorKey.currentContext!)
          .push(
            Platform.isIOS
            ? CupertinoPageRoute(builder: (context) => target)
            : MaterialPageRoute(builder: (context) => target)
          );
      if (a == null) {
        return;
      } else {
        amountToSend = a;
      }
    }

    var wallet = Provider.of<WalletProvider>(navigatorKey.currentContext!);
    var paymentId = wallet.paymentCredentials.first.id!;

    var invoiceMap = await createInvoice(
        wallet.getLnInKey(paymentId)!, SatoshiAmount(amountToSend),
        memo: description);

    var index = invoiceMap['checking_id'];
    var invoice = invoiceMap['payment_request'];
    if (invoice == null || index == null) {
      showErrorMessage('Invoice erstellen fehlgeschlagen');
      return;
    }

    String toCall =
        '$callback${callback.contains('?') ? '&' : '?'}k1=$k1&pr=$invoice';
    Response res;
    try {
      res = await get(Uri.parse(toCall));
    } catch (e) {
      showErrorMessage('Auszahlung fehlgeschlagen', testBuild ? '$e' : '');
      return;
    }
    if (res.statusCode == 200) {
      var body = jsonDecode(res.body);
      String status = body['status'];
      if (status.toLowerCase() == 'ok') {
        wallet.newPayment(
            paymentId, index, description, SatoshiAmount(amountToSend));
      } else {
        showErrorMessage(
            'Auszahlung fehlgeschlagen', 'Grund: ${body['reason']}');
      }
    } else {
      showErrorMessage('Auszahlung fehlgeschlagen');
    }
  } else {
    showErrorMessage(
        'Unbekannte lnurl Funktion', '${parsed['tag']} wird nicht unterstützt');
  }
}

class Invoice {
  String paymentHash;
  String? descriptionHash;
  SatoshiAmount amount;
  String? description;
  DateTime date;
  int? expirySeconds;

  Invoice(this.amount, this.description, this.date, this.expirySeconds,
      this.paymentHash,
      [this.descriptionHash]);

  factory Invoice.fromJson(dynamic jsonData) {
    var data = credentialToMap(jsonData);
    logger.d(data);

    return Invoice(
        SatoshiAmount.fromUnitAndValue(data['amount_msat'], SatoshiUnit.msat),
        data['description'],
        DateTime.fromMillisecondsSinceEpoch(data['date'] * 1000),
        data['expiry'],
        data['payment_hash'],
        data['description_hash']);
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

// Source: https://github.com/bottlepay/dart_lnurl/blob/master/lib/src/bech32.dart
/// Converts a list of character positions in the bech32 alphabet ("words")
/// to binary data.
List<int> fromWords(List<int> words) {
  final res = convert(words, 5, 8, false);
  return res;
}

/// Taken from bech32 (bitcoinjs): https://github.com/bitcoinjs/bech32
List<int> convert(List<int> data, int inBits, int outBits, bool pad) {
  var value = 0;
  var bits = 0;
  var maxV = (1 << outBits) - 1;

  var result = <int>[];
  for (var i = 0; i < data.length; ++i) {
    value = (value << inBits) | data[i];
    bits += inBits;

    while (bits >= outBits) {
      bits -= outBits;
      result.add((value >> bits) & maxV);
    }
  }

  if (pad) {
    if (bits > 0) {
      result.add((value << (outBits - bits)) & maxV);
    }
  } else {
    if (bits >= inBits) {
      throw Exception('Excess padding');
    }

    if ((value << (outBits - bits)) & maxV > 0) {
      throw Exception('Non-zero padding');
    }
  }

  return result;
}
