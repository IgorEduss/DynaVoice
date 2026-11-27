package com.example.mvp_uema

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec

class MainActivity : FlutterActivity() {
    private val bridgeName = "dynavoice/overlay_bridge"
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val appChannel = BasicMessageChannel<Any>(
            flutterEngine.dartExecutor.binaryMessenger,
            bridgeName,
            JSONMessageCodec.INSTANCE,
        )
        connectOverlay(appChannel, 0)
    }

    private fun connectOverlay(appChannel: BasicMessageChannel<Any>, attempt: Int) {
        // flutter_overlay_window creates this engine when the Activity attaches.
        val engine = FlutterEngineCache.getInstance().get("myCachedEngine")
        if (engine == null) {
            if (attempt < 40) {
                handler.postDelayed({ connectOverlay(appChannel, attempt + 1) }, 250)
            } else {
                Log.w("DynaVoiceBridge", "Overlay engine was not available")
            }
            return
        }
        val overlayChannel = BasicMessageChannel<Any>(
            engine.dartExecutor.binaryMessenger,
            bridgeName,
            JSONMessageCodec.INSTANCE,
        )
        appChannel.setMessageHandler { message, reply ->
            overlayChannel.send(message) { response -> reply.reply(response) }
        }
        overlayChannel.setMessageHandler { message, reply ->
            appChannel.send(message) { response -> reply.reply(response) }
        }
    }
}
