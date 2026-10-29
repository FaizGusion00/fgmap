package com.fguniversalempire.fgmaps.car

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Satu sesi antara Flutter dan Android Auto. Peta kereta tidak membuka GPS sendiri.
 */
object CarBridge {
    const val CHANNEL = "com.fguniversalempire.fgmaps/car"

    @Volatile
    var ready: Boolean = false
        private set

    @Volatile
    var session: Map<String, Any?> = emptyMap()
        private set

    var onSession: ((Map<String, Any?>) -> Unit)? = null

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        val method = MethodChannel(messenger, CHANNEL)
        channel = method
        ready = true
        method.setMethodCallHandler { call, result ->
            if (call.method == "session") {
                @Suppress("UNCHECKED_CAST")
                val map = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                session = map
                onSession?.invoke(map)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    fun search(query: String, callback: (List<CarPlace>) -> Unit) {
        val ch = channel
        if (ch == null) {
            callback(emptyList())
            return
        }
        ch.invokeMethod("search", mapOf("query" to query), object : MethodChannel.Result {
            override fun success(result: Any?) {
                val rows = result as? List<*> ?: emptyList<Any>()
                callback(rows.mapNotNull { row ->
                    val map = row as? Map<*, *> ?: return@mapNotNull null
                    val lat = (map["lat"] as? Number)?.toDouble() ?: return@mapNotNull null
                    val lng = (map["lng"] as? Number)?.toDouble() ?: return@mapNotNull null
                    CarPlace(
                        name = map["name"]?.toString().orEmpty(),
                        subtitle = map["subtitle"]?.toString().orEmpty(),
                        lat = lat,
                        lng = lng,
                    )
                })
            }

            override fun error(code: String, message: String?, details: Any?) {
                callback(emptyList())
            }

            override fun notImplemented() {
                callback(emptyList())
            }
        })
    }

    fun openPlace(place: CarPlace, callback: (String?) -> Unit) {
        channel?.invokeMethod(
            "openPlace",
            mapOf(
                "name" to place.name,
                "subtitle" to place.subtitle,
                "lat" to place.lat,
                "lng" to place.lng,
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) = callback(result as? String)
                override fun error(code: String, message: String?, details: Any?) =
                    callback(message ?: code)

                override fun notImplemented() = callback("unavailable")
            },
        ) ?: callback("unavailable")
    }

    fun endNavigation() {
        channel?.invokeMethod("endNavigation", null)
    }

    fun recenter() {
        channel?.invokeMethod("recenter", null)
    }

    fun pan() {
        channel?.invokeMethod("pan", null)
    }

    fun launchPhone(context: android.content.Context) {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launch)
    }
}

data class CarPlace(
    val name: String,
    val subtitle: String,
    val lat: Double,
    val lng: Double,
)
