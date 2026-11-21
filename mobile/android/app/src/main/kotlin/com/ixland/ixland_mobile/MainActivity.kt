package com.ixland.ixland_mobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

class MainActivity : FlutterActivity() {
    private var pendingBluetoothPermission: MethodChannel.Result? = null
    private var wearBridge: WearBridge? = null
    private var companionBridge: CompanionBridge? = null
    private var patientSettingsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        wearBridge = WearBridge(applicationContext, messenger)
        companionBridge = CompanionBridge(this, messenger)
        val patientPrefs = getSharedPreferences("patient_settings", Context.MODE_PRIVATE)
        patientSettingsChannel = MethodChannel(
            messenger,
            "ixland/patient_settings",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPatientId" -> result.success(patientPrefs.getString("patient_id", null))
                    "setPatientId" -> {
                        val id = call.arguments as? String
                        if (id.isNullOrEmpty()) {
                            result.error("invalid_patient_id", "Enter a patient ID.", null)
                        } else if (patientPrefs.edit().putString("patient_id", id).commit()) {
                            result.success(null)
                        } else {
                            result.error("save_failed", "Could not save patient ID.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(messenger, "ixland/bluetooth")
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
        patientSettingsChannel?.setMethodCallHandler(null)
        patientSettingsChannel = null
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
