package com.example.android_voice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.android_voice/whisper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "transcribe") {
                val filePath = call.argument<String>("filePath")
                if (filePath.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "File path is null or empty", null)
                    return@setMethodCallHandler
                }
                // TODO: 接入 whisper 转写逻辑
                val transcriptionResult = "模拟转写结果，音频路径: $filePath"
                result.success(transcriptionResult)
            } else {
                result.notImplemented()
            }
        }
    }
}
