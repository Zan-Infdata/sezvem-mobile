package com.ixland.ixland_mobile

import android.app.Activity
import android.app.AlertDialog
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.pm.ServiceInfo
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ResultReceiver
import android.provider.Settings
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Hosts the companion in a small system overlay window.
 *
 * The window is only as large as the character, isn't focusable, and lets touches outside its
 * bounds reach the app underneath. While the chat is open, the window expands to the usable screen
 * and becomes focusable so the keyboard can type into it. The character is drawn by a second Flutter engine that runs
 * the `companionOverlayMain` entry point. Movement and gestures are decided in Dart, which calls
 * back through [WINDOW_CHANNEL].
 *
 * The service runs in the foreground with a notification so the app keeps running in the
 * background and can show, hide, and move the companion. Closing the companion only removes its
 * window. The service stops through the notification's Stop action or [CompanionBridge].
 */
class CompanionOverlayService : Service() {
    private val windowManager by lazy { getSystemService(WINDOW_SERVICE) as WindowManager }
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var root: OverlayRoot? = null
    private var assistant: AssistantBridge? = null
    /** The window's bounds before [expand], or null while the window is collapsed. */
    private var collapsed: Rect? = null
    private var params: WindowManager.LayoutParams? = null
    private var channel: MethodChannel? = null
    private var dialog: AlertDialog? = null
    private var readyForCheckIns = false
    private var pendingCheckIn: String? = null
    private var checkInActive = false
    private var sound: AudioTrack? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Whether the companion window is on screen. */
    val isShowing: Boolean
        get() = view != null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val shown = intent?.action != ACTION_STOP && show()
        @Suppress("DEPRECATION")
        val result = intent?.getParcelableExtra<ResultReceiver>(EXTRA_SHOW_RESULT)
        result?.send(if (shown) Activity.RESULT_OK else Activity.RESULT_CANCELED, null)
        if (!shown) stopSelf()
        return START_NOT_STICKY
    }

    /** Adds the companion window if it isn't showing. Returns false without overlay access. */
    fun show(): Boolean {
        if (view != null) return true
        if (!Settings.canDrawOverlays(this)) return false

        val engine = FlutterEngine(this, null, false)
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, WINDOW_CHANNEL)
        channel.setMethodCallHandler(::onWindowCall)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                ENTRY_POINT,
            ),
        )

        val size = (WINDOW_SIZE_DP * resources.displayMetrics.density).roundToInt()
        val screen = screenBounds()
        val params = WindowManager.LayoutParams(
            size,
            size,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            COLLAPSED_FLAGS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Start just past the right edge so the character can walk in.
            x = screen.right
            y = screen.centerY() - size / 2
        }
        val view = FlutterView(this, RenderMode.texture, TransparencyMode.transparent)
        view.attachToFlutterEngine(engine)
        val root = OverlayRoot(this).apply { addView(view) }
        windowManager.addView(root, params)
        engine.lifecycleChannel.appIsResumed()

        this.engine = engine
        this.channel = channel
        this.assistant = AssistantBridge(this, engine.dartExecutor.binaryMessenger) { _ ->
            if (checkInActive) {
                showAlert("Check-in preview", "The assistant prepared your check-in report on this phone.")
            }
        }
        this.view = view
        this.root = root
        this.params = params
        return true
    }

    private fun onWindowCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getLayout" -> result.success(layout())
            "getLook" -> result.success(CompanionPrefs.look(this))
            "readyForCheckIns" -> {
                readyForCheckIns = true
                pendingCheckIn?.let { channel?.invokeMethod("startCheckIn", mapOf("prompt" to it)) }
                pendingCheckIn = null
                result.success(null)
            }
            "moveTo" -> {
                val params = params
                val root = root
                if (params == null || root == null || collapsed != null) {
                    result.success(null)
                    return
                }
                val screen = screenBounds()
                params.x = call.argument<Number>("x")?.toInt() ?: params.x
                // Horizontal positions may leave the screen so the character can walk off.
                params.y = (call.argument<Number>("y")?.toInt() ?: params.y)
                    .coerceIn(screen.top, maxOf(screen.top, screen.bottom - params.height))
                windowManager.updateViewLayout(root, params)
                result.success(null)
            }
            "resize" -> {
                val params = params
                val root = root
                if (params == null || root == null || collapsed != null) {
                    result.success(layout())
                    return
                }
                val density = resources.displayMetrics.density
                val width = ((call.argument<Number>("width")?.toDouble() ?: WINDOW_SIZE_DP.toDouble()) * density)
                    .roundToInt()
                val height = ((call.argument<Number>("height")?.toDouble() ?: WINDOW_SIZE_DP.toDouble()) * density)
                    .roundToInt()
                // Keep the bottom center in place so the character doesn't jump.
                val screen = screenBounds()
                params.x += (params.width - width) / 2
                params.y = (params.y + params.height - height)
                    .coerceIn(screen.top, maxOf(screen.top, screen.bottom - height))
                params.width = width
                params.height = height
                windowManager.updateViewLayout(root, params)
                result.success(layout())
            }
            "expand" -> {
                expand()
                result.success(layout())
            }
            "collapse" -> {
                collapse()
                result.success(layout())
            }
            "playInflateSound" -> {
                playInflateSound(call.argument<Number>("durationMs")?.toInt() ?: 2000)
                result.success(null)
            }
            "stopSound" -> {
                stopSound()
                result.success(null)
            }
            "showAlert" -> {
                showAlert(
                    call.argument<String>("title") ?: "",
                    call.argument<String>("message") ?: "",
                )
                result.success(null)
            }
            "close" -> {
                result.success(null)
                // Destroy the engine after this call returns, not while it's handling the call.
                mainHandler.post {
                    if (isShowing) {
                        hide()
                        onWindowDismissed?.invoke()
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Grows the window to the usable screen and makes it focusable for the chat. [collapse]
     * restores the earlier bounds.
     */
    private fun expand() {
        val params = params ?: return
        val root = root ?: return
        if (collapsed == null) {
            collapsed = Rect(params.x, params.y, params.x + params.width, params.y + params.height)
        }
        fitToScreen(params)
        params.flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        windowManager.updateViewLayout(root, params)
        view?.requestFocus()
    }

    private fun collapse() {
        val params = params ?: return
        val root = root ?: return
        val bounds = collapsed ?: return
        collapsed = null
        params.x = bounds.left
        params.y = bounds.top
        params.width = bounds.width()
        params.height = bounds.height()
        params.flags = COLLAPSED_FLAGS
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_STATE_UNSPECIFIED
        windowManager.updateViewLayout(root, params)
    }

    private fun fitToScreen(params: WindowManager.LayoutParams) {
        val screen = screenBounds()
        params.x = screen.left
        params.y = screen.top
        params.width = screen.width()
        params.height = screen.height()
    }

    /** Sends Back to the overlay while the chat is open, instead of to the app underneath. */
    private inner class OverlayRoot(context: Context) : FrameLayout(context) {
        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
            if (event.keyCode == KeyEvent.KEYCODE_BACK && collapsed != null) {
                if (event.action == KeyEvent.ACTION_UP) channel?.invokeMethod("backPressed", null)
                return true
            }
            return super.dispatchKeyEvent(event)
        }
    }

    fun showAlert(title: String, message: String): Boolean {
        if (!isShowing || !Settings.canDrawOverlays(this)) return false
        dialog?.dismiss()
        val themed = ContextThemeWrapper(this, android.R.style.Theme_DeviceDefault_Light_Dialog_Alert)
        dialog = AlertDialog.Builder(themed)
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton(android.R.string.ok, null)
            .create()
            .also {
                it.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
                it.setOnDismissListener { _ -> if (dialog === it) dialog = null }
                it.show()
            }
        return true
    }

    fun startCheckIn(prompt: String): Boolean {
        val channel = channel ?: return false
        if (!isShowing || !Settings.canDrawOverlays(this)) return false
        dialog?.dismiss()
        checkInActive = true
        if (readyForCheckIns) {
            channel.invokeMethod("startCheckIn", mapOf("prompt" to prompt))
        } else {
            pendingCheckIn = prompt
        }
        return true
    }

    fun clearCheckIn() {
        checkInActive = false
        pendingCheckIn = null
        dialog?.dismiss()
        if (readyForCheckIns) channel?.invokeMethod("clearCheckIn", null)
    }

    /** Plays a generated balloon sound: rushing air under a rising tone. */
    private fun playInflateSound(durationMs: Int) {
        stopSound()
        val count = SAMPLE_RATE * durationMs.coerceIn(100, 10_000) / 1000
        val samples = ShortArray(count)
        val noise = java.util.Random(7)
        var phase = 0.0
        var air = 0.0
        for (i in 0 until count) {
            val t = i.toDouble() / count
            phase += 2 * PI * (160 + 560 * t * t) / SAMPLE_RATE
            // Low-pass filtered noise sounds like air rather than static.
            air += ((noise.nextDouble() * 2 - 1) - air) * 0.18
            val tone = sin(phase) * 0.35 + sin(phase * 2) * 0.1
            val fade = min(1.0, t * 25) * min(1.0, (1 - t) * 25)
            samples[i] = ((tone + air * 0.9) * fade * 0.5 * Short.MAX_VALUE).toInt().toShort()
        }
        sound = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(count * 2)
                .build()
                .also {
                    it.write(samples, 0, count)
                    it.play()
                }
        } catch (_: Exception) {
            // Sound is decoration. The animation still runs without it.
            null
        }
    }

    private fun stopSound() {
        sound?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        sound = null
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val params = params ?: return
        val root = root ?: return
        val screen = screenBounds()
        if (collapsed != null) {
            // The open chat fills the new screen. Collapsing returns to the old spot, clamped.
            fitToScreen(params)
            collapsed = collapsed?.let {
                val x = it.left.coerceIn(screen.left, maxOf(screen.left, screen.right - it.width()))
                val y = it.top.coerceIn(screen.top, maxOf(screen.top, screen.bottom - it.height()))
                Rect(x, y, x + it.width(), y + it.height())
            }
        } else {
            // Keep the character on screen after rotation or a display change.
            params.x = params.x.coerceIn(screen.left, maxOf(screen.left, screen.right - params.width))
            params.y = params.y.coerceIn(screen.top, maxOf(screen.top, screen.bottom - params.height))
        }
        windowManager.updateViewLayout(root, params)
        channel?.invokeMethod("layoutChanged", layout())
    }

    /**
     * Asks the companion to walk to a point given in 0 to 1 screen coordinates. [onResult] receives
     * false when the companion isn't showing, isn't ready, or is busy with another action.
     */
    fun moveTo(u: Double, v: Double, onResult: (Boolean) -> Unit) {
        val channel = channel ?: return onResult(false)
        channel.invokeMethod(
            "moveToUv",
            mapOf("u" to u, "v" to v),
            object : MethodChannel.Result {
                override fun success(result: Any?) = onResult(result == true)
                override fun error(code: String, message: String?, details: Any?) = onResult(false)
                // The overlay engine hasn't registered its handler yet.
                override fun notImplemented() = onResult(false)
            },
        )
    }

    /** Switches a visible companion to [look], in the form [CompanionPrefs.look] returns. */
    fun applyLook(look: Map<String, String?>) {
        channel?.invokeMethod("lookChanged", look)
    }

    /** Removes the companion window and its engine. The service keeps running. */
    fun hide() {
        stopSound()
        dialog?.dismiss()
        dialog = null
        readyForCheckIns = false
        pendingCheckIn = null
        checkInActive = false
        channel?.setMethodCallHandler(null)
        channel = null
        assistant?.close()
        assistant = null
        // Free the model's memory. The chat lives only as long as the window.
        AssistantEngine.unload()
        root?.let { windowManager.removeView(it) }
        root = null
        view?.detachFromFlutterEngine()
        view = null
        params = null
        collapsed = null
        engine?.destroy()
        engine = null
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        mainHandler.removeCallbacksAndMessages(null)
        hide()
        super.onDestroy()
    }

    private fun startInForeground() {
        val notifications = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL,
                    "Companion",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = "Shown while the companion can appear over other apps." },
            )
        }
        val stop = PendingIntent.getService(
            this,
            0,
            Intent(this, CompanionOverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_companion)
            .setContentTitle("IXLand companion")
            .setContentText("The companion can appear over other apps.")
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Stop", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun layout(): Map<String, Any> {
        val screen = screenBounds()
        return mapOf(
            "x" to (params?.x ?: 0),
            "y" to (params?.y ?: 0),
            "width" to (params?.width ?: 0),
            "height" to (params?.height ?: 0),
            "screenLeft" to screen.left,
            "screenTop" to screen.top,
            "screenRight" to screen.right,
            "screenBottom" to screen.bottom,
            "density" to resources.displayMetrics.density.toDouble(),
        )
    }

    /** The area not covered by system bars or display cutouts, in physical pixels. */
    private fun screenBounds(): Rect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = windowManager.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            return Rect(metrics.bounds).apply {
                left += insets.left
                top += insets.top
                right -= insets.right
                bottom -= insets.bottom
            }
        }
        val display = resources.displayMetrics
        return Rect(0, 0, display.widthPixels, display.heightPixels)
    }

    companion object {
        const val WINDOW_CHANNEL = "ixland/companion/window"
        const val ACTION_STOP = "com.ixland.ixland_mobile.companion.STOP"
        const val EXTRA_SHOW_RESULT = "com.ixland.ixland_mobile.companion.SHOW_RESULT"
        var onWindowDismissed: (() -> Unit)? = null
        private const val NOTIFICATION_CHANNEL = "companion"
        private const val NOTIFICATION_ID = 7

        /** The running service, or null. The bridge uses it to control the companion. */
        var instance: CompanionOverlayService? = null
            private set
        private const val ENTRY_POINT = "companionOverlayMain"
        /** Must match `companionWindowSize` in `companion_actions.dart`. */
        private const val WINDOW_SIZE_DP = 192
        private const val SAMPLE_RATE = 22_050
        private const val COLLAPSED_FLAGS =
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
    }
}
