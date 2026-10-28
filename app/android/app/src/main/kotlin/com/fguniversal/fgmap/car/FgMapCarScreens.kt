package com.fguniversal.fgmap.car

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
import com.fguniversal.fgmap.R

class FgMapSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen {
        if (!CarBridge.ready) CarBridge.launchPhone(carContext)
        return FgMapNavScreen(carContext)
    }
}

/**
 * Templat navigasi padat: manuver dan ETA di slot templat, peta MapLibre pada permukaan,
 * tindakan terhad kepada carian, pusatkan, dan tamat.
 */
class FgMapNavScreen(carContext: CarContext) : Screen(carContext) {
    private val surface = CarMapSurface(carContext)

    init {
        CarBridge.onSession = { session ->
            surface.apply(session)
            invalidate()
        }
        CarBridge.session.let { if (it.isNotEmpty()) surface.apply(it) }
        surface.attach()
    }

    override fun onGetTemplate(): Template {
        val session = CarBridge.session
        val mode = session["mode"] as? String ?: "browse"
        val builder = NavigationTemplate.Builder()
            .setActionStrip(actions(mode))
            .setMapActionStrip(mapActions())
            .setPanModeListener { inPan -> if (inPan) CarBridge.pan() }
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

    private fun mapActions(): ActionStrip = ActionStrip.Builder()
        .addAction(
            Action.Builder()
                .setIcon(icon(R.drawable.ic_car_recenter))
                .setOnClickListener { CarBridge.recenter() }
                .build(),
        )
        .build()

    private fun icon(res: Int): CarIcon = CarIcon.Builder(
        IconCompat.createWithResource(carContext, res),
    ).build()

    private fun routing(session: Map<String, Any?>): RoutingInfo? {
        val maneuver = session["maneuver"] as? String ?: return null
        val step = Step.Builder(maneuver).build()
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
