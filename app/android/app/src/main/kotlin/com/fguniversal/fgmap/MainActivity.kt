package com.fguniversal.fgmap

import com.fguniversal.fgmap.car.CarBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CarBridge.attach(flutterEngine.dartExecutor.binaryMessenger)
    }
}
