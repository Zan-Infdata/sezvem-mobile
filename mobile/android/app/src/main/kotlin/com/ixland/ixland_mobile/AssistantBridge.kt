package com.ixland.ixland_mobile

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Connects a Flutter engine to [AssistantEngine].
 *
 * Methods on [METHOD_CHANNEL] are `status`, `load`, `send`, `cancel`, and `reset`. A `send` call
 * carries an `id` chosen by Dart, and reply events on [EVENT_CHANNEL] carry the same `id` with a
 * `type` of `chunk`, `done`, or `error`.
 */
internal class AssistantBridge(context: Context, messenger: BinaryMessenger) {
    private val context = context.applicationContext
    private val methods = MethodChannel(messenger, METHOD_CHANNEL)
    private val events = EventChannel(messenger, EVENT_CHANNEL)
    private var sink: EventChannel.EventSink? = null

    init {
        events.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(AssistantEngine.status(context))
                "load" -> AssistantEngine.load(
                    context,
                    call.argument<String>("backend") ?: "cpu",
                ) { result.success(it) }
                "send" -> {
                    val id = call.argument<Number>("id")?.toInt()
                    val text = call.argument<String>("text")
                    if (id == null || text.isNullOrBlank()) {
                        result.error("invalid_message", "Enter a message.", null)
                        return@setMethodCallHandler
                    }
                    val refused = AssistantEngine.send(
                        text,
                        onChunk = { emit(id, "chunk", it) },
                        onDone = { emit(id, "done") },
                        onError = { emit(id, "error", it) },
                    )
                    if (refused == null) result.success(null) else result.error("not_ready", refused, null)
                }
                "cancel" -> {
                    AssistantEngine.cancel()
                    result.success(null)
                }
                "reset" -> {
                    AssistantEngine.reset()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun emit(id: Int, type: String, text: String? = null) {
        sink?.success(mapOf("id" to id, "type" to type, "text" to text))
    }

    fun close() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
    }

    companion object {
        const val METHOD_CHANNEL = "ixland/assistant"
        const val EVENT_CHANNEL = "ixland/assistant/events"
    }
}
