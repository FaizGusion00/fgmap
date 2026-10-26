package com.fguniversal.fgmap_valhalla

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.valhalla.valhalla.Valhalla
import com.valhalla.valhalla.config.ValhallaConfigFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.concurrent.Executors

/**
 * Jambatan nipis ke enjin Valhalla dalam peranti (valhalla-mobile).
 *
 * Kontrak sengaja minimum dan bebas platform: Dart menghantar permintaan Valhalla sebagai JSON dan
 * menerima respons JSON mentah, sama seperti ketika memanggil API Valhalla awam. Dengan itu satu
 * penghurai Dart digunakan untuk laluan online dan offline.
 *
 * - `open(tarPath)`  buka enjin pada tile extract (.tar). Menggantikan enjin sebelumnya.
 * - `route(json)`    kira laluan; memulangkan JSON respons Valhalla.
 * - `traceAttributes(json)` atribut tepi jalan sepanjang jejak (cth. had laju); JSON mentah.
 * - `close()`        lepaskan enjin (mmap tile). Mesti dipanggil sebelum fail tile diganti atau dipadam.
 */
class FgmapValhallaPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    // Satu thread: Valhalla menyirikan permintaan pada satu instance, dan kita tidak mahu
    // open/close berlumba dengan route yang sedang berjalan.
    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "fgmap-valhalla") }
    private val main = Handler(Looper.getMainLooper())

    // Hanya diakses dari `worker`.
    private var engine: Valhalla? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "fgmap_valhalla")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "open" -> {
                val path = call.argument<String>("tarPath")
                if (path == null) {
                    result.error("bad_args", "tarPath is required", null)
                    return
                }
                runAsync(result) { open(path) }
            }
            "route" -> {
                val json = call.argument<String>("request")
                if (json == null) {
                    result.error("bad_args", "request is required", null)
                    return
                }
                runAsync(result) { route(json) }
            }
            "traceAttributes" -> {
                val json = call.argument<String>("request")
                if (json == null) {
                    result.error("bad_args", "request is required", null)
                    return
                }
                runAsync(result) { traceAttributes(json) }
            }
            "close" -> runAsync(result) { closeEngine(); null }
            else -> result.notImplemented()
        }
    }

    private fun open(tarPath: String): Any? {
        val file = File(tarPath)
        if (!file.isFile || file.length() == 0L) {
            throw EngineException("tiles_missing", "Tile file not found or empty: $tarPath")
        }
        closeEngine()
        try {
            engine = Valhalla(appContext, ValhallaConfigFactory.usingTileExtract(tarPath))
        } catch (e: Exception) {
            throw EngineException("open_failed", "${e.javaClass.simpleName}: ${e.message}")
        }
        return null
    }

    private fun route(requestJson: String): Any? {
        val v = engine ?: throw EngineException("not_open", "Offline engine is not open")
        try {
            return v.routeRaw(requestJson)
        } catch (e: Exception) {
            // Mesej valhalla-mobile membawa JSON ralat Valhalla (error_code); Dart menghuraikannya.
            throw EngineException("route_failed", "${e.javaClass.simpleName}: ${e.message}")
        }
    }

    private fun traceAttributes(requestJson: String): Any? {
        val v = engine ?: throw EngineException("not_open", "Offline engine is not open")
        try {
            return v.traceAttributesRaw(requestJson)
        } catch (e: Exception) {
            throw EngineException("route_failed", "${e.javaClass.simpleName}: ${e.message}")
        }
    }

    private fun closeEngine() {
        engine?.close()
        engine = null
    }

    private class EngineException(val code: String, message: String) : Exception(message)

    private fun runAsync(result: Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: EngineException) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: Throwable) {
                main.post { result.error("internal", "${e.javaClass.simpleName}: ${e.message}", null) }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker.execute { closeEngine() }
        worker.shutdown()
    }
}
