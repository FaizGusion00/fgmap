package com.fguniversalempire.fg_device_music

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * Jambatan senarai lagu pada peranti (MediaStore). Saluran `fgmaps/device_music`:
 * `access` | `request` -> "unsupported" | "notDetermined" | "denied" | "authorized";
 * `list` -> senarai {id, title, artist?, durationMs, uri}. Hanya metadata dibaca; URI `content://`
 * dimain terus oleh pemain audio. Kebenaran tidak pernah diminta tanpa panggilan `request`.
 */
class FgDeviceMusicPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: Result? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val permission: String
        get() =
            if (Build.VERSION.SDK_INT >= 33) {
                "android.permission.READ_MEDIA_AUDIO"
            } else {
                "android.permission.READ_EXTERNAL_STORAGE"
            }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "fgmaps/device_music")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detach()

    private fun detach() {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
    }

    private fun prefs() =
        context?.getSharedPreferences("fg_device_music", Context.MODE_PRIVATE)

    private fun access(): String {
        val ctx = context ?: return "unsupported"
        if (ctx.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            return "authorized"
        }
        if (prefs()?.getBoolean("asked", false) != true) return "notDetermined"
        // Ditolak sekali: Android masih menunjukkan dialog sekali lagi (rasional). Selepas itu
        // ("Jangan tanya lagi") kebenaran hanya boleh diubah dalam Tetapan.
        val canAskAgain = activity?.shouldShowRequestPermissionRationale(permission) ?: false
        return if (canAskAgain) "notDetermined" else "denied"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "access" -> result.success(access())
            "request" -> request(result)
            "list" -> list(result)
            else -> result.notImplemented()
        }
    }

    private fun request(result: Result) {
        if (access() == "authorized") {
            result.success("authorized")
            return
        }
        val act = activity
        if (act == null || pending != null) {
            result.error("no_activity", "Tiada aktiviti untuk meminta kebenaran", null)
            return
        }
        pending = result
        act.requestPermissions(arrayOf(permission), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        prefs()?.edit()?.putBoolean("asked", true)?.apply()
        pending?.success(access())
        pending = null
        return true
    }

    private fun list(result: Result) {
        val ctx = context
        if (ctx == null) {
            result.error("no_context", "Konteks tiada", null)
            return
        }
        executor.execute {
            try {
                val songs = querySongs(ctx)
                main.post { result.success(songs) }
            } catch (e: SecurityException) {
                main.post { result.error("denied", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("list_failed", e.message, null) }
            }
        }
    }

    private fun querySongs(ctx: Context): List<Map<String, Any>> {
        val base = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection =
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.DURATION,
            )
        // Muzik sahaja (bukan nada dering/pemberitahuan) dan sekurang-kurangnya 30 saat.
        val selection =
            "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= 30000"
        val order = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        val out = ArrayList<Map<String, Any>>()
        ctx.contentResolver.query(base, projection, selection, null, order)?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                val song =
                    hashMapOf<String, Any>(
                        "id" to id.toString(),
                        "title" to (c.getString(titleCol) ?: "").ifBlank { "Tanpa tajuk" },
                        "durationMs" to c.getLong(durCol),
                        "uri" to ContentUris.withAppendedId(base, id).toString(),
                    )
                val artist = c.getString(artistCol)
                if (!artist.isNullOrBlank() && artist != MediaStore.UNKNOWN_STRING) {
                    song["artist"] = artist
                }
                out.add(song)
            }
        }
        return out
    }

    private companion object {
        const val REQUEST_CODE = 0x46474d // "FGM"
    }
}
