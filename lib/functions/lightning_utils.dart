import 'dart:convert';

import 'package:http/http.dart';

String? lnAuthToken;

Future<void> getLnAuthToken() async {
  var login = '5a9ec88b1677a8e4a14e';
  var password = '968394acb0ceeaf993c8';
  var res = await post(Uri.https('ln.pixeldev.eu', 'lndhub/auth'),
      body: {'login': login, 'password': password});
  if (res.statusCode == 200) {
    var decodedResponse = jsonDecode(res.body);
    lnAuthToken = decodedResponse['access_token'];
    print(lnAuthToken);
  } else {
    throw Exception('cant get access token for lndhub');
  }
}
