package com.fguniversalempire.fgmaps.car

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Sebab senarai kereta kosong selain "tiada hasil": skrin kereta memaparkan mesej yang jujur. */
enum class CarFailure {
    /** Enjin Flutter sedang bermula (atau belum mendaftar saluran). */
    STARTING,

    /** Tiada lokasi GPS untuk "Berdekatan" atau asal laluan. */
    NO_LOCATION,

    /** Pelayan carian gagal atau tiada jawapan dalam masa. */
    FAILED,

    /** Tiada laluan ke destinasi (atau pelayan laluan gagal). */
    NO_ROUTE,
}

/**
 * Satu sesi antara Flutter dan Android Auto. Peta kereta tidak membuka GPS sendiri.
 *
 * Enjin Flutter ialah enjin dikongsi `audio_service` (sama dengan [com.fguniversalempire.fgmaps.MainActivity]).
 * Dahulu enjin hanya hidup bila app telefon dibuka: FGMaps yang dibuka terus dari skrin kereta (kes
 * biasa) mendapat peta kosong, dan carian/Berdekatan berkata "semak internet" walaupun internet ada,
 * kerana cubaan membuka app telefon dari latar dihalang Android 10+. Kini skrin kereta memulakan enjin
 * itu sendiri tanpa paparan ([ensureEngine]).
 */
object CarBridge {
    const val CHANNEL = "com.fguniversalempire.fgmaps/car"

    /** Had masa jawapan Dart untuk carian/Berdekatan (Dart sendiri berhenti selepas ~15 s). */
    private const val REPLY_TIMEOUT_MS = 25_000L

    @Volatile
    var ready: Boolean = false
        private set

    private var engine: FlutterEngine? = null
    private var appContext: Context? = null
    private val main = Handler(Looper.getMainLooper())

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

    /** Ujian sahaja: jawapan Dart palsu (nilai, atau [CarFailure] sebagai ralat), tanpa enjin Flutter. */
    @androidx.annotation.VisibleForTesting
    internal var testReplies: ((String, Any?) -> Any?)? = null

    /** Ujian sahaja: gambar sesi seperti yang dihantar Dart. */
    @androidx.annotation.VisibleForTesting
    internal fun setSessionForTest(map: Map<String, Any?>) {
        session = map
    }

    /**
     * Pastikan enjin Flutter berjalan untuk skrin kereta. Jika app telefon belum dibuka, enjin dikongsi
     * dimulakan tanpa paparan (main() Dart berjalan seperti biasa); app telefon yang dibuka kemudian
     * menggunakan enjin yang sama. Mesti dipanggil pada benang utama.
     */
    fun ensureEngine(context: Context) {
        appContext = context.applicationContext
        if (engine != null && channel != null) return
        try {
            attach(AudioServicePlugin.getFlutterEngine(context.applicationContext))
        } catch (_: Throwable) {
            // Enjin gagal dimulakan: skrin kereta kekal pada mesej "memulakan" dan cuba lagi kemudian.
        }
    }

