//
//  EventChannelManager.swift
//  Runner
//
//  Created by Jonas Bentke on 13.08.24.
//

import Foundation
import Flutter

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
