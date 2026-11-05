package io.nuc134r.nux

import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Files from other apps, by content URI: "Open with nux" (VIEW / EDIT), "Share to nux" (SEND), and folders
 * picked with the system picker (for uploading a whole folder). Dart reads and writes them through this
 * channel; nothing is copied unless Dart asks.
 */
object ContentChannel {
    private const val CHANNEL = "nux/content"
    const val PICK_TREE = 4711

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Intents that arrived before Dart asked for them. */
    private val pending = mutableListOf<Map<String, Any?>>()
    private var channel: MethodChannel? = null
    private lateinit var resolver: ContentResolver

    private val streams = mutableMapOf<Int, InputStream>()
    private var nextStream = 1
    private var pickResult: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine, context: Context) {
        resolver = context.applicationContext.contentResolver
        if (channel != null) return
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result -> handle(call, result) }
        }
    }

    /** Remembers [intent] when it brings files or text, and tells Dart. */
    fun onIntent(intent: Intent?) {
        if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val action = when (intent.action) {
            Intent.ACTION_VIEW -> "view"
            Intent.ACTION_EDIT -> "edit"
            Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> "send"
            else -> return
        }
        val uris = mutableListOf<Uri>()
        if (action == "send") {
            @Suppress("DEPRECATION")
            if (intent.action == Intent.ACTION_SEND) {
                (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uris.add(it) }
            } else {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
            }
        } else {
            intent.data?.let { uris.add(it) }
        }
        val text = if (action == "send") intent.getStringExtra(Intent.EXTRA_TEXT) else null
        if (uris.isEmpty() && text == null) return
        val writable = intent.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION != 0 || action == "edit"
        io.execute {
            val items = uris.map { describe(it) }
            main.post {
                pending.add(mapOf("action" to action, "items" to items, "text" to text, "writable" to writable))
                channel?.invokeMethod("incoming", null)
            }
        }
        // Handled: a later activity restart must not bring it again.
        intent.action = null
    }

    private fun describe(uri: Uri): Map<String, Any?> {
        var name: String? = null
        var size: Long = -1
        try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
                if (it.moveToFirst()) {
                    val n = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = it.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0 && !it.isNull(n)) name = it.getString(n)
                    if (s >= 0 && !it.isNull(s)) size = it.getLong(s)
                }
            }
        } catch (_: Exception) {
        }
        return mapOf(
            "uri" to uri.toString(),
            "name" to (name ?: uri.lastPathSegment?.substringAfterLast('/') ?: "file"),
            "size" to size,
            "mime" to resolver.getType(uri),
        )
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_TREE) return false
        val result = pickResult ?: return true
        pickResult = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        io.execute {
            try {
                val files = mutableListOf<Map<String, Any?>>()
                val rootId = DocumentsContract.getTreeDocumentId(tree)
                val rootName = describe(DocumentsContract.buildDocumentUriUsingTree(tree, rootId))["name"] as String
                walk(tree, rootId, rootName, files)
                main.post { result.success(mapOf("name" to rootName, "files" to files)) }
            } catch (e: Exception) {
                main.post { result.error("pick", e.toString(), null) }
            }
        }
        return true
    }

    /** Files under the document [id] of [tree], with paths relative to the tree's parent. */
    private fun walk(tree: Uri, id: String, path: String, out: MutableList<Map<String, Any?>>) {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        resolver.query(children, columns, null, null, null)?.use {
            while (it.moveToNext()) {
                val childId = it.getString(0)
                val name = it.getString(1)
                val mime = it.getString(2)
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    walk(tree, childId, "$path/$name", out)
                } else {
                    out.add(
                        mapOf(
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, childId).toString(),
                            "name" to "$path/$name",
                            "size" to (if (it.isNull(3)) -1L else it.getLong(3)),
                            "mime" to mime,
                        ),
                    )
                }
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "take" -> {
                result.success(pending.toList())
                pending.clear()
            }
            "pickTree" -> {
                val activity = MainActivity.current
                if (activity == null || pickResult != null) {
                    result.success(null)
                    return
                }
                pickResult = result
                @Suppress("DEPRECATION")
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_TREE)
            }
            else -> io.execute {
                try {
                    val value = blocking(call)
                    main.post { result.success(value) }
                } catch (e: SecurityException) {
                    main.post { result.error("denied", e.toString(), null) }
                } catch (e: Exception) {
                    main.post { result.error("io", e.toString(), null) }
                }
            }
        }
    }

    private fun blocking(call: MethodCall): Any? {
        val uri = call.argument<String>("uri")?.let { Uri.parse(it) }
        return when (call.method) {
            "stat" -> describe(uri!!)
            "read" -> resolver.openInputStream(uri!!)!!.use { it.readBytes() }
            "write" -> {
                val bytes = call.argument<ByteArray>("bytes")!!
                // "wt" truncates; some providers only know "w".
                val out = try {
                    resolver.openOutputStream(uri!!, "wt")
                } catch (_: Exception) {
                    resolver.openOutputStream(uri!!, "w")
                }
                out!!.use { it.write(bytes) }
                null
            }
            "open" -> {
                val stream = resolver.openInputStream(uri!!)!!
                val start = (call.argument<Number>("start") ?: 0).toLong()
                var skipped = 0L
                while (skipped < start) {
                    val n = stream.skip(start - skipped)
                    if (n <= 0) break
                    skipped += n
                }
                val id = nextStream++
                synchronized(streams) { streams[id] = stream }
                id
            }
            "next" -> {
                val id = call.argument<Int>("id")!!
                val stream = synchronized(streams) { streams[id] } ?: return null
                val buffer = ByteArray(256 * 1024)
                val n = stream.read(buffer)
                if (n < 0) null else buffer.copyOf(n)
            }
            "close" -> {
                val id = call.argument<Int>("id")!!
                synchronized(streams) { streams.remove(id) }?.close()
                null
            }
            else -> throw IllegalArgumentException("unknown method ${call.method}")
        }
    }
}
