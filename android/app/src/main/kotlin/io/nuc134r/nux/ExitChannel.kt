package io.nuc134r.nux

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

/**
 * Why the previous runs of nux ended, for the log: a crash in Kotlin or Java code, a native crash, the
 * system killing the app, all of which end the process before Dart can write anything.
 *
 * Android keeps these itself (ApplicationExitInfo, Android 11+); a Java crash also leaves its stack
 * trace in a file here. Dart asks once at start (`unseen`) and gets only what it has not seen yet.
 */
object ExitChannel {
    private const val CHANNEL = "nux/exits"
    private const val PREFS = "nux_exits"
    // v2: tombstones are read now; report the earlier native crashes again, with their stacks.
    private const val SEEN = "seen_v2"
    private const val CRASH_FILE = "last_crash.txt"
    private var channel: MethodChannel? = null
    private var handlerInstalled = false

    fun attach(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        installCrashHandler(app)
        if (channel != null) return
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "unseen" -> result.success(
                        try {
                            unseen(app)
                        } catch (e: Exception) {
                            listOf(mapOf("reason" to "unknown", "description" to "Exit reasons unavailable: $e"))
                        }
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Keeps the stack trace of a Java / Kotlin crash, then lets Android handle it as before. */
    private fun installCrashHandler(context: Context) {
        if (handlerInstalled) return
        handlerInstalled = true
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val trace = StringWriter().also { error.printStackTrace(PrintWriter(it)) }.toString()
                File(context.filesDir, CRASH_FILE).writeText("Thread ${thread.name}: ${trace.take(16000)}")
            } catch (_: Throwable) {
            }
            previous?.uncaughtException(thread, error)
        }
    }

    private fun unseen(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val seen = prefs.getLong(SEEN, 0)
        val exits = mutableListOf<Map<String, Any?>>()
        var newest = seen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            for (info in am.getHistoricalProcessExitReasons(context.packageName, 0, 16)) {
                if (info.timestamp <= seen) continue
                newest = maxOf(newest, info.timestamp)
                exits.add(
                    mapOf(
                        "time" to info.timestamp,
                        "reason" to reasonName(info.reason),
                        "description" to info.description,
                        "status" to info.status,
                        "importance" to info.importance,
                        "process" to info.processName,
                        "trace" to if (info.reason == ApplicationExitReason.CRASH_NATIVE) nativeTrace(info) else null,
                    )
                )
            }
        }
        val crash = File(context.filesDir, CRASH_FILE)
        if (crash.exists()) {
            exits.add(mapOf("reason" to "java crash", "time" to crash.lastModified(), "trace" to crash.readText()))
            crash.delete()
        }
        prefs.edit().putLong(SEEN, newest).apply()
        return exits
    }

    /** The crashing thread's signal and stack from a native crash's tombstone (Android 12+). */
    private fun nativeTrace(info: android.app.ApplicationExitInfo): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return try {
            info.traceInputStream?.use { Tombstone.summary(it.readBytes()) }
        } catch (e: Exception) {
            "Tombstone unreadable: $e"
        }
    }

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitReason.EXIT_SELF -> "exit self"
        ApplicationExitReason.SIGNALED -> "signaled"
        ApplicationExitReason.LOW_MEMORY -> "low memory"
        ApplicationExitReason.CRASH -> "crash"
        ApplicationExitReason.CRASH_NATIVE -> "native crash"
        ApplicationExitReason.ANR -> "not responding"
        ApplicationExitReason.INITIALIZATION_FAILURE -> "initialization failure"
        ApplicationExitReason.PERMISSION_CHANGE -> "permission change"
        ApplicationExitReason.EXCESSIVE_RESOURCE_USAGE -> "excessive resource usage"
        ApplicationExitReason.USER_REQUESTED -> "user requested"
        ApplicationExitReason.USER_STOPPED -> "user stopped"
        ApplicationExitReason.DEPENDENCY_DIED -> "dependency died"
        ApplicationExitReason.OTHER -> "other"
        ApplicationExitReason.FREEZER -> "freezer"
        ApplicationExitReason.PACKAGE_STATE_CHANGE -> "package state change"
        ApplicationExitReason.PACKAGE_UPDATED -> "package updated"
        else -> "reason $reason"
    }
}

/** ApplicationExitInfo.REASON_* (constants, so they compile against any SDK level). */
private object ApplicationExitReason {
    const val EXIT_SELF = 1
    const val SIGNALED = 2
    const val LOW_MEMORY = 3
    const val CRASH = 4
    const val CRASH_NATIVE = 5
    const val ANR = 6
    const val INITIALIZATION_FAILURE = 7
    const val PERMISSION_CHANGE = 8
    const val EXCESSIVE_RESOURCE_USAGE = 9
    const val USER_REQUESTED = 10
    const val USER_STOPPED = 11
    const val DEPENDENCY_DIED = 12
    const val OTHER = 13
    const val FREEZER = 14
    const val PACKAGE_STATE_CHANGE = 15
    const val PACKAGE_UPDATED = 16
}

