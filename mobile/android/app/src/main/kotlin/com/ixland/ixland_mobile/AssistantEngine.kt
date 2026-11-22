package com.ixland.ixland_mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.tool
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

/**
 * Runs Gemma on the phone through LiteRT-LM. There is one engine per app process, so the overlay
 * and the main app share the loaded model.
 *
 * Loading, conversation changes, and unloading run one at a time on a background thread. Replies
 * stream through LiteRT-LM's own thread. Every callback reaches the caller on the main thread.
 * Nothing is written to disk except LiteRT-LM's model cache, and logs contain counts and timings
 * only, never message text.
 */
internal object AssistantEngine {
    /** Must match the file name in `docs/mobile-implementation.md`. */
    const val MODEL_FILE = "gemma-4-E2B-it.litertlm"

    private const val TAG = "AssistantEngine"
    /** Used only if Flutter sends no instruction. The real one is `mobile/assets/soul.md`. */
    private const val FALLBACK_INSTRUCTION =
        "You are KEVIN, the ŠEzVEM companion and a medical help assistant. Only answer questions about " +
            "health and medicine. For anything else, reply exactly: I don't know that, I'm a medical expert."

    private val worker = Executors.newSingleThreadExecutor { Thread(it, "assistant-engine") }
    private val main = Handler(Looper.getMainLooper())

    // Read and written on the worker thread only.
    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var instruction = FALLBACK_INSTRUCTION
    private var checkInPreview: ((HeartRateCheckInReport) -> Unit)? = null

    // Read on any thread, written on the worker or main thread.
    @Volatile private var state = "unloaded"
    @Volatile private var detail: String? = null
    @Volatile private var backendName = "cpu"
    @Volatile private var loadMs: Long? = null
    @Volatile private var conversationGeneration = 0
    private val activeReply = AtomicReference<Reply?>(null)

    private class Reply {
        @Volatile var cancelled = false
    }

    /**
     * The model's expected location. Creates the app-owned `models` folder so a file copied there
     * with ADB stays readable by the app.
     */
    fun modelFile(context: Context): File {
        val folder = File(context.getExternalFilesDir(null), "models")
        folder.mkdirs()
        return File(folder, MODEL_FILE)
    }

    /** The engine state for Flutter: unloaded, loading, ready, missing, or error. */
    fun status(context: Context): Map<String, Any?> {
        val file = modelFile(context)
        val current = if (state == "unloaded" && !file.exists()) "missing" else state
        return mapOf(
            "state" to current,
            "modelPath" to file.absolutePath,
            "backend" to backendName,
            "loadMs" to loadMs,
            "message" to detail,
        )
    }

    /**
     * Loads the model if needed and reports the resulting status. [systemInstruction] sets who the
     * assistant is. If it differs from the loaded conversation's, the conversation starts over.
     */
    fun load(
        context: Context,
        backend: String,
        systemInstruction: String?,
        preview: ((HeartRateCheckInReport) -> Unit)?,
        done: (Map<String, Any?>) -> Unit,
    ) {
        val app = context.applicationContext
        worker.execute {
            val wanted = systemInstruction?.takeIf { it.isNotBlank() } ?: FALLBACK_INSTRUCTION
            val source = when {
                preview != null -> "soul.md and monitoring state prompts"
                wanted == FALLBACK_INSTRUCTION -> "fallback"
                else -> "soul.md"
            }
            Log.i(TAG, "System instruction from $source, ${wanted.length} characters")
            val replaceConversation = wanted != instruction || preview != null || checkInPreview != null
            instruction = wanted
            checkInPreview = preview
            try {
                val loaded = engine
                if (loaded != null) {
                    if (replaceConversation) restartConversation(loaded)
                    state = "ready"
                    detail = null
                } else {
                    val file = modelFile(app)
                    if (!file.exists()) {
                        state = "missing"
                        detail = null
                        val result = status(app)
                        main.post { done(result) }
                        return@execute
                    }
                    state = "loading"
                    detail = null
                    backendName = if (backend == "gpu") "gpu" else "cpu"
                    val started = SystemClock.elapsedRealtime()
                    val created = Engine(
                        EngineConfig(
                            modelPath = file.absolutePath,
                            backend = if (backendName == "gpu") Backend.GPU() else Backend.CPU(),
                            cacheDir = app.cacheDir.absolutePath,
                        ),
                    )
                    engine = created
                    created.initialize()
                    conversation = created.createConversation(conversationConfig())
                    loadMs = SystemClock.elapsedRealtime() - started
                    state = "ready"
                    Log.i(TAG, "Loaded on $backendName in $loadMs ms")
                }
            } catch (error: Throwable) {
                closeQuietly()
                state = "error"
                detail = error.javaClass.simpleName
                Log.w(TAG, "Load failed on $backendName ($detail)")
            }
            val result = status(app)
            main.post { done(result) }
        }
    }

