package com.example.new_twitch_app

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pipBridge: TwitchPipBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = TwitchPipBridge(this)
        bridge.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vio_class/android_pip"))
        pipBridge = bridge
    }

    override fun onDestroy() {
        pipBridge?.detach()
        pipBridge = null
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        super.onCreate(savedInstanceState)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) return
        pipBridge?.enterPipFromUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipBridge?.notifyPipModeChanged(isInPictureInPictureMode)
    }
}
