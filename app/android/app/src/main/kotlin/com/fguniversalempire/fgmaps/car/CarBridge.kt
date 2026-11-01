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

    /** Permukaan peta kereta sedang dipaparkan, dan mod malam kereta ([CarContext.isDarkMode]). */
    @Volatile
    var carVisible: Boolean = false
        private set

    @Volatile
    var carDark: Boolean = false
        private set

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        val method = MethodChannel(messenger, CHANNEL)
        channel = method
        ready = true
        method.setMethodCallHandler { call, result ->
            when (call.method) {
                "session" -> {
                    @Suppress("UNCHECKED_CAST")
                    val incoming = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                    val map = withStickyKeys(incoming, session)
                    session = map
                    // Ralat skrin kereta tidak boleh menjatuhkan app telefon (benang utama).
                    try {
                        onSession?.invoke(map)
                    } catch (_: Throwable) {
                    }
                    result.success(null)
                }
                // Dart bertanya keadaan semasa (enjin Flutter boleh bermula selepas kereta bersambung).
                "carState" -> result.success(carStateMap())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Lapor keterlihatan permukaan dan mod malam kereta kepada Dart: pam kamera kereta hanya berjalan
     * bila skrin kereta kelihatan, dan gaya peta mengikut siang/malam kereta.
     */
    fun reportCar(visible: Boolean = carVisible, dark: Boolean = carDark) {
        if (visible == carVisible && dark == carDark) return
        carVisible = visible
        carDark = dark
        try {
            channel?.invokeMethod("carState", carStateMap())
        } catch (_: Throwable) {
        }
    }

    private fun carStateMap(): Map<String, Any?> = mapOf("visible" to carVisible, "dark" to carDark)

    /**
     * Dart menghantar geometri laluan dan badan gaya hanya bila berubah. Salinan terakhir dibawa ke
     * hadapan supaya [session] sentiasa lengkap: permukaan kereta yang dicipta semula (skrin kereta
     * dimatikan/dihidupkan, tukar app di kepala unit) atau gaya yang dimuat semula (siang/malam)
     * dahulu kehilangan garisan laluan, malah peta kosong, sehingga laluan atau gaya berubah lagi.
     */
    internal fun withStickyKeys(
        incoming: Map<String, Any?>,
        previous: Map<String, Any?>,
    ): Map<String, Any?> {
        val keepRoute = !incoming.containsKey("route") &&
            previous.containsKey("route") &&
            incoming["routeVersion"] == previous["routeVersion"]
        val keepStyle = !incoming.containsKey("style") &&
            previous.containsKey("style") &&
            incoming["styleKey"] == previous["styleKey"]
        if (!keepRoute && !keepStyle) return incoming
        val merged = HashMap(incoming)
        if (keepRoute) merged["route"] = previous["route"]
        if (keepStyle) merged["style"] = previous["style"]
        return merged
    }

    fun search(query: String, callback: (List<CarPlace>) -> Unit) {
        places("search", mapOf("query" to query), callback)
    }

    /** Senarai kategori "Berdekatan" (id + nama dalam bahasa peranti), tersusun ikut keperluan pemandu. */
    fun categories(callback: (List<CarCategory>) -> Unit) {
        val ch = channel
        if (ch == null) {
            callback(emptyList())
            return
        }
        ch.invokeMethod("nearbyCategories", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val rows = result as? List<*> ?: emptyList<Any>()
                callback(rows.mapNotNull { row ->
                    val map = row as? Map<*, *> ?: return@mapNotNull null
                    val id = map["id"]?.toString() ?: return@mapNotNull null
                    CarCategory(id = id, label = map["label"]?.toString().orEmpty())
                })
            }

            override fun error(code: String, message: String?, details: Any?) = callback(emptyList())

            override fun notImplemented() = callback(emptyList())
        })
    }

    /** Tempat terdekat bagi satu kategori; `subtitle` sudah mengandungi jarak dan kawasan. */
    fun nearby(categoryId: String, callback: (List<CarPlace>) -> Unit) {
        places("nearby", mapOf("category" to categoryId), callback)
    }

    private fun places(
        method: String,
        arguments: Map<String, Any?>,
        callback: (List<CarPlace>) -> Unit,
    ) {
        val ch = channel
        if (ch == null) {
            callback(emptyList())
            return
        }
        ch.invokeMethod(method, arguments, object : MethodChannel.Result {
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

data class CarCategory(
    val id: String,
    val label: String,
)