    /**
     * Sends [text] and streams the reply. Returns an error message instead of starting when the
     * model isn't ready or a reply is already streaming.
     */
    fun send(
        text: String,
        onChunk: (String) -> Unit,
        onDone: () -> Unit,
        onError: (String) -> Unit,
    ): String? {
        if (state != "ready") return "The model isn't loaded."
        val reply = Reply()
        if (!activeReply.compareAndSet(null, reply)) return "A reply is already in progress."
        worker.execute {
            if (activeReply.get() !== reply) return@execute
            val active = conversation
            if (active == null) {
                if (activeReply.compareAndSet(reply, null)) {
                    main.post { onError("The model isn't loaded.") }
                }
                return@execute
            }
            val started = SystemClock.elapsedRealtime()
            var chunks = 0
            try {
                active.sendMessageAsync(
                    text,
                    object : MessageCallback {
                        override fun onMessage(message: Message) {
                            val chunk = textOf(message)
                            if (chunk.isEmpty()) return
                            chunks++
                            main.post { if (!reply.cancelled) onChunk(chunk) }
                        }

                        override fun onDone() {
                            if (!activeReply.compareAndSet(reply, null)) return
                            Log.i(TAG, "Reply of $chunks chunks in ${SystemClock.elapsedRealtime() - started} ms")
                            main.post(onDone)
                        }

                        override fun onError(throwable: Throwable) {
                            if (!activeReply.compareAndSet(reply, null)) return
                            Log.w(TAG, "Reply failed after $chunks chunks (${throwable.javaClass.simpleName})")
                            main.post { onError("The model could not complete the reply.") }
                        }
                    },
                )
            } catch (error: Throwable) {
                if (activeReply.compareAndSet(reply, null)) {
                    Log.w(TAG, "Reply failed to start (${error.javaClass.simpleName})")
                    main.post { onError("The model could not start the reply.") }
                }
            }
        }
        return null
    }

    /** Stops the streaming reply, if any. */
    fun cancel() {
        worker.execute {
            cancelReply()
        }
    }

    /** Forgets the conversation so the next message starts fresh. The model stays loaded. */
    fun reset(done: (Boolean) -> Unit) {
        worker.execute {
            val reset = runCatching { engine?.let(::restartConversation) }.isSuccess
            if (!reset) {
                closeQuietly()
                state = "error"
                detail = "The conversation could not be reset."
            }
            main.post { done(reset) }
        }
    }

    /** Releases the model and its memory. */
    fun unload() {
        worker.execute {
            closeQuietly()
            state = "unloaded"
            detail = null
            loadMs = null
            checkInPreview = null
        }
    }

    private fun cancelReply() {
        val reply = activeReply.getAndSet(null) ?: return
        reply.cancelled = true
        conversation?.cancelProcess()
    }

    private fun restartConversation(loaded: Engine) {
        conversationGeneration++
        cancelReply()
        conversation?.close()
        conversation = loaded.createConversation(conversationConfig())
    }

    private fun conversationConfig(): ConversationConfig {
        val generation = conversationGeneration
        val tools = checkInPreview?.let { preview ->
            listOf(tool(HeartRateCheckInTool { report ->
                val reply = activeReply.get()
                if (reply == null || generation != conversationGeneration) {
                    false
                } else {
                    main.post {
                        if (!reply.cancelled && generation == conversationGeneration) preview(report)
                    }
                }
            }))
        }.orEmpty()
        return ConversationConfig(systemInstruction = Contents.of(instruction), tools = tools)
    }

    private fun textOf(message: Message): String =
        message.contents.contents.filterIsInstance<Content.Text>().joinToString("") { it.text }

    private fun closeQuietly() {
        conversationGeneration++
        try {
            cancelReply()
        } catch (_: Throwable) {
        }
        try {
            conversation?.close()
        } catch (_: Throwable) {
        }
        try {
            engine?.close()
        } catch (_: Throwable) {
        }
        conversation = null
        engine = null
    }
}