    fun attach(flutterEngine: FlutterEngine) {
        if (flutterEngine === engine && channel != null) return
        engine = flutterEngine
        // Enjin dimusnahkan (cth. servis audio tamat tanpa app telefon): lupakan saluran lama supaya
        // panggilan seterusnya memulakan enjin baharu, bukan menunggu jawapan yang tidak akan tiba.
        flutterEngine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() {}

            override fun onEngineWillDestroy() {
                if (engine === flutterEngine) {
                    engine = null
                    channel = null
                    ready = false
                }
            }
        })
        val method = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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

    private fun carStateMap(): Map<String, Any?> =
        mapOf("visible" to carVisible, "dark" to carDark, "connected" to connected)

    /** Telefon bersambung dengan Android Auto (walaupun skrin FGMaps di kereta belum dibuka). */
    @Volatile
    var connected: Boolean = false
        private set

    private var watching = false

    /**
     * Pantau sambungan Android Auto. Bila bersambung, Dart menghidupkan perkhidmatan muzik supaya
     * bahagian media FGMaps di kereta terus ada senarai lagu dan radio. Mesti dipanggil pada benang utama.
     */
    fun watchConnection(context: Context) {
        if (watching) return
        watching = true
        try {
            androidx.car.app.connection.CarConnection(context.applicationContext).type
                .observeForever { type ->
                    val now = type == androidx.car.app.connection.CarConnection.CONNECTION_TYPE_PROJECTION
                    if (now == connected) return@observeForever
                    connected = now
                    try {
                        channel?.invokeMethod("carState", carStateMap())
                    } catch (_: Throwable) {
                    }
                }
        } catch (_: Throwable) {
            watching = false
        }
    }

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

    fun search(query: String, callback: (List<CarPlace>, CarFailure?) -> Unit) {
        places("search", mapOf("query" to query), callback)
    }

    /** Senarai kategori "Berdekatan" (id + nama dalam bahasa peranti), tersusun ikut keperluan pemandu. */
    fun categories(callback: (List<CarCategory>, CarFailure?) -> Unit) {
        call("nearbyCategories", null, callback) { result -> parseCategories(result) }
    }

    /** Tempat terdekat bagi satu kategori; `subtitle` sudah mengandungi jarak dan kawasan. */
    fun nearby(categoryId: String, callback: (List<CarPlace>, CarFailure?) -> Unit) {
        places("nearby", mapOf("category" to categoryId), callback)
    }

    private fun places(
        method: String,
        arguments: Map<String, Any?>,
        callback: (List<CarPlace>, CarFailure?) -> Unit,
    ) {
        call(method, arguments, callback) { result -> parsePlaces(result) }
    }

    private fun parsePlaces(result: Any?): List<CarPlace> =
        (result as? List<*> ?: emptyList<Any>()).mapNotNull { parsePlace(it) }

    private fun parsePlace(row: Any?): CarPlace? {
        val map = row as? Map<*, *> ?: return null
        val lat = (map["lat"] as? Number)?.toDouble() ?: return null
        val lng = (map["lng"] as? Number)?.toDouble() ?: return null
        return CarPlace(
            name = map["name"]?.toString().orEmpty(),
            subtitle = map["subtitle"]?.toString().orEmpty(),
            lat = lat,
            lng = lng,
            meters = (map["meters"] as? Number)?.toDouble(),
            area = map["area"]?.toString().orEmpty(),
        )
    }

    /** Hab "Tempat": Rumah, Kerja, kegemaran dan terkini (null bila enjin belum sedia / gagal). */
    fun placesHub(callback: (CarPlacesHub?, CarFailure?) -> Unit) {
        callAny("places", null) { result, failure ->
            val map = result as? Map<*, *>
            if (map == null) {
                callback(null, failure ?: CarFailure.FAILED)
                return@callAny
            }
            callback(
                CarPlacesHub(
                    home = parsePlace(map["home"]),
                    work = parsePlace(map["work"]),
                    favorites = parsePlaces(map["favorites"]),
                    recents = parsePlaces(map["recents"]),
                ),
                null,
            )
        }
    }

    /** Pilihan laluan ke [place] (paling banyak 3), dengan masa, jarak, tol dan garisan untuk peta. */
    fun preview(place: CarPlace, callback: (List<CarRoute>, CarFailure?) -> Unit) {
        call("preview", placeArgs(place), callback) { result ->
            (result as? List<*> ?: emptyList<Any>()).mapNotNull { row ->
                val map = row as? Map<*, *> ?: return@mapNotNull null
                val points = (map["points"] as? List<*>).orEmpty().mapNotNull { pair ->
                    val p = pair as? List<*> ?: return@mapNotNull null
                    val lat = (p.getOrNull(0) as? Number)?.toDouble() ?: return@mapNotNull null
                    val lng = (p.getOrNull(1) as? Number)?.toDouble() ?: return@mapNotNull null
                    doubleArrayOf(lat, lng)
                }
                CarRoute(
                    durationS = (map["durationS"] as? Number)?.toLong() ?: return@mapNotNull null,
                    distanceM = (map["distanceM"] as? Number)?.toDouble() ?: 0.0,
                    title = map["title"]?.toString().orEmpty(),
                    detail = map["detail"]?.toString().orEmpty(),
                    points = points,
                )
            }
        }
    }

    /** Mula navigasi dengan pilihan [index] daripada pratonton terakhir; null = berjaya. */
    fun startPreview(index: Int, callback: (String?) -> Unit) {
        callAny("startPreview", mapOf("index" to index)) { result, failure ->
            callback(if (failure != null) "unavailable" else result as? String)
        }
    }

    fun reportTypes(callback: (List<CarCategory>, CarFailure?) -> Unit) {
        call("reportTypes", null, callback) { result -> parseCategories(result) }
    }

    /** Hantar laporan; jawapan `created`, `confirmed`, `no-location` atau `failed`. */
    fun report(typeId: String, callback: (String) -> Unit) {
        callAny("report", mapOf("type" to typeId)) { result, failure ->
            callback(
                when (failure) {
                    null -> result as? String ?: "failed"
                    CarFailure.NO_LOCATION -> "no-location"
                    else -> "failed"
                },
            )
        }
    }

    fun settings(callback: (Map<String, Boolean>?) -> Unit) {
        callAny("settings", null) { result, _ -> callback(parseSettings(result)) }
    }

    fun setSetting(key: String, value: Boolean, callback: (Map<String, Boolean>?) -> Unit) {
        callAny("setSetting", mapOf("key" to key, "value" to value)) { result, _ ->
            callback(parseSettings(result))
        }
    }

    private fun parseSettings(result: Any?): Map<String, Boolean>? {
        val map = result as? Map<*, *> ?: return null
        return map.entries.mapNotNull { (k, v) ->
            val key = k?.toString() ?: return@mapNotNull null
            (v as? Boolean)?.let { key to it }
        }.toMap()
    }

    /** Bahagian media Android Auto dibuka: mulakan perkhidmatan audio Dart (senarai lagu dan radio). */
    fun mediaBrowserConnected(context: Context) {
        ensureEngine(context)
        callAny("mediaBrowser", null) { _, failure ->
            // Enjin masih bermula: cuba sekali lagi supaya senarai media tidak kekal kosong.
            if (failure == CarFailure.STARTING) {
                main.postDelayed({ callAny("mediaBrowser", null) { _, _ -> } }, 2_000L)
            }
        }
    }

    private fun parseCategories(result: Any?): List<CarCategory> =
        (result as? List<*> ?: emptyList<Any>()).mapNotNull { row ->
            val map = row as? Map<*, *> ?: return@mapNotNull null
            val id = map["id"]?.toString() ?: return@mapNotNull null
            CarCategory(id = id, label = map["label"]?.toString().orEmpty())
        }

    private fun placeArgs(place: CarPlace): Map<String, Any?> = mapOf(
        "name" to place.name,
        "subtitle" to place.subtitle,
        "lat" to place.lat,
        "lng" to place.lng,
    )

    /** Satu panggilan Dart dengan senarai sebagai jawapan (lihat [callAny]). */
    private fun <T> call(
        method: String,
        arguments: Any?,
        callback: (List<T>, CarFailure?) -> Unit,
        parse: (Any?) -> List<T>,
    ) {
        callAny(method, arguments) { result, failure ->
            if (failure != null) {
                callback(emptyList(), failure)
                return@callAny
            }
            val rows = try {
                parse(result)
            } catch (_: Throwable) {
                emptyList()
            }
            callback(rows, null)
        }
    }

    /**
     * Satu panggilan Dart. [callback] dipanggil tepat sekali: jawapan, atau null bersama sebabnya
     * (enjin bermula, tiada lokasi, tiada laluan, gagal / tamat masa).
     */
    private fun callAny(
        method: String,
        arguments: Any?,
        callback: (Any?, CarFailure?) -> Unit,
    ) {
        testReplies?.let { reply ->
            val result = reply(method, arguments)
            if (result is CarFailure) callback(null, result) else callback(result, null)
            return
        }
        val ch = channel ?: run {
            appContext?.let { ensureEngine(it) }
            callback(null, CarFailure.STARTING)
            return
        }
        var done = false
        fun finish(result: Any?, failure: CarFailure?) {
            if (done) return
            done = true
            try {
                callback(result, failure)
            } catch (_: Throwable) {
                // Ralat skrin kereta tidak boleh menjatuhkan app telefon.
            }
        }
        val timeout = Runnable { finish(null, CarFailure.FAILED) }
        main.postDelayed(timeout, REPLY_TIMEOUT_MS)
        try {
            ch.invokeMethod(method, arguments, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    main.removeCallbacks(timeout)
                    finish(result, null)
                }

                override fun error(code: String, message: String?, details: Any?) {
                    main.removeCallbacks(timeout)
                    finish(
                        null,
                        when (code) {
                            "no-location" -> CarFailure.NO_LOCATION
                            "no-route" -> CarFailure.NO_ROUTE
                            else -> CarFailure.FAILED
                        },
                    )
                }

                // Dart belum mendaftar pengendali (main() masih memuatkan): enjin sedang bermula.
                override fun notImplemented() {
                    main.removeCallbacks(timeout)
                    finish(null, CarFailure.STARTING)
                }
            })
        } catch (_: Throwable) {
            main.removeCallbacks(timeout)
            finish(null, CarFailure.FAILED)
        }
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
}

data class CarPlace(
    val name: String,
    val subtitle: String,
    val lat: Double,
    val lng: Double,
    /** Jarak dari pengguna (null bila lokasi tidak diketahui). */
    val meters: Double? = null,
    /** Kawasan sahaja (tanpa jarak), untuk baris yang jaraknya dipaparkan sebagai span jarak hos. */
    val area: String = "",
)

data class CarPlacesHub(
    val home: CarPlace?,
    val work: CarPlace?,
    val favorites: List<CarPlace>,
    val recents: List<CarPlace>,
)

/** Satu pilihan laluan untuk pratonton kereta. [points]: pasangan [lat, lng]. */
data class CarRoute(
    val durationS: Long,
    val distanceM: Double,
    val title: String,
    val detail: String,
    val points: List<DoubleArray>,
)

data class CarCategory(
    val id: String,
    val label: String,
)
