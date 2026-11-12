@file:Suppress("DEPRECATION") // PlaceListNavigationTemplate: pengganti (MapWithContentTemplate) perlu Car API 7.

package com.fguniversalempire.fgmaps.car

import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.constraints.ConstraintManager
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.CarLocation
import androidx.car.app.model.Distance
import androidx.car.app.model.DistanceSpan
import androidx.car.app.model.DurationSpan
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Metadata
import androidx.car.app.model.Place
import androidx.car.app.model.PlaceMarker
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.model.Toggle
import androidx.car.app.navigation.model.PlaceListNavigationTemplate
import androidx.car.app.navigation.model.RoutePreviewNavigationTemplate
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.fguniversalempire.fgmaps.R

/*
 * Ciri app telefon di skrin kereta, dalam templat Android Auto yang dibenarkan untuk app navigasi:
 * Tempat (grid), senarai tempat bernombor di atas peta, pilihan laluan sebelum mula, Lapor dan Tetapan.
 * Setiap skrin membina templat dalam try/catch: templat yang gagal disahkan hos menjadi mesej ringkas,
 * bukan app tertutup di kereta.
 */

/**
 * Jarak dibundar sama seperti telefon (`carFormatDistance`): 10 m di bawah 1 km, 0.1 km di bawah
 * 10 km, km bulat selepas itu.
 */
internal fun carDistance(meters: Double): Distance {
    if (meters < 995) {
        val m = (Math.round(meters / 10.0) * 10).coerceIn(10L, 990L)
        return Distance.create(m.toDouble(), Distance.UNIT_METERS)
    }
    val km = meters / 1000.0
    if (km < 10) return Distance.create(Math.round(km * 10) / 10.0, Distance.UNIT_KILOMETERS_P1)
    return Distance.create(Math.round(km).toDouble(), Distance.UNIT_KILOMETERS)
}

internal fun carIcon(context: CarContext, res: Int, tint: CarColor? = null): CarIcon {
    val builder = CarIcon.Builder(IconCompat.createWithResource(context, res))
    if (tint != null) builder.setTint(tint)
    return builder.build()
}

internal fun carToast(context: CarContext, text: String) {
    try {
        CarToast.makeText(context, text, CarToast.LENGTH_LONG).show()
    } catch (_: Throwable) {
    }
}

private fun gridLimit(context: CarContext): Int = try {
    context.getCarService(ConstraintManager::class.java)
        .getContentLimit(ConstraintManager.CONTENT_LIMIT_TYPE_GRID)
} catch (_: Throwable) {
    6
}

/**
 * Ralat templat terakhir (ditolak pengesahan Car App Library). Dilog supaya dapat dikesan dalam logcat
 * dan ujian, kerana skrin kereta sendiri hanya memaparkan templat sandaran.
 */
internal object CarTemplateErrors {
    @Volatile
    var last: Throwable? = null
        private set

    fun note(e: Throwable) {
        last = e
        try {
            android.util.Log.w("FGMapsCar", "Templat kereta ditolak", e)
        } catch (_: Throwable) {
        }
    }

    @androidx.annotation.VisibleForTesting
    fun clear() {
        last = null
    }
}

/** Templat ringkas bila templat sebenar gagal dibina (hos tetap memaparkan sesuatu). */
private fun fallbackTemplate(title: String, message: String): Template =
    MessageTemplate.Builder(message).setTitle(title).setHeaderAction(Action.BACK).build()

/** Ikon bagi kategori "Berdekatan" (nama enum Dart); kategori lain guna pin tempat. */
internal fun categoryIcon(id: String): Int = when (id) {
    "fuel" -> R.drawable.ic_car_fuel
    "food" -> R.drawable.ic_car_food
    "mosque" -> R.drawable.ic_car_mosque
    "toilets" -> R.drawable.ic_car_toilets
    "atm", "bank" -> R.drawable.ic_car_atm
    "pharmacy" -> R.drawable.ic_car_pharmacy
    "evCharging" -> R.drawable.ic_car_ev
    "hospital", "clinic" -> R.drawable.ic_car_hospital
    "parking" -> R.drawable.ic_car_parking
    "police" -> R.drawable.ic_car_police
    "workshop", "tyres", "carWash" -> R.drawable.ic_car_broken
    else -> R.drawable.ic_car_place
}

