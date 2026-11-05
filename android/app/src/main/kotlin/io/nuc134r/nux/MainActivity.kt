package io.nuc134r.nux

import android.content.Context
import android.content.Intent
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
        ContentChannel.attach(NuxEngine.get(this), this) // the engine exists before super.onCreate looks it up
        super.onCreate(savedInstanceState)
        current = this
        // "Open with" / "Share to" nux (not when the activity is only being recreated).
        if (savedInstanceState == null) ContentChannel.onIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ContentChannel.onIntent(intent)
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (ContentChannel.onActivityResult(requestCode, resultCode, data)) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        /** The activity on screen, for pickers that need one. */
        var current: MainActivity? = null
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine = NuxEngine.get(context)

    override fun getCachedEngineId(): String {
        NuxEngine.get(this)
        return NuxEngine.ID
    }

    // The engine outlives the screen; see NuxEngine.
    override fun shouldDestroyEngineWithHost(): Boolean = false
}
