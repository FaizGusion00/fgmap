package com.fguniversalempire.fgmaps.car

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Point as ScreenPoint
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Bundle
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory.iconAllowOverlap
import org.maplibre.android.style.layers.PropertyFactory.iconAnchor
import org.maplibre.android.style.layers.PropertyFactory.lineSortKey
import org.maplibre.android.style.layers.PropertyFactory.symbolSortKey
import org.maplibre.android.style.layers.PropertyFactory.iconIgnorePlacement
import org.maplibre.android.style.layers.PropertyFactory.iconImage
import org.maplibre.android.style.layers.PropertyFactory.iconPitchAlignment
import org.maplibre.android.style.layers.PropertyFactory.iconRotate
import org.maplibre.android.style.layers.PropertyFactory.iconRotationAlignment
import org.maplibre.android.style.layers.PropertyFactory.lineCap
import org.maplibre.android.style.layers.PropertyFactory.lineColor
import org.maplibre.android.style.layers.PropertyFactory.lineJoin
import org.maplibre.android.style.layers.PropertyFactory.lineOpacity
import org.maplibre.android.style.layers.PropertyFactory.lineWidth
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import android.app.Presentation
import kotlin.math.ln

/**
 * MapLibre pada permukaan Android Auto. Pose datang daripada sesi Flutter, bukan GPS kedua.
 * Kelajuan dan papan had dilukis di atas peta, dalam kawasan yang tidak ditutup templat.
 *
 * Semasa memandu pusat kamera ialah kenderaan; padding kamera meletakkan kenderaan di bahagian bawah
 * kawasan stabil (tidak ditutup kad manuver), apa jua saiz skrin kereta. Penanda kenderaan dilukis
 * di sini: kereta 3D telefon dilukis oleh Flutter dan tidak wujud pada peta kereta.
 */