/**
 * Reads the parts of an Android tombstone (system/core/debuggerd/proto/tombstone.proto) that say where a
 * native crash happened: the signal, the abort message and the crashing thread's frames. A minimal
 * protobuf reader, so no library is needed.
 */
internal object Tombstone {
    private class Reader(val b: ByteArray, var i: Int = 0, val end: Int = b.size) {
        fun more() = i < end
        fun varint(): Long {
            var shift = 0
            var r = 0L
            while (true) {
                val x = b[i++].toInt() and 0xff
                r = r or ((x and 0x7f).toLong() shl shift)
                if (x and 0x80 == 0) return r
                shift += 7
            }
        }

        /** Calls [f] with each field number, wire type and (for length-delimited fields) a sub-reader. */
        fun fields(f: (Int, Int, Long, Reader?) -> Unit) {
            while (more()) {
                val key = varint()
                val field = (key ushr 3).toInt()
                when (val type = (key and 7).toInt()) {
                    0 -> f(field, type, varint(), null)
                    1 -> { i += 8; f(field, type, 0, null) }
                    5 -> { i += 4; f(field, type, 0, null) }
                    2 -> {
                        val len = varint().toInt()
                        val sub = Reader(b, i, i + len)
                        i += len
                        f(field, type, 0, sub)
                    }
                    else -> return
                }
            }
        }

        fun string() = String(b, i, end - i, Charsets.UTF_8)
    }

    fun summary(bytes: ByteArray): String {
        var tid = 0L
        var signal = ""
        var abort = ""
        val threads = mutableMapOf<Long, Pair<String, List<String>>>()
        val causes = mutableListOf<String>()
        Reader(bytes).fields { field, _, value, sub ->
            when (field) {
                15 -> sub?.let { causes.add(cause(it)) }
                6 -> tid = value
                10 -> sub?.let { s ->
                    var name = ""
                    var code = ""
                    s.fields { f, _, _, v -> if (f == 2) name = v!!.string() else if (f == 4) code = v!!.string() }
                    signal = "$name $code".trim()
                }
                14 -> abort = sub?.string() ?: ""
                16 -> sub?.let { entry ->
                    var key = 0L
                    var thread: Pair<String, List<String>>? = null
                    entry.fields { f, _, v, t -> if (f == 1) key = v else if (f == 2) thread = thread(t!!) }
                    thread?.let { threads[key] = it }
                }
            }
        }
        val (name, frames) = threads[tid] ?: ("?" to emptyList())
        return buildString {
            append("$signal in thread $name")
            if (abort.isNotEmpty()) append("\nAbort: ${abort.take(500)}")
            for (c in causes) append("\n$c")
            for ((n, frame) in frames.take(24).withIndex()) append("\n#${n.toString().padStart(2, '0')} $frame")
        }
    }

    /**
     * A cause found by GWP-ASan or MTE (enabled in the manifest): what went wrong and where the memory was
     * allocated and freed, which names the code that corrupted it.
     */
    private fun cause(r: Reader): String {
        var text = ""
        val alloc = mutableListOf<String>()
        val free = mutableListOf<String>()
        var size = 0L
        r.fields { f, _, _, sub ->
            when (f) {
                1 -> text = sub!!.string()
                2 -> sub!!.fields { g, _, _, error ->
                    if (g == 3) error!!.fields { h, _, v, frame ->
                        when (h) {
                            2 -> size = v
                            4 -> alloc.add(frame(frame!!))
                            6 -> free.add(frame(frame!!))
                        }
                    }
                }
            }
        }
        return buildString {
            append("Cause: $text")
            if (size > 0) append(" (object of $size bytes)")
            if (alloc.isNotEmpty()) append("\nAllocated at:")
            for ((n, f) in alloc.take(16).withIndex()) append("\n  #${n.toString().padStart(2, '0')} $f")
            if (free.isNotEmpty()) append("\nFreed at:")
            for ((n, f) in free.take(16).withIndex()) append("\n  #${n.toString().padStart(2, '0')} $f")
        }
    }

    private fun thread(r: Reader): Pair<String, List<String>> {
        var name = ""
        val frames = mutableListOf<String>()
        r.fields { f, _, _, sub ->
            when (f) {
                2 -> name = sub!!.string()
                4 -> frames.add(frame(sub!!))
            }
        }
        return name to frames
    }

    /** `pc 0007184c libc.so (abort+160)`: BacktraceFrame's relative pc, file and function. */
    private fun frame(r: Reader): String {
        var pc = 0L
        var function = ""
        var offset = 0L
        var file = ""
        r.fields { g, _, v, s ->
            when (g) {
                1 -> pc = v
                4 -> function = s!!.string()
                5 -> offset = v
                6 -> file = s!!.string().substringAfterLast('/')
            }
        }
        val fn = if (function.isEmpty()) "" else " ($function+$offset)"
        return "pc ${pc.toString(16).padStart(8, '0')} $file$fn"
    }
}
