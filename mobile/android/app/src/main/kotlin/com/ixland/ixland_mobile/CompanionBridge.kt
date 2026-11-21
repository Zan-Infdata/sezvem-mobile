package com.ixland.ixland_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Lets the main app check overlay access and show, hide, and move the companion. */
internal class CompanionBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "ixland/companion")
    private var pendingPermission: MethodChannel.Result? = null

    init {
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
            val intent = Intent(activity, CompanionOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }
            result.success(true)
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
        pendingPermission = null
    }

    companion object {
        private const val OVERLAY_PERMISSION_REQUEST = 102
    }
}
