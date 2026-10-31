package com.fguniversalempire.fgmaps

import android.app.Activity
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Kompas sebenar untuk skrin Kiblat. Arah GPS (course) hanya wujud semasa bergerak, jadi telefon yang
 * diam tidak mempunyai arah langsung; di sini arah dibaca daripada sensor orientasi telefon.
 *
 * - Sensor: ROTATION_VECTOR (gabungan magnetometer + giroskop + pecutan, tahan condong dan getaran).
 *   Jika tiada, jatuh kepada pecutan + medan magnet.
 * - Arah dihitung untuk bahagian atas telefon apabila ia hampir mendatar, dan untuk arah belakang
 *   telefon apabila ia hampir tegak (cara kompas kamera), serta diputar ikut orientasi skrin.
 * - Utara benar = utara magnet + deklinasi daripada GeomagneticField (model magnet dalam Android) bagi
 *   lokasi pengguna, dihantar oleh Dart melalui `setLocation`. Tanpa lokasi, utara magnet.
 * - Ketepatan sensor (0 tidak boleh dipercayai … 3 tinggi) dihantar supaya UI boleh meminta kalibrasi
 *   dan tidak mendakwa "tepat" apabila bacaan tidak boleh dipercayai.
 *
 * Tiada kebenaran diperlukan. Sensor hanya berjalan selama ada pendengar aliran.
 */
class CompassBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler, SensorEventListener {

    private val sensors = activity.getSystemService(Activity.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null

    private var declination = 0f
    private var hasLocation = false

    // Laluan sandaran (tanpa ROTATION_VECTOR).
    private var gravity: FloatArray? = null
    private var magnetic: FloatArray? = null
    private var magneticAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE

    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)
    private val orientation = FloatArray(3)
    private var lastEmitMs = 0L

    init {
        EventChannel(messenger, EVENTS).setStreamHandler(this)
        MethodChannel(messenger, CONTROL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLocation" -> {
                    val lat = (call.argument<Double>("lat") ?: 0.0).toFloat()
                    val lng = (call.argument<Double>("lng") ?: 0.0).toFloat()
                    val alt = (call.argument<Double>("alt") ?: 0.0).toFloat()
                    declination = GeomagneticField(lat, lng, alt, System.currentTimeMillis()).declination
                    hasLocation = true
                    result.success(declination.toDouble())
                }
                "isAvailable" -> result.success(hasAnySensor())
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAnySensor() =
        sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null ||
            (sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null &&
                sensors.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        gravity = null
        magnetic = null
        val rv = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (rv != null) {
            sensors.registerListener(this, rv, SensorManager.SENSOR_DELAY_GAME)
            return
        }
        val acc = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val mag = sensors.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (acc == null || mag == null) {
            events.success(mapOf("unavailable" to true))
            return
        }
        sensors.registerListener(this, acc, SensorManager.SENSOR_DELAY_GAME)
        sensors.registerListener(this, mag, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) magneticAccuracy = accuracy
    }

    override fun onSensorChanged(event: SensorEvent) {
        val accuracy: Int
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(rotation, event.values)
                accuracy = event.accuracy
            }
            Sensor.TYPE_ACCELEROMETER -> {
                gravity = lowPass(gravity, event.values)
                return emitFromRaw()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                magnetic = lowPass(magnetic, event.values)
                magneticAccuracy = event.accuracy
                return emitFromRaw()
            }
            else -> return
        }
        emit(accuracy)
    }

    private fun emitFromRaw() {
        val g = gravity ?: return
        val m = magnetic ?: return
        if (!SensorManager.getRotationMatrix(rotation, null, g, m)) return
        emit(magneticAccuracy)
    }

    private fun emit(accuracy: Int) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmitMs < MIN_INTERVAL_MS) return
        lastEmitMs = now
        val out = sink ?: return

        // 1) Orientasi skrin: dapatkan paksi X/Y peranti seperti yang pengguna lihat.
        var axisX = SensorManager.AXIS_X
        var axisY = SensorManager.AXIS_Y
        when (displayRotation()) {
            Surface.ROTATION_90 -> {
                axisX = SensorManager.AXIS_Y
                axisY = SensorManager.AXIS_MINUS_X
            }
            Surface.ROTATION_180 -> {
                axisX = SensorManager.AXIS_MINUS_X
                axisY = SensorManager.AXIS_MINUS_Y
            }
            Surface.ROTATION_270 -> {
                axisX = SensorManager.AXIS_MINUS_Y
                axisY = SensorManager.AXIS_X
            }
        }
        SensorManager.remapCoordinateSystem(rotation, axisX, axisY, remapped)
        SensorManager.getOrientation(remapped, orientation)
        var azimuth = orientation[0]

        // 2) Telefon hampir tegak (pitch > ~57°): arah atas menghala ke langit dan tidak bermakna, jadi
        //    guna arah belakang telefon (cara kompas kamera).
        if (Math.abs(orientation[1]) > UPRIGHT_PITCH_RAD) {
            SensorManager.remapCoordinateSystem(remapped, SensorManager.AXIS_X, SensorManager.AXIS_Z, rotation)
            SensorManager.getOrientation(rotation, orientation)
            azimuth = orientation[0]
        }

        val magneticDeg = ((Math.toDegrees(azimuth.toDouble()) + 360.0) % 360.0)
        val trueDeg = (magneticDeg + declination + 360.0) % 360.0
        out.success(
            mapOf(
                "heading" to trueDeg,
                "magnetic" to magneticDeg,
                "declination" to declination.toDouble(),
                "trueNorth" to hasLocation,
                "accuracy" to accuracy.coerceIn(0, 3),
            ),
        )
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int =
        try {
            activity.windowManager.defaultDisplay.rotation
        } catch (_: Exception) {
            Surface.ROTATION_0
        }

    private fun lowPass(prev: FloatArray?, next: FloatArray): FloatArray {
        val out = prev ?: next.clone()
        for (i in 0..2) out[i] = out[i] + ALPHA * (next[i] - out[i])
        return out
    }

    private companion object {
        const val EVENTS = "com.fguniversalempire.fgmaps/heading"
        const val CONTROL = "com.fguniversalempire.fgmaps/heading_ctl"
        const val MIN_INTERVAL_MS = 30L
        const val ALPHA = 0.25f
        const val UPRIGHT_PITCH_RAD = 1.0f
    }
}
