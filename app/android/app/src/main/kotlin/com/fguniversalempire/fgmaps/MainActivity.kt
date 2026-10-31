package com.fguniversalempire.fgmaps

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.fguniversalempire.fgmaps.car.CarBridge
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (masih FlutterActivity): kawalan skrin kunci/notifikasi media untuk Muzik.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CarBridge.attach(flutterEngine.dartExecutor.binaryMessenger)
        // Pintasan ke tetapan sistem untuk Waktu Azan: notifikasi app dan pengecualian bateri.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> result.success(
                        launch(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        ),
                    )
                    "openBatterySettings" -> result.success(
                        launch(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)),
                    )
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                                pm.isIgnoringBatteryOptimizations(packageName),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Buka skrin tetapan; jika peranti tiada skrin itu, buka butiran app sebagai ganti. */
    private fun launch(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", packageName, null)),
                )
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private companion object {
        const val SYSTEM_CHANNEL = "com.fguniversalempire.fgmaps/system"
    }
}
