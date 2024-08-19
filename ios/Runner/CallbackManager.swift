//
//  CallbackManager.swift
//  Runner
//
//  Created by Jonas Bentke on 13.08.24.
//

import Foundation
import Flutter
import AusweisApp2SDKWrapper

class CallbackManager: WorkflowCallbacks {
    
    func onAccessRights(error: String?, accessRights: AusweisApp2SDKWrapper.AccessRights?) {
        print("############### onAccessRights ######################")
        // ACCESS_RIGHTS
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
        print("############### onAuthenticationCompleted ######################")
        // String? error, major, minor, language, description, message, reason, url;
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
    
    func onAuthenticationStarted() {
        print("############### onAuthenticationStarted ######################")
        // @dev ?
    }
    
    func onAuthenticationStartFailed(error: String) {
        print("############### onAuthenticationFailed ######################")
        // @dev ?
    }
    
    func onBadState(error: String) {
        print("############### onBadState ######################")
        // @dev ?
    }
    
    func onCertificate(certificateDescription: AusweisApp2SDKWrapper.CertificateDescription) {
        print("############### onCertificate ######################")
        // CERTIFICATE
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
    
    func onChangePinCompleted(changePinResult: AusweisApp2SDKWrapper.ChangePinResult) {
        print("############### onChangePinCompleted ######################")
        // @dev ?
    }
    
    func onChangePinStarted() {
        print("############### onChangePinStarted ######################")
        // @dev ?
    }
    
    func onEnterCan(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        print("############### onEnterCan ######################")
        // ENTER_CAN
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
    
    func onEnterNewPin(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        print("############### onEnterNewPin ######################")
        // @dev ?
    }
    
    func onEnterPin(error: String?, reader: AusweisApp2SDKWrapper.Reader) {
        print("############### onEnterPin ######################")
        // ENTER_PIN
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
        print("############### onEnterPuk ######################")
        // ENTER_PUK
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
    
    func onInfo(versionInfo: AusweisApp2SDKWrapper.VersionInfo) {
        print("############### onInfo ######################")
        // @dev ?
    }
    
    func onInsertCard(error: String?) {
        print("############### onInsertCard ######################")
        // type INSERT_CARD, String? error
        struct InsertCardResult: Encodable {
            let msg: String
            let error: String?
        }
        let message = try! JSONEncoder().encode(InsertCardResult(msg: "INSERT_CARD", error: error))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onInternalError(error: String) {
        print("############### onInternalError ######################")
        // @dev ?
    }
    
    func onPause(cause: AusweisApp2SDKWrapper.Cause) {
        print("############### onPause ######################")
        // type PAUSE, String? error
        struct PauseResult: Encodable {
            let msg: String
            let cause: String?
        }
        
        let message = try! JSONEncoder().encode(PauseResult(msg: "INSERT_CARD", cause: cause.rawValue))
        
        let jsonString = String(data: message, encoding: .utf8)
        EventChannelManager.shared.sendEvent(jsonString as Any)
    }
    
    func onReader(reader: AusweisApp2SDKWrapper.Reader?) {
        print("############### onReader ######################")
        // READER
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
    
    func onReaderList(readers: [AusweisApp2SDKWrapper.Reader]?) {
        print("############### onReaderList ######################")
        // @dev ?
    }
    
    func onStarted() {
        print("############### onStarted ######################")
        // @dev ?
    }
    
    func onStatus(workflowProgress: AusweisApp2SDKWrapper.WorkflowProgress) {
        print("############### onStatus ######################")
        // STATUS
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
        print("############### onWrappedError ######################")
        // @dev ?
    }

}
