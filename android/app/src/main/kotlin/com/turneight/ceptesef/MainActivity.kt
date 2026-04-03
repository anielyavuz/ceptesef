package com.turneight.ceptesef

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val SHARE_CHANNEL = "com.turneight.ceptesef/share"
    private var pendingSharedItems: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Uygulama başlarken intent kontrol et
        handleIncomingIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedItems" -> {
                        result.success(pendingSharedItems)
                    }
                    "clearSharedItems" -> {
                        pendingSharedItems = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("image/") == true) {
                    val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    if (uri != null) {
                        val path = copyToCache(uri)
                        if (path != null) {
                            pendingSharedItems = """[{"type":"image","path":"$path"}]"""
                        }
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                if (intent.type?.startsWith("image/") == true) {
                    val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    if (uris != null && uris.isNotEmpty()) {
                        val uri = uris[0] // İlk görseli al
                        val path = copyToCache(uri)
                        if (path != null) {
                            pendingSharedItems = """[{"type":"image","path":"$path"}]"""
                        }
                    }
                }
            }
        }
    }

    /**
     * Content URI'dan dosyayı cache dizinine kopyala ve dosya yolunu döndür.
     */
    private fun copyToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val ext = getFileExtension(uri)
            val file = File(cacheDir, "shared_${System.currentTimeMillis()}.$ext")
            FileOutputStream(file).use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()
            file.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun getFileExtension(uri: Uri): String {
        val mimeType = contentResolver.getType(uri) ?: return "jpg"
        return when {
            mimeType.contains("png") -> "png"
            mimeType.contains("webp") -> "webp"
            mimeType.contains("gif") -> "gif"
            else -> "jpg"
        }
    }
}
