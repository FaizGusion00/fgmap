package com.fguniversalempire.fgmaps

import com.fguniversalempire.fgmaps.car.CarBridge
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

// AudioServiceActivity (masih FlutterActivity): kawalan skrin kunci/notifikasi media untuk Muzik.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CarBridge.attach(flutterEngine.dartExecutor.binaryMessenger)
    }
}
