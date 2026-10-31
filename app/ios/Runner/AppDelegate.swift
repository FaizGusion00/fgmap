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
  }
}
