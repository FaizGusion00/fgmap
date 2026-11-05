package com.fguniversalempire.fgmaps

import android.app.ActivityManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.speech.tts.TextToSpeech
import com.fguniversalempire.fgmaps.car.CarBridge
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (masih FlutterActivity): kawalan skrin kunci/notifikasi media untuk Muzik.
class MainActivity : AudioServiceActivity() {
    private var compass: CompassBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CarBridge.attach(flutterEngine.dartExecutor.binaryMessenger)
        // Kompas sensor sebenar untuk Kiblat (arah GPS tidak wujud ketika telefon diam).
        compass = CompassBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // Maklumat peranti untuk Mod Lite: RAM keseluruhan, bendera "RAM rendah" sistem dan bilangan teras.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "deviceInfo") {
                    val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                    val mem = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                    result.success(
                        mapOf(
                            "totalMemBytes" to mem.totalMem,
                            "lowRamDevice" to am.isLowRamDevice,
                            "cores" to Runtime.getRuntime().availableProcessors(),
                            "sdk" to Build.VERSION.SDK_INT,
                        ),
                    )
                } else {
                    result.notImplemented()
                }
            }
        // Pintasan ke tetapan sistem untuk Waktu Azan: notifikasi app dan pengecualian bateri.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> result.success(
                        launchFirst(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        ),
                    )
                    // Senarai pengoptimuman bateri. Senarai ini lalai menapis "Not optimized" sehingga
                    // FGMaps (yang dioptimumkan secara lalai) tidak kelihatan; sebab itu
                    // `requestIgnoreBatteryOptimizations` diutamakan di UI.
                    "openBatterySettings" -> result.success(
                        launchFirst(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)),
                    )
                    // Dialog sistem terus untuk FGMaps sahaja: "Benarkan app sentiasa berjalan di latar
                    // belakang?". Tanpa pengecualian ini, sesetengah telefon mematikan app yang ditutup
                    // dan azan tidak berbunyi. Jika dialog tidak tersedia, buka senarai, kemudian
                    // butiran app.
                    "requestIgnoreBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                                pm.isIgnoringBatteryOptimizations(packageName)
                            ) {
                                true
                            } else {
                                launchFirst(
                                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                        .setData(Uri.parse("package:$packageName")),
                                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                                )
                            },
                        )
                    }
                    "openAppSettings" -> result.success(launchFirst())
                    // Suara navigasi offline: skrin muat turun data suara enjin TTS (Google: pilih
                    // "Melayu"), kemudian tetapan TTS sistem jika skrin itu tiada.
                    "openTtsSettings" -> result.success(
                        launchFirst(
                            Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
                            Intent("com.android.settings.TTS_SETTINGS"),
                        ),
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

    /**
     * Buka skrin pertama yang berjaya daripada [intents]; jika semuanya gagal (peranti tiada skrin itu),
     * buka butiran app sebagai pilihan terakhir.
     */
    private fun launchFirst(vararg intents: Intent): Boolean {
        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // cuba yang seterusnya
            }
        }
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.fromParts("package", packageName, null)),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val SYSTEM_CHANNEL = "com.fguniversalempire.fgmaps/system"
        const val DEVICE_CHANNEL = "com.fguniversalempire.fgmaps/device"
    }
}
