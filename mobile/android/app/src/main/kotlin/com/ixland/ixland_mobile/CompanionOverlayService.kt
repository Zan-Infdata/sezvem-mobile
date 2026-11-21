package com.ixland.ixland_mobile

import android.app.AlertDialog
import android.app.Service
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.WindowInsets
import android.view.WindowManager
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
 * The window is only as large as the character, is never focusable, and lets touches outside its
 * bounds reach the app underneath. The character is drawn by a second Flutter engine that runs
 * the `companionOverlayMain` entry point. Movement and gestures are decided in Dart, which calls
 * back through [WINDOW_CHANNEL].
 */
class CompanionOverlayService : Service() {
    private val windowManager by lazy { getSystemService(WINDOW_SERVICE) as WindowManager }
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var params: WindowManager.LayoutParams? = null
    private var channel: MethodChannel? = null
    private var dialog: AlertDialog? = null
    private var sound: AudioTrack? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!show()) stopSelf()
        return START_NOT_STICKY
    }

    private fun show(): Boolean {
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
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Start just past the right edge so the character can walk in.
            x = screen.right
            y = screen.centerY() - size / 2
        }
        val view = FlutterView(this, RenderMode.texture, TransparencyMode.transparent)
        view.attachToFlutterEngine(engine)
        windowManager.addView(view, params)
        engine.lifecycleChannel.appIsResumed()

        this.engine = engine
        this.channel = channel
        this.view = view
        this.params = params
        return true
    }

    private fun onWindowCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getLayout" -> result.success(layout())
            "moveTo" -> {
                val params = params
                val view = view
                if (params == null || view == null) {
                    result.success(null)
                    return
                }
                val screen = screenBounds()
                params.x = call.argument<Number>("x")?.toInt() ?: params.x
                // Horizontal positions may leave the screen so the character can walk off.
                params.y = (call.argument<Number>("y")?.toInt() ?: params.y)
                    .coerceIn(screen.top, maxOf(screen.top, screen.bottom - params.height))
                windowManager.updateViewLayout(view, params)
                result.success(null)
            }
            "resize" -> {
                val params = params
                val view = view
                if (params == null || view == null) {
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
                windowManager.updateViewLayout(view, params)
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
                stopSelf()
            }
            else -> result.notImplemented()
        }
    }

    private fun showAlert(title: String, message: String) {
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
        val view = view ?: return
        // Keep the character on screen after rotation or a display change.
        val screen = screenBounds()
        params.x = params.x.coerceIn(screen.left, maxOf(screen.left, screen.right - params.width))
        params.y = params.y.coerceIn(screen.top, maxOf(screen.top, screen.bottom - params.height))
        windowManager.updateViewLayout(view, params)
        channel?.invokeMethod("layoutChanged", layout())
    }

    override fun onDestroy() {
        stopSound()
        dialog?.dismiss()
        dialog = null
        channel?.setMethodCallHandler(null)
        channel = null
        view?.let {
            windowManager.removeView(it)
            it.detachFromFlutterEngine()
        }
        view = null
        params = null
        engine?.destroy()
        engine = null
        super.onDestroy()
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
        private const val ENTRY_POINT = "companionOverlayMain"
        /** Must match `companionWindowSize` in `companion_actions.dart`. */
        private const val WINDOW_SIZE_DP = 96
        private const val SAMPLE_RATE = 22_050
    }
}
