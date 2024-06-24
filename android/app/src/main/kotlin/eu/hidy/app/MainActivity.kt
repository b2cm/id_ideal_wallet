package eu.hidy.app

import android.app.ActivityManager
import android.app.Application
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.nfc.NfcAdapter
import android.nfc.NfcAdapter.ReaderCallback
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.os.RemoteException
import android.view.WindowManager.LayoutParams
import com.governikus.ausweisapp2.IAusweisApp2Sdk
import com.governikus.ausweisapp2.IAusweisApp2SdkCallback
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
    private var contentReceiver: BroadcastReceiver? = null

    private val deepLinkChannel = "app.channel.deeplink"
    private val deepLinkEvents = "app.channel.deeplink/events"
    private var linkReceiver: BroadcastReceiver? = null
    private var initialLink: String? = null

    private val hceChannel = "app.channel.hce"
    private val hceEvents = "app.channel.hce/events"
    private var hceReceiver: BroadcastReceiver? = null
    private var initialHceBytes: ByteArray? = null

    private val AA2_PROCESS = "ausweisapp2_service"
    private val methodChannel = "app.channel.method"
    private val eventChannel = "app.channel.event"
    private var messageReceiver: BroadcastReceiver? = null

    private var boundToService = false

    var mSdk: IAusweisApp2Sdk? = null
    var mSessionId: String? = null

    var myAppContext: Context? = null

    private var mAdapter: NfcAdapter? = null
    private val mFlags =
        NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
    private var mReaderCallback: ReaderCallback? = null

    private val mCallback = object : IAusweisApp2SdkCallback.Stub() {

        override fun sessionIdGenerated(pSessionId: String?, pIsSecureSessoinId: Boolean) {
            mSessionId = pSessionId
        }

        override fun receive(pJson: String?) {
            Handler(Looper.getMainLooper()).post {
                val intent = Intent(Intent.ACTION_VIEW)
                intent.putExtra("data", pJson)
                messageReceiver?.onReceive(myAppContext, intent)
            }


        }

        override fun sdkDisconnected() {
            Handler(Looper.getMainLooper()).post {
                val intent = Intent(Intent.ACTION_VIEW)
                intent.putExtra("data", "{\"msg\":\"DISCONNECT\"}")
                messageReceiver?.onReceive(myAppContext, intent)
            }
        }

    }

    /** Defines callbacks for service binding, passed to bindService().  */
    private val mConnection = object : ServiceConnection {

        override fun onServiceConnected(className: ComponentName, service: IBinder) {

            try {
                mSdk = IAusweisApp2Sdk.Stub.asInterface(service)
                println(mSdk)
                if (!mSdk!!.connectSdk(mCallback)) {
                    println("Already connected")
                } else {
                    println("Connection successful")
                }

                mReaderCallback = ReaderCallback { pTag ->
                    println("Reader callback")
                    if (listOf(*pTag.techList).contains(IsoDep::class.java.name)) {
                        println("correctTech / $mSessionId / $mSdk")
                        mSdk?.updateNfcTag(mSessionId, pTag)
                    }
                }
                enableAdapter()


            } catch (e: ClassCastException) {
                // ...
            } catch (e: RemoteException) {
            }
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            mSdk = null
        }
    }

    fun enableAdapter() {
        mAdapter?.enableReaderMode(this, mReaderCallback, mFlags, null)
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // if in process of ausweisapp sdk, do not initialize things
        if (isAA2Process()) return

        myAppContext = this.applicationContext

        val intent = intent
        val action = intent.action
        val type = intent.type
        val data = intent.data
        val extra = intent.extras

        println("Oncreate initial data: $data")
        if (intent.hasExtra("nfcCommand")) {
            initialHceBytes = extra?.getByteArray("nfcCommand")
            return
        }


        if (data != null && data.scheme == "content") {
            val `is` = contentResolver.openInputStream(intent.data!!)
            val content = `is`?.let { unwrap(it) }
            sharedText = content
        } else {
            initialLink = intent.dataString
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.action
        val type = intent.type
        val data = intent.data

        println("New intent data: $data")
        if (data != null) {
            println("scheme: ${data.scheme}")
        }

        println(intent.extras)
        println(intent.action)

        if (action == "android.nfc.action.TECH_DISCOVERED") {
            val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)

            if (tag != null && mSdk != null) {
                try {
                    mSdk!!.updateNfcTag(mSessionId, tag)
                } catch (e: RemoteException) {
                    // ...
                }
            }
        } else if (intent.hasExtra("nfcCommand")) {
            hceReceiver?.onReceive(this.applicationContext, intent)

        } else if (data != null && data.scheme == "content") {
            contentReceiver?.onReceive(this.applicationContext, intent)
        } else {
            linkReceiver?.onReceive(this.applicationContext, intent)
        }
    }

    private fun isAA2Process(): Boolean {
        if (Build.VERSION.SDK_INT >= 28) {
            return Application.getProcessName().endsWith(AA2_PROCESS)
        }

        val pid = Process.myPid()
        val manager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        for (appProcess in manager.runningAppProcesses) {
            if (appProcess.pid == pid) {
                return appProcess.processName.endsWith(AA2_PROCESS)
            }
        }
        return false
    }

    fun createReceiver(events: EventChannel.EventSink): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(
                context: Context,
                content: Intent
            ) {
                println("linkReceiverContent: ${content.getStringExtra("data")}")
                if (content.hasExtra("data"))
                    events.success(content.getStringExtra("data"))
                else
                    events.error("No Link", "No Link", null)
            }
        }
    }

    public override fun onResume() {
        super.onResume()
        enableAdapter()
    }

    public override fun onPause() {
        super.onPause()
        mAdapter?.disableReaderMode(this)
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

    fun createLinkReceiver(events: EventChannel.EventSink): BroadcastReceiver {
        println("link receiver create")
        return object : BroadcastReceiver() {
            override fun onReceive(
                context: Context,
                content: Intent
            ) { // NOTE: assuming intent.getAction() is Intent.ACTION_VIEW
//                val dataString =
//                    intent.dataString ?: events.error("UNAVAILABLE", "Link unavailable", null)
                println("linkReceiverContent: ${content.data.toString()}")
                if (content.data != null)
                    events.success(content.data.toString())
                else
                    events.error("No Link", "No Link", null)
            }
        }
    }

    fun createHceReceiver(events: EventChannel.EventSink): BroadcastReceiver {
        println("hce receiver create")
        return object : BroadcastReceiver() {
            override fun onReceive(
                context: Context,
                content: Intent
            ) {
                if (content.hasExtra("nfcCommand")) {
                    events.success(content.extras?.getByteArray("nfcCommand"))
                } else
                    events.error("No Nfc command", "No nfc command", null)
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
        // No Screenshots
        window.addFlags(LayoutParams.FLAG_SECURE)

        // Flutter
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // init Method channel for reading pkpass file
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method!!.contentEquals("getSharedText")) {
                    result.success(sharedText)
                    sharedText = null
                }
            }

        // init deep link Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method!!.contentEquals("getInitialLink")) {
                    if (initialLink != null) {
                        println("initialLink: $initialLink")
                        result.success(initialLink)
                        initialLink = null
                    }
                }
            }

        // init hce Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hceChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method!!.contentEquals("sendData")) {
                    val intent: Intent = Intent(this, HceService::class.java)
                    intent.putExtra("message", call.arguments as ByteArray)
                    this.startService(intent)
                }
            }

        //init Method channel ausweis
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                println(call.method!!.toString())
                if (call.method!!.contentEquals("connectSdk")) {
                    try {
                        mAdapter = NfcAdapter.getDefaultAdapter(this)
                        if (!boundToService) {
                            val pkg = applicationContext.packageName
                            val name = "com.governikus.ausweisapp2.START_SERVICE"
                            val serviceIntent = Intent(name)
                            serviceIntent.setPackage(pkg)
                            bindService(serviceIntent, mConnection, BIND_AUTO_CREATE)
                            boundToService = true
                            result.success("Connected")
                        } else {

                            if (!mSdk!!.connectSdk(mCallback)) {
                                println("Already connected")
                                result.error("Already connected", "", "")
                            } else {
                                println("Connection successful")
                                result.success("connected");
                            }
                        }
                    } catch (e: RemoteException) {
                        println("Connection failed:$e")
                        result.error("Connection failed", e.toString(), "")
                    }
                } else if (call.method!!.contentEquals("sendCommand")) {
                    try {
                        if (!mSdk!!.send(mSessionId, call.arguments as String)) {
                            result.error("Connection lost", "", "")
                        }
                    } catch (e: RemoteException) {
                        println("Send failed:$e")
                        result.error("Send failed", e.toString(), "")
                    }
                } else if (call.method!!.contentEquals("disconnectSdk")) {
                    unbindService(mConnection)
                    mAdapter?.disableReaderMode(this)
                    boundToService = false
                }
            }

        // init EventChannel for pkpass
        EventChannel(flutterEngine.dartExecutor, EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    contentReceiver = createChangeReceiver(events)
                }

                override fun onCancel(args: Any?) {
                    contentReceiver = null
                }
            }
        )

        // init EventChannel for deeplinks
        EventChannel(flutterEngine.dartExecutor, deepLinkEvents).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    linkReceiver = createLinkReceiver(events)
                }

                override fun onCancel(args: Any?) {
                    linkReceiver = null
                }
            }
        )

        // init EventChannel for hce stuff
        EventChannel(flutterEngine.dartExecutor, hceEvents).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    hceReceiver = createHceReceiver(events)
                }

                override fun onCancel(args: Any?) {
                    hceReceiver = null
                }
            }
        )

        // init EventChannel ausweis
        EventChannel(flutterEngine.dartExecutor, eventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    messageReceiver = createReceiver(events)
                }

                override fun onCancel(args: Any?) {
                    messageReceiver = null
                }
            }
        )

    }


}
