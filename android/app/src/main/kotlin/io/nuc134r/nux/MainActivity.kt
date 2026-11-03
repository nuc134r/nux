package io.nuc134r.nux

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity: local_auth (device unlock before using a protected key) needs a FragmentActivity.
//
// The screen borrows the app-wide engine (NuxEngine) instead of owning one: closing nux from the recent
// apps destroys this activity, not the engine, so terminals, file browsers and forwards keep running while
// the background service keeps the process alive. Opening nux again attaches to the same engine, with
// every tab as it was. (The pattern audio_service uses for background playback.)
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        NuxEngine.get(this) // exists before super.onCreate looks it up by id
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine = NuxEngine.get(context)

    override fun getCachedEngineId(): String {
        NuxEngine.get(this)
        return NuxEngine.ID
    }

    // The engine outlives the screen; see NuxEngine.
    override fun shouldDestroyEngineWithHost(): Boolean = false
}
