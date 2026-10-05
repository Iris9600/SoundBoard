package com.example.soundboard

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soundboard/device_name")
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceName") {
                    result.success(Settings.Global.getString(contentResolver, "device_name"))
                } else {
                    result.notImplemented()
                }
            }
    }
}
