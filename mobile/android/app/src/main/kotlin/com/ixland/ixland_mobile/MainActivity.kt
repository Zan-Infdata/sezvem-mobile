package com.ixland.ixland_mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingBluetoothPermission: MethodChannel.Result? = null
    private var wearBridge: WearBridge? = null
    private var companionBridge: CompanionBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wearBridge = WearBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        companionBridge = CompanionBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ixland/bluetooth")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestScanPermissions") {
                    requestBluetoothPermissions(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        wearBridge?.close()
        wearBridge = null
        companionBridge?.close()
        companionBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        val permissions = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
                arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
            else -> arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        val missing = permissions.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
        } else if (pendingBluetoothPermission != null) {
            result.error("request_in_progress", "A permission request is already open.", null)
        } else {
            pendingBluetoothPermission = result
            requestPermissions(missing.toTypedArray(), BLUETOOTH_PERMISSION_REQUEST)
        }
    }

    @Deprecated("Forwards the overlay settings result to the companion bridge.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (companionBridge?.onActivityResult(requestCode) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == BLUETOOTH_PERMISSION_REQUEST) {
            val result = pendingBluetoothPermission
            pendingBluetoothPermission = null
            result?.success(
                grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED },
            )
        }
    }

    companion object {
        private const val BLUETOOTH_PERMISSION_REQUEST = 101
    }
}
