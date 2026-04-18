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
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.util.Log
import android.util.TypedValue
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class FloatingBubbleService : Service() {
	private lateinit var windowManager: WindowManager
	private var bubbleView: View? = null
	private var resultOverlayView: View? = null
	private var diagnosticsEnabled: Boolean = false

	override fun onCreate() {
		super.onCreate()
		windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
		ensureChannel(this)
		trace("service.create")
		if (!hasOverlayPermission()) {
			trace("service.create:skipBubble missingOverlayPermission")
			showToast("Overlay permission is required for floating bubble")
		} else {
			createOverlayBubble()
		}
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
				val overlayFontSizeSp = intent
					.getDoubleExtra(EXTRA_OVERLAY_FONT_SIZE_SP, DEFAULT_OVERLAY_FONT_SIZE_SP)
					.toFloat()
					.coerceIn(12f, 28f)
				if (!hasOverlayPermission()) {
					trace("service.showResult:blocked missingOverlayPermission")
					showToast("Overlay permission is required for floating windows")
					return START_STICKY
				}
				if (bubbleView == null) {
					createOverlayBubble()
				}
				showResultOverlay(
					title = intent.getStringExtra(EXTRA_RESULT_TITLE) ?: "Translation Result",
					message = intent.getStringExtra(EXTRA_RESULT_MESSAGE) ?: "",
					showRetry = intent.getBooleanExtra(EXTRA_SHOW_RETRY, false),
					overlayFontSizeSp = overlayFontSizeSp,
				)
			}
			ACTION_HIDE_RESULT -> {
				trace("service.hideResult")
				hideResultOverlay()
			}
			else -> {
				trace("service.keepAlive")
				if (!hasOverlayPermission()) {
					trace("service.keepAlive:skipBubble missingOverlayPermission")
				} else if (bubbleView == null) {
					createOverlayBubble()
				}
			}
		}
		return START_STICKY
	}

	override fun onDestroy() {
		hideResultOverlay()
		releaseBubble()
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
				launchAction(ACTION_TRANSLATE_CLIPBOARD)
			}
			setOnLongClickListener {
				launchAction(ACTION_OPEN_RECENT_HISTORY)
				true
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

		try {
			windowManager.addView(bubble, layoutParams)
			bubbleView = bubble
		} catch (securityError: SecurityException) {
			trace("service.bubble.create:securityException ${securityError.message}")
			showToast("System blocked floating window. Please enable overlay permission.")
		}
	}

	private fun releaseBubble() {
		trace("service.bubble.release")
		bubbleView?.let { windowManager.removeView(it) }
		bubbleView = null
	}

	private fun showResultOverlay(
		title: String,
		message: String,
		showRetry: Boolean,
		overlayFontSizeSp: Float,
	) {
		trace("service.overlay.show title=$title messageLength=${message.length} showRetry=$showRetry")
		hideResultOverlay()
		val recentHistory = if (title == "Recent History") parseRecentHistoryPayload(message, overlayFontSizeSp) else null
		val translationResult = if (title == "Translation Result") {
			parseTranslationResultPayload(message, overlayFontSizeSp)
		} else {
			null
		}

		val screenWidth = resources.displayMetrics.widthPixels
		val screenHeight = resources.displayMetrics.heightPixels
		val overlayWidth = (screenWidth * 0.92f).toInt()
		val overlayHeight = (screenHeight * 0.72f).toInt()

		val container = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			setBackgroundResource(android.R.drawable.dialog_holo_light_frame)
			setPadding(40, 32, 40, 24)
			addView(
				TextView(context).apply {
					text = title
					setTextSize(TypedValue.COMPLEX_UNIT_SP, overlayFontSizeSp + 2f)
				}
			)

			val bodyView = when {
				recentHistory != null -> buildRecentHistoryContent(recentHistory)
				translationResult != null -> buildTranslationResultContent(translationResult)
				else -> buildPlainTextOverlayBody(message, overlayFontSizeSp)
			}

			addView(
				ScrollView(context).apply {
					setPadding(0, 16, 0, 16)
					addView(bodyView)
					layoutParams = LinearLayout.LayoutParams(
						LinearLayout.LayoutParams.MATCH_PARENT,
						0,
						1f,
					)
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
								launchAction(ACTION_TRANSLATE_CLIPBOARD)
							}
						}
					)
				}
				addView(
					Button(context).apply {
						text = "Copy"
						setOnClickListener {
							val copyText = translationResult?.translatedText ?: message
							copyToClipboard(copyText)
							showToast("Copied")
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
			overlayWidth,
			overlayHeight,
			layoutType,
			WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
			PixelFormat.TRANSLUCENT,
		).apply {
			gravity = Gravity.CENTER
		}

		try {
			windowManager.addView(container, params)
			resultOverlayView = container
		} catch (securityError: SecurityException) {
			trace("service.overlay.show:securityException ${securityError.message}")
			showToast("System blocked floating window. Please enable overlay permission.")
		}
	}

	private fun buildPlainTextOverlayBody(message: String, fontSizeSp: Float): View {
		return TextView(this).apply {
			text = message.ifEmpty { "(empty)" }
			setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
			setPadding(0, 8, 0, 8)
		}
	}

	private fun buildTranslationResultContent(payload: TranslationResultPayload): View {
		val fontSizeSp = payload.fontSizeSp
		return LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			addView(
				TextView(context).apply {
					text = "Original"
					setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
				}
			)
			addView(
				TextView(context).apply {
					text = payload.sourceText.ifEmpty { "(empty)" }
					setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
					setPadding(0, 8, 0, 16)
				}
			)
			addView(
				TextView(context).apply {
					text = "Translation"
					setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
				}
			)
			addView(
				TextView(context).apply {
					text = payload.translatedText.ifEmpty { "(empty)" }
					setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
					setPadding(0, 8, 0, 8)
				}
			)
		}
	}

	private fun buildRecentHistoryContent(payload: RecentHistoryPayload): View {
		val fontSizeSp = payload.fontSizeSp
		if (payload.entries.isEmpty()) {
			return TextView(this).apply {
				text = payload.emptyHint.ifEmpty { "No translation history yet. Tap the bubble once to translate first." }
				setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
				setPadding(0, 16, 0, 16)
			}
		}

		val listContainer = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
		}

		payload.entries.forEachIndexed { index, entry ->
			val row = LinearLayout(this).apply {
				orientation = LinearLayout.VERTICAL
				setPadding(0, 12, 0, 16)
				addView(
					TextView(context).apply {
						text = "${index + 1}. ${entry.sourceText}"
						setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
					}
				)
				addView(
					TextView(context).apply {
						text = "→ ${entry.translatedText}"
						setTextSize(TypedValue.COMPLEX_UNIT_SP, fontSizeSp)
						setPadding(0, 6, 0, 6)
					}
				)
				addView(
					TextView(context).apply {
						text = "${entry.createdAt}  [${entry.status}]"
						setTextSize(TypedValue.COMPLEX_UNIT_SP, (fontSizeSp - 1f).coerceAtLeast(10f))
					}
				)

				val quickActionRow = LinearLayout(context).apply {
					orientation = LinearLayout.HORIZONTAL
					gravity = Gravity.START
					setPadding(0, 8, 0, 0)
					addView(
						Button(context).apply {
							text = "Copy original"
							setOnClickListener {
								copyToClipboard(entry.sourceText, "history_source")
								showToast("Copied source text")
							}
						}
					)
					addView(
						Button(context).apply {
							text = "Copy translation"
							setOnClickListener {
								copyToClipboard(entry.translatedText, "history_translated")
								showToast("Copied translation")
							}
						}
					)
				}
				addView(quickActionRow)
			}

			listContainer.addView(row)
		}

		return listContainer
	}

	private fun parseRecentHistoryPayload(message: String, fallbackFontSizeSp: Float): RecentHistoryPayload? {
		return try {
			val root = JSONObject(message)
			if (root.optString("type") != "recent_history_v1") {
				return null
			}

			val entriesJson = root.optJSONArray("entries")
			val entries = mutableListOf<HistoryEntry>()
			if (entriesJson != null) {
				for (index in 0 until entriesJson.length()) {
					val item = entriesJson.optJSONObject(index) ?: continue
					entries.add(
						HistoryEntry(
							sourceText = item.optString("sourceText"),
							translatedText = item.optString("translatedText"),
							createdAt = item.optString("createdAt"),
							status = item.optString("status", "unknown"),
						)
					)
				}
			}

			RecentHistoryPayload(
				entries = entries,
				emptyHint = root.optString("emptyHint", ""),
				fontSizeSp = root.optDouble("fontSizeSp", fallbackFontSizeSp.toDouble()).toFloat().coerceIn(12f, 28f),
			)
		} catch (_: Throwable) {
			null
		}
	}

	private fun parseTranslationResultPayload(message: String, fallbackFontSizeSp: Float): TranslationResultPayload {
		return try {
			val root = JSONObject(message)
			if (root.optString("type") != "translation_result_v1") {
				return TranslationResultPayload(
					sourceText = "Source text unavailable",
					translatedText = message,
					fontSizeSp = fallbackFontSizeSp,
				)
			}

			TranslationResultPayload(
				sourceText = root.optString("sourceText", "Source text unavailable"),
				translatedText = root.optString("translatedText", ""),
				fontSizeSp = root.optDouble("fontSizeSp", fallbackFontSizeSp.toDouble()).toFloat().coerceIn(12f, 28f),
			)
		} catch (_: Throwable) {
			TranslationResultPayload(
				sourceText = "Source text unavailable",
				translatedText = message,
				fontSizeSp = fallbackFontSizeSp,
			)
		}
	}

	private fun hideResultOverlay() {
		trace("service.overlay.hide")
		resultOverlayView?.let { windowManager.removeView(it) }
		resultOverlayView = null
	}

	private fun copyToClipboard(message: String, label: String = "translation_result") {
		trace("service.overlay.copy messageLength=${message.length}")
		val clipboardManager = getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager ?: return
		clipboardManager.setPrimaryClip(ClipData.newPlainText(label, message))
	}

	private fun showToast(message: String) {
		Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
	}

	private fun hasOverlayPermission(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			Settings.canDrawOverlays(this)
		} else {
			true
		}
	}

	private fun launchAction(actionId: String) {
		trace("service.overlay.launchAction actionId=$actionId")
		val launchIntent = Intent(this, MainActivity::class.java).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NO_ANIMATION)
			putExtra(EXTRA_ACTION_ID, actionId)
			putExtra(EXTRA_FROM_FLOATING_BUBBLE, true)
		}
		startActivity(launchIntent)
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
		const val ACTION_START = "modeltranslation.action.START_FLOATING_BUBBLE"
		const val ACTION_STOP = "modeltranslation.action.STOP_FLOATING_BUBBLE"
		const val ACTION_SHOW_RESULT = "modeltranslation.action.SHOW_RESULT_OVERLAY"
		const val ACTION_HIDE_RESULT = "modeltranslation.action.HIDE_RESULT_OVERLAY"
		const val ACTION_TRANSLATE_CLIPBOARD = "translate_clipboard"
		const val ACTION_OPEN_RECENT_HISTORY = "open_recent_history"
		const val EXTRA_ACTION_ID = "extra_action_id"
		const val EXTRA_RESULT_TITLE = "extra_result_title"
		const val EXTRA_RESULT_MESSAGE = "extra_result_message"
		const val EXTRA_SHOW_RETRY = "extra_show_retry"
		const val EXTRA_OVERLAY_FONT_SIZE_SP = "extra_overlay_font_size_sp"
		const val EXTRA_DIAGNOSTICS_ENABLED = "extra_diagnostics_enabled"
		const val EXTRA_FROM_FLOATING_BUBBLE = "extra_from_floating_bubble"
		private const val DEFAULT_OVERLAY_FONT_SIZE_SP = 15.0
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
			overlayFontSizeSp: Double = DEFAULT_OVERLAY_FONT_SIZE_SP,
		) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_SHOW_RESULT
					putExtra(EXTRA_RESULT_TITLE, title)
					putExtra(EXTRA_RESULT_MESSAGE, message)
					putExtra(EXTRA_SHOW_RETRY, showRetry)
					putExtra(EXTRA_OVERLAY_FONT_SIZE_SP, overlayFontSizeSp)
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

	private data class HistoryEntry(
		val sourceText: String,
		val translatedText: String,
		val createdAt: String,
		val status: String,
	)

	private data class RecentHistoryPayload(
		val entries: List<HistoryEntry>,
		val emptyHint: String,
		val fontSizeSp: Float,
	)

	private data class TranslationResultPayload(
		val sourceText: String,
		val translatedText: String,
		val fontSizeSp: Float,
	)
}