private fun reportIcon(id: String): Int = when (id) {
    "police" -> R.drawable.ic_car_police
    "accident" -> R.drawable.ic_car_accident
    "hazard" -> R.drawable.ic_car_report
    "traffic_jam" -> R.drawable.ic_car_jam
    "road_closed" -> R.drawable.ic_car_closed
    "broken_down" -> R.drawable.ic_car_broken
    "flood" -> R.drawable.ic_car_flood
    else -> R.drawable.ic_car_report
}

// ------------------------------------------------------------------------------------------ Tempat

/**
 * Hab "Tempat": satu ketukan ke Rumah, Kerja, Berdekatan, Kegemaran, Terkini, Lapor dan Tetapan.
 * Grid ikon besar, seperti skrin utama app peta kereta lain; Rumah/Kerja memaparkan jarak semasa.
 */
class FgMapPlacesHubScreen(carContext: CarContext) : Screen(carContext) {
    private var hub: CarPlacesHub? = null
    private var failure: CarFailure? = null
    private var loading = true

    init {
        load()
    }

    private fun load() {
        CarBridge.placesHub { data, why ->
            hub = data
            failure = why
            loading = false
            invalidate()
            if (why == CarFailure.STARTING) {
                Handler(Looper.getMainLooper()).postDelayed({ if (hub == null) load() }, 2_000L)
            }
        }
    }

    override fun onGetTemplate(): Template = try {
        grid()
    } catch (e: Throwable) {
        CarTemplateErrors.note(e)
        fallbackTemplate(CarStrings.places, CarStrings.startingRetry)
    }

    private fun grid(): Template {
        val data = hub
        val items = ItemList.Builder()
        fun tile(title: String, text: String?, icon: Int, tint: CarColor?, onClick: () -> Unit) {
            val item = GridItem.Builder()
                .setTitle(title)
                .setImage(carIcon(carContext, icon, tint), GridItem.IMAGE_TYPE_ICON)
                .setOnClickListener(onClick)
            if (!text.isNullOrBlank()) item.setText(text)
            items.addItem(item.build())
        }
        fun slotText(place: CarPlace?): String? = when {
            loading -> null
            data == null -> null
            place == null -> CarStrings.notSet
            place.meters != null -> carDistanceText(place.meters)
            else -> null
        }
        val tiles = mutableListOf<() -> Unit>()
        tiles += {
            tile(CarStrings.home, slotText(data?.home), R.drawable.ic_car_home, CarColor.BLUE) {
                openSaved(data?.home, CarStrings.homeNotSet)
            }
        }
        tiles += {
            tile(CarStrings.work, slotText(data?.work), R.drawable.ic_car_work, CarColor.BLUE) {
                openSaved(data?.work, CarStrings.workNotSet)
            }
        }
        tiles += {
            tile(CarStrings.nearby, null, R.drawable.ic_car_nearby, CarColor.GREEN) {
                screenManager.push(FgMapNearbyScreen(carContext))
            }
        }
        tiles += {
            tile(CarStrings.favorites, null, R.drawable.ic_car_star, CarColor.YELLOW) {
                openList(CarStrings.favorites, data?.favorites, CarStrings.noFavorites)
            }
        }
        tiles += {
            tile(CarStrings.recents, null, R.drawable.ic_car_history, null) {
                openList(CarStrings.recents, data?.recents, CarStrings.noRecents)
            }
        }
        tiles += {
            tile(CarStrings.report, null, R.drawable.ic_car_report, CarColor.RED) {
                screenManager.push(FgMapReportScreen(carContext))
            }
        }
        tiles += {
            tile(CarStrings.settings, null, R.drawable.ic_car_settings, null) {
                screenManager.push(FgMapSettingsScreen(carContext))
            }
        }
        tiles.take(gridLimit(carContext)).forEach { it() }
        return GridTemplate.Builder()
            .setTitle(CarStrings.places)
            .setHeaderAction(Action.BACK)
            .setSingleList(items.build())
            .build()
    }

    private fun openSaved(place: CarPlace?, notSet: String) {
        when {
            hub == null -> carToast(carContext, CarStrings.emptyMessage(failure ?: CarFailure.STARTING))
            place == null -> carToast(carContext, notSet)
            else -> screenManager.push(FgMapRoutePreviewScreen(carContext, place))
        }
    }

