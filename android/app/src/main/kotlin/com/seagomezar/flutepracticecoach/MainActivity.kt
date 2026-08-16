package com.seagomezar.flutepracticecoach

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    private val captureChannel = "flute/capture_lifecycle"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, captureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "begin" -> {
                        val kind = call.argument<String>("kind") ?: "audio"
                        CaptureForegroundService.start(this, kind)
                        result.success(null)
                    }

                    "end" -> {
                        CaptureForegroundService.stop(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
