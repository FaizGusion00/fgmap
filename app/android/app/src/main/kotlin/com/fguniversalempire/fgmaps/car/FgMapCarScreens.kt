package com.fguniversalempire.fgmaps.car

import android.content.Intent
import android.content.res.Configuration
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.constraints.ConstraintManager
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Alert
import androidx.car.app.model.AlertCallback
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarText
import androidx.car.app.model.Distance
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.NavigationManager
import androidx.car.app.navigation.NavigationManagerCallback
import androidx.car.app.navigation.model.MessageInfo
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.car.app.model.SearchTemplate
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.fguniversalempire.fgmaps.R

class FgMapSession : Session() {
    /** Siang/malam kereta (lampu atau penderia hos) bertukar: peta kereta menukar gaya. */
    override fun onCarConfigurationChanged(newConfiguration: Configuration) {
        try {
            CarBridge.reportCar(dark = carContext.isDarkMode)
        } catch (_: Throwable) {
        }
    }

    override fun onCreateScreen(intent: Intent): Screen {
        // Ikatan penemuan tidak boleh melempar: Android Auto membuang aplikasi dari pelancar.
        return try {
            if (!CarBridge.ready) {
                try {
                    CarBridge.launchPhone(carContext)
                } catch (_: Throwable) {
                }
            }
            FgMapNavScreen(carContext)
        } catch (_: Throwable) {
            FgMapNavScreen(carContext, attachMap = false)
        }
    }
}

/**
 * Templat navigasi padat: manuver dan ETA di slot templat, peta MapLibre pada permukaan,
 * tindakan terhad kepada carian, pusatkan, dan tamat.
 *
 * Isyarat pemanduan (kamera > cuaca > R&R) sentiasa menjadi cue pada langkah
 * (Car API 1). API 5+ menambah Alert berasingan. AQI hanya dalam mod browse.
 */
