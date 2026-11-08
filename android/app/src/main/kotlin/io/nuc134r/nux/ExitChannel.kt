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
    private const val SEEN = "seen"
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
