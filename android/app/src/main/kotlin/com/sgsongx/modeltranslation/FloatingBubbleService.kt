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
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FloatingBubbleService : Service() {
	private lateinit var windowManager: WindowManager
	private var bubbleView: View? = null
	private var resultOverlayView: View? = null

	override fun onCreate() {
		super.onCreate()
		windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
		ensureChannel(this)
		createOverlayBubble()
		startForeground(NOTIFICATION_ID, buildNotification())
	}

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		when (intent?.action) {
			ACTION_STOP -> stopSelf()
			ACTION_SHOW_RESULT -> {
				if (bubbleView == null) {
					createOverlayBubble()
				}
				showResultOverlay(
					title = intent.getStringExtra(EXTRA_RESULT_TITLE) ?: "Translation Result",
					message = intent.getStringExtra(EXTRA_RESULT_MESSAGE) ?: "",
					showRetry = intent.getBooleanExtra(EXTRA_SHOW_RETRY, false),
				)
			}
			ACTION_HIDE_RESULT -> hideResultOverlay()
			else -> {
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
		super.onDestroy()
	}

	override fun onBind(intent: Intent?): IBinder? = null

	private fun createOverlayBubble() {
		if (bubbleView != null) {
			return
		}

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
		bubbleView?.let { windowManager.removeView(it) }
		bubbleView = null
	}

	private fun showResultOverlay(title: String, message: String, showRetry: Boolean) {
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
		resultOverlayView?.let { windowManager.removeView(it) }
		resultOverlayView = null
	}

	private fun copyToClipboard(message: String) {
		val clipboardManager = getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager ?: return
		clipboardManager.setPrimaryClip(ClipData.newPlainText("translation_result", message))
	}

	private fun launchTranslationAction() {
		val launchIntent = Intent(this, MainActivity::class.java).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
			putExtra(EXTRA_ACTION_ID, ACTION_TRANSLATE_CLIPBOARD)
		}
		startActivity(launchIntent)
	}

	private fun buildNotification(): Notification {
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
		const val EXTRA_ACTION_ID = "extra_action_id"
		const val EXTRA_RESULT_TITLE = "extra_result_title"
		const val EXTRA_RESULT_MESSAGE = "extra_result_message"
		const val EXTRA_SHOW_RETRY = "extra_show_retry"
		private const val CHANNEL_ID = "modeltranslation.floating_bubble"
		private const val NOTIFICATION_ID = 1001

		fun start(context: Context) {
			val intent = Intent(context, FloatingBubbleService::class.java).apply {
				action = ACTION_START
			}
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				context.startForegroundService(intent)
			} else {
				context.startService(intent)
			}
		}

		fun stop(context: Context) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_STOP
				}
			)
		}

		fun showResult(context: Context, title: String, message: String, showRetry: Boolean = false) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_SHOW_RESULT
					putExtra(EXTRA_RESULT_TITLE, title)
					putExtra(EXTRA_RESULT_MESSAGE, message)
					putExtra(EXTRA_SHOW_RETRY, showRetry)
				}
			)
		}

		fun hideResult(context: Context) {
			context.startService(
				Intent(context, FloatingBubbleService::class.java).apply {
					action = ACTION_HIDE_RESULT
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
}