class FgMapNavScreen(
    carContext: CarContext,
    attachMap: Boolean = true,
) : Screen(carContext) {
    private val surface = CarMapSurface(carContext)
    private var lastAlertText: String? = null
    private var alertShowing = false

    /** Kandungan templat terakhir; templat hanya dibina semula bila ia berubah (bukan setiap pose). */
    private var templateKey: List<Any?>? = null

    /** Imej lorong dilukis sekali bagi setiap set lorong (bukan setiap kemas kini templat). */
    private var lanesKey: Any? = null
    private var lanesIcon: CarIcon? = null

    /** Hos tahu navigasi sedang berjalan (kluster, HUD, app navigasi lain menghentikan kita). */
    private var navigationStarted = false
    private val navigation: NavigationManager? = try {
        carContext.getCarService(NavigationManager::class.java).also {
            it.setNavigationManagerCallback(object : NavigationManagerCallback {
                // Pemandu memulakan navigasi dalam app lain: tamatkan perjalanan kita (telefon juga).
                override fun onStopNavigation() {
                    navigationStarted = false
                    CarBridge.endNavigation()
                }
            })
        }
    } catch (_: Throwable) {
        null
    }

    private val onSession: (Map<String, Any?>) -> Unit = { session ->
        try {
            surface.apply(session)
        } catch (_: Throwable) {
        }
        try {
            syncNavigation(session)
            syncDriveAlert(session)
            val key = templateKeyOf(session)
            if (key != templateKey) {
                templateKey = key
                invalidate()
            }
        } catch (_: Throwable) {
        }
    }

    init {
        if (attachMap) {
            try {
                CarBridge.onSession = onSession
                CarBridge.session.let {
                    if (it.isNotEmpty()) {
                        surface.apply(it)
                        syncNavigation(it)
                        syncDriveAlert(it)
                    }
                }
                surface.attach()
            } catch (_: Throwable) {
                // Peta boleh gagal kemudian. Penemuan hos mesti tetap berjaya.
            }
            lifecycle.addObserver(object : DefaultLifecycleObserver {
                override fun onDestroy(owner: LifecycleOwner) {
                    // Sesi kereta tamat (putus sambungan): jangan terus memanggil skrin yang mati.
                    if (CarBridge.onSession === onSession) CarBridge.onSession = null
                    try {
                        if (navigationStarted) navigation?.navigationEnded()
                    } catch (_: Throwable) {
                    }
                    navigationStarted = false
                    surface.detach()
                }
            })
        }
    }

    /** navigationStarted/Ended mengikut mod sesi (wajib untuk app navigasi Android Auto). */
    private fun syncNavigation(session: Map<String, Any?>) {
        val manager = navigation ?: return
        val want = session["mode"] == "navigating"
        if (want == navigationStarted) return
        try {
            if (want) manager.navigationStarted() else manager.navigationEnded()
            navigationStarted = want
        } catch (_: Throwable) {
        }
    }

    /**
     * Apa yang kelihatan dalam templat. Jarak dibundar seperti paparan ([distanceOf]) dan ETA ke
     * minit, jadi pose kamera 10 Hz tidak membina semula templat (dan imej lorong) setiap kali.
     */
    private fun templateKeyOf(session: Map<String, Any?>): List<Any?> {
        val toManeuver = (session["distanceToManeuverM"] as? Number)?.toDouble()
        val remaining = (session["remainingM"] as? Number)?.toDouble()
        val eta = (session["etaEpochMs"] as? Number)?.toLong()
        val remainingS = (session["remainingS"] as? Number)?.toLong()
        return listOf(
            session["mode"],
            session["maneuver"],
            session["maneuverKind"],
            session["roundaboutExit"],
            toManeuver?.let { distanceOf(it) },
            remaining?.let { distanceOf(it) },
            eta?.div(60_000L),
            remainingS?.div(60L),
            session["lanes"],
            session["laneHint"],
            driveAlertOf(session),
            session["weatherAlert"],
            session["prayerLine"],
            session["airAqi"],
            session["rerouting"],
            session["arrived"],
            session["destination"],
        )
    }

    override fun onGetTemplate(): Template {
        return try {
            filledTemplate()
        } catch (_: Throwable) {
            bareTemplate()
        }
    }

    private fun filledTemplate(): Template {
        val session = CarBridge.session
        val mode = session["mode"] as? String ?: "browse"
        val builder = NavigationTemplate.Builder().setActionStrip(actions(mode))
        // Jalur peta dan mod seret ialah API kereta 2. Butang tersuai ialah API 4.
        // Di bawah itu templat kekal pada NavigationTemplate asas (API 1).
        val api = carContext.carAppApiLevel
        if (api >= 2) {
            builder.setMapActionStrip(mapActions(api))
            builder.setPanModeListener { inPan ->
                // Peta kereta diseret sendiri (onScroll/onScale di CarMapSurface).
                surface.setPanMode(inPan)
                if (inPan) CarBridge.pan()
            }
        }
        when (mode) {
            "navigating" -> if (session["arrived"] == true) {
                builder.setNavigationInfo(arrivedMessage(session))
            } else {
                builder.setNavigationInfo(routing(session))
                estimate(session)?.let { builder.setDestinationTravelEstimate(it) }
            }
            "cruise" -> builder.setNavigationInfo(cruiseMessage(session))
            else -> builder.setNavigationInfo(browseMessage(session))
        }
        return builder.build()
    }

    private fun bareTemplate(): Template = NavigationTemplate.Builder()
        .setActionStrip(
            ActionStrip.Builder()
                .addAction(
                    Action.Builder()
                        .setTitle("FGMaps")
                        .setOnClickListener { }
                        .build(),
                )
                .build(),
        )
        .build()

    private fun actions(mode: String): ActionStrip {
        // NavigationTemplate membenarkan paling banyak 2 tindakan bertajuk: semasa navigasi
        // (Cari + Tamat) "Berdekatan" hanya ikon; selainnya (Cari + Berdekatan) kedua-duanya bertajuk.
        val navigating = mode == "navigating"
        val search = Action.Builder()
            .setIcon(icon(R.drawable.ic_car_search))
            .setTitle(CarStrings.search)
            .setOnClickListener { screenManager.push(FgMapSearchScreen(carContext)) }
            .build()
        val nearby = Action.Builder()
            .setIcon(icon(R.drawable.ic_car_nearby))
            .apply { if (!navigating) setTitle(CarStrings.nearby) }
            .setOnClickListener { screenManager.push(FgMapNearbyScreen(carContext)) }
            .build()
        val strip = ActionStrip.Builder().addAction(search).addAction(nearby)
        if (navigating) {
            strip.addAction(
                Action.Builder()
                    .setIcon(icon(R.drawable.ic_car_close))
                    .setTitle(CarStrings.end)
                    .setOnClickListener { CarBridge.endNavigation() }
                    .build(),
            )
        }
        return strip.build()
    }

    private fun mapActions(api: Int): ActionStrip {
        // Tanpa Action.PAN hos tidak menghantar seretan dan tidak pernah masuk mod seret, jadi
        // dahulu API 4+ (hanya butang pusatkan) tidak boleh menggerakkan peta langsung.
        val strip = ActionStrip.Builder().addAction(Action.PAN)
        if (api >= 4) {
            strip.addAction(
                Action.Builder()
                    .setIcon(icon(R.drawable.ic_car_recenter))
                    .setOnClickListener {
                        surface.recenter()
                        CarBridge.recenter()
                    }
                    .build(),
            )
        }
        return strip.build()
    }

    private fun icon(res: Int): CarIcon = CarIcon.Builder(
        IconCompat.createWithResource(carContext, res),
    ).build()

    /** Telefon menunjukkan kad ketibaan; kereta menunjukkan mesej yang sama dan butang Tamat. */
    private fun arrivedMessage(session: Map<String, Any?>): MessageInfo {
        val info = MessageInfo.Builder(CarStrings.arrived)
        (session["destination"] as? String)?.takeIf { it.isNotBlank() }?.let { info.setText(it) }
        return info.build()
    }

    /**
     * Kira semula laluan, atau belum ada fix GPS pertama (tiada manuver): "memuatkan", bukan
     * manuver lapuk laluan lama atau templat kosong.
     */
    private fun routing(session: Map<String, Any?>): RoutingInfo {
        val maneuver = (session["maneuver"] as? String)?.takeIf { it.isNotBlank() }
        if (session["rerouting"] == true || maneuver == null) {
            return RoutingInfo.Builder().setLoading(true).build()
        }
        val stepBuilder = Step.Builder(maneuver)
        // Ikon manuver piawai hos (bulatan dengan nombor keluar, belok, dll.) supaya skrin kereta
        // sepadan dengan HUD telefon; teks kekal jika jenis tidak dikenali.
        CarManeuvers.build(
            session["maneuverKind"] as? String,
            (session["roundaboutExit"] as? Number)?.toInt(),
        )?.let { stepBuilder.setManeuver(it) }
        // Lorong sebenar (hanya data Valhalla; Dart tidak menghantar anggaran): lorong + imej lorong.
        // Tanpa lorong, ayat sisi ("Guna lorong paling kanan") menjadi cue jika tiada isyarat lain.
        val rawLanes = session["lanes"]
        if (rawLanes != lanesKey) {
            lanesKey = rawLanes
            lanesIcon = CarLanes.image(rawLanes)
        }
        val lanesShown = CarLanes.apply(stepBuilder, rawLanes, lanesIcon)
        val laneHint = if (lanesShown) null else (session["laneHint"] as? String)?.takeIf { it.isNotBlank() }
        // setCue ialah Car API 1, jadi hos lama memaparkan isyarat di sini.
        // Alert (RequiresCarApi 5) ditambah dalam syncDriveAlert; cue kekal jika banner ditolak.
        (driveAlertOf(session) ?: laneHint)?.let { stepBuilder.setCue(it) }
        val step = stepBuilder.build()
        val meters = (session["distanceToManeuverM"] as? Number)?.toDouble()
        val info = RoutingInfo.Builder()
        if (meters != null) {
            info.setCurrentStep(step, distanceOf(meters))
        } else {
            info.setCurrentStep(step, Distance.create(0.0, Distance.UNIT_METERS))
        }
        return info.build()
    }

    private fun estimate(session: Map<String, Any?>): TravelEstimate? {
        val remainingM = (session["remainingM"] as? Number)?.toDouble() ?: return null
        val eta = (session["etaEpochMs"] as? Number)?.toLong() ?: return null
        val remainingS = (session["remainingS"] as? Number)?.toLong() ?: 0L
        return TravelEstimate.Builder(
            distanceOf(remainingM),
            androidx.car.app.model.DateTimeWithZone.create(
                eta,
                java.util.TimeZone.getDefault(),
            ),
        ).setRemainingTimeSeconds(remainingS).build()
    }

    /**
     * Jarak dibundar sama seperti telefon (`carFormatDistance`): 10 m di bawah 1 km, 0.1 km di bawah
     * 10 km, km bulat selepas itu. Dahulu nilai mentah (cth. 1.2374 km) dihantar.
     */
    private fun distanceOf(meters: Double): Distance {
        if (meters < 995) {
            val m = (Math.round(meters / 10.0) * 10).coerceIn(10L, 990L)
            return Distance.create(m.toDouble(), Distance.UNIT_METERS)
        }
        val km = meters / 1000.0
        if (km < 10) return Distance.create(Math.round(km * 10) / 10.0, Distance.UNIT_KILOMETERS_P1)
        return Distance.create(Math.round(km).toDouble(), Distance.UNIT_KILOMETERS)
    }

    /** Browse: waktu solat seterusnya, dengan IPU di bawahnya jika ada. */
    private fun browseMessage(session: Map<String, Any?>): MessageInfo {
        val prayer = (session["prayerLine"] as? String)?.takeIf { it.isNotBlank() }
        val aqi = (session["airAqi"] as? String)?.takeIf { it.isNotBlank() }
        val info = MessageInfo.Builder(prayer ?: aqi ?: "FGMaps")
        if (prayer != null && aqi != null) info.setText(aqi)
        return info.build()
    }

    /** Cruise: amaran cuaca didahulukan (keselamatan); waktu solat di bawahnya atau sebagai tajuk. */
    private fun cruiseMessage(session: Map<String, Any?>): MessageInfo {
        val weather = (session["weatherAlert"] as? String)?.takeIf { it.isNotBlank() }
        val prayer = (session["prayerLine"] as? String)?.takeIf { it.isNotBlank() }
        val info = MessageInfo.Builder(weather ?: prayer ?: CarStrings.cruise)
        if (weather != null && prayer != null) info.setText(prayer)
        return info.build()
    }

    /** kamera > cuaca > R&R (Dart sudah menapis alongCue bila kamera ada). */
    private fun driveAlertOf(session: Map<String, Any?>): String? {
        val direct = session["driveAlert"] as? String
        if (!direct.isNullOrBlank()) return direct
        val camera = session["cameraAlert"] as? String
        if (!camera.isNullOrBlank()) return camera
        val weather = session["weatherAlert"] as? String
        if (!weather.isNullOrBlank()) return weather
        val along = session["alongCue"] as? String
        return along?.takeIf { it.isNotBlank() }
    }

    /**
     * API 5+: paparkan Alert host apabila teks isyarat berubah.
     * Buang apabila tiada isyarat atau keluar navigasi.
     */
    private fun syncDriveAlert(session: Map<String, Any?>) {
        if (carContext.carAppApiLevel < 5) return
        val mode = session["mode"] as? String ?: "browse"
        val text = if (mode == "navigating" || mode == "cruise") {
            driveAlertOf(session)
        } else {
            null
        }
        try {
            val manager = carContext.getCarService(AppManager::class.java)
            if (text.isNullOrBlank()) {
                if (alertShowing) {
                    manager.dismissAlert(DRIVE_ALERT_ID)
                    alertShowing = false
                    lastAlertText = null
                }
                return
            }
            if (text == lastAlertText && alertShowing) return
            lastAlertText = text
            val alert = Alert.Builder(
                DRIVE_ALERT_ID,
                CarText.create(text),
                ALERT_DURATION_MS,
            )
                .setCallback(object : AlertCallback {
                    override fun onCancel(reason: Int) {
                        alertShowing = false
                    }

                    override fun onDismiss() {
                        alertShowing = false
                    }
                })
                .build()
            manager.showAlert(alert)
            alertShowing = true
        } catch (_: Throwable) {
            // Hos lama / Alert tidak disokong: teks langkah (API < 5) sudah mencukupi.
        }
    }

    companion object {
        private const val DRIVE_ALERT_ID = 71001
        // Cukup lama untuk kamera ~800 m pada 90 km/j; dimuat semula bila teks berubah.
        private const val ALERT_DURATION_MS = 45_000L
    }
}

