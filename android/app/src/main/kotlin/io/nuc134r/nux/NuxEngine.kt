package io.nuc134r.nux

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The one Flutter engine of the app, created on the application context and kept in
 * [FlutterEngineCache] so that it is not tied to [MainActivity]: Dart (and with it every SSH connection,
 * port forward and the ZeroTier node) keeps running when the activity is gone. It lives as long as the
 * process; the background service keeps the process alive while something is connected.
 */
object NuxEngine {
    const val ID = "nux_engine"

    @Synchronized
    fun get(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        // Plugins register themselves (GeneratedPluginRegistrant); activity-bound ones attach when an
        // activity uses the engine and detach when it goes.
        val engine = FlutterEngine(context.applicationContext)
        engine.navigationChannel.setInitialRoute("/")
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine
    }
}
