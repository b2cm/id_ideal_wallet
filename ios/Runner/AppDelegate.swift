import UIKit
import Flutter
import AusweisApp2SDKWrapper

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    var methodChannelDeepLink: FlutterMethodChannel?
    var eventChannelDeepLink: FlutterEventChannel?
    
    var methodChannel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    
    var initialLink: String?
    
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      let workflowCallback = CallbackManager()
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      
      // initialize ausweis sdk channels
      methodChannel = FlutterMethodChannel(name: "app.channel.method", binaryMessenger: controller.binaryMessenger)
      eventChannel = FlutterEventChannel(name: "app.channel.event", binaryMessenger: controller.binaryMessenger)
      eventChannel!.setStreamHandler(EventChannelManager.shared)
      
      // initialize deep link channels
      methodChannelDeepLink = FlutterMethodChannel(name: "app.channel.deeplink", binaryMessenger: controller.binaryMessenger)
      eventChannelDeepLink = FlutterEventChannel(name: "app.channel.deeplink/events", binaryMessenger: controller.binaryMessenger)
      eventChannelDeepLink?.setStreamHandler(EventChannelManagerDeepLink.shared)
      
      methodChannel!.setMethodCallHandler({
          [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
          // check what method is called
          switch call.method {
          case "connectSdk":
              AA2SDKWrapper.workflowController.registerCallbacks(workflowCallback)
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
    
      methodChannelDeepLink!.setMethodCallHandler({
          [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
          switch call.method {
              case "getInitialLink":
                  if let initialLink = self?.initialLink {
                      result(initialLink)
                  } else {
                      result(FlutterError(code: "NO LINK FOUND", message: "No initial link has been stored yet", details: nil))
                  }
              default:
                  result(FlutterMethodNotImplemented)
            }
      })
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    // Handle incoming URL schemes
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // store it for the method handler
        self.initialLink = url.absoluteString
        
        // send the url to flutter to be handled there
        EventChannelManagerDeepLink.shared.sendEvent(url.absoluteString)
        
        let handled = super.application(app, open: url, options: options)
        
        return handled
    }
 
    override func application(_ application: UIApplication,
                              continue userActivity: NSUserActivity,
                              restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            guard let url = userActivity.webpageURL else {
                return false
            }
            
            // Store it for your method handler
            self.initialLink = url.absoluteString
            
            // Notify Flutter via EventChannel
            EventChannelManagerDeepLink.shared.sendEvent(url.absoluteString)
            return true
        }
        return false
    }
}

/**
    This function serves as link to the sdk. We decode the json we received from flutter,
    analyze the command that has been issued and call the correct sdk function. We also parse
    some datatypes when needed and do some pre checks.
**/
func decodeAndSendCommand(jsonString: String, res: FlutterResult) {

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

/**
    Simple extension we need when parsing the json
**/
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
