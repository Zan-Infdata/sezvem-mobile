package com.ixland.ixland_mobile.wear

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.PassiveListenerCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import androidx.health.services.client.data.PassiveListenerConfig
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.Wearable
import kotlin.math.roundToInt

class WatchActivity : Activity() {
    private val measureClient by lazy { HealthServices.getClient(this).measureClient }
    private val capabilities by lazy { Wearable.getCapabilityClient(this) }
    private val messages by lazy { Wearable.getMessageClient(this) }
    private val stepClient by lazy { HealthServices.getClient(this).passiveMonitoringClient }
    private lateinit var measurement: TextView
    private lateinit var phoneStatus: TextView
    private lateinit var toggle: Button
    private var measuring = false
    private var visible = false
    private var phoneId: String? = null
    private var latestSteps: Long? = null

    private val stepCallback = object : PassiveListenerCallback {
        override fun onNewDataPointsReceived(dataPoints: DataPointContainer) {
            if (!measuring) return
            val count = dataPoints.getData(DataType.STEPS_DAILY)
                .maxByOrNull { it.endDurationFromBoot }?.value ?: return
            if (count < 0) return
            latestSteps = count
            phoneId?.let(::sendSteps)
        }

        override fun onPermissionLost() {
            latestSteps = null
        }
    }

    private val phoneListener = CapabilityClient.OnCapabilityChangedListener { capability ->
        updatePhone(capability)
    }

    private val heartRateCallback = object : MeasureCallback {
        override fun onAvailabilityChanged(dataType: DeltaDataType<*, *>, availability: Availability) = Unit

        override fun onDataReceived(data: DataPointContainer) {
            val readings = data.getData(DataType.HEART_RATE_BPM).mapNotNull { sample ->
                sample.value.takeIf { it.isFinite() && it > 0 }?.roundToInt()?.takeIf { it > 0 }
            }
            if (readings.isEmpty()) return
            runOnUiThread {
                if (!measuring) return@runOnUiThread
                measurement.text = "${readings.last()} bpm"
                phoneId?.let { node ->
                    sendSteps(node)
                    readings.forEach { bpm ->
                        messages.sendMessage(node, HEART_RATE_PATH, bpm.toString().toByteArray())
                    }
                }
            }
        }

        override fun onRegistrationFailed(throwable: Throwable) {
            runOnUiThread {
                if (measuring) {
                    stopMeasurement("Heart rate unavailable")
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            val inset = (24 * resources.displayMetrics.density).roundToInt()
            setPadding(inset, inset, inset, inset)
        }
        measurement = TextView(this).apply {
            text = "Ready"
            textSize = 24f
            gravity = Gravity.CENTER
        }
        phoneStatus = TextView(this).apply {
            text = "Finding IXLand on phone…"
            gravity = Gravity.CENTER
        }
        toggle = Button(this).apply {
            text = "Start"
            setOnClickListener {
                if (measuring) stopMeasurement("Stopped") else requestMeasurement()
            }
        }
        content.addView(measurement)
        content.addView(phoneStatus)
        content.addView(toggle)
        setContentView(ScrollView(this).apply {
            isFillViewport = true
            addView(content)
        })
    }

    override fun onStart() {
        super.onStart()
        visible = true
        capabilities.addListener(phoneListener, PHONE_CAPABILITY)
        capabilities.getCapability(PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener(::updatePhone)
            .addOnFailureListener { if (visible) phoneStatus.text = "Phone connection unavailable" }
    }

    override fun onStop() {
        visible = false
        phoneId = null
        capabilities.removeListener(phoneListener, PHONE_CAPABILITY)
        if (measuring) stopMeasurement("Stopped")
        super.onStop()
    }

    private fun updatePhone(capability: CapabilityInfo) {
        if (!visible) return
        phoneId = capability.nodes.filter { it.isNearby }.minByOrNull { it.id }?.id
        phoneStatus.text = if (phoneId == null) "Open IXLand on your paired phone" else "Phone available"
    }

    private fun requestMeasurement() {
        val heartPermission = heartRatePermission()
        val permissions = buildList {
            if (checkSelfPermission(heartPermission) != PackageManager.PERMISSION_GRANTED) {
                add(heartPermission)
            }
            if (checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) {
                add(Manifest.permission.ACTIVITY_RECOGNITION)
            }
        }
        if (permissions.isEmpty()) startMeasurement()
        else requestPermissions(permissions.toTypedArray(), MEASUREMENT_REQUEST)
    }

    private fun heartRatePermission(): String =
        if (Build.VERSION.SDK_INT >= 36) {
            "android.permission.health.READ_HEART_RATE"
        } else {
            Manifest.permission.BODY_SENSORS
        }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MEASUREMENT_REQUEST) return
        if (checkSelfPermission(heartRatePermission()) == PackageManager.PERMISSION_GRANTED) {
            if (visible) startMeasurement()
        } else {
            measurement.text = "Allow heart-rate access"
        }
    }

    private fun startMeasurement() {
        if (measuring) return
        measuring = true
        measurement.text = "Measuring…"
        toggle.text = "Stop"
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        try {
            measureClient.registerMeasureCallback(DataType.HEART_RATE_BPM, heartRateCallback)
        } catch (_: Exception) {
            stopMeasurement("Heart rate unavailable")
            return
        }
        if (checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED) {
            try {
                val config = PassiveListenerConfig.builder()
                    .setDataTypes(setOf(DataType.STEPS_DAILY))
                    .build()
                stepClient.setPassiveListenerCallback(config, stepCallback)
            } catch (_: SecurityException) {
                // Keep heart-rate streaming if activity access was revoked.
            }
        }
    }

    private fun sendSteps(node: String) {
        latestSteps?.let { count ->
            messages.sendMessage(node, STEP_COUNT_PATH, count.toString().toByteArray())
        }
    }

    private fun stopMeasurement(label: String) {
        measuring = false
        stepClient.clearPassiveListenerCallbackAsync()
        latestSteps = null
        measureClient.unregisterMeasureCallbackAsync(DataType.HEART_RATE_BPM, heartRateCallback)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        measurement.text = label
        toggle.text = "Start"
    }

    private companion object {
        const val PHONE_CAPABILITY = "ixland_phone_v1"
        const val HEART_RATE_PATH = "/ixland/heart-rate/v1"
        const val STEP_COUNT_PATH = "/ixland/steps/v1"
        const val MEASUREMENT_REQUEST = 1
    }
}
