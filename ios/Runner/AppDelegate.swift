import UIKit
import Flutter
import AusweisApp2SDKWrapper

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let methodChannel = FlutterMethodChannel(name: "app.channel.method",
                                                binaryMessenger: controller.binaryMessenger)
      let eventChannel = FlutterEventChannel(name: "app.channel.event",
                                                     binaryMessenger: controller.binaryMessenger)
              eventChannel.setStreamHandler(EventChannelManager.shared)
      methodChannel.setMethodCallHandler({
          [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
          // This method is invoked on the UI thread.
          switch call.method {
          case "connectSdk":
              AA2SDKWrapper.workflowController.start()
          case "disconnectSdk":
              AA2SDKWrapper.workflowController.stop()
          case "sendCommand":
              if let arguments = call.arguments as? String {
                  decodeAndSendCommand(jsonString: arguments, res: result)
              } else {
                  result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected a JSON string as arguments", details: nil))
              }
          default:
              result(FlutterMethodNotImplemented)
          }
      })
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
}

func decodeAndSendCommand(jsonString: String, res: FlutterResult) {
    let decoder = JSONDecoder()
    do {
        let commandDict = try JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!, options: []) as? [String: Any]
        guard let cmdType = commandDict?["cmd"] as? String else {
            print("Command type is missing")
            return
        } 
        switch cmdType {
        case "GET_INFO":
            AA2SDKWrapper.workflowController.getInfo()
        case "GET_STATUS":
            AA2SDKWrapper.workflowController.getStatus()
        case "GET_API_LEVEL":
            print("Received unknown command type: \(cmdType)")
        case "SET_API_LEVEL":
            print("Received unknown command type: \(cmdType)")
        case "GET_READER":
            if let name = commandDict?["name"] as? String {
                AA2SDKWrapper.workflowController.getReader(name: name)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No reader given", details: nil))
            }
        case "GET_READER_LIST":
            AA2SDKWrapper.workflowController.getReaderList()

        case "GET_ACCESS_RIGHTS":
            AA2SDKWrapper.workflowController.getAccessRights()

        case "SET_ACCESS_RIGHTS":
            if let accessRights = commandDict?["chat"] as? [AccessRight] {
                AA2SDKWrapper.workflowController.setAccessRights(accessRights)
            }

        case "SET_CARD":
            if let name = commandDict?["name"] as? String {
                AA2SDKWrapper.workflowController.setCard(name: name)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No name given", details: nil))
            }

        case "GET_CERTIFICATE":
            AA2SDKWrapper.workflowController.getCertificate()

        case "CANCEL":
            AA2SDKWrapper.workflowController.cancel()

        case "ACCEPT":
            AA2SDKWrapper.workflowController.accept()

        case "INTERRUPT":
            AA2SDKWrapper.workflowController.interrupt()

        case "CONTINUE":
            AA2SDKWrapper.workflowController.continueWorkflow()

        case "SET_PIN":
            if let value = commandDict?["value"] as? String {
                AA2SDKWrapper.workflowController.setPin(value)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No value given", details: nil))
            }

        case "SET_NEW_PIN":
            if let value = commandDict?["value"] as? String {
                AA2SDKWrapper.workflowController.setNewPin(value)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No value given", details: nil))
            }

        case "SET_CAN":
            if let value = commandDict?["value"] as? String {
                AA2SDKWrapper.workflowController.setCan(value)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No value given", details: nil))
            }

        case "SET_PUK":
            if let value = commandDict?["value"] as? String {
                AA2SDKWrapper.workflowController.setPuk(value)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No value given", details: nil))
            }

        case "RUN_AUTH":
            // @dev Token Url is mandatory, so we require it at the top level
            if let tcTokenUrl = commandDict?["tcTokenURL"] as? String {
                // @dev we now take apart the "messages" dictionary that contain the AA2UserInfoMessages
                var sessionStarted: String? = nil
                var sessionFailed: String? = nil
                var sessionSucceeded: String? = nil
                var sessionInProgress: String? = nil
                // @dev if there are no AA2UserInfoMessages we can skip since its optional
                if let messagesDict = commandDict?["messages"] as? [String: String?] {
                    sessionStarted = messagesDict["sessionStarted"] ?? nil
                    sessionFailed = messagesDict["sessionFailed"] ?? nil
                    sessionSucceeded = messagesDict["sessionSucceeded"] ?? nil
                    sessionInProgress = messagesDict["sessionInProgress"] ?? nil
                }
                // @dev everything is optional except the url, so we force the url and parse everything else to either the default value defined in startAuthentication or take the value that we received
                AA2SDKWrapper.workflowController.startAuthentication(
                    withTcTokenUrl: URL.init(string: tcTokenUrl)!,
                    withDeveloperMode: (commandDict?["developerMode"] as? String ?? "false").boolValue ?? false,
                    withUserInfoMessages:
                        AA2UserInfoMessages.init(
                            sessionStarted: sessionStarted,
                            sessionFailed: sessionFailed,
                            sessionSucceeded: sessionSucceeded,
                            sessionInProgress: sessionInProgress),
                    withStatusMsgEnabled: (commandDict?["status"] as? String ?? "false").boolValue ?? false)
            } else {
                res(FlutterError(code: "INVALID_ARGUMENTS", message: "No tcTokenURL given", details: nil))
            }

        case "RUN_CHANGE_PIN":
            // @dev we now take apart the "messages" dictionary that contain the AA2UserInfoMessages
            var sessionStarted: String? = nil
            var sessionFailed: String? = nil
            var sessionSucceeded: String? = nil
            var sessionInProgress: String? = nil
            // @dev if there are no AA2UserInfoMessages we can skip since its optional
            if let messagesDict = commandDict?["messages"] as? [String: String?] {
                sessionStarted = messagesDict["sessionStarted"] ?? nil
                sessionFailed = messagesDict["sessionFailed"] ?? nil
                sessionSucceeded = messagesDict["sessionSucceeded"] ?? nil
                sessionInProgress = messagesDict["sessionInProgress"] ?? nil
            }
            AA2SDKWrapper.workflowController.startChangePin(
                withUserInfoMessages:
                    AA2UserInfoMessages.init(
                        sessionStarted: sessionStarted,
                        sessionFailed: sessionFailed,
                        sessionSucceeded: sessionSucceeded,
                        sessionInProgress: sessionInProgress),
                withStatusMsgEnabled: (commandDict?["status"] as? String ?? "false").boolValue ?? false)

        default:
            print("Received unknown command type: \(cmdType)")
        }
    } catch {
        print("Error decoding JSON: \(error)")
    }
}


