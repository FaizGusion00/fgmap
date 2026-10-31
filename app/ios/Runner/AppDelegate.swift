import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Saluran kereta (CarPlay) sama dengan Android Auto. Tanpa entitlement CarPlay, adegan kereta
    // tidak pernah dicipta; jambatan ini kekal tidur dan tidak menjejaskan app.
    CarBridge.shared.attach(messenger: engineBridge.applicationRegistrar.messenger())
    // Kompas sensor sebenar untuk skrin Kiblat (arah GPS tidak wujud ketika telefon diam).
    CompassBridge.shared.attach(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Kompas untuk skrin Kiblat melalui CoreLocation heading. `trueHeading` sudah mengambil kira
/// deklinasi magnet (utara benar); jika tidak tersedia, jatuh semula kepada utara magnet dan ditandakan
/// `trueNorth: false`. `headingAccuracy` (darjah) dipetakan kepada 0–3 seperti Android. Sensor hanya
/// berjalan selama ada pendengar aliran.
final class CompassBridge: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  static let shared = CompassBridge()

  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  func attach(messenger: FlutterBinaryMessenger) {
    FlutterEventChannel(name: "com.fguniversalempire.fgmaps/heading", binaryMessenger: messenger)
      .setStreamHandler(self)
    FlutterMethodChannel(
      name: "com.fguniversalempire.fgmaps/heading_ctl", binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "setLocation": result(0.0)  // trueHeading sudah mengambil kira deklinasi
      case "isAvailable": result(CLLocationManager.headingAvailable())
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    guard CLLocationManager.headingAvailable() else {
      events(["unavailable": true])
      return nil
    }
    sink = events
    manager.delegate = self
    manager.headingFilter = 1
    // trueHeading memerlukan lokasi; ketepatan kasar sahaja untuk menjimatkan bateri.
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    manager.startUpdatingLocation()
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    manager.stopUpdatingHeading()
    manager.stopUpdatingLocation()
    sink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let acc = newHeading.headingAccuracy
    let level: Int
    if acc < 0 {
      level = 0
    } else if acc <= 10 {
      level = 3
    } else if acc <= 20 {
      level = 2
    } else if acc <= 35 {
      level = 1
    } else {
      level = 0
    }
    let trueOk = newHeading.trueHeading >= 0
    sink?([
      "heading": trueOk ? newHeading.trueHeading : newHeading.magneticHeading,
      "magnetic": newHeading.magneticHeading,
      "trueNorth": trueOk,
      "accuracy": level,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    true
  }
}
