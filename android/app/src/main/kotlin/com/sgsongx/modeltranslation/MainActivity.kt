package com.sgsongx.modeltranslation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		ModelTranslationBridge(
			applicationContext = applicationContext,
			messenger = flutterEngine.dartExecutor.binaryMessenger,
		)
	}
}

private class ModelTranslationBridge(
	private val applicationContext: Context,
	messenger: io.flutter.plugin.common.BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
	private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
	private val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
	private var eventSink: EventChannel.EventSink? = null

	init {
		methodChannel.setMethodCallHandler(this)
		eventChannel.setStreamHandler(this)
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"getClipboardText" -> result.success(readClipboardText())
			"showOverlay" -> result.success(true)
			"hideOverlay" -> result.success(true)
			"getBridgeCapabilities" -> {
				result.success(
					mapOf(
						"methodChannel" to METHOD_CHANNEL_NAME,
						"eventChannel" to EVENT_CHANNEL_NAME,
						"supportsClipboard" to true,
						"supportsOverlay" to true,
					)
				)
			}
			else -> result.notImplemented()
		}
	}

	override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
		eventSink = events
	}

	override fun onCancel(arguments: Any?) {
		eventSink = null
	}

	private fun readClipboardText(): String? {
		val clipboardManager = applicationContext.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
			?: return null
		val primaryClip: ClipData = clipboardManager.primaryClip ?: return null
		if (primaryClip.itemCount == 0) {
			return null
		}

		val text = primaryClip.getItemAt(0).coerceToText(applicationContext)?.toString()?.trim()
		return text?.takeIf { it.isNotEmpty() }
	}

	fun emitAction(actionId: String, payload: Map<String, Any?>) {
		eventSink?.success(
			mapOf(
				"kind" to "action",
				"actionId" to actionId,
				"payload" to payload,
				"createdAt" to System.currentTimeMillis().toString(),
			)
		)
	}

	companion object {
		private const val METHOD_CHANNEL_NAME = "modeltranslation/platform"
		private const val EVENT_CHANNEL_NAME = "modeltranslation/action_events"
	}
}
