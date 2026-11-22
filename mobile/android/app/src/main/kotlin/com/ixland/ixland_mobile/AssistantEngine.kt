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
import java.io.File
import java.util.concurrent.Executors

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
        "You are the IXLand companion, a medical help assistant. Only answer questions about " +
            "health and medicine. For anything else, reply exactly: I don't know, I only know medicine."

    private val worker = Executors.newSingleThreadExecutor { Thread(it, "assistant-engine") }
    private val main = Handler(Looper.getMainLooper())

    // Read and written on the worker thread only.
    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var instruction = FALLBACK_INSTRUCTION

    // Read on any thread, written on the worker or main thread.
    @Volatile private var state = "unloaded"
    @Volatile private var detail: String? = null
    @Volatile private var backendName = "cpu"
    @Volatile private var loadMs: Long? = null
    @Volatile private var replying = false

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
        done: (Map<String, Any?>) -> Unit,
    ) {
        val app = context.applicationContext
        worker.execute {
            val wanted = systemInstruction?.takeIf { it.isNotBlank() } ?: FALLBACK_INSTRUCTION
            if (wanted != instruction) {
                instruction = wanted
                val loaded = engine
                if (loaded != null && !replying) {
                    conversation?.close()
                    conversation = loaded.createConversation(conversationConfig())
                }
            }
            if (engine == null) {
                val file = modelFile(app)
                if (!file.exists()) {
                    state = "missing"
                    detail = null
                } else {
                    state = "loading"
                    detail = null
                    backendName = if (backend == "gpu") "gpu" else "cpu"
                    val started = SystemClock.elapsedRealtime()
                    try {
                        val created = Engine(
                            EngineConfig(
                                modelPath = file.absolutePath,
                                backend = if (backendName == "gpu") Backend.GPU() else Backend.CPU(),
                                cacheDir = app.cacheDir.absolutePath,
                            ),
                        )
                        created.initialize()
                        engine = created
                        conversation = created.createConversation(conversationConfig())
                        loadMs = SystemClock.elapsedRealtime() - started
                        state = "ready"
                        Log.i(TAG, "Loaded on $backendName in $loadMs ms")
                    } catch (error: Throwable) {
                        closeQuietly()
                        state = "error"
                        detail = error.message ?: error.javaClass.simpleName
                        Log.w(TAG, "Load failed on $backendName", error)
                    }
                }
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
        if (replying) return "A reply is already in progress."
        replying = true
        worker.execute {
            val active = conversation
            if (active == null) {
                replying = false
                main.post { onError("The model isn't loaded.") }
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
                            main.post { onChunk(chunk) }
                        }

                        override fun onDone() {
                            replying = false
                            Log.i(TAG, "Reply of $chunks chunks in ${SystemClock.elapsedRealtime() - started} ms")
                            main.post(onDone)
                        }

                        override fun onError(throwable: Throwable) {
                            replying = false
                            Log.w(TAG, "Reply failed after $chunks chunks", throwable)
                            val message = throwable.message ?: throwable.javaClass.simpleName
                            main.post { onError(message) }
                        }
                    },
                )
            } catch (error: Throwable) {
                replying = false
                Log.w(TAG, "Reply failed to start", error)
                main.post { onError(error.message ?: error.javaClass.simpleName) }
            }
        }
        return null
    }

    /** Stops the streaming reply, if any. */
    fun cancel() {
        worker.execute {
            if (replying) conversation?.cancelProcess()
        }
    }

    /** Forgets the conversation so the next message starts fresh. The model stays loaded. */
    fun reset() {
        worker.execute {
            val loaded = engine ?: return@execute
            if (replying) conversation?.cancelProcess()
            conversation?.close()
            conversation = loaded.createConversation(conversationConfig())
            replying = false
        }
    }

    /** Releases the model and its memory. */
    fun unload() {
        worker.execute {
            if (replying) conversation?.cancelProcess()
            closeQuietly()
            state = "unloaded"
            detail = null
            loadMs = null
            replying = false
        }
    }

    private fun conversationConfig() =
        ConversationConfig(systemInstruction = Contents.of(instruction))

    private fun textOf(message: Message): String =
        message.contents.contents.filterIsInstance<Content.Text>().joinToString("") { it.text }

    private fun closeQuietly() {
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