    private fun openList(title: String, places: List<CarPlace>?, empty: String) {
        when {
            hub == null -> carToast(carContext, CarStrings.emptyMessage(failure ?: CarFailure.STARTING))
            places.isNullOrEmpty() -> carToast(carContext, empty)
            else -> screenManager.push(FgMapPlaceListScreen(carContext, title, places))
        }
    }
}

/** "12 km" / "800 m" untuk teks grid (span jarak hanya untuk baris senarai). */
private fun carDistanceText(meters: Double): String {
    val d = carDistance(meters)
    val n = d.displayDistance
    return when (d.displayUnit) {
        Distance.UNIT_METERS -> "${n.toLong()} m"
        Distance.UNIT_KILOMETERS_P1 -> String.format(java.util.Locale.US, "%.1f km", n)
        else -> "${n.toLong()} km"
    }
}

// ------------------------------------------------------------------------------------------ Senarai tempat

/**
 * Senarai tempat bernombor DI ATAS PETA: nombor baris sama dengan pin di peta, jarak dalam format hos.
 * Satu ketukan membuka pilihan laluan. [places] null bermaksud memuatkan melalui [load].
 */
class FgMapPlaceListScreen(
    carContext: CarContext,
    private val title: String,
    initial: List<CarPlace>? = null,
    private val load: (((List<CarPlace>, CarFailure?) -> Unit) -> Unit)? = null,
) : Screen(carContext) {
    private var places: List<CarPlace>? = initial
    private var failure: CarFailure? = null

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = showPins()

            override fun onStop(owner: LifecycleOwner) {
                CarMapSurface.current?.clearOverlay(this@FgMapPlaceListScreen)
            }
        })
        if (places == null) fetch()
    }

    private fun fetch() {
        load?.invoke { rows, why ->
            places = rows
            failure = why
            invalidate()
            showPins()
        }
    }

    private fun shown(): List<CarPlace> = places.orEmpty().take(listLimit(carContext))

    private fun showPins() {
        val rows = shown()
        if (rows.isEmpty()) return
        CarMapSurface.current?.showPins(this, rows.map { doubleArrayOf(it.lat, it.lng) })
    }

    override fun onGetTemplate(): Template = try {
        mapList()
    } catch (e: Throwable) {
        CarTemplateErrors.note(e)
        try {
            plainList()
        } catch (e2: Throwable) {
            CarTemplateErrors.note(e2)
            fallbackTemplate(title, CarStrings.emptyMessage(failure))
        }
    }

    private fun mapList(): Template {
        val rows = places
        val builder = PlaceListNavigationTemplate.Builder()
            .setTitle(title)
            .setHeaderAction(Action.BACK)
        if (rows == null) return builder.setLoading(true).build()
        // Senarai atas peta mewajibkan jarak pada setiap baris; tanpa lokasi guna senarai biasa.
        if (rows.isNotEmpty() && rows.any { it.meters == null }) return plainList()
        val list = ItemList.Builder()
        if (rows.isEmpty()) list.setNoItemsMessage(CarStrings.emptyMessage(failure))
        shown().forEachIndexed { i, place ->
            val text = SpannableString(if (place.area.isBlank()) " " else "  · ${place.area}")
            text.setSpan(
                DistanceSpan.create(carDistance(place.meters ?: 0.0)),
                0,
                1,
                Spanned.SPAN_INCLUSIVE_INCLUSIVE,
            )
            val marker = PlaceMarker.Builder().setLabel((i + 1).toString()).build()
            list.addItem(
                Row.Builder()
                    .setTitle(place.name.ifBlank { CarStrings.place })
                    .addText(text)
                    .setMetadata(
                        Metadata.Builder().setPlace(
                            Place.Builder(CarLocation.create(place.lat, place.lng))
                                .setMarker(marker)
                                .build(),
                        ).build(),
                    )
                    .setOnClickListener { open(place) }
                    .build(),
            )
        }
        return builder.setItemList(list.build()).build()
    }

    private fun plainList(): Template {
        val rows = places
        val builder = ListTemplate.Builder().setTitle(title).setHeaderAction(Action.BACK)
        if (rows == null) return builder.setLoading(true).build()
        val list = ItemList.Builder()
        if (rows.isEmpty()) list.setNoItemsMessage(CarStrings.emptyMessage(failure))
        for (place in shown()) {
            val row = Row.Builder().setTitle(place.name.ifBlank { CarStrings.place })
            if (place.subtitle.isNotBlank()) row.addText(place.subtitle)
            list.addItem(row.setOnClickListener { open(place) }.build())
        }
        return builder.setSingleList(list.build()).build()
    }

    private fun open(place: CarPlace) {
        screenManager.push(FgMapRoutePreviewScreen(carContext, place))
    }
}

