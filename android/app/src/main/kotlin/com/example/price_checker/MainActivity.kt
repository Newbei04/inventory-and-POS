package com.example.price_checker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Process

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.price_checker/app"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "killApp") {
                    result.success(null)
                    Process.killProcess(Process.myPid())
                } else {
                    result.notImplemented()
                }
            }
    }
}
