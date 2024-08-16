import CoreNFC

class NFCReader: NSObject, NFCTagReaderSessionDelegate {
    var nfcSession: NFCTagReaderSession?

    func beginScanning() {
        guard NFCTagReaderSession.readingAvailable else {
            print("NFC is not available on this device")
            return
        }
        nfcSession = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        nfcSession?.alertMessage = "Hold your iPhone near the NFC tag."
        nfcSession?.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("NFC session became active")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("Session invalidated: \(error.localizedDescription)")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "No tags found")
            return
        }

        session.connect(to: firstTag) { (error: Error?) in
            if let error = error {
                print("Failed to connect to tag: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Connection failed")
                return
            }

            switch firstTag {
            case .iso7816(let iso7816Tag):
                print("ISO7816 tag detected: \(iso7816Tag.identifier)")
                // Insert APDU communication here
            default:
                session.invalidate(errorMessage: "Unsupported tag type")
            }
        }
    }
}
