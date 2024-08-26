//
//  EventChannelManager.swift
//  Runner
//
//  Created by Jonas Bentke on 13.08.24.
//

import Foundation
import Flutter

/**
 This Channel Manager is used for communication between flutter and Ausweis Sdk Wrapper
 */
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

/**
 This EventChannelManager is used for deep links. We defined the supported deep links in the info.plist
 */
class EventChannelManagerDeepLink: NSObject, FlutterStreamHandler {
    static let shared = EventChannelManagerDeepLink()
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
