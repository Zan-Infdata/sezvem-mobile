package com.ixland.ixland_mobile

import com.google.ai.edge.litertlm.Tool
import com.google.ai.edge.litertlm.ToolParam
import com.google.ai.edge.litertlm.ToolSet
import java.util.concurrent.atomic.AtomicBoolean

internal data class HeartRateCheckInReport(
    val heartFeeling: String,
    val spo2Percent: Int?,
) {
    val stateId: String get() = "s-123"
}

internal class HeartRateCheckInTool(
    private val preview: (HeartRateCheckInReport) -> Boolean,
) : ToolSet {
    private val reported = AtomicBoolean(false)

    @Tool(description = "Preview a completed critical heart rate check-in on this device.")
    fun reportHeartRateCheckIn(
        @ToolParam(description = "How the patient described their heart feeling.")
        heartFeeling: String,
        @ToolParam(description = "Reported SpO2 as a whole percent. Omit if unavailable or declined.")
        oxygenSaturationPercent: Int? = null,
    ): Map<String, String> {
        val feeling = heartFeeling.trim()
        if (feeling.isEmpty() || (oxygenSaturationPercent != null && oxygenSaturationPercent !in 0..100)) {
            return mapOf("status" to "invalid_check_in", "message" to "Use the patient's answer and actual percentage.")
        }
        if (!reported.compareAndSet(false, true)) return mapOf("status" to "already_previewed")
        if (!preview(HeartRateCheckInReport(feeling, oxygenSaturationPercent))) {
            reported.set(false)
            return mapOf("status" to "preview_unavailable")
        }
        return mapOf("status" to "preview_only", "message" to "No report was sent to the care team.")
    }
}