// ------------------------------------------------------------------------------------------ Pilihan laluan

/**
 * Pilihan laluan sebelum memandu, seperti di telefon: masa, jarak dan tol bagi setiap laluan, laluan
 * dipilih biru di peta dan yang lain kelabu. "Mula" memulakan navigasi yang sama dengan telefon.
 */
class FgMapRoutePreviewScreen(
    carContext: CarContext,
    private val place: CarPlace,
) : Screen(carContext) {
    private var routes: List<CarRoute>? = null
    private var failure: CarFailure? = null
    private var selected = 0
    private var starting = false

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = showRoutes()

            override fun onStop(owner: LifecycleOwner) {
                CarMapSurface.current?.clearOverlay(this@FgMapRoutePreviewScreen)
            }
        })
        fetch()
    }

    private fun fetch() {
        routes = null
        failure = null
        CarBridge.preview(place) { rows, why ->
            routes = rows
            failure = why ?: if (rows.isEmpty()) CarFailure.NO_ROUTE else null
            selected = 0
            invalidate()
            showRoutes()
        }
    }

    private fun showRoutes() {
        val rows = routes ?: return
        if (rows.isEmpty()) return
        CarMapSurface.current?.showRoutes(this, rows.map { it.points }, selected)
    }

    private val title: String get() = place.name.ifBlank { CarStrings.place }

    override fun onGetTemplate(): Template = try {
        preview()
    } catch (e: Throwable) {
        CarTemplateErrors.note(e)
        fallbackTemplate(title, CarStrings.noRoute)
    }

    private fun preview(): Template {
        val rows = routes
        if (rows != null && rows.isEmpty()) {
            return MessageTemplate.Builder(CarStrings.emptyMessage(failure ?: CarFailure.NO_ROUTE))
                .setTitle(title)
                .setHeaderAction(Action.BACK)
                .setIcon(carIcon(carContext, R.drawable.ic_car_navigate))
                .addAction(
                    Action.Builder()
                        .setTitle(CarStrings.retry)
                        .setOnClickListener {
                            fetch()
                            invalidate()
                        }
                        .build(),
                )
                .build()
        }
        val builder = RoutePreviewNavigationTemplate.Builder()
            .setTitle(title)
            .setHeaderAction(Action.BACK)
        if (rows == null || starting) return builder.setLoading(true).build()
        val list = ItemList.Builder()
        for (route in rows.take(listLimit(carContext))) {
            val name = SpannableString(if (route.title.isBlank()) " " else "  · ${route.title}")
            name.setSpan(DurationSpan.create(route.durationS), 0, 1, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
            val row = Row.Builder().setTitle(name)
            if (route.detail.isNotBlank()) row.addText(route.detail)
            list.addItem(row.build())
        }
        list.setSelectedIndex(selected.coerceIn(0, (rows.size - 1).coerceAtLeast(0)))
        list.setOnSelectedListener { index ->
            selected = index
            showRoutes()
        }
        return builder
            .setItemList(list.build())
            .setNavigateAction(
                Action.Builder()
                    .setTitle(CarStrings.go)
                    .setIcon(carIcon(carContext, R.drawable.ic_car_navigate))
                    .setOnClickListener { start() }
                    .build(),
            )
            .build()
    }

    private fun start() {
        if (starting) return
        starting = true
        invalidate()
        CarBridge.startPreview(selected) { error ->
            starting = false
            if (error == null) {
                screenManager.popToRoot()
            } else {
                carToast(carContext, CarStrings.cannotStart)
                invalidate()
            }
        }
    }
}

// ------------------------------------------------------------------------------------------ Lapor

