package com.fguniversalempire.fgmaps.car

import android.content.Intent
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Distance
import androidx.car.app.model.ItemList
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
 */
class FgMapNavScreen(
    carContext: CarContext,
    attachMap: Boolean = true,
) : Screen(carContext) {
    private val surface = CarMapSurface(carContext)

    init {
        if (attachMap) {
            try {
                CarBridge.onSession = { session ->
                    try {
                        surface.apply(session)
                    } catch (_: Throwable) {
                    }
                    invalidate()
                }
                CarBridge.session.let { if (it.isNotEmpty()) surface.apply(it) }
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
            "cruise" -> builder.setNavigationInfo(
                MessageInfo.Builder("Memandu bebas").build(),
            )
            else -> builder.setNavigationInfo(
                MessageInfo.Builder("FGMaps").build(),
            )
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
        val search = Action.Builder()
            .setIcon(icon(R.drawable.ic_car_search))
            .setTitle("Cari")
            .setOnClickListener { screenManager.push(FgMapSearchScreen(carContext)) }
            .build()
        val strip = ActionStrip.Builder().addAction(search)
        if (mode == "navigating") {
            strip.addAction(
                Action.Builder()
                    .setIcon(icon(R.drawable.ic_car_close))
                    .setTitle("Tamat")
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
}

class FgMapSearchScreen(carContext: CarContext) : Screen(carContext) {
    private var items: ItemList = ItemList.Builder()
        .setNoItemsMessage("Taip destinasi")
        .build()
    private var hint = "Cari destinasi"

    override fun onGetTemplate(): Template {
        return SearchTemplate.Builder(object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) {}

            override fun onSearchSubmitted(searchText: String) {
                hint = "Mencari…"
                invalidate()
                CarBridge.search(searchText) { places ->
                    val list = ItemList.Builder()
                    if (places.isEmpty()) {
                        list.setNoItemsMessage("Tiada hasil")
                    } else {
                        for (place in places) {
                            val row = Row.Builder()
                                .setTitle(place.name.ifBlank { "Tempat" })
                            if (place.subtitle.isNotBlank()) row.addText(place.subtitle)
                            list.addItem(
                                row
                                    .setOnClickListener {
                                        CarBridge.openPlace(place) { _ ->
                                            screenManager.pop()
                                        }
                                    }
                                    .build(),
                            )
                        }
                    }
                    items = list.build()
                    hint = "Cari destinasi"
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
