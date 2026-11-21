package com.ixland.ixland_mobile

import android.content.Context
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class WearBridge(context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val capabilities = Wearable.getCapabilityClient(context)
    private val messages = Wearable.getMessageClient(context)
    private val commands = MethodChannel(messenger, "ixland/wear")
    private val readings = EventChannel(messenger, "ixland/wear/heart_rate")
    private var listener: MessageClient.OnMessageReceivedListener? = null

    init {
        commands.setMethodCallHandler { call, result ->
            if (call.method == "findWatches") {
                capabilities.getCapability(WATCH_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                    .addOnSuccessListener { capability ->
                        result.success(
                            capability.nodes.filter { it.isNearby }.sortedBy { it.displayName }.map {
                                mapOf("id" to it.id, "name" to it.displayName)
                            },
                        )
                    }
                    .addOnFailureListener {
                        result.error("wear_discovery_failed", "Could not look up paired watches.", null)
                    }
            } else {
                result.notImplemented()
            }
        }
        readings.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val nodeId = arguments as? String
        if (nodeId.isNullOrBlank()) {
            events.error("invalid_watch", "Select a paired watch first.", null)
            events.endOfStream()
            return
        }
        onCancel(null)
        val receiver = object : MessageClient.OnMessageReceivedListener {
            override fun onMessageReceived(event: MessageEvent) {
                if (listener === this && event.sourceNodeId == nodeId && event.path == HEART_RATE_PATH) {
                    event.data.decodeToString().toIntOrNull()?.takeIf { it > 0 }?.let(events::success)
                }
            }
        }
        listener = receiver
        messages.addListener(receiver)
            .addOnSuccessListener {
                if (listener === receiver) events.success("connected")
            }
            .addOnFailureListener {
                if (listener === receiver) {
                    events.error("wear_listener_failed", "Could not start the watch connection.", null)
                    events.endOfStream()
                }
            }
    }

    override fun onCancel(arguments: Any?) {
        listener?.let { messages.removeListener(it) }
        listener = null
    }

    fun close() {
        onCancel(null)
        commands.setMethodCallHandler(null)
        readings.setStreamHandler(null)
    }

    private companion object {
        const val WATCH_CAPABILITY = "ixland_watch_v1"
        const val HEART_RATE_PATH = "/ixland/heart-rate/v1"
    }
}
