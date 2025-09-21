package com.tomalito.angel_or_devil

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
	private val CHANNEL = "angel_or_devil/debug"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "logDebug") {
				val payload = call.argument<String>("payload")
				val actionId = call.argument<String>("actionId")
				val input = call.argument<String>("input")
				Log.d("AngelOrDevilDebug", "Notification debug: payload=$payload, actionId=$actionId, input=$input")
				result.success(null)
			} else {
				result.notImplemented()
			}
		}
	}
}
