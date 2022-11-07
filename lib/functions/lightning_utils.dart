import 'dart:convert';

import 'package:http/http.dart';

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
