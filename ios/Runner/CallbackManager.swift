//
//  CallbackManager.swift
//  Runner
//
//  Created by Jonas Bentke on 13.08.24.
//
/**
 This Class implements the CallbackManager that is required by the AusweisApp. Since the Datatypes from the Ausweis App are not codable we manually encode them into json. There are some
 discrapancies between the datatypes defined here and the once that get send straight from the AusweisSdk. Since the Android version is directly communicating with the sdk instead of the wrapper
 we parse the data how the sdk returns them to match with android.
 The only other thing we do here is calling interupt whenever a user input is required such as onEnterPin etc.
 There are also a bunch of callbacks that do nothing simply because we dont need them to do anything on the flutter side. Those functions can be found at the end.
 */
import Foundation
import Flutter
import AusweisApp2SDKWrapper

class CallbackManager: WorkflowCallbacks {
    
    func onAccessRights(error: String?, accessRights: AusweisApp2SDKWrapper.AccessRights?) {
        print("############### onAccessRights ######################")

        struct AccessRightsResult: Codable {
            let msg: String
            let error, transactionInfo: String?
            let chat: Chat
            let ageVerificationDate: String?
            let aux: Aux
        }
        
        struct Chat: Codable {
            let optional, required, effective: [String?]
        }
        
        struct Aux: Codable {
            let validityDate: String?
            let requiredAge, communityId: String?
        }
        
        let message = try! JSONEncoder().encode(AccessRightsResult(msg: "ACCESS_RIGHTS", error: error, transactionInfo: accessRights?.transactionInfo, chat: Chat(optional: accessRights!.optionalRights.map { $0.rawValue }, required: accessRights!.requiredRights.map { $0.rawValue }, effective: accessRights!.effectiveRights.map { $0.rawValue }), ageVerificationDate: accessRights?.auxiliaryData?.ageVerificationDate?.description, aux: Aux(validityDate: accessRights?.auxiliaryData?.validityDate?.description, requiredAge: accessRights?.auxiliaryData?.requiredAge?.description, communityId: accessRights?.auxiliaryData?.communityId)))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onAuthenticationCompleted(authResult: AusweisApp2SDKWrapper.AuthResult) {

        struct authCompletedResult: Encodable {
            let msg: String
            let error: String?
            let result: Result
            let url: String?
        }
        
        struct Result: Codable {
            let major: String?
            let minor: String?
            let language: String?
            let description: String?
            let message: String?
            let reason: String?
        }
        
        let message = try! JSONEncoder().encode(authCompletedResult(msg: "AUTH", error: nil, result: Result(major: authResult.result?.major, minor: authResult.result?.minor, language: authResult.result?.language, description: authResult.result?.description, message: authResult.result?.message, reason: authResult.result?.reason), url: authResult.url?.absoluteString))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onCertificate(certificateDescription: AusweisApp2SDKWrapper.CertificateDescription) {
        
        struct CertificateResult: Codable {
            let msg: String
            let description: Description
            let validity: Validity
        }
        
        struct Description: Codable {
            let issuerName, issuerUrl, subjectName, subjectUrl, termsOfUsage, purpose: String
        }
        
        struct Validity: Codable {
            let effectiveDate, expirationDate: String
        }
        
        let message = try! JSONEncoder().encode(CertificateResult(msg: "CERTIFICATE", description: Description(issuerName: certificateDescription.issuerName, issuerUrl: certificateDescription.issuerUrl!.absoluteString, subjectName: certificateDescription.subjectName, subjectUrl: certificateDescription.subjectUrl!.absoluteString, termsOfUsage: certificateDescription.termsOfUsage, purpose: certificateDescription.purpose), validity: Validity(effectiveDate: certificateDescription.validity.effectiveDate.description, expirationDate: certificateDescription.validity.expirationDate.description)))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onEnterCan(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        
        struct ReaderCardCodable: Codable {
            let name: String
            let attached: Bool
            let card: Card
            let insertable: Bool?
            let keypad: Bool?
            
        }
        
        struct Card: Codable {
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let cardRetryCounter: Int?
        }
        
        struct EnterCanResult: Codable {
            let msg: String
            let error: String?
            let reader: ReaderCardCodable?
        }
        
        let message = try! JSONEncoder().encode(EnterCanResult(msg: "ENTER_CAN", error: error, reader: ReaderCardCodable(name: reader.name, attached: reader.attached, card: Card(cardDeactivated: reader.card?.deactivated, cardInoperative: reader.card?.inoperative, cardRetryCounter: reader.card?.pinRetryCounter), insertable: reader.insertable, keypad: reader.keypad)))
        
        let jsonString = String(data: message, encoding: .utf8)
        AA2SDKWrapper.workflowController.interrupt()
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onEnterPin(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        
        struct ReaderCardCodable: Codable {
            let name: String
            let attached: Bool
            let card: Card
            let insertable: Bool?
            let keypad: Bool?
            
        }
        
        struct Card: Codable {
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let cardRetryCounter: Int?
        }
        
        struct EnterPinResult: Codable {
            let msg: String
            let reader: ReaderCardCodable?
        }
        
        let message = try! JSONEncoder().encode(EnterPinResult(msg: "ENTER_PIN", reader: ReaderCardCodable(name: reader.name, attached: reader.attached, card: Card(cardDeactivated: reader.card?.deactivated, cardInoperative: reader.card?.inoperative, cardRetryCounter: reader.card?.pinRetryCounter), insertable: reader.insertable, keypad: reader.keypad)))
        
        let jsonString = String(data: message, encoding: .utf8)
        AA2SDKWrapper.workflowController.interrupt()
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onEnterPuk(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        
        struct ReaderCardCodable: Codable {
            let name: String
            let attached: Bool
            let card: Card
            let insertable: Bool?
            let keypad: Bool?
            
        }
        
        struct Card: Codable {
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let cardRetryCounter: Int?
        }
        
        struct EnterPukResult: Codable {
            let msg: String
            let error: String?
            let reader: ReaderCardCodable?
        }
        
        let message = try! JSONEncoder().encode(EnterPukResult(msg: "ENTER_CAN", error: error, reader: ReaderCardCodable(name: reader.name, attached: reader.attached, card: Card(cardDeactivated: reader.card?.deactivated, cardInoperative: reader.card?.inoperative, cardRetryCounter: reader.card?.pinRetryCounter), insertable: reader.insertable, keypad: reader.keypad)))
        
        let jsonString = String(data: message, encoding: .utf8)
        AA2SDKWrapper.workflowController.interrupt()
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onInsertCard(error: String?) {
        
        struct InsertCardResult: Encodable {
            let msg: String
            let error: String?
        }
        let message = try! JSONEncoder().encode(InsertCardResult(msg: "INSERT_CARD", error: error))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onPause(cause: AusweisApp2SDKWrapper.Cause) {
        
        struct PauseResult: Encodable {
            let msg: String
            let cause: String?
        }
        
        let message = try! JSONEncoder().encode(PauseResult(msg: "INSERT_CARD", cause: cause.rawValue))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onReader(reader: AusweisApp2SDKWrapper.Reader?) {
        
        struct ReaderCardCodable: Codable {
            let msg: String
            let name: String
            let attached: Bool
            let card: Card
            let insertable: Bool?
            let keypad: Bool?
            
        }
        
        struct Card: Codable {
            let cardDeactivated: Bool?
            let cardInoperative: Bool?
            let cardRetryCounter: Int?
        }
        
        let message = try! JSONEncoder().encode(ReaderCardCodable(msg: "READER", name: reader?.name ?? "custom", attached: reader?.attached ?? false, card: Card(cardDeactivated: reader?.card?.deactivated, cardInoperative: reader?.card?.inoperative, cardRetryCounter: reader?.card?.pinRetryCounter), insertable: reader?.insertable, keypad: reader?.keypad))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onStatus(workflowProgress: AusweisApp2SDKWrapper.WorkflowProgress) {
        
        struct StatusResult: Encodable {
            let msg: String
            let workflow, state: String?
            let progress: Int?
        }
        
        let message = try! JSONEncoder().encode(StatusResult(msg: "STATUS", workflow: workflowProgress.workflow?.rawValue, state: workflowProgress.state, progress: workflowProgress.progress))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onWrapperError(error: AusweisApp2SDKWrapper.WrapperError) {
        // @dev ?
    }
    
    func onReaderList(readers: [AusweisApp2SDKWrapper.Reader]?) {
        // @dev ?
    }
    
    func onStarted() {
        // @dev ?
    }
    
    func onInternalError(error: String) {
        // @dev ?
    }
    
    func onInfo(versionInfo: AusweisApp2SDKWrapper.VersionInfo) {
        // @dev ?
    }
    
    func onEnterNewPin(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        // @dev ?
    }
    
    func onChangePinCompleted(changePinResult: AusweisApp2SDKWrapper.ChangePinResult) {
        // @dev ?
    }
    
    func onChangePinStarted() {
        // @dev ?
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
}
