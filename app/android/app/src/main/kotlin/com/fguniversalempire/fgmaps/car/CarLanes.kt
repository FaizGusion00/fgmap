package com.fguniversalempire.fgmaps.car

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.car.app.model.CarIcon
import androidx.car.app.navigation.model.Lane
import androidx.car.app.navigation.model.LaneDirection
import androidx.car.app.navigation.model.Step
import androidx.core.graphics.drawable.IconCompat
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Lorong untuk skrin Android Auto. Hanya data lorong SEBENAR dihantar oleh Dart (UI lorong kereta
 * tiada label "anggaran"), setiap lorong dengan senarai arah dan arah yang disyorkan.
 *
 * Hos memerlukan imej lorong bersama senarai lorong, jadi imej dilukis di sini dengan reka bentuk
 * yang sama seperti telefon: lorong disyorkan disorot biru, arah lain dimalapkan. Apa-apa kegagalan
 * (data pelik, bitmap) menggugurkan lorong sahaja; langkah manuver dan teks kekal.
 */
object CarLanes {
    private const val CELL = 96
    private const val HEIGHT = 112
    private const val MAX_LANES = 8

    private val shapes = mapOf(
        "through" to LaneDirection.SHAPE_STRAIGHT,
        "slightLeft" to LaneDirection.SHAPE_SLIGHT_LEFT,
        "left" to LaneDirection.SHAPE_NORMAL_LEFT,
        "sharpLeft" to LaneDirection.SHAPE_SHARP_LEFT,
        "slightRight" to LaneDirection.SHAPE_SLIGHT_RIGHT,
        "right" to LaneDirection.SHAPE_NORMAL_RIGHT,
        "sharpRight" to LaneDirection.SHAPE_SHARP_RIGHT,
        // Lalu lintas sebelah kiri: pusingan U dibuat ke kanan.
        "reverse" to LaneDirection.SHAPE_U_TURN_RIGHT,
    )

    /** Sudut dari lurus (darjah, positif = kanan) untuk melukis setiap arah. */
    private val angles = mapOf(
        "through" to 0f,
        "slightLeft" to -38f,
        "left" to -90f,
        "sharpLeft" to -135f,
        "slightRight" to 38f,
        "right" to 90f,
        "sharpRight" to 135f,
    )

    private class ParsedLane(val arrows: List<String>, val recommended: Boolean, val highlighted: Set<String>)

    /** Tambah lorong pada [step]; benar jika lorong berjaya ditambah. */
    fun apply(step: Step.Builder, raw: Any?): Boolean {
        val lanes = parse(raw)
        if (lanes.size < 2) return false
        return try {
            val image = CarIcon.Builder(IconCompat.createWithBitmap(render(lanes))).build()
            for (lane in lanes) {
                val builder = Lane.Builder()
                for (arrow in lane.arrows) {
                    val shape = shapes[arrow] ?: continue
                    // Arah disyorkan: yang ditonjolkan; jika lorong disyorkan tanpa arah khusus,
                    // semua arahnya.
                    val recommended = lane.recommended &&
                        (lane.highlighted.isEmpty() || arrow in lane.highlighted)
                    builder.addDirection(LaneDirection.create(shape, recommended))
                }
                step.addLane(builder.build())
            }
            step.setLanesImage(image)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun parse(raw: Any?): List<ParsedLane> {
        val list = raw as? List<*> ?: return emptyList()
        if (list.size > MAX_LANES) return emptyList()
        val out = ArrayList<ParsedLane>(list.size)
        for (item in list) {
            val map = item as? Map<*, *> ?: return emptyList()
            val arrows = (map["arrows"] as? List<*>)
                ?.mapNotNull { it as? String }
                ?.filter { shapes.containsKey(it) }
                .orEmpty()
            // Lorong tanpa arah yang dikenali tidak boleh dilukis; buang semua daripada tersalah.
            if (arrows.isEmpty()) return emptyList()
            val highlighted = (map["highlighted"] as? List<*>)
                ?.mapNotNull { it as? String }
                ?.toSet()
                .orEmpty()
            out.add(ParsedLane(arrows, map["recommended"] == true, highlighted))
        }
        return out
    }

    private fun render(lanes: List<ParsedLane>): Bitmap {
        val bitmap = Bitmap.createBitmap(CELL * lanes.size, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val road = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF2A3342.toInt() }
        val highlight = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF4F8FDF.toInt() }
        val divider = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xCCFFFFFF.toInt()
            strokeWidth = 3f
        }
        for ((i, lane) in lanes.withIndex()) {
            val x = (i * CELL).toFloat()
            val rect = RectF(x + 2f, 2f, x + CELL - 2f, HEIGHT - 2f)
            canvas.drawRoundRect(rect, 10f, 10f, if (lane.recommended) highlight else road)
            if (i > 0) {
                var y = 8f
                while (y < HEIGHT - 8f) {
                    canvas.drawLine(x, y, x, y + 8f, divider)
                    y += 16f
                }
            }
            drawArrows(canvas, x + CELL / 2f, HEIGHT - 14f, lane)
        }
        return bitmap
    }

