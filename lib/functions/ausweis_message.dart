import 'dart:convert';

class AusweisMessage {
  String type;

  AusweisMessage({required this.type});

  factory AusweisMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? type = data['msg'];
    if (type == 'ACCESS_RIGHTS') {
      return AccessRightsMessage.fromJson(jsonData);
    } else if (type == 'API_LEVEL') {
      return ApiLevelMessage.fromJson(jsonData);
    } else if (type == 'AUTH') {
      return AuthMessage.fromJson(jsonData);
    } else if (type == 'BAD_STATE') {
      return BadStateMessage.fromJson(jsonData);
    } else if (type == 'CERTIFICATE') {
      return CertificateMessage.fromJson(jsonData);
    } else if (type == 'CHANGE_PIN') {
      return ChangePinMessage.fromJson(jsonData);
    } else if (type == 'ENTER_CAN') {
      return EnterCanMessage.fromJson(jsonData);
    } else if (type == 'ENTER_PIN') {
      return EnterPinMessage.fromJson(jsonData);
    } else if (type == 'ENTER_NEW_PIN') {
      return EnterNewPinMessage.fromJson(jsonData);
    } else if (type == 'ENTER_PUK') {
      return EnterPukMessage.fromJson(jsonData);
    } else if (type == 'INFO') {
      return InfoMessage.fromJson(jsonData);
    } else if (type == 'INSERT_CARD') {
      return InsertCardMessage.fromJson(jsonData);
    } else if (type == 'INTERNAL_ERROR') {
      return InternalErrorMessage.fromJson(jsonData);
    } else if (type == 'INVALID') {
      return InvalidMessage.fromJson(jsonData);
    } else if (type == 'READER') {
      return ReaderMessage.fromJson(jsonData);
    } else if (type == 'READER_LIST') {
      return ReaderListMessage.fromJson(jsonData);
    } else if (type == 'STATUS') {
      return StatusMessage.fromJson(jsonData);
    } else if (type == 'UNKNOWN_COMMAND') {
      return UnknownCommandMessage.fromJson(jsonData);
    } else if (type == 'DISCONNECT') {
      return DisconnectMessage();
    } else if (type == 'PAUSE') {
      return PauseMessage();
    } else {
      return AusweisMessage(type: type ?? '');
    }
  }

  Map<String, dynamic> toJson() {
    return {'msg': type};
  }
}

class DisconnectMessage extends AusweisMessage {
  DisconnectMessage() : super(type: 'DISCONNECT');
}

class AccessRightsMessage extends AusweisMessage {
  String? error, transactionInfo;
  List<String> optionalRights, requiredRights, effectiveRights;
  DateTime? ageVerificationDate, validityDate;
  String? requiredAge, communityId;

  AccessRightsMessage(
      {this.error,
      required this.optionalRights,
      required this.requiredRights,
      List<String>? effectiveRights,
      this.transactionInfo,
      this.ageVerificationDate,
      this.communityId,
      this.requiredAge,
      this.validityDate})
      : effectiveRights = effectiveRights ?? requiredRights + optionalRights,
        super(type: 'ACCESS_RIGHTS');

  factory AccessRightsMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    String? ti = data['transactionInfo'];

    List? optionalRights, requiredRights, effectiveRights;
    Map chat = data['chat'];
    optionalRights = chat['optional'];
    effectiveRights = chat['effective'];
    requiredRights = chat['required'];

    Map? aux = data['aux'];
    DateTime? ageVerificationDate, validityDate;
    String? requiredAge, communityId;
    if (aux != null) {
      requiredAge = aux['requiredAge'];
      communityId = aux['communityId'];
      if (aux.containsKey('validityDate')) {
        validityDate = DateTime.parse(aux['validityDate']);
      }
      if (aux.containsKey('ageVerificationDate')) {
        ageVerificationDate = DateTime.parse(aux['ageVerificationDate']);
      }
    }

    return AccessRightsMessage(
        error: error,
        transactionInfo: ti,
        effectiveRights: effectiveRights?.cast<String>() ?? [],
        optionalRights: optionalRights?.cast<String>() ?? [],
        requiredRights: requiredRights?.cast<String>() ?? [],
        ageVerificationDate: ageVerificationDate,
        communityId: communityId,
        requiredAge: requiredAge,
        validityDate: validityDate);
  }
}

