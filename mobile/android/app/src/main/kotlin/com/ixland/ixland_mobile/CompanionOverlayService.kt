package com.ixland.ixland_mobile

import android.app.AlertDialog
import android.app.Service
import android.content.Intent
import android.content.res.Configuration
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
import kotlin.math.roundToInt

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
        private const val WINDOW_SIZE_DP = 96
    }
}