class CarMapSurface(
    private val carContext: CarContext,
) : SurfaceCallback {
    private var virtualDisplay: VirtualDisplay? = null
    private var presentation: Presentation? = null
    private var mapView: MapView? = null
    private var map: MapLibreMap? = null
    private var overlay: SpeedOverlay? = null
    private val stable = Rect()
    private val visible = Rect()
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var appliedStyleKey: String? = null
    private var appliedRouteVersion: Int? = null
    private var lastSession: Map<String, Any?> = emptyMap()

    /** Anak panah arah pada laluan (lihat [CarRouteGuide]); kosong jika tiada laluan atau gagal dikira. */
    private var routeChevrons: List<CarRouteGuide.Chevron> = emptyList()
    private var chevronCursor = CHEVRON_UNSET
    private var chevronIcon: Bitmap? = null

    /** Mod seret hos aktif, dan masa gerak isyarat terakhir (pan/zum) di skrin kereta. */
    private var panMode = false
    private var lastGestureAt = 0L

    fun attach() {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
        current = this
    }

    fun detach() {
        if (current === this) current = null
        try {
            carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
        } catch (_: Throwable) {
        }
        destroyMap()
    }

    /**
     * Lapisan sementara skrin lain (senarai tempat bernombor, pilihan laluan) di atas peta yang sama.
     * [owner] ialah skrin yang memaparkannya: skrin baharu bermula sebelum skrin lama berhenti, jadi
     * skrin lama tidak boleh memadam lapisan skrin baharu.
     */
    private var overlayOwner: Any? = null
    private var overlayPins: List<DoubleArray> = emptyList()
    private var overlayRoutes: List<List<DoubleArray>> = emptyList()
    private var overlaySelected = 0
    private var overlayFitted = false

    /** Tempat bernombor 1..N di peta, sepadan dengan nombor baris dalam senarai kereta. */
    fun showPins(owner: Any, pins: List<DoubleArray>) {
        overlayOwner = owner
        overlayPins = pins
        overlayRoutes = emptyList()
        overlayFitted = false
        refreshOverlay()
    }

    /** Pilihan laluan: yang dipilih biru di atas, yang lain kelabu di bawah; destinasi sebagai pin. */
    fun showRoutes(owner: Any, routes: List<List<DoubleArray>>, selected: Int) {
        val changedRoutes = overlayOwner !== owner || routes !== overlayRoutes
        overlayOwner = owner
        overlayRoutes = routes
        overlaySelected = selected
        overlayPins = routes.getOrNull(selected)?.lastOrNull()?.let { listOf(it) } ?: emptyList()
        if (changedRoutes) overlayFitted = false
        refreshOverlay()
    }

    fun clearOverlay(owner: Any) {
        if (overlayOwner !== owner) return
        overlayOwner = null
        overlayPins = emptyList()
        overlayRoutes = emptyList()
        refreshOverlay()
        // Kembali mengikut kenderaan selepas senarai/pratonton ditutup.
        map?.let { if (!userMovedMap()) moveCamera(it, lastSession) }
    }

    private fun refreshOverlay() {
        val map = map ?: return
        try {
            map.style?.let { drawOverlay(it) }
            if (!overlayFitted) fitOverlay(map)
        } catch (_: Throwable) {
        }
    }

    fun apply(session: Map<String, Any?>) {
        lastSession = session
        val map = map ?: return
        val styleKey = session["styleKey"] as? String
        val styleBody = session["style"] as? String
        if (styleBody != null && styleKey != null && styleKey != appliedStyleKey) {
            val builder = if (styleBody.trimStart().startsWith("{")) {
                Style.Builder().fromJson(styleBody)
            } else {
                Style.Builder().fromUri(styleBody)
            }
            map.setStyle(builder) {
                appliedStyleKey = styleKey
                appliedRouteVersion = null
                // Gaya baharu membuang sumber/lapisan: lukis semula daripada sesi TERKINI.
                drawRoute(it, lastSession)
                drawChevrons(it, lastSession)
                drawOverlay(it)
                drawVehicle(it, lastSession)
            }
        } else {
            map.style?.let {
                drawRoute(it, session)
                drawChevrons(it, session)
                drawVehicle(it, session)
            }
        }
        // Senarai tempat / pratonton laluan dibuka: peta kekal menunjukkan semuanya, bukan mengikut kenderaan.
        if (overlayOwner == null && session["following"] != false && !userMovedMap()) {
            moveCamera(map, session)
        } else if (overlayOwner != null && !overlayFitted) {
            fitOverlay(map)
        }
        overlay?.session = session
        overlay?.stable = stable
        overlay?.invalidate()
    }

    /** Mod seret hos (butang pan): kamera berhenti mengikut sehingga keluar + tempoh rehat. */
    fun setPanMode(inPan: Boolean) {
        panMode = inPan
        if (inPan) lastGestureAt = SystemClock.elapsedRealtime()
    }

    /** Butang "Pusatkan": kembali mengikut kenderaan serta-merta. */
    fun recenter() {
        panMode = false
        lastGestureAt = 0L
        map?.let { moveCamera(it, lastSession) }
    }

    /** Sama seperti telefon: 10 s selepas sentuhan terakhir kamera kembali mengikut kenderaan. */
    private fun userMovedMap(): Boolean {
        if (panMode) return true
        val last = lastGestureAt
        if (last == 0L) return false
        if (SystemClock.elapsedRealtime() - last < AUTO_RECENTER_MS) return true
        lastGestureAt = 0L
        return false
    }

    override fun onScroll(distanceX: Float, distanceY: Float) {
        val map = map ?: return
        lastGestureAt = SystemClock.elapsedRealtime()
        try {
            map.scrollBy(-distanceX, -distanceY)
        } catch (_: Throwable) {
        }
    }

    override fun onScale(focusX: Float, focusY: Float, scaleFactor: Float) {
        val map = map ?: return
        lastGestureAt = SystemClock.elapsedRealtime()
        // Faktor tidak sah (cth. ketuk dua kali pada sesetengah hos): zum masuk satu tahap.
        val delta = if (scaleFactor > 0f) ln(scaleFactor.toDouble()) / ln(2.0) else 1.0
        try {
            map.moveCamera(
                CameraUpdateFactory.zoomBy(delta, ScreenPoint(focusX.toInt(), focusY.toInt())),
            )
        } catch (_: Throwable) {
        }
    }

    override fun onSurfaceAvailable(container: SurfaceContainer) {
        val surface = container.surface ?: return
        surfaceWidth = container.width
        surfaceHeight = container.height
        try {
            showMap(container, surface)
            CarBridge.reportCar(visible = true, dark = carContext.isDarkMode)
        } catch (_: Throwable) {
            destroyMap()
        }
    }

    private fun showMap(container: SurfaceContainer, surface: android.view.Surface) {
        MapLibre.getInstance(carContext)
        val dm = carContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = dm.createVirtualDisplay(
            "fgmap-car",
            container.width,
            container.height,
            container.dpi,
            surface,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_PRESENTATION,
        )
        virtualDisplay = display
        val host = object : Presentation(carContext, display.display) {
            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                val root = FrameLayout(context)
                val view = MapView(context)
                view.onCreate(null)
                val speed = SpeedOverlay(context)
                root.addView(view, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ))
                root.addView(speed, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    Gravity.START,
                ))
                setContentView(root)
                mapView = view
                overlay = speed
                view.onStart()
                view.onResume()
                val density = context.resources.displayMetrics
                view.getMapAsync { ready ->
                    map = ready
                    ready.uiSettings.setAllGesturesEnabled(false)
                    ready.uiSettings.isLogoEnabled = false
                    ready.uiSettings.isAttributionEnabled = false
                    vehicleIcons = VehicleIcons.render(density.density, density.densityDpi)
                    pinDensity = density.density
                    pinDpi = density.densityDpi
                    overlayFitted = false
                    chevronIcon = try {
                        CarRouteGuide.icon(density.density, density.densityDpi)
                    } catch (_: Throwable) {
                        null
                    }
                    // Permukaan baharu (hos AA bangun / skrin kembali): lukis semula
                    // gaya, laluan dan kamera daripada gambar sesi terakhir.
                    appliedStyleKey = null
                    appliedRouteVersion = null
                    apply(lastSession)
                }
            }
        }
        presentation = host
        host.show()
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        visible.set(visibleArea)
        overlay?.invalidate()
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        // Kawasan stabil (tidak berubah bila amaran/kad muncul) untuk kamera dan gelembung kelajuan;
        // dahulu kawasan kelihatan menimpanya dan kenderaan melompat setiap kali amaran muncul.
        stable.set(stableArea)
        overlay?.stable = stable
        overlay?.invalidate()
        map?.let {
            if (overlayOwner != null) {
                overlayFitted = false
                fitOverlay(it)
            } else if (!userMovedMap()) {
                moveCamera(it, lastSession)
            }
        }
    }

    override fun onSurfaceDestroyed(container: SurfaceContainer) {
        destroyMap()
    }

    private fun destroyMap() {
        map = null
        mapView?.onPause()
        mapView?.onStop()
        mapView?.onDestroy()
        mapView = null
        overlay = null
        presentation?.dismiss()
        presentation = null
        virtualDisplay?.release()
        virtualDisplay = null
        appliedStyleKey = null
        appliedRouteVersion = null
        CarBridge.reportCar(visible = false)
    }

    private var pinDensity = 0f
    private var pinDpi = 0

    /** Muatkan semua pin/laluan (dan kenderaan, bagi senarai tempat) dalam kawasan stabil. */
    private fun fitOverlay(map: MapLibreMap) {
        try {
            fitOverlayOrThrow(map)
        } catch (_: Throwable) {
            overlayFitted = true
        }
    }

    private fun fitOverlayOrThrow(map: MapLibreMap) {
        val points = mutableListOf<LatLng>()
        overlayRoutes.forEach { r -> r.forEach { points.add(LatLng(it[0], it[1])) } }
        overlayPins.forEach { points.add(LatLng(it[0], it[1])) }
        if (overlayRoutes.isEmpty()) {
            val lat = (lastSession["vehicleLat"] as? Number ?: lastSession["lat"] as? Number)?.toDouble()
            val lng = (lastSession["vehicleLng"] as? Number ?: lastSession["lng"] as? Number)?.toDouble()
            if (lat != null && lng != null) points.add(LatLng(lat, lng))
        }
        if (points.isEmpty()) return
        val width = mapView?.width?.takeIf { it > 0 } ?: surfaceWidth
        val height = mapView?.height?.takeIf { it > 0 } ?: surfaceHeight
        if (width <= 0 || height <= 0) return
        val area = when {
            stable.width() > 0 && stable.height() > 0 -> stable
            visible.width() > 0 && visible.height() > 0 -> visible
            else -> Rect(0, 0, width, height)
        }
        val margin = (40f * (if (pinDensity > 0f) pinDensity else 1f)).toInt()
        val left = area.left + margin
        val top = area.top + margin
        val right = (width - area.right) + margin
        val bottom = (height - area.bottom) + margin
        if (width - left - right < 50 || height - top - bottom < 50) return
        if (points.size == 1) {
            map.moveCamera(
                CameraUpdateFactory.newCameraPosition(
                    CameraPosition.Builder()
                        .target(points[0])
                        .zoom(15.0)
                        .tilt(0.0)
                        .bearing(0.0)
                        .padding(doubleArrayOf(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble()))
                        .build(),
                ),
            )
        } else {
            val bounds = LatLngBounds.Builder().includes(points).build()
            map.moveCamera(
                CameraUpdateFactory.newLatLngBounds(bounds, 0.0, 0.0, left, top, right, bottom),
            )
        }
        overlayFitted = true
    }

    /** Laluan pratonton dan pin bernombor. Semuanya pilihan: kegagalan hanya menggugurkan lapisan ini. */
    private fun drawOverlay(style: Style) {
        try {
            val lines = overlayRoutes.mapIndexedNotNull { i, route ->
                if (route.size < 2) return@mapIndexedNotNull null
                Feature.fromGeometry(
                    LineString.fromLngLats(route.map { Point.fromLngLat(it[1], it[0]) }),
                ).also { it.addNumberProperty("sel", if (i == overlaySelected) 1 else 0) }
            }
            var routeSource = style.getSource(PREVIEW_SOURCE) as? GeoJsonSource
            if (routeSource == null && lines.isNotEmpty()) {
                routeSource = GeoJsonSource(PREVIEW_SOURCE)
                style.addSource(routeSource)
                val selected = Expression.eq(Expression.get("sel"), Expression.literal(1))
                val casing = LineLayer(PREVIEW_CASING, PREVIEW_SOURCE).withProperties(
                    lineColor("#FFFFFF"),
                    lineWidth(Expression.switchCase(selected, Expression.literal(12.5f), Expression.literal(9f))),
                    lineCap("round"),
                    lineJoin("round"),
                    lineSortKey(Expression.get("sel")),
                )
                val line = LineLayer(PREVIEW_LINE, PREVIEW_SOURCE).withProperties(
                    lineColor(
                        Expression.switchCase(
                            selected,
                            Expression.color(Color.rgb(47, 107, 255)),
                            Expression.color(Color.rgb(140, 152, 175)),
                        ),
                    ),
                    lineWidth(Expression.switchCase(selected, Expression.literal(8f), Expression.literal(6f))),
                    lineCap("round"),
                    lineJoin("round"),
                    lineSortKey(Expression.get("sel")),
                )
                addBelowVehicle(style, casing)
                addBelowVehicle(style, line)
            }
            routeSource?.setGeoJson(FeatureCollection.fromFeatures(lines))

            val pins = overlayPins.mapIndexed { i, p ->
                Feature.fromGeometry(Point.fromLngLat(p[1], p[0])).also {
                    val n = (i + 1).coerceAtMost(MAX_PIN_NUMBER)
                    it.addStringProperty("icon", if (overlayRoutes.isEmpty()) "$PIN$n" else PIN_DEST)
                    it.addNumberProperty("order", -i)
                }
            }
            var pinSource = style.getSource(PIN_SOURCE) as? GeoJsonSource
            if (pinSource == null && pins.isNotEmpty()) {
                val density = if (pinDensity > 0f) pinDensity else 2f
                for (n in 1..MAX_PIN_NUMBER) {
                    if (style.getImage("$PIN$n") == null) {
                        style.addImage("$PIN$n", CarPins.numbered(n, density, pinDpi))
                    }
                }
                if (style.getImage(PIN_DEST) == null) {
                    style.addImage(PIN_DEST, CarPins.destination(density, pinDpi))
                }
                pinSource = GeoJsonSource(PIN_SOURCE)
                style.addSource(pinSource)
                addBelowVehicle(
                    style,
                    SymbolLayer(PIN_LAYER, PIN_SOURCE).withProperties(
                        iconImage(Expression.get("icon")),
                        iconAnchor(Property.ICON_ANCHOR_BOTTOM),
                        iconAllowOverlap(true),
                        iconIgnorePlacement(true),
                        symbolSortKey(Expression.get("order")),
                    ),
                )
            }
            pinSource?.setGeoJson(FeatureCollection.fromFeatures(pins))
        } catch (_: Throwable) {
        }
    }

    private fun addBelowVehicle(style: Style, layer: org.maplibre.android.style.layers.Layer) {
        if (style.getLayer(VEHICLE_LAYER) != null) {
            style.addLayerBelow(layer, VEHICLE_LAYER)
        } else {
            style.addLayer(layer)
        }
    }

    private fun moveCamera(map: MapLibreMap, session: Map<String, Any?>) {
        val vehicleLat = (session["vehicleLat"] as? Number)?.toDouble()
        val vehicleLng = (session["vehicleLng"] as? Number)?.toDouble()
        val lat = vehicleLat ?: (session["lat"] as? Number)?.toDouble() ?: return
        val lng = vehicleLng ?: (session["lng"] as? Number)?.toDouble() ?: return
        // Kenderaan di ~68% tinggi kawasan stabil (sama seperti telefon mendatar); browse di tengah.
        val fraction = if (session["mode"] == "browse") 0.5 else VEHICLE_SCREEN_FRACTION
        val position = CameraPosition.Builder()
            .target(LatLng(lat, lng))
            .zoom((session["zoom"] as? Number)?.toDouble() ?: 16.0)
            .tilt((session["tilt"] as? Number)?.toDouble() ?: 0.0)
            .bearing((session["bearing"] as? Number)?.toDouble() ?: 0.0)
            .padding(padding(fraction))
            .build()
        map.moveCamera(CameraUpdateFactory.newCameraPosition(position))
    }

    /** Padding kamera (kiri, atas, kanan, bawah) supaya sasaran jatuh pada [fraction] kawasan stabil. */
    private fun padding(fraction: Double): DoubleArray {
        val width = mapView?.width?.takeIf { it > 0 } ?: surfaceWidth
        val height = mapView?.height?.takeIf { it > 0 } ?: surfaceHeight
        val area = when {
            stable.width() > 0 && stable.height() > 0 -> stable
            visible.width() > 0 && visible.height() > 0 -> visible
            else -> return doubleArrayOf(0.0, 0.0, 0.0, 0.0)
        }
        if (width <= 0 || height <= 0) return doubleArrayOf(0.0, 0.0, 0.0, 0.0)
        val bottom = (height - area.bottom).coerceAtLeast(0).toDouble()
        // Pusat kawasan berpadding = (atas + area.bottom) / 2 = area.top + fraction x tinggi.
        val top = (area.top + (2 * fraction - 1) * area.height()).coerceAtLeast(0.0)
        val left = area.left.coerceAtLeast(0).toDouble()
        val right = (width - area.right).coerceAtLeast(0).toDouble()
        return doubleArrayOf(left, top, right, bottom)
    }

    private fun drawRoute(style: Style, session: Map<String, Any?>) {
        val version = (session["routeVersion"] as? Number)?.toInt() ?: 0
        val mode = session["mode"] as? String
        if (mode == "navigating" && version == appliedRouteVersion && style.getSource(SOURCE) != null) {
            return
        }
        val route = session["route"] as? List<*>
        // Muatan tanpa laluan (versi sama telah dihantar) tidak boleh memadam garisan sedia ada.
        if (mode == "navigating" && route == null) return
        val points = mutableListOf<Point>()
        if (mode == "navigating") {
            for (item in route.orEmpty()) {
                val pair = item as? List<*> ?: continue
                if (pair.size < 2) continue
                val lat = (pair[0] as? Number)?.toDouble() ?: continue
                val lng = (pair[1] as? Number)?.toDouble() ?: continue
                points.add(Point.fromLngLat(lng, lat))
            }
        }
        val feature = if (points.size >= 2) {
            Feature.fromGeometry(LineString.fromLngLats(points))
        } else {
            null
        }
        // Laluan baharu: anak panah dikira semula daripada geometri yang sama. Kegagalan hanya
        // menggugurkan anak panah; garisan laluan tidak terjejas.
        routeChevrons = try {
            CarRouteGuide.chevrons(points)
        } catch (_: Throwable) {
            emptyList()
        }
        chevronCursor = CHEVRON_UNSET
        val existing = style.getSource(SOURCE) as? GeoJsonSource
        if (existing == null) {
            if (feature == null) return
            style.addSource(GeoJsonSource(SOURCE, feature))
            val line = LineLayer(LAYER, SOURCE).withProperties(
                lineColor("#2F6BFF"),
                lineWidth(8f),
                lineCap("round"),
                lineJoin("round"),
            )
            // Garisan sentiasa di bawah penanda kenderaan.
            if (style.getLayer(VEHICLE_LAYER) != null) {
                style.addLayerBelow(line, VEHICLE_LAYER)
            } else {
                style.addLayer(line)
            }
            // Tepi putih di bawah garisan: laluan kelihatan jelas di atas peta gelap, terang dan satelit.
            // Pilihan: jika gagal, garisan biru kekal.
            try {
                style.addLayerBelow(
                    LineLayer(CASING_LAYER, SOURCE).withProperties(
                        lineColor("#FFFFFF"),
                        lineWidth(12.5f),
                        lineOpacity(0.92f),
                        lineCap("round"),
                        lineJoin("round"),
                    ),
                    LAYER,
                )
            } catch (_: Throwable) {
            }
        } else if (feature == null) {
            existing.setGeoJson(FeatureCollection.fromFeatures(emptyList<Feature>()))
        } else {
            existing.setGeoJson(feature)
        }
        appliedRouteVersion = if (mode == "navigating") version else null
    }

    /**
     * Anak panah arah putih di atas laluan, beberapa di hadapan kenderaan. Hanya dihantar semula
     * bila anak panah terdekat bertukar (setiap ~70 m), bukan pada setiap gambar sesi. Semuanya
     * pilihan: apa-apa kegagalan menggugurkan anak panah sahaja.
     */
    private fun drawChevrons(style: Style, session: Map<String, Any?>) {
        try {
            val icon = chevronIcon ?: return
            val navigating = session["mode"] == "navigating"
            var source = style.getSource(CHEVRON_SOURCE) as? GeoJsonSource
            if (source == null) {
                if (!navigating || routeChevrons.isEmpty()) return
                if (style.getImage(CHEVRON) == null) style.addImage(CHEVRON, icon)
                source = GeoJsonSource(CHEVRON_SOURCE)
                style.addSource(source)
                val layer = SymbolLayer(CHEVRON_LAYER, CHEVRON_SOURCE).withProperties(
                    iconImage(CHEVRON),
                    iconRotate(Expression.get("bearing")),
                    iconRotationAlignment(Property.ICON_ROTATION_ALIGNMENT_MAP),
                    iconPitchAlignment(Property.ICON_PITCH_ALIGNMENT_MAP),
                    iconAllowOverlap(true),
                    iconIgnorePlacement(true),
                )
                // Di atas garisan laluan, di bawah penanda kenderaan.
                if (style.getLayer(VEHICLE_LAYER) != null) {
                    style.addLayerBelow(layer, VEHICLE_LAYER)
                } else {
                    style.addLayer(layer)
                }
                chevronCursor = CHEVRON_UNSET
            }
            if (!navigating || routeChevrons.isEmpty()) {
                if (chevronCursor != CHEVRON_CLEARED) {
                    source.setGeoJson(FeatureCollection.fromFeatures(emptyList<Feature>()))
                    chevronCursor = CHEVRON_CLEARED
                }
                return
            }
            val lat = (session["vehicleLat"] as? Number)?.toDouble() ?: return
            val lng = (session["vehicleLng"] as? Number)?.toDouble() ?: return
            val cursor = CarRouteGuide.cursor(routeChevrons, maxOf(chevronCursor, 0), lat, lng)
            if (cursor == chevronCursor) return
            chevronCursor = cursor
            val features = CarRouteGuide.ahead(routeChevrons, cursor).map { c ->
                Feature.fromGeometry(Point.fromLngLat(c.lng, c.lat)).also {
                    it.addNumberProperty("bearing", c.bearing)
                }
            }
            source.setGeoJson(FeatureCollection.fromFeatures(features))
        } catch (_: Throwable) {
        }
    }

    private var vehicleIcons: VehicleIcons? = null

    /** Penanda kenderaan (anak panah ikut arah) atau titik lokasi (browse, arah tidak diketahui). */
    private fun drawVehicle(style: Style, session: Map<String, Any?>) {
        val icons = vehicleIcons ?: return
        val lat = (session["vehicleLat"] as? Number)?.toDouble()
        val lng = (session["vehicleLng"] as? Number)?.toDouble()
        val bearing = (session["vehicleBearing"] as? Number)?.toDouble()
        var source = style.getSource(VEHICLE_SOURCE) as? GeoJsonSource
        if (source == null) {
            if (lat == null || lng == null) return
            if (style.getImage(ARROW) == null) style.addImage(ARROW, icons.arrow)
            if (style.getImage(DOT) == null) style.addImage(DOT, icons.dot)
            source = GeoJsonSource(VEHICLE_SOURCE)
            style.addSource(source)
            style.addLayer(
                SymbolLayer(VEHICLE_LAYER, VEHICLE_SOURCE).withProperties(
                    iconImage(Expression.get("icon")),
                    iconRotate(Expression.get("bearing")),
                    iconRotationAlignment(Property.ICON_ROTATION_ALIGNMENT_MAP),
                    iconPitchAlignment(Property.ICON_PITCH_ALIGNMENT_MAP),
                    iconAllowOverlap(true),
                    iconIgnorePlacement(true),
                ),
            )
        }
        if (lat == null || lng == null) {
            source.setGeoJson(FeatureCollection.fromFeatures(emptyList<Feature>()))
            return
        }
        val feature = Feature.fromGeometry(Point.fromLngLat(lng, lat))
        feature.addStringProperty("icon", if (bearing == null) DOT else ARROW)
        feature.addNumberProperty("bearing", bearing ?: 0.0)
        source.setGeoJson(feature)
    }

    companion object {
        /** Peta kereta yang sedang dipasang (satu sesi kereta pada satu masa). */
        @Volatile
        var current: CarMapSurface? = null
            private set

        private const val PREVIEW_SOURCE = "fgmap-car-preview"
        private const val PREVIEW_LINE = "fgmap-car-preview-line"
        private const val PREVIEW_CASING = "fgmap-car-preview-casing"
        private const val PIN_SOURCE = "fgmap-car-pins"
        private const val PIN_LAYER = "fgmap-car-pin-icons"
        private const val PIN = "fgmap-car-pin-"
        private const val PIN_DEST = "fgmap-car-pin-dest"
        private const val MAX_PIN_NUMBER = 12
        const val SOURCE = "fgmap-car-route"
        const val LAYER = "fgmap-car-route-line"
        const val CASING_LAYER = "fgmap-car-route-casing"
        const val CHEVRON_SOURCE = "fgmap-car-chevron-src"
        const val CHEVRON_LAYER = "fgmap-car-chevrons"
        const val CHEVRON = "fgmap-car-chevron"
        const val CHEVRON_UNSET = -1
        const val CHEVRON_CLEARED = -2
        const val VEHICLE_SOURCE = "fgmap-car-vehicle"
        const val VEHICLE_LAYER = "fgmap-car-vehicle-icon"
        const val ARROW = "fgmap-car-vehicle-arrow"
        const val DOT = "fgmap-car-vehicle-dot"
        const val VEHICLE_SCREEN_FRACTION = 0.68
        const val AUTO_RECENTER_MS = 10_000L
    }
}

