package com.fguniversalempire.fgmaps.car

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface

/**
 * Pin peta kereta, dilukis pada ketumpatan skrin kereta: pin bernombor (sepadan dengan nombor baris
 * senarai) dan pin destinasi bagi pratonton laluan. Gaya sama seperti pin telefon: titisan berwarna
 * dengan tepi putih dan bayang lembut, supaya jelas di atas peta cerah, gelap dan satelit.
 */
internal object CarPins {
    private val accent = Color.rgb(47, 107, 255)
    private val destination = Color.rgb(229, 57, 53)

    fun numbered(n: Int, density: Float, densityDpi: Int): Bitmap =
        draw(accent, n.toString(), density, densityDpi)

    fun destination(density: Float, densityDpi: Int): Bitmap =
        draw(destination, null, density, densityDpi)

    private fun draw(fill: Int, label: String?, density: Float, densityDpi: Int): Bitmap {
        val w = (34f * density).toInt().coerceAtLeast(20)
        val h = (44f * density).toInt().coerceAtLeast(26)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        if (densityDpi > 0) bitmap.density = densityDpi
        val canvas = Canvas(bitmap)
        val cx = w / 2f
        val r = w / 2f - 2f * density
        val cy = r + 2f * density
        val tip = h - 2f * density
        fun drop(radius: Float, dy: Float): Path = Path().apply {
            addArc(RectF(cx - radius, cy - radius + dy, cx + radius, cy + radius + dy), 150f, 240f)
            lineTo(cx, tip + dy - (r - radius))
            close()
        }
        val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(70, 0, 0, 0) }
        canvas.drawPath(drop(r, 1.5f * density), shadow)
        canvas.drawPath(drop(r, 0f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        canvas.drawPath(drop(r - 2.5f * density, 0f), Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill })
        if (label != null) {
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textAlign = Paint.Align.CENTER
                typeface = Typeface.DEFAULT_BOLD
                textSize = (if (label.length > 1) 13f else 15f) * density
            }
            canvas.drawText(label, cx, cy - (text.descent() + text.ascent()) / 2f, text)
        } else {
            canvas.drawCircle(cx, cy, r * 0.36f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        }
        return bitmap
    }
}
