package com.sgsongx.modeltranslation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var bridge: ModelTranslationBridge? = null
	private var pendingActionId: String? = null
	private var pendingPayload: Map<String, Any?> = emptyMap()

	override fun onCreate(savedInstanceState: android.os.Bundle?) {
		if (isFloatingBubbleLaunch(intent)) {
			setTheme(R.style.BubbleBridgeTheme)
		}
		super.onCreate(savedInstanceState)
		if (isFloatingBubbleLaunch(intent)) {
			overridePendingTransition(0, 0)
		}
		consumeIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		if (isFloatingBubbleLaunch(intent)) {
			overridePendingTransition(0, 0)
		}
		consumeIntent(intent)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		bridge = ModelTranslationBridge(
			applicationContext = applicationContext,
			messenger = flutterEngine.dartExecutor.binaryMessenger,
			moveTaskToBack = { moveTaskToBack(true) },
		)
		consumePendingAction()
	}

	private fun consumeIntent(intent: Intent?) {
		val actionId = intent?.getStringExtra(FloatingBubbleService.EXTRA_ACTION_ID)
		if (actionId != null) {
			val clipboardText = readClipboardText()
			trace("bridge.clipboard.prefetch actionId=$actionId length=${clipboardText?.length ?: 0}")
			pendingActionId = actionId
			pendingPayload = mapOf(
				"source" to "floating_bubble",
				"clipboardText" to clipboardText,
			)

			val fromFloatingBubble = intent.getBooleanExtra(FloatingBubbleService.EXTRA_FROM_FLOATING_BUBBLE, false)
			if (fromFloatingBubble) {
				android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
					moveTaskToBack(true)
					overridePendingTransition(0, 0)
					trace("moved to background after floating bubble launch")
				}, 100)
			}

			consumePendingAction()
		}
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

	private fun consumePendingAction() {
		val currentActionId = pendingActionId ?: return
		trace("bridge.pendingAction:emit actionId=$currentActionId")
		bridge?.emitAction(currentActionId, pendingPayload)
		pendingActionId = null
		pendingPayload = emptyMap()
	}

	private fun trace(message: String) {
		bridge?.trace(message)
	}

	private fun isFloatingBubbleLaunch(intent: Intent?): Boolean {
		if (intent == null) {
			return false
		}

		return intent.getBooleanExtra(FloatingBubbleService.EXTRA_FROM_FLOATING_BUBBLE, false)
	}
}

private class ModelTranslationBridge(
	private val applicationContext: Context,
	messenger: io.flutter.plugin.common.BinaryMessenger,
	private val moveTaskToBack: () -> Boolean,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
	private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
	private val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
	private var eventSink: EventChannel.EventSink? = null
	private val pendingEvents: MutableList<Map<String, Any?>> = mutableListOf()
	private var diagnosticsEnabled = false

	init {
		methodChannel.setMethodCallHandler(this)
		eventChannel.setStreamHandler(this)
	}

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"setDiagnosticsEnabled" -> {
				diagnosticsEnabled = call.arguments as? Boolean ?: false
				trace("diagnostics.enabled=$diagnosticsEnabled")
				result.success(true)
			}
			"getClipboardText" -> result.success(readClipboardText())
			"hasOverlayPermission" -> result.success(hasOverlayPermission())
			"openOverlayPermissionSettings" -> result.success(openOverlayPermissionSettings())
			"startFloatingBubble" -> result.success(startFloatingBubble())
			"stopFloatingBubble" -> result.success(stopFloatingBubble())
			"moveTaskToBack" -> result.success(moveTaskToBack())
			"showOverlay" -> result.success(showOverlay(call))
			"hideOverlay" -> result.success(hideOverlay())
			"getBridgeCapabilities" -> {
				result.success(
					mapOf(
						"methodChannel" to METHOD_CHANNEL_NAME,
						"eventChannel" to EVENT_CHANNEL_NAME,
						"supportsClipboard" to true,
						"supportsOverlay" to true,
						"supportsFloatingBubble" to true,
					)
				)
			}
			else -> result.notImplemented()
		}
	}

	override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
		eventSink = events
		flushPendingEvents()
	}

	override fun onCancel(arguments: Any?) {
		eventSink = null
	}

	private fun hasOverlayPermission(): Boolean {
		trace("bridge.overlay.permission:check")
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			Settings.canDrawOverlays(applicationContext)
		} else {
			true
		}
	}

	private fun openOverlayPermissionSettings(): Boolean {
		trace("bridge.overlay.permission:openSettings")
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return true
		}

		val intent = Intent(
			Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
			Uri.parse("package:${applicationContext.packageName}"),
		).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		applicationContext.startActivity(intent)
		return true
	}

	private fun showOverlay(call: MethodCall): Boolean {
		val title = call.argument<String>("title") ?: "Translation Result"
		val message = call.argument<String>("message") ?: ""
		val showRetry = title == "Translation Error"
		trace("bridge.overlay.show title=$title messageLength=${message.length} showRetry=$showRetry")
		FloatingBubbleService.ensureChannel(applicationContext)
		FloatingBubbleService.start(applicationContext, diagnosticsEnabled)
		FloatingBubbleService.showResult(applicationContext, title, message, showRetry, diagnosticsEnabled)
		return true
	}

	private fun hideOverlay(): Boolean {
		trace("bridge.overlay.hide")
		FloatingBubbleService.hideResult(applicationContext, diagnosticsEnabled)
		return true
	}

	private fun readClipboardText(): String? {
		trace("bridge.clipboard.read")
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
		trace("bridge.event.emit actionId=$actionId payloadSize=${payload.size}")
		val event = mapOf(
			"kind" to "action",
			"actionId" to actionId,
			"payload" to payload,
			"createdAt" to System.currentTimeMillis().toString(),
		)

		val sink = eventSink
		if (sink != null) {
			sink.success(event)
			return
		}

		pendingEvents.add(event)
		trace("bridge.event.queue size=${pendingEvents.size}")
	}

	private fun flushPendingEvents() {
		val sink = eventSink ?: return
		if (pendingEvents.isEmpty()) {
			return
		}

		trace("bridge.event.flush count=${pendingEvents.size}")
		pendingEvents.forEach { sink.success(it) }
		pendingEvents.clear()
	}

	companion object {
		private const val METHOD_CHANNEL_NAME = "modeltranslation/platform"
		private const val EVENT_CHANNEL_NAME = "modeltranslation/action_events"
	}

	private fun startFloatingBubble(): Boolean {
		trace("bridge.bubble.start")
		FloatingBubbleService.ensureChannel(applicationContext)
		FloatingBubbleService.start(applicationContext, diagnosticsEnabled)
		return true
	}

	private fun stopFloatingBubble(): Boolean {
		trace("bridge.bubble.stop")
		FloatingBubbleService.stop(applicationContext, diagnosticsEnabled)
		return true
	}

	fun trace(message: String) {
		if (diagnosticsEnabled) {
			Log.d("ModelTranslationBridge", message)
		}
	}
}