class ApiLevelMessage extends AusweisMessage {
  String? error;
  int currentLevel;
  List<int>? availableLevels;

  ApiLevelMessage(
      {this.error, required this.currentLevel, this.availableLevels})
      : super(type: 'API_LEVEL');

  factory ApiLevelMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    int level = data['current'];
    List? availableLevels = data['available'];

    return ApiLevelMessage(
        currentLevel: level,
        error: error,
        availableLevels: availableLevels?.cast<int>());
  }
}

class AuthMessage extends AusweisMessage {
  String? error, major, minor, language, description, message, reason, url;

  AuthMessage(
      {this.error,
      this.description,
      this.language,
      this.major,
      this.message,
      this.minor,
      this.reason,
      this.url})
      : super(type: 'AUTH');

  factory AuthMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'], url = data['url'];
    Map? result = data['result'];
    String? major = result?['major'],
        minor = result?['minor'],
        description = result?['description'],
        lang = result?['language'],
        message = result?['message'],
        reason = result?['reason'];

    return AuthMessage(
        error: error,
        description: description,
        language: lang,
        major: major,
        message: message,
        minor: minor,
        reason: reason,
        url: url);
  }
}

class BadStateMessage extends AusweisMessage {
  String? errorCmd;

  BadStateMessage({this.errorCmd}) : super(type: 'BAD_STATE');

  factory BadStateMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    return BadStateMessage(errorCmd: error);
  }
}

class CertificateMessage extends AusweisMessage {
  String issuerName, issuerUrl, subjectName, subjectUrl, termsOfUsage, purpose;
  DateTime effectiveDate, expirationDate;

  CertificateMessage(
      {required this.issuerName,
      required this.issuerUrl,
      required this.subjectName,
      required this.subjectUrl,
      required this.termsOfUsage,
      required this.purpose,
      required this.effectiveDate,
      required this.expirationDate})
      : super(type: 'CERTIFICATE');

  factory CertificateMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    Map description = data['description'];
    Map validity = data['validity'];

    return CertificateMessage(
        issuerName: description['issuerName'],
        issuerUrl: description['issuerUrl'],
        subjectName: description['subjectName'],
        subjectUrl: description['subjectUrl'],
        termsOfUsage: description['termsOfUsage'],
        purpose: description['purpose'],
        effectiveDate: DateTime.parse(validity['effectiveDate']),
        expirationDate: DateTime.parse(validity['expirationDate']));
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'issuerName': issuerName,
      'issuerUrl': issuerUrl,
      'subjectName': subjectName,
      'subjectUrl': subjectUrl,
      'purpose': purpose,
      'termsOfUsage': termsOfUsage,
      'effectiveDate': effectiveDate.toLocal().toIso8601String(),
      'expirationDate': expirationDate.toLocal().toIso8601String()
    };
  }
}

class ChangePinMessage extends AusweisMessage {
  bool success;
  String? reason;

  ChangePinMessage({required this.success, this.reason})
      : super(type: 'CHANGE_PIN');

  factory ChangePinMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);

    return ChangePinMessage(success: data['success'], reason: data['reason']);
  }
}

class EnterCanMessage extends AusweisMessage {
  String? error;
  ReaderMessage? reader;

  EnterCanMessage({this.error, this.reader}) : super(type: 'ENTER_CAN');

  factory EnterCanMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    return EnterCanMessage(
        error: data['error'],
        reader: data.containsKey('reader')
            ? ReaderMessage.fromJson(data['reader'])
            : null);
  }
}

class EnterPinMessage extends AusweisMessage {
  String? error;
  ReaderMessage? reader;

  EnterPinMessage({this.error, this.reader}) : super(type: 'ENTER_PIN');

  factory EnterPinMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    return EnterPinMessage(
        error: data['error'],
        reader: data.containsKey('reader')
            ? ReaderMessage.fromJson(data['reader'])
            : null);
  }
}

class EnterNewPinMessage extends AusweisMessage {
  String? error;
  ReaderMessage? reader;

  EnterNewPinMessage({this.error, this.reader}) : super(type: 'ENTER_NEW_PIN');

  factory EnterNewPinMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    return EnterNewPinMessage(
        error: data['error'],
        reader: data.containsKey('reader')
            ? ReaderMessage.fromJson(data['reader'])
            : null);
  }
}

class EnterPukMessage extends AusweisMessage {
  String? error;
  ReaderMessage? reader;

