package com.vioclass.app

import android.content.res.Configuration
import android.app.PictureInPictureUiState
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pipBridge: TwitchPipBridge? = null
    private var updateBridge: VioClassUpdateBridge? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        VioClassReceivingEngine.engine

    override fun shouldDestroyEngineWithHost(): Boolean =
        !VioClassWhisperService.running && !VioClassPlaybackService.running

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VioClassReceivingEngine.engine = flutterEngine
        VioClassReceivingEngine.host = this
        if (!flutterEngine.plugins.has(VioClassBackgroundPlugin::class.java)) {
            flutterEngine.plugins.add(VioClassBackgroundPlugin())
        }
        if (!flutterEngine.plugins.has(VioClassPlaybackPlugin::class.java)) {
            flutterEngine.plugins.add(VioClassPlaybackPlugin())
        }
        val bridge = TwitchPipBridge(this)
        bridge.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vio_class/android_pip"))
        pipBridge = bridge
        val updater = VioClassUpdateBridge(this)
        updater.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vio_class/app_update"))
        updateBridge = updater
    }

    override fun onDestroy() {
        pipBridge?.detach()
        pipBridge = null
        updateBridge?.detach()
        updateBridge = null
        if (VioClassReceivingEngine.host === this) {
            VioClassReceivingEngine.host = null
            if (!VioClassWhisperService.running && !VioClassPlaybackService.running) VioClassReceivingEngine.engine = null
        }
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        pipBridge?.notifyActivityStarted()
    }

    override fun onStop() {
        pipBridge?.notifyActivityStopped()
        super.onStop()
    }

    override fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) {
            super.onUserLeaveHint()
            return
        }
        pipBridge?.enterPipFromUserLeaveHint()
        super.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipBridge?.notifyPipModeChanged(isInPictureInPictureMode)
    }

    override fun onPictureInPictureUiStateChanged(pipState: PictureInPictureUiState) {
        super.onPictureInPictureUiStateChanged(pipState)
        if (Build.VERSION.SDK_INT >= 35 && pipState.isTransitioningToPip) {
            pipBridge?.notifyPipTransitionStarted()
        }
    }
}
