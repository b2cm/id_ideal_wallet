import 'dart:convert';

import 'package:http/http.dart';

String? lnAuthToken;

Future<String?> getLnAuthToken() async {
  var login = '5a9ec88b1677a8e4a14e';
  var password = '968394acb0ceeaf993c8';
  var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/auth'),
      body: {'login': login, 'password': password});
  if (res.statusCode == 200) {
    var decodedResponse = jsonDecode(res.body);
    lnAuthToken = decodedResponse['access_token'];

    print(lnAuthToken);
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
