package com.fguniversalempire.fgmaps.car

import android.content.Intent
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
import androidx.car.app.navigation.model.MessageInfo
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.car.app.model.SearchTemplate
import androidx.core.graphics.drawable.IconCompat
import com.fguniversalempire.fgmaps.R

class FgMapSession : Session() {
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

    init {
        if (attachMap) {
            try {
                CarBridge.onSession = { session ->
                    try {
                        surface.apply(session)
                    } catch (_: Throwable) {
                    }
                    syncDriveAlert(session)
                    invalidate()
                }
                CarBridge.session.let {
                    if (it.isNotEmpty()) {
                        surface.apply(it)
                        syncDriveAlert(it)
                    }
                }
                surface.attach()
            } catch (_: Throwable) {
                // Peta boleh gagal kemudian. Penemuan hos mesti tetap berjaya.
            }
        }
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
            builder.setPanModeListener { inPan -> if (inPan) CarBridge.pan() }
        }
        when (mode) {
            "navigating" -> {
                routing(session)?.let { builder.setNavigationInfo(it) }
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
        val strip = ActionStrip.Builder()
        if (api >= 4) {
            strip.addAction(
                Action.Builder()
                    .setIcon(icon(R.drawable.ic_car_recenter))
                    .setOnClickListener { CarBridge.recenter() }
                    .build(),
            )
        } else {
            // API 2–3 hanya membenarkan tindakan pan pada jalur peta.
            strip.addAction(Action.PAN)
        }
        return strip.build()
    }

    private fun icon(res: Int): CarIcon = CarIcon.Builder(
        IconCompat.createWithResource(carContext, res),
    ).build()

    private fun routing(session: Map<String, Any?>): RoutingInfo? {
        val maneuver = session["maneuver"] as? String ?: return null
        val stepBuilder = Step.Builder(maneuver)
        // Ikon manuver piawai hos (bulatan dengan nombor keluar, belok, dll.) supaya skrin kereta
        // sepadan dengan HUD telefon; teks kekal jika jenis tidak dikenali.
        CarManeuvers.build(
            session["maneuverKind"] as? String,
            (session["roundaboutExit"] as? Number)?.toInt(),
        )?.let { stepBuilder.setManeuver(it) }
        // Lorong sebenar (hanya data Valhalla; Dart tidak menghantar anggaran): lorong + imej lorong.
        // Tanpa lorong, ayat sisi ("Guna lorong paling kanan") menjadi cue jika tiada isyarat lain.
        val lanesShown = CarLanes.apply(stepBuilder, session["lanes"])
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

    private fun distanceOf(meters: Double): Distance =
        if (meters >= 1000) {
            Distance.create(meters / 1000.0, Distance.UNIT_KILOMETERS)
        } else {
            Distance.create(meters, Distance.UNIT_METERS)
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
                    if (error == null) {
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
