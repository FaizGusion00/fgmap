package com.fguniversalempire.fgmaps.car

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import org.maplibre.geojson.Point
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Anak panah arah pada laluan di peta Android Auto, sama seperti di telefon: titik tetap pada jalan
 * (kelipatan jarak laluan, bukan relatif kepada kenderaan) supaya tidak "berjalan" bersama kereta,
 * hanya beberapa di hadapan kenderaan. Logik tulen (tanpa MapLibre) supaya mudah disemak.
 */
object CarRouteGuide {
    /** Jarak antara anak panah (m). */
    const val SPACING_M = 70.0

    /** Bilangan anak panah di hadapan kenderaan yang dilukis (~840 m). */
    const val AHEAD = 12

    /** Tetingkap carian kedudukan kenderaan: sedikit ke belakang, jauh ke hadapan (indeks anak panah). */
    private const val BACK_WINDOW = 4
    private const val FORWARD_WINDOW = 160

    /** Had kasar supaya laluan sangat panjang tidak memakan memori kereta. */
    private const val MAX_CHEVRONS = 8000

    class Chevron(val lng: Double, val lat: Double, val bearing: Double)

    private const val EARTH_M = 6_371_000.0

    private fun rad(deg: Double) = Math.toRadians(deg)

    private fun distanceM(aLat: Double, aLng: Double, bLat: Double, bLng: Double): Double {
        val dLat = rad(bLat - aLat)
        val dLng = rad(bLng - aLng)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(rad(aLat)) * cos(rad(bLat)) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * EARTH_M * Math.asin(min(1.0, sqrt(h)))
    }

    /** Arah (darjah, 0 = utara, ikut jam) dari a ke b. */
    fun bearing(aLat: Double, aLng: Double, bLat: Double, bLng: Double): Double {
        val lat1 = rad(aLat)
        val lat2 = rad(bLat)
        val dLng = rad(bLng - aLng)
        val y = sin(dLng) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        return (Math.toDegrees(atan2(y, x)) + 360.0) % 360.0
    }

    /** Anak panah sepanjang [points] setiap [SPACING_M] meter; tidak di 20 m terakhir laluan. */
    fun chevrons(points: List<Point>): List<Chevron> {
        if (points.size < 2) return emptyList()
        val out = ArrayList<Chevron>()
        var next = SPACING_M
        var travelled = 0.0
        for (i in 1 until points.size) {
            val a = points[i - 1]
            val b = points[i]
            val seg = distanceM(a.latitude(), a.longitude(), b.latitude(), b.longitude())
            if (seg <= 0.0) continue
            val dir = bearing(a.latitude(), a.longitude(), b.latitude(), b.longitude())
            while (travelled + seg >= next) {
                val t = (next - travelled) / seg
                out.add(
                    Chevron(
                        lng = a.longitude() + (b.longitude() - a.longitude()) * t,
                        lat = a.latitude() + (b.latitude() - a.latitude()) * t,
                        bearing = dir,
                    ),
                )
                if (out.size >= MAX_CHEVRONS) return out
                next += SPACING_M
            }
            travelled += seg
        }
        // Anak panah yang menuding ke luar laluan di hujung mengelirukan.
        while (out.isNotEmpty() && travelled - lastTravel(out.size) < 20.0) out.removeAt(out.size - 1)
        return out
    }

    private fun lastTravel(count: Int) = count * SPACING_M

    /**
     * Indeks anak panah paling hampir dengan kenderaan, dicari dalam tetingkap sekitar [from] supaya
     * kosnya tetap kecil dan kenderaan tidak "melompat" ke bahagian lain laluan yang berselang.
     */
    fun cursor(chevrons: List<Chevron>, from: Int, lat: Double, lng: Double): Int {
        if (chevrons.isEmpty()) return 0
        val lo = max(0, from - BACK_WINDOW)
        val hi = min(chevrons.size - 1, from + FORWARD_WINDOW)
        if (lo > hi) return chevrons.size - 1
        var best = lo
        var bestD = Double.MAX_VALUE
        for (i in lo..hi) {
            val c = chevrons[i]
            val d = distanceM(lat, lng, c.lat, c.lng)
            if (d < bestD) {
                bestD = d
                best = i
            }
        }
        return best
    }

    /** Anak panah di hadapan kenderaan bagi [cursor]: dari selepas yang terdekat. */
    fun ahead(chevrons: List<Chevron>, cursor: Int): List<Chevron> {
        val start = cursor + 1
        if (start >= chevrons.size) return emptyList()
        return chevrons.subList(start, min(chevrons.size, start + AHEAD))
    }

    /** Ikon anak panah pada ketumpatan paparan kereta; menuding ke atas (utara) sebelum diputar peta. */
    fun icon(density: Float, densityDpi: Int): Bitmap {
        val size = (30f * density).toInt().coerceAtLeast(18)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        // Tanpa ini MapLibre menganggap ketumpatan telefon dan ikon menjadi terlalu kecil.
        bitmap.density = densityDpi
        val canvas = Canvas(bitmap)
        val s = size.toFloat()
        val path = Path().apply {
            moveTo(s * 0.5f, s * 0.16f)
            lineTo(s * 0.86f, s * 0.56f)
            lineTo(s * 0.72f, s * 0.7f)
            lineTo(s * 0.5f, s * 0.46f)
            lineTo(s * 0.28f, s * 0.7f)
            lineTo(s * 0.14f, s * 0.56f)
            close()
        }
        val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(110, 0, 0, 0)
            style = Paint.Style.STROKE
            strokeWidth = 2.2f * density
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(path, outline)
        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        return bitmap
    }
}