    private fun drawArrows(canvas: Canvas, cx: Float, bottom: Float, lane: ParsedLane) {
        val h = HEIGHT * 0.72f
        val t = 9f
        val bright = 0xFFFFFFFF.toInt()
        val faded = 0x73FFFFFF
        val idle = 0xB0FFFFFF.toInt()
        val hasThrough = "through" in lane.arrows
        val turnY = bottom - h * (if (hasThrough) 0.5f else 0.46f)
        fun stroke(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = t
            strokeCap = Paint.Cap.BUTT
        }
        canvas.drawLine(cx, bottom, cx, turnY, stroke(if (lane.recommended) bright else idle))
        // Hanya arah yang disyorkan menyala dalam lorong yang disyorkan; lain dimalapkan.
        val reach = CELL * 0.34f
        for (arrow in lane.arrows) {
            val on = lane.recommended && (lane.highlighted.isEmpty() || arrow in lane.highlighted)
            val color = if (!lane.recommended) idle else if (on) bright else faded
            val line = stroke(color)
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
            if (arrow == "reverse") {
                drawUTurn(canvas, cx, bottom, h, line, fill, t)
                continue
            }
            val deg = angles[arrow] ?: continue
            val rad = deg * PI.toFloat() / 180f
            val dx = sin(rad)
            val dy = -cos(rad)
            val endX: Float
            val endY: Float
            if (arrow == "through") {
                endX = cx
                endY = bottom - h
            } else {
                // Sisi dihad supaya anak panah belok tidak keluar daripada lorong.
                val len = minOf(h * 0.42f, reach / maxOf(0.01f, kotlin.math.abs(dx)))
                endX = cx + dx * len
                endY = turnY + dy * len * (if (kotlin.math.abs(deg) > 100f) 1f else 0.9f)
            }
            val head = t * 2.6f
            canvas.drawLine(cx, turnY, endX - dx * head * 0.9f, endY - dy * head * 0.9f, line)
            drawHead(canvas, endX, endY, dx, dy, head, fill)
        }
    }

    private fun drawHead(canvas: Canvas, x: Float, y: Float, dx: Float, dy: Float, len: Float, paint: Paint) {
        val sx = -dy
        val sy = dx
        val bx = x - dx * len
        val by = y - dy * len
        val path = Path().apply {
            moveTo(x, y)
            lineTo(bx + sx * len * 0.75f, by + sy * len * 0.75f)
            lineTo(bx - sx * len * 0.75f, by - sy * len * 0.75f)
            close()
        }
        canvas.drawPath(path, paint)
    }

    private fun drawUTurn(canvas: Canvas, cx: Float, bottom: Float, h: Float, line: Paint, fill: Paint, t: Float) {
        val r = h * 0.2f
        val top = bottom - h * 0.74f
        val left = cx - r
        val path = Path().apply {
            moveTo(left, bottom - h * 0.42f)
            lineTo(left, top + r)
            arcTo(RectF(left, top, left + r * 2f, top + r * 2f), 180f, 180f)
            lineTo(left + r * 2f, top + r * 1.9f)
        }
        canvas.drawPath(path, line)
        drawHead(canvas, left + r * 2f, top + r * 1.9f + t * 2.6f, 0f, 1f, t * 2.6f, fill)
    }
}