/** Had baris senarai yang dibenarkan hos pada masa ini (lebih rendah ketika memandu). */
internal fun listLimit(context: CarContext): Int = try {
    context.getCarService(ConstraintManager::class.java)
        .getContentLimit(ConstraintManager.CONTENT_LIMIT_TYPE_LIST)
} catch (_: Throwable) {
    6
}

/** Baris tempat: nama, dan "jarak · kawasan" di bawahnya. Klik memulakan laluan ke sana. */
private fun placeRows(
    context: CarContext,
    screen: Screen,
    places: List<CarPlace>,
): ItemList {
    val list = ItemList.Builder()
    if (places.isEmpty()) {
        list.setNoItemsMessage(CarStrings.noResults)
        return list.build()
    }
    for (place in places.take(listLimit(context))) {
        val row = Row.Builder().setTitle(place.name.ifBlank { CarStrings.place })
        if (place.subtitle.isNotBlank()) row.addText(place.subtitle)
        list.addItem(
            row.setOnClickListener {
                CarBridge.openPlace(place) { error ->
                    if (error == null || error == "tolls") {
                        // "tolls": navigasi sudah bermula, cuma "Tanpa tol" tidak dapat dipenuhi.
                        if (error != null) {
                            CarToast.makeText(context, CarStrings.tollsOnRoute, CarToast.LENGTH_LONG).show()
                        }
                        screen.screenManager.popToRoot()
                    } else {
                        // Kekal pada senarai supaya pemandu boleh cuba tempat lain.
                        CarToast.makeText(context, CarStrings.cannotStart, CarToast.LENGTH_LONG).show()
                    }
                }
            }.build(),
        )
    }
    return list.build()
}

