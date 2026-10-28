package com.fguniversal.fgmap.car

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.os.Bundle
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
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.PropertyFactory.lineCap
import org.maplibre.android.style.layers.PropertyFactory.lineColor
import org.maplibre.android.style.layers.PropertyFactory.lineJoin
import org.maplibre.android.style.layers.PropertyFactory.lineWidth
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import android.app.Presentation

/**
 * MapLibre pada permukaan Android Auto. Pose datang daripada sesi Flutter, bukan GPS kedua.
 * Kelajuan dan papan had dilukis di atas peta, dalam kawasan yang tidak ditutup templat.
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
    private var appliedStyleKey: String? = null
    private var appliedRouteVersion: Int? = null
    private var lastSession: Map<String, Any?> = emptyMap()

    fun attach() {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(this)
    }

    fun detach() {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(null)
        destroyMap()
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
                drawRoute(it, session)
            }
        } else {
            map.style?.let { drawRoute(it, session) }
        }
        if (session["following"] != false) moveCamera(map, session)
        overlay?.session = session
        overlay?.stable = stable
        overlay?.invalidate()
    }

    override fun onSurfaceAvailable(container: SurfaceContainer) {
        val surface = container.surface ?: return
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
                view.getMapAsync { ready ->
                    map = ready
                    ready.uiSettings.setAllGesturesEnabled(false)
                    ready.uiSettings.isLogoEnabled = false
                    ready.uiSettings.isAttributionEnabled = false
                    apply(lastSession)
                }
            }
        }
        presentation = host
        host.show()
    }

    override fun onVisibleAreaChanged(visibleArea: Rect) {
        stable.set(visibleArea)
        overlay?.stable = stable
        overlay?.invalidate()
    }

    override fun onStableAreaChanged(stableArea: Rect) {
        stable.set(stableArea)
        overlay?.stable = stable
        overlay?.invalidate()
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
    }

    private fun moveCamera(map: MapLibreMap, session: Map<String, Any?>) {
        val lat = (session["lat"] as? Number)?.toDouble() ?: return
        val lng = (session["lng"] as? Number)?.toDouble() ?: return
        val position = CameraPosition.Builder()
            .target(LatLng(lat, lng))
            .zoom((session["zoom"] as? Number)?.toDouble() ?: 16.0)
            .tilt((session["tilt"] as? Number)?.toDouble() ?: 0.0)
            .bearing((session["bearing"] as? Number)?.toDouble() ?: 0.0)
            .build()
        map.moveCamera(CameraUpdateFactory.newCameraPosition(position))
    }

    private fun drawRoute(style: Style, session: Map<String, Any?>) {
        val version = (session["routeVersion"] as? Number)?.toInt() ?: 0
        val mode = session["mode"] as? String
        if (mode == "navigating" && version == appliedRouteVersion && style.getSource(SOURCE) != null) {
            return
        }
        val route = session["route"] as? List<*>
        val points = mutableListOf<Point>()
        if (mode == "navigating" && route != null) {
            for (item in route) {
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
        val existing = style.getSource(SOURCE) as? GeoJsonSource
        if (existing == null) {
            if (feature == null) return
            style.addSource(GeoJsonSource(SOURCE, feature))
            style.addLayer(
                LineLayer(LAYER, SOURCE).withProperties(
                    lineColor("#2F6BFF"),
                    lineWidth(6f),
                    lineCap("round"),
                    lineJoin("round"),
                ),
            )
        } else if (feature == null) {
            existing.setGeoJson(FeatureCollection.fromFeatures(emptyList<Feature>()))
        } else {
            existing.setGeoJson(feature)
        }
        appliedRouteVersion = if (mode == "navigating") version else null
    }

    private companion object {
        const val SOURCE = "fgmap-car-route"
        const val LAYER = "fgmap-car-route-line"
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