  EnterPukMessage({this.error, this.reader}) : super(type: 'ENTER_PUK');

  factory EnterPukMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    return EnterPukMessage(
        error: data['error'],
        reader: data.containsKey('reader')
            ? ReaderMessage.fromJson(data['reader'])
            : null);
  }
}

class InfoMessage extends AusweisMessage {
  String name,
      implementationTitle,
      implementationVendor,
      implementationVersion,
      specificationTitle,
      specificationVersion,
      specificationVendor;
  String? ausweisApp;

  InfoMessage(
      {required this.name,
      required this.implementationTitle,
      required this.implementationVendor,
      required this.implementationVersion,
      required this.specificationTitle,
      required this.specificationVendor,
      required this.specificationVersion,
      this.ausweisApp})
      : super(type: 'INFO');

  factory InfoMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    Map versionInfo = data['VersionInfo'];

    return InfoMessage(
        name: versionInfo['Name'],
        implementationTitle: versionInfo['Implementation-Title'],
        implementationVendor: versionInfo['Implementation-Vendor'],
        implementationVersion: versionInfo['Implementation-Version'],
        specificationTitle: versionInfo['Specification-Title'],
        specificationVendor: versionInfo['Specification-Vendor'],
        specificationVersion: versionInfo['Specification-Version'],
        ausweisApp: data['AusweisApp']);
  }
}

class InsertCardMessage extends AusweisMessage {
  String? error;

  InsertCardMessage({this.error}) : super(type: 'INSERT_CARD');

  factory InsertCardMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    return InsertCardMessage(error: error);
  }
}

class InternalErrorMessage extends AusweisMessage {
  String? error;

  InternalErrorMessage({this.error}) : super(type: 'INTERNAL_ERROR');

  factory InternalErrorMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    return InternalErrorMessage(error: error);
  }
}

class InvalidMessage extends AusweisMessage {
  String? error;

  InvalidMessage({this.error}) : super(type: 'INVALID');

  factory InvalidMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    return InvalidMessage(error: error);
  }
}

class ReaderMessage extends AusweisMessage {
  String name;
  bool attached;

  bool? cardInoperative, cardDeactivated, insertable, keypad;
  int? cardRetryCounter;

  ReaderMessage(
      {required this.name,
      this.insertable,
      required this.attached,
      this.keypad,
      this.cardDeactivated,
      this.cardInoperative,
      this.cardRetryCounter})
      : super(type: 'READER');

  factory ReaderMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    Map? card = data['card'];

    return ReaderMessage(
        name: data['name'],
        insertable: data['insertable'],
        attached: data['attached'],
        keypad: data['keypad'],
        cardDeactivated: card?['deactivated'],
        cardInoperative: card?['inoperative'],
        cardRetryCounter: card?['retryCounter']);
  }
}

class ReaderListMessage extends AusweisMessage {
  List<ReaderMessage> readers;

  ReaderListMessage({required this.readers}) : super(type: 'READER_LIST');

  factory ReaderListMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    List r = data['readers'];

    return ReaderListMessage(
        readers: r.map((e) => ReaderMessage.fromJson(e)).toList());
  }
}

class StatusMessage extends AusweisMessage {
  String? workflow, state;
  int? progress;

  StatusMessage({this.workflow, this.progress, this.state})
      : super(type: 'STATUS');

  factory StatusMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    return StatusMessage(
        workflow: data['workflow'],
        progress: data['progress'],
        state: data['state']);
  }
}

class PauseMessage extends AusweisMessage {
  String? cause;

  PauseMessage({this.cause}) : super(type: 'PAUSE');

  factory PauseMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    return PauseMessage(
      cause: data['cause'],
    );
  }
}

class UnknownCommandMessage extends AusweisMessage {
  String? error;

  UnknownCommandMessage({this.error}) : super(type: 'UNKNOWN_COMMAND');

  factory UnknownCommandMessage.fromJson(dynamic jsonData) {
    var data = _toJsonMap(jsonData);
    String? error = data['error'];
    return UnknownCommandMessage(error: error);
  }
}

Map<String, dynamic> _toJsonMap(dynamic jsonData) {
  if (jsonData is String) {
    return jsonDecode(jsonData);
  } else if (jsonData is Map<String, dynamic>) {
    return jsonData;
  } else {
    throw Exception();
  }
}
