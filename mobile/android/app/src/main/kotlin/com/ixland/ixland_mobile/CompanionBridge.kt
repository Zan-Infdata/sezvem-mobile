package com.ixland.ixland_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Lets the main app check overlay access and show, hide, and move the companion. */
internal class CompanionBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "ixland/companion")
    private val dismissals = EventChannel(messenger, "ixland/companion/dismissed")
    private var dismissalSink: EventChannel.EventSink? = null
    private val onWindowDismissed: () -> Unit = { dismissalSink?.success(null) }
    private var pendingPermission: MethodChannel.Result? = null

    init {
        CompanionOverlayService.onWindowDismissed = onWindowDismissed
        dismissals.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                dismissalSink = events
            }

            override fun onCancel(arguments: Any?) {
                dismissalSink = null
            }
        })
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(Settings.canDrawOverlays(activity))
                "requestPermission" -> requestPermission(result)
                "show" -> show(result)
                "hide" -> {
                    // Stops the foreground service along with the companion.
                    activity.stopService(Intent(activity, CompanionOverlayService::class.java))
                    result.success(null)
                }
                "isShowing" -> result.success(CompanionOverlayService.instance?.isShowing == true)
                "showAlert" -> result.success(
                    CompanionOverlayService.instance?.showAlert(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("message") ?: "",
                    ) == true,
                )
                "moveTo" -> {
                    val service = CompanionOverlayService.instance
                    val u = call.argument<Number>("u")?.toDouble()
                    val v = call.argument<Number>("v")?.toDouble()
                    if (service == null || u == null || v == null) {
                        result.success(false)
                    } else {
                        service.moveTo(u.coerceIn(0.0, 1.0), v.coerceIn(0.0, 1.0)) { result.success(it) }
                    }
                }
                "getLook" -> result.success(CompanionPrefs.look(activity))
                "setLook" -> {
                    CompanionPrefs.setLook(
                        activity,
                        call.argument<String>("style"),
                        call.argument<String>("choices"),
                    )
                    CompanionOverlayService.instance?.applyLook(CompanionPrefs.look(activity))
                    result.success(null)
                }
                "minimizeApp" -> result.success(activity.moveTaskToBack(true))
                else -> result.notImplemented()
            }
        }
    }

    private fun show(result: MethodChannel.Result) {
        if (!Settings.canDrawOverlays(activity)) {
            result.error("permission_denied", "Overlay access is off.", null)
            return
        }
        // A running service can add its window again without a new start, even in the background.
        val service = CompanionOverlayService.instance
        if (service != null) {
            result.success(service.show())
            return
        }
        try {
            val receiver = object : ResultReceiver(Handler(Looper.getMainLooper())) {
                override fun onReceiveResult(resultCode: Int, resultData: Bundle?) {
                    result.success(resultCode == Activity.RESULT_OK)
                }
            }
            val intent = Intent(activity, CompanionOverlayService::class.java)
                .putExtra(CompanionOverlayService.EXTRA_SHOW_RESULT, receiver)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }
        } catch (error: IllegalStateException) {
            // Android can refuse to start a foreground service while the app is in the background.
            result.error("start_blocked", "Android didn't allow the companion to start now.", null)
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        when {
            Settings.canDrawOverlays(activity) -> result.success(true)
            pendingPermission != null ->
                result.error("request_in_progress", "A permission request is already open.", null)
            else -> {
                pendingPermission = result
                activity.startActivityForResult(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}"),
                    ),
                    OVERLAY_PERMISSION_REQUEST,
                )
            }
        }
    }

    /** Returns true when the result belonged to this bridge. */
    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != OVERLAY_PERMISSION_REQUEST) return false
        val result = pendingPermission
        pendingPermission = null
        result?.success(Settings.canDrawOverlays(activity))
        return true
    }

    fun close() {
        channel.setMethodCallHandler(null)
        dismissals.setStreamHandler(null)
        dismissalSink = null
        if (CompanionOverlayService.onWindowDismissed === onWindowDismissed) {
            CompanionOverlayService.onWindowDismissed = null
        }
        pendingPermission = null
    }

    companion object {
        private const val OVERLAY_PERMISSION_REQUEST = 102
    }
}