/** Ikon kenderaan pada ketumpatan paparan kereta (bukan telefon), supaya saiznya betul di skrin kereta. */
private class VehicleIcons(val arrow: Bitmap, val dot: Bitmap) {
    companion object {
        fun render(density: Float, densityDpi: Int): VehicleIcons {
            val size = (40f * density).toInt().coerceAtLeast(24)
            return VehicleIcons(arrow(size, density, densityDpi), dot(size, density, densityDpi))
        }

        private fun base(size: Int, densityDpi: Int): Pair<Bitmap, Canvas> {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            // Tanpa ini MapLibre menganggap ketumpatan telefon dan ikon menjadi terlalu kecil.
            bitmap.density = densityDpi
            return bitmap to Canvas(bitmap)
        }

        private fun arrow(size: Int, density: Float, densityDpi: Int): Bitmap {
            val (bitmap, canvas) = base(size, densityDpi)
            val c = size / 2f
            val r = size / 2f - 2f * density
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(47, 107, 255) }
            val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(70, 0, 0, 0) }
            canvas.drawCircle(c, c + density, r, shadow)
            canvas.drawCircle(c, c, r, ring)
            canvas.drawCircle(c, c, r - 3f * density, fill)
            // Anak panah menghala ke atas (utara); lapisan memutarnya mengikut arah kenderaan.
            val head = Path().apply {
                moveTo(c, c - r * 0.62f)
                lineTo(c + r * 0.48f, c + r * 0.5f)
                lineTo(c, c + r * 0.22f)
                lineTo(c - r * 0.48f, c + r * 0.5f)
                close()
            }
            canvas.drawPath(head, ring)
            return bitmap
        }

        private fun dot(size: Int, density: Float, densityDpi: Int): Bitmap {
            val (bitmap, canvas) = base(size, densityDpi)
            val c = size / 2f
            val r = size * 0.3f
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(47, 107, 255) }
            val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(60, 47, 107, 255) }
            canvas.drawCircle(c, c, size / 2f - density, halo)
            canvas.drawCircle(c, c, r, ring)
            canvas.drawCircle(c, c, r - 3f * density, fill)
            return bitmap
        }
    }
}

