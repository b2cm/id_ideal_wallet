package eu.hidy.app

import android.content.Intent
import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class HceService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray? {
        forwardTheResult(commandApdu)
        return null
    }

    override fun onDeactivated(reason: Int) {

    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        // Check if intent has extras
        if (intent.extras != null) {
            // Get message
            val message = intent.extras!!.getByteArray("message")
            sendResponseApdu(message)
        }
        return START_NOT_STICKY
    }


    private fun forwardTheResult(command: ByteArray) {
        startActivity(
            Intent(this, MainActivity::class.java)
                .apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("nfcCommand", command)
                }
        )
    }

}