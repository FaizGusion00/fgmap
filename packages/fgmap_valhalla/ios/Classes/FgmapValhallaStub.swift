import Flutter

/// Sandaran CocoaPods: dipakai HANYA apabila Swift Package Manager dimatikan. valhalla-mobile tersedia
/// melalui SwiftPM sahaja, jadi laluan ini tidak mempunyai enjin offline: semua panggilan dijawab "tidak
/// dilaksanakan" (Dart menukarnya kepada ValhallaEngineException('unsupported') dan app jatuh balik ke
/// laluan online). Pelaksanaan sebenar: ios/fgmap_valhalla/Sources/fgmap_valhalla/FgmapValhallaPlugin.swift.
public class FgmapValhallaPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fgmap_valhalla", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FgmapValhallaPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}