class CallbackManager: WorkflowCallbacks {
    
    func onAccessRights(error: String?, accessRights: AusweisApp2SDKWrapper.AccessRights?) {
        // ACCESS_RIGHTS
        struct AccessRightsResult: Codable {
            let type: String
            let error, transactionInfo: String?
            let optionalRights, requiredRights, effectiveRights: [String]
            let ageVerificationDate, validityDate: Date?
            let requiredAge, communityId: String?
        }
        
        let message = try! JSONEncoder().encode(AccessRightsResult(type: "ACCESS_RIGHTS", error: error, transactionInfo: accessRights?.transactionInfo, optionalRights: accessRights!.optionalRights.map { $0.rawValue }, requiredRights: accessRights!.requiredRights.map { $0.rawValue }, effectiveRights: accessRights!.effectiveRights.map { $0.rawValue }, ageVerificationDate: accessRights?.auxiliaryData?.ageVerificationDate, validityDate: accessRights?.auxiliaryData?.validityDate, requiredAge: accessRights?.auxiliaryData?.requiredAge?.description, communityId: accessRights?.auxiliaryData?.communityId))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onAuthenticationCompleted(authResult: AusweisApp2SDKWrapper.AuthResult) {
        // String? error, major, minor, language, description, message, reason, url;
        struct authCompletedResult: Encodable {
            let type: String
            let error: String?
            let major: String?
            let minor: String?
            let language: String?
            let description: String?
            let message: String?
            let reason: String?
            let url: String?
        }
        let message = try! JSONEncoder().encode(authCompletedResult(type: "AUTH", error: nil, major: authResult.result?.major, minor: authResult.result?.minor, language: authResult.result?.language, description: authResult.result?.description, message: authResult.result?.message, reason: authResult.result?.reason, url: authResult.url?.absoluteString))
        
        EventChannelManager.shared.sendEvent(message)
        
    }
    
    func onAuthenticationStarted() {
        // @dev ?
    }
    
    func onAuthenticationStartFailed(error: String) {
        // @dev ?
    }
    
    func onBadState(error: String) {
        // @dev ?
    }
    
    func onCertificate(certificateDescription: AusweisApp2SDKWrapper.CertificateDescription) {
        // CERTIFICATE
        struct CertificateResult: Codable {
            let type: String
            let issuerName, issuerUrl, subjectName, subjectUrl, termsOfUsage, purpose: String
            let effectiveDate, expirationDate: Date
        }
        
        let message = try! JSONEncoder().encode(CertificateResult(type: "CERTIFICATE", issuerName: certificateDescription.issuerName, issuerUrl: certificateDescription.issuerUrl!.absoluteString, subjectName: certificateDescription.subjectName, subjectUrl: certificateDescription.subjectUrl!.absoluteString, termsOfUsage: certificateDescription.termsOfUsage, purpose: certificateDescription.purpose, effectiveDate: certificateDescription.validity.effectiveDate, expirationDate: certificateDescription.validity.expirationDate))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onChangePinCompleted(changePinResult: AusweisApp2SDKWrapper.ChangePinResult) {
        // @dev ?
    }
    
    func onChangePinStarted() {
        // @dev ?
    }
    
    func onEnterCan(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        // ENTER_CAN
        struct ReaderCardCodable: Codable {
            let name: String
            let attached: Bool
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let insertable: Bool?
            let keypad: Bool?
            let cardRetryCounter: Int?
        }
        
        struct EnterCanResult: Codable {
            let type: String
            let error: String?
            let reader: ReaderCardCodable?
        }
        
        let message = try! JSONEncoder().encode(EnterCanResult(type: "ENTER_CAN", error: error, reader: ReaderCardCodable(name: reader.name, attached: reader.attached, cardDeactivated: reader.card?.deactivated, cardInoperative: reader.card?.inoperative, insertable: reader.insertable, keypad: reader.keypad, cardRetryCounter: reader.card?.pinRetryCounter)))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onEnterNewPin(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        // @dev ?
    }
    
    func onEnterPin(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        // ENTER_PIN
        struct ReaderCardCodable: Codable {
            let name: String
            let attached: Bool
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let insertable: Bool?
            let keypad: Bool?
            let cardRetryCounter: Int?
        }
        
        struct EnterPinResult: Codable {
            let type: String
            let reader: ReaderCardCodable?
        }
        
        let message = try! JSONEncoder().encode(EnterPinResult(type: "ENTER_PIN", reader: ReaderCardCodable(name: reader.name, attached: reader.attached, cardDeactivated: reader.card?.deactivated, cardInoperative: reader.card?.inoperative, insertable: reader.insertable, keypad: reader.keypad, cardRetryCounter: reader.card?.pinRetryCounter)))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onEnterPuk(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        // ENTER_PUK
        struct ReaderCardCodable: Codable {
            let name: String
            let attached: Bool
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let insertable: Bool?
            let keypad: Bool?
            let cardRetryCounter: Int?
        }
        
        struct EnterPukResult: Codable {
            let type: String
            let error: String?
            let reader: ReaderCardCodable?
        }
        
        let message = try! JSONEncoder().encode(EnterPukResult(type: "ENTER_CAN", error: error, reader: ReaderCardCodable(name: reader.name, attached: reader.attached, cardDeactivated: reader.card?.deactivated, cardInoperative: reader.card?.inoperative, insertable: reader.insertable, keypad: reader.keypad, cardRetryCounter: reader.card?.pinRetryCounter)))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onInfo(versionInfo: AusweisApp2SDKWrapper.VersionInfo) {
        // @dev ?
    }
    
    func onInsertCard(error: String?) {
        // type INSERT_CARD, String? error
        struct InsertCardResult: Encodable {
            let type: String
            let error: String?
        }
        let message = try! JSONEncoder().encode(InsertCardResult(type: "INSERT_CARD", error: error))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onInternalError(error: String) {
        // @dev ?
    }
    
    func onPause(cause: AusweisApp2SDKWrapper.Cause) {
        // type PAUSE, String? error
        struct PauseResult: Encodable {
            let type: String
            let cause: String?
        }
        
        let message = try! JSONEncoder().encode(PauseResult(type: "INSERT_CARD", cause: cause.rawValue))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onReader(reader: AusweisApp2SDKWrapper.Reader?) {
        // READER
        struct ReaderCardCodable: Codable {
            let type: String
            let name: String
            let attached: Bool
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let insertable: Bool?
            let keypad: Bool?
            let cardRetryCounter: Int?
        }
        
        let message = try! JSONEncoder().encode(ReaderCardCodable(type: "READER", name: reader!.name, attached: reader!.attached, cardDeactivated: reader?.card?.deactivated, cardInoperative: reader?.card?.inoperative, insertable: reader?.insertable, keypad: reader?.keypad, cardRetryCounter: reader?.card?.pinRetryCounter))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onReaderList(readers: [AusweisApp2SDKWrapper.Reader]?) {
        // @dev ?
    }
    
    func onStarted() {
        // @dev ?
    }
    
    func onStatus(workflowProgress: AusweisApp2SDKWrapper.WorkflowProgress) {
        // STATUS
        struct StatusResult: Encodable {
            let type: String
            let workflow, state: String?
            let progress: Int?
        }
        
        let message = try! JSONEncoder().encode(StatusResult(type: "STATUS", workflow: workflowProgress.workflow?.rawValue, state: workflowProgress.state, progress: workflowProgress.progress))
        
        EventChannelManager.shared.sendEvent(message)
    }
    
    func onWrapperError(error: AusweisApp2SDKWrapper.WrapperError) {
        // @dev ?
    }

}

extension String {
    var boolValue: Bool? {
        switch self.lowercased() {
            case "true", "TRUE", "True", "1":
                return true
            case "false", "FALSE", "False", "0":
                return false
            default:
                return nil
        }
    }
}

class EventChannelManager: NSObject, FlutterStreamHandler {
    static let shared = EventChannelManager()
    private var eventSink: FlutterEventSink?

    private override init() { super.init() }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendEvent(_ event: Any) {
        eventSink?(event)
    }
}