class FgMapSearchScreen(carContext: CarContext) : Screen(carContext) {
    private var items: ItemList = ItemList.Builder()
        .setNoItemsMessage(CarStrings.typeDestination)
        .build()
    private var hint = CarStrings.searchHint

    override fun onGetTemplate(): Template {
        return SearchTemplate.Builder(object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) {}

            override fun onSearchSubmitted(searchText: String) {
                hint = CarStrings.searching
                invalidate()
                // Teks atau suara: "kedai gunting terdekat", "balik rumah" atau nama tempat.
                CarBridge.search(searchText) { places ->
                    items = placeRows(carContext, this@FgMapSearchScreen, places)
                    hint = CarStrings.searchHint
                    invalidate()
                }
            }
        })
            .setHeaderAction(Action.BACK)
            .setSearchHint(hint)
            .setItemList(items)
            .setShowKeyboardByDefault(true)
            .build()
    }
}

/**
 * "Berdekatan": kategori yang paling kerap dicari pemandu (minyak, makan, surau, tandas, ATM, farmasi,
 * pengecas EV...). Satu ketukan, tanpa menaip. Ketika memandu hos hanya membenarkan beberapa baris
 * (enam yang pertama ialah yang paling penting); selebihnya muncul bila kereta berhenti.
 */