/** Gelembung kelajuan dan papan had, maklumat yang sama seperti SpeedBubble telefon. */
class SpeedOverlay(context: Context) : View(context) {
    var session: Map<String, Any?> = emptyMap()
    var stable: Rect = Rect()

    private val bubble = Paint(Paint.ANTI_ALIAS_FLAG)
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.WHITE
    }
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        color = Color.rgb(198, 40, 40)
    }
    private val signFill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val signText = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.BLACK
    }

    override fun onDraw(canvas: Canvas) {
        val kmh = (session["speedKmh"] as? Number)?.toInt() ?: return
        if (session["mode"] == "browse") return
        val density = resources.displayMetrics.density
        val size = 56f * density
        val pad = 12f * density
        val area = if (stable.width() > 0 && stable.height() > 0) stable else Rect(0, 0, width, height)
        val cx = area.left + pad + size / 2f
        var cy = area.bottom - pad - size / 2f
        val limit = (session["limitKmh"] as? Number)?.toInt()
        if (limit != null && limit > 0) {
            val sign = 46f * density
            val signCy = cy - size / 2f - 8f * density - sign / 2f
            canvas.drawCircle(cx, signCy, sign / 2f, ring)
            canvas.drawCircle(cx, signCy, sign / 2f - 6f * density, signFill)
            signText.textSize = 16f * density
            canvas.drawText(limit.toString(), cx, signCy + 6f * density, signText)
        }
        val over = session["overspeed"] == true
        bubble.color = if (over) Color.rgb(198, 40, 40) else Color.argb(210, 20, 24, 33)
        canvas.drawCircle(cx, cy, size / 2f, bubble)
        text.textSize = 18f * density
        canvas.drawText(kmh.toString(), cx, cy + 4f * density, text)
        text.textSize = 10f * density
        canvas.drawText("km/j", cx, cy + 18f * density, text)
    }
}
