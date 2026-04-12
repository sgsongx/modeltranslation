package com.sgsongx.modeltranslation

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.util.Log
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class FloatingBubbleService : Service() {
	private lateinit var windowManager: WindowManager
	private var bubbleView: View? = null
	private var resultOverlayView: View? = null
	private var diagnosticsEnabled: Boolean = false
	private var backgroundEngine: FlutterEngine? = null
	private var backgroundChannel: MethodChannel? = null

	override fun onCreate() {
		super.onCreate()
		windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
		ensureChannel(this)
		ensureBackgroundEngine()
		trace("service.create")
		createOverlayBubble()
		startForeground(NOTIFICATION_ID, buildNotification())
	}

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		diagnosticsEnabled = intent?.getBooleanExtra(EXTRA_DIAGNOSTICS_ENABLED, diagnosticsEnabled) ?: diagnosticsEnabled
		when (intent?.action) {
			ACTION_STOP -> {
				trace("service.stop")
				stopSelf()
			}
			ACTION_SHOW_RESULT -> {
				trace("service.showResult")
				if (bubbleView == null) {
					createOverlayBubble()
				}
				showResultOverlay(
					title = intent.getStringExtra(EXTRA_RESULT_TITLE) ?: "Translation Result",
					message = intent.getStringExtra(EXTRA_RESULT_MESSAGE) ?: "",
					showRetry = intent.getBooleanExtra(EXTRA_SHOW_RETRY, false),
				)
			}
			ACTION_HIDE_RESULT -> {
				trace("service.hideResult")
				hideResultOverlay()
			}
			else -> {
				trace("service.keepAlive")
				if (bubbleView == null) {
					createOverlayBubble()
				}
			}
		}
		return START_STICKY
	}

	override fun onDestroy() {
		hideResultOverlay()
		releaseBubble()
		backgroundChannel = null
		backgroundEngine?.destroy()
		backgroundEngine = null
		super.onDestroy()
	}

	override fun onBind(intent: Intent?): IBinder? = null

	private fun createOverlayBubble() {
		if (bubbleView != null) {
			return
		}
		trace("service.bubble.create")

		val bubble = FrameLayout(this).apply {
			setBackgroundResource(android.R.drawable.btn_default_small)
			setPadding(32, 32, 32, 32)
			addView(
				TextView(context).apply {
					text = "T"
					textSize = 18f
					gravity = Gravity.CENTER
				}
			)
			setOnClickListener {
				launchTranslationAction()
			}
		}

		val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
		} else {
			WindowManager.LayoutParams.TYPE_PHONE
		}

		val layoutParams = WindowManager.LayoutParams(
			WindowManager.LayoutParams.WRAP_CONTENT,
			WindowManager.LayoutParams.WRAP_CONTENT,
			layoutType,
			WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
			PixelFormat.TRANSLUCENT,
		).apply {
			gravity = Gravity.TOP or Gravity.END
			x = 32
			y = 240
		}

		windowManager.addView(bubble, layoutParams)
		bubbleView = bubble
	}

	private fun releaseBubble() {
		trace("service.bubble.release")
		bubbleView?.let { windowManager.removeView(it) }
		bubbleView = null
	}

	private fun showResultOverlay(title: String, message: String, showRetry: Boolean) {
		trace("service.overlay.show title=$title messageLength=${message.length} showRetry=$showRetry")
		hideResultOverlay()

		val container = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			setBackgroundResource(android.R.drawable.dialog_holo_light_frame)
			setPadding(40, 32, 40, 24)
			addView(
				TextView(context).apply {
					text = title
					textSize = 18f
				}
			)
			addView(
				TextView(context).apply {
					text = message.ifEmpty { "(empty)" }
					textSize = 15f
					setPadding(0, 16, 0, 16)
				}
			)

			val actionRow = LinearLayout(context).apply {
				orientation = LinearLayout.HORIZONTAL
				gravity = Gravity.END
				if (showRetry) {
					addView(
						Button(context).apply {
							text = "Retry"
							setOnClickListener {
								hideResultOverlay()
								launchTranslationAction()
							}
						}
					)
				}
				addView(
					Button(context).apply {
						text = "Copy"
						setOnClickListener {
							copyToClipboard(message)
						}
					}
				)
				addView(
					Button(context).apply {
						text = "Close"
						setOnClickListener {
							hideResultOverlay()
						}
					}
				)
			}
			addView(actionRow)
		}

		val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
		} else {
			WindowManager.LayoutParams.TYPE_PHONE
		}

		val params = WindowManager.LayoutParams(
			WindowManager.LayoutParams.WRAP_CONTENT,
			WindowManager.LayoutParams.WRAP_CONTENT,
			layoutType,
			WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
			PixelFormat.TRANSLUCENT,
		).apply {
			gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
			y = 380
		}

		windowManager.addView(container, params)
		resultOverlayView = container
	}

	private fun hideResultOverlay() {
		trace("service.overlay.hide")
		resultOverlayView?.let { windowManager.removeView(it) }
		resultOverlayView = null
	}

	private fun copyToClipboard(message: String) {
		trace("service.overlay.copy messageLength=${message.length}")
		val clipboardManager = getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager ?: return
		clipboardManager.setPrimaryClip(ClipData.newPlainText("translation_result", message))
	}

	private fun launchTranslationAction() {
		trace("service.overlay.launchTranslationAction")

		val clipboardText = readClipboardText()
		if (clipboardText.isNullOrBlank()) {
			showResultOverlay(
				title = "Translation Error",
				message = "Clipboard is empty",
				showRetry = true,
			)
			return
		}

		ensureBackgroundEngine()
		val channel = backgroundChannel
		if (channel == null) {
			showResultOverlay(
				title = "Translation Error",
				message = "Background translation channel unavailable",
				showRetry = true,
			)
			return
		}

		trace("service.translation.invoke length=${clipboardText.length}")
		channel.invokeMethod(
			"translateClipboard",
			mapOf("clipboardText" to clipboardText),
			object : MethodChannel.Result {
				override fun success(result: Any?) {
					handleBackgroundResult(result)
				}

				override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
					Handler(Looper.getMainLooper()).post {
						showResultOverlay(
							title = "Translation Error",
							message = errorMessage ?: "Background translation failed ($errorCode)",
							showRetry = true,
						)
					}
				}

				override fun notImplemented() {
					Handler(Looper.getMainLooper()).post {
						showResultOverlay(
							title = "Translation Error",
							message = "Background translation method is not implemented",
							showRetry = true,
						)
					}
				}
			},
		)
	}

	private fun ensureBackgroundEngine() {
		if (backgroundEngine != null && backgroundChannel != null) {
			return
		}

		val flutterLoader = FlutterInjector.instance().flutterLoader()
		if (!flutterLoader.initialized()) {
			flutterLoader.startInitialization(applicationContext)
			flutterLoader.ensureInitializationComplete(applicationContext, null)
		}

		val engine = FlutterEngine(applicationContext)
		GeneratedPluginRegistrant.registerWith(engine)
		val entrypoint = DartExecutor.DartEntrypoint(
			flutterLoader.findAppBundlePath(),
			BACKGROUND_DART_ENTRYPOINT,
		)
		engine.dartExecutor.executeDartEntrypoint(entrypoint)

		backgroundEngine = engine
		backgroundChannel = MethodChannel(engine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL_NAME)
		trace("service.backgroundEngine.ready")
	}

	private fun handleBackgroundResult(result: Any?) {
		@Suppress("UNCHECKED_CAST")
		val payload = result as? Map<String, Any?>
		val ok = payload?.get("ok") as? Boolean ?: false
		if (!ok) {
			val error = payload?.get("error") as? String ?: "Translation failed"
			Handler(Looper.getMainLooper()).post {
				showResultOverlay(
					title = "Translation Error",
					message = error,
					showRetry = true,
				)
			}
			return
		}

		val translatedText = (payload["translatedText"] as? String).orEmpty().ifEmpty { "(empty)" }
		Handler(Looper.getMainLooper()).post {
			showResultOverlay(
				title = "Translation Result",
				message = translatedText,
				showRetry = false,
			)
		}
	}

	private fun readClipboardText(): String? {
		val clipboardManager = getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager ?: return null
		val primaryClip: ClipData = clipboardManager.primaryClip ?: return null
		if (primaryClip.itemCount == 0) {
			return null
		}

		val text = primaryClip.getItemAt(0).coerceToText(applicationContext)?.toString()?.trim()
		return text?.takeIf { it.isNotEmpty() }
	}

	private fun buildNotification(): Notification {
		trace("service.notification.build")
		val contentIntent = PendingIntent.getActivity(
			this,
			0,
			Intent(this, MainActivity::class.java),
			pendingIntentFlags(),
		)
		return NotificationCompat.Builder(this, CHANNEL_ID)
			.setContentTitle("Model Translation")
			.setContentText("Floating translation bubble is running")
			.setSmallIcon(android.R.drawable.ic_dialog_info)
			.setContentIntent(contentIntent)
			.setOngoing(true)
			.build()
	}

	private fun pendingIntentFlags(): Int {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
		} else {
			PendingIntent.FLAG_UPDATE_CURRENT
		}
	}

	companion object {
		private const val BACKGROUND_CHANNEL_NAME = "modeltranslation/background_translate"
		private const val BACKGROUND_DART_ENTRYPOINT = "backgroundMain"
		const val ACTION_START = "modeltranslation.action.START_FLOATING_BUBBLE"
		const val ACTION_STOP = "modeltranslation.action.STOP_FLOATING_BUBBLE"
		const val ACTION_SHOW_RESULT = "modeltranslation.action.SHOW_RESULT_OVERLAY"
		const val ACTION_HIDE_RESULT = "modeltranslation.action.HIDE_RESULT_OVERLAY"
		const val ACTION_TRANSLATE_CLIPBOARD = "translate_clipboard"
		const val EXTRA_ACTION_ID = "extra_action_id"
		const val EXTRA_RESULT_TITLE = "extra_result_title"
		const val EXTRA_RESULT_MESSAGE = "extra_result_message"
		const val EXTRA_SHOW_RETRY = "extra_show_retry"
		const val EXTRA_DIAGNOSTICS_ENABLED = "extra_diagnostics_enabled"
		const val EXTRA_FROM_FLOATING_BUBBLE = "extra_from_floating_bubble"
		private const val CHANNEL_ID = "modeltranslation.floating_bubble"
		private const val NOTIFICATION_ID = 1001

		fun start(context: Context, diagnosticsEnabled: Boolean = false) {
			val intent = Intent(context, FloatingBubbleService::class.java).apply {
				action = ACTION_START
				putExtra(EXTRA_DIAGNOSTICS_ENABLED, diagnosticsEnabled)
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				context.startForegroundService(intent)
			} else {
				context.startService(intent)
			}
		}

		fun stop(context: Context, diagnosticsEnabled: Boolean = false) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_STOP
					putExtra(EXTRA_DIAGNOSTICS_ENABLED, diagnosticsEnabled)
				}
			)
		}

		fun showResult(
			context: Context,
			title: String,
			message: String,
			showRetry: Boolean = false,
			diagnosticsEnabled: Boolean = false,
		) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_SHOW_RESULT
					putExtra(EXTRA_RESULT_TITLE, title)
					putExtra(EXTRA_RESULT_MESSAGE, message)
					putExtra(EXTRA_SHOW_RETRY, showRetry)
					putExtra(EXTRA_DIAGNOSTICS_ENABLED, diagnosticsEnabled)
				}
			)
		}

		fun hideResult(context: Context, diagnosticsEnabled: Boolean = false) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_HIDE_RESULT
					putExtra(EXTRA_DIAGNOSTICS_ENABLED, diagnosticsEnabled)
				}
			)
		}

		fun ensureChannel(context: Context) {
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
				return
			}

			val manager = context.getSystemService(NotificationManager::class.java)
			if (manager.getNotificationChannel(CHANNEL_ID) != null) {
				return
			}

			manager.createNotificationChannel(
				NotificationChannel(
					CHANNEL_ID,
					"Floating bubble",
					NotificationManager.IMPORTANCE_LOW,
				)
			)
		}

	}

	private fun trace(message: String) {
		if (diagnosticsEnabled) {
			Log.d("FloatingBubbleService", message)
		}
	}
}