/** Laporan jalan satu ketukan di kedudukan semasa (sama seperti butang Lapor di telefon). */
class FgMapReportScreen(carContext: CarContext) : Screen(carContext) {
    private var types: List<CarCategory>? = null
    private var failure: CarFailure? = null
    private var sending = false

    init {
        load()
    }

    private fun load() {
        CarBridge.reportTypes { rows, why ->
            types = rows
            failure = why
            invalidate()
            if (why == CarFailure.STARTING) {
                Handler(Looper.getMainLooper()).postDelayed({ if (types.isNullOrEmpty()) load() }, 2_000L)
            }
        }
    }

    override fun onGetTemplate(): Template = try {
        grid()
    } catch (e: Throwable) {
        CarTemplateErrors.note(e)
        fallbackTemplate(CarStrings.report, CarStrings.reportFailed)
    }

    private fun grid(): Template {
        val rows = types
        val builder = GridTemplate.Builder()
            .setTitle(CarStrings.reportWhat)
            .setHeaderAction(Action.BACK)
        if (rows == null || sending) return builder.setLoading(true).build()
        val items = ItemList.Builder()
        if (rows.isEmpty()) items.setNoItemsMessage(CarStrings.emptyMessage(failure))
        for (type in rows.take(gridLimit(carContext))) {
            items.addItem(
                GridItem.Builder()
                    .setTitle(type.label)
                    .setImage(carIcon(carContext, reportIcon(type.id), CarColor.RED), GridItem.IMAGE_TYPE_ICON)
                    .setOnClickListener { send(type) }
                    .build(),
            )
        }
        return builder.setSingleList(items.build()).build()
    }

    private fun send(type: CarCategory) {
        if (sending) return
        sending = true
        invalidate()
        CarBridge.report(type.id) { result ->
            sending = false
            carToast(
                carContext,
                when (result) {
                    "created" -> CarStrings.reportSent
                    "confirmed" -> CarStrings.reportConfirmed
                    "no-location" -> CarStrings.noLocation
                    else -> CarStrings.reportFailed
                },
            )
            if (result == "created" || result == "confirmed") screenManager.pop() else invalidate()
        }
    }
}

// ------------------------------------------------------------------------------------------ Tetapan

/** Tetapan yang selamat diubah di kereta. Selebihnya kekal di app telefon. */
class FgMapSettingsScreen(carContext: CarContext) : Screen(carContext) {
    private var values: Map<String, Boolean>? = null

    init {
        load()
    }

    private fun load() {
        CarBridge.settings { map ->
            values = map ?: emptyMap()
            invalidate()
            if (map == null) {
                Handler(Looper.getMainLooper()).postDelayed({ if (values.isNullOrEmpty()) load() }, 2_000L)
            }
        }
    }

    override fun onGetTemplate(): Template = try {
        list()
    } catch (e: Throwable) {
        CarTemplateErrors.note(e)
        fallbackTemplate(CarStrings.settings, CarStrings.startingRetry)
    }

    private fun list(): Template {
        val current = values
        val builder = ListTemplate.Builder().setTitle(CarStrings.settings).setHeaderAction(Action.BACK)
        if (current == null) return builder.setLoading(true).build()
        val list = ItemList.Builder()
        if (current.isEmpty()) list.setNoItemsMessage(CarStrings.startingRetry)
        fun toggle(key: String, title: String, icon: Int, hint: String? = null) {
            val checked = current[key] ?: return
            val row = Row.Builder()
                .setTitle(title)
                .setImage(carIcon(carContext, icon), Row.IMAGE_TYPE_ICON)
                .setToggle(
                    Toggle.Builder { on ->
                        values = current + (key to on)
                        CarBridge.setSetting(key, on) { updated ->
                            if (updated != null) values = updated
                            invalidate()
                        }
                    }.setChecked(checked).build(),
                )
            if (hint != null) row.addText(hint)
            list.addItem(row.build())
        }
        toggle("voice", CarStrings.voice, R.drawable.ic_car_volume_on)
        toggle("avoidTolls", CarStrings.avoidTolls, R.drawable.ic_car_navigate, CarStrings.avoidTollsHint)
        toggle("cameras", CarStrings.cameras, R.drawable.ic_car_report)
        toggle("satellite", CarStrings.satellite, R.drawable.ic_car_place)
        return builder.setSingleList(list.build()).build()
    }
}
