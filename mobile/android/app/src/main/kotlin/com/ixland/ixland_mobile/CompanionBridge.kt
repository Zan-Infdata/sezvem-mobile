package com.ixland.ixland_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Lets the main app check overlay access and start or stop the companion overlay. */
internal class CompanionBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "ixland/companion")
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(Settings.canDrawOverlays(activity))
                "requestPermission" -> requestPermission(result)
                "show" -> {
                    if (Settings.canDrawOverlays(activity)) {
                        activity.startService(Intent(activity, CompanionOverlayService::class.java))
                        result.success(null)
                    } else {
                        result.error("permission_denied", "Overlay access is off.", null)
                    }
                }
                "hide" -> {
                    activity.stopService(Intent(activity, CompanionOverlayService::class.java))
                    result.success(null)
                }
                "minimizeApp" -> result.success(activity.moveTaskToBack(true))
                else -> result.notImplemented()
            }
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
