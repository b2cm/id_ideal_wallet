package eu.hidy.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager.LayoutParams
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream


class MainActivity : FlutterFragmentActivity() {

    // source: https://medium.com/flutter-community/deep-links-and-flutter-applications-how-to-handle-them-properly-8c9865af9283
    // source: https://docs.flutter.dev/get-started/flutter-for/android-devs#what-is-the-equivalent-of-an-intent-in-flutter
    private var sharedText: ByteArray? = null
    private val CHANNEL = "app.channel.shared.data"
    private val EVENTS = "app.channel.shared.data/events"
    private var linksReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = intent
        val action = intent.action
        val type = intent.type
        val data = intent.data

        println(data)

        if (data != null && data.scheme == "content") {
            val `is` = contentResolver.openInputStream(intent.data!!)
            val content = `is`?.let { unwrap(it) }
            sharedText = content
        }

    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.action
        val type = intent.type
        val data = intent.data

        println(data)

        if (data != null && data.scheme == "content") {
            linksReceiver?.onReceive(this.applicationContext, intent)

        }
    }

    fun createChangeReceiver(events: EventChannel.EventSink): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(
                context: Context,
                content: Intent
            ) { // NOTE: assuming intent.getAction() is Intent.ACTION_VIEW

                val `is` = contentResolver.openInputStream(content.data!!)
                val file = `is`?.let { unwrap(it) }
                events.success(file)


            }
        }
    }


    @Throws(IOException::class)
    fun unwrap(`is`: InputStream): ByteArray? {
        val baos = ByteArrayOutputStream()
        var nRead: Int
        val data = ByteArray(4096)
        while (`is`.read(data, 0, data.size).also { nRead = it } != -1) {
            baos.write(data, 0, nRead)
        }
        baos.flush()
        `is`.close()
        baos.close()
        return baos.toByteArray()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        window.addFlags(LayoutParams.FLAG_SECURE)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method!!.contentEquals("getSharedText")) {
                    result.success(sharedText)
                    sharedText = null
                }
            }

        EventChannel(flutterEngine.dartExecutor, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    linksReceiver = createChangeReceiver(events)
                }

                override fun onCancel(args: Any?) {
                    linksReceiver = null
                }
            }
        )

    }


}