class FgMapNearbyScreen(carContext: CarContext) : Screen(carContext) {
    private var categories: List<CarCategory>? = null

    init {
        CarBridge.categories { rows ->
            categories = rows
            invalidate()
        }
    }

    override fun onGetTemplate(): Template {
        val rows = categories
        val builder = ListTemplate.Builder()
            .setTitle(CarStrings.nearby)
            .setHeaderAction(Action.BACK)
        if (rows == null) return builder.setLoading(true).build()
        val list = ItemList.Builder()
        if (rows.isEmpty()) {
            list.setNoItemsMessage(CarStrings.noResults)
        }
        for (category in rows.take(listLimit(carContext))) {
            list.addItem(
                Row.Builder()
                    .setTitle(category.label)
                    .setBrowsable(true)
                    .setOnClickListener {
                        screenManager.push(FgMapPlacesScreen(carContext, category))
                    }
                    .build(),
            )
        }
        return builder.setSingleList(list.build()).build()
    }
}

/** Tempat terdekat bagi satu kategori, tersusun ikut jarak. */
class FgMapPlacesScreen(
    carContext: CarContext,
    private val category: CarCategory,
) : Screen(carContext) {
    private var places: List<CarPlace>? = null

    init {
        CarBridge.nearby(category.id) { rows ->
            places = rows
            invalidate()
        }
    }

    override fun onGetTemplate(): Template {
        val rows = places
        val builder = ListTemplate.Builder()
            .setTitle(category.label)
            .setHeaderAction(Action.BACK)
        if (rows == null) return builder.setLoading(true).build()
        return builder.setSingleList(placeRows(carContext, this, rows)).build()
    }
}
