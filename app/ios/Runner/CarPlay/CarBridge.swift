import CoreLocation
import Flutter
import Foundation

/// Satu sesi antara Flutter dan CarPlay. Peta kereta tidak membuka GPS sendiri.
///
/// Cermin `CarBridge.kt` (Android Auto): saluran, nama kaedah dan bentuk muatan SAMA.
/// Flutter -> native: `session`. Native -> Flutter: `search`, `openPlace`, `endNavigation`,
/// `recenter`, `pan`. Kontrak ini diuji di Dart: test/features/navigation/carplay_channel_test.dart.
final class CarBridge {
  static let channelName = "com.fguniversalempire.fgmaps/car"

  static let shared = CarBridge()

  /// Nama kaedah (mesti sama dengan `car_session_hub.dart` dan `CarBridge.kt`).
  enum Method {
    static let session = "session"
    static let search = "search"
    static let openPlace = "openPlace"
    static let endNavigation = "endNavigation"
    static let recenter = "recenter"
    static let pan = "pan"
  }

  /// Dihidupkan apabila enjin Flutter sedia (AppDelegate). Sebelum itu CarPlay paparkan "buka telefon".
  private(set) var ready = false

  /// Gambar sesi terkini. `route` hanya dihantar apabila `routeVersion` berubah, jadi disimpan di sini.
  private(set) var session: [String: Any] = [:]
  private(set) var route: [CLLocationCoordinate2D] = []

  /// Dipanggil pada thread utama setiap kali Flutter menolak `session`.
  var onSession: (([String: Any]) -> Void)?

  private var channel: FlutterMethodChannel?

  private init() {}

  func attach(messenger: FlutterBinaryMessenger) {
    let method = FlutterMethodChannel(name: CarBridge.channelName, binaryMessenger: messenger)
    channel = method
    ready = true
    method.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      if call.method == Method.session {
        let map = (call.arguments as? [String: Any]) ?? [:]
        self.merge(map)
        self.onSession?(self.session)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    // Sambungan CarPlay mungkin tiba sebelum enjin sedia: beritahu pendengar supaya muat semula.
    onSession?(session)
  }

  /// Flutter hanya menghantar `route` / `style` bila berubah (lihat CarSessionSnapshot.toMap);
  /// kekalkan nilai lama supaya rangka seterusnya tidak mengosongkannya.
  private func merge(_ map: [String: Any]) {
    var next = map
    if let rows = map["route"] as? [Any] {
      route = rows.compactMap { row in
        guard let pair = row as? [Any], pair.count >= 2,
          let lat = (pair[0] as? NSNumber)?.doubleValue,
          let lng = (pair[1] as? NSNumber)?.doubleValue
        else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
      }
    } else if (map["mode"] as? String) != "navigating" {
      route = []
    }
    next.removeValue(forKey: "route")
    session = next
  }

  // MARK: - Native -> Flutter

  func search(_ query: String, callback: @escaping ([CarPlace]) -> Void) {
    guard let channel else {
      callback([])
      return
    }
    channel.invokeMethod(Method.search, arguments: ["query": query]) { result in
      guard let rows = result as? [Any] else {
        callback([])
        return
      }
      callback(
        rows.compactMap { row in
          guard let map = row as? [String: Any],
            let lat = (map["lat"] as? NSNumber)?.doubleValue,
            let lng = (map["lng"] as? NSNumber)?.doubleValue
          else { return nil }
          return CarPlace(
            name: (map["name"] as? String) ?? "",
            subtitle: (map["subtitle"] as? String) ?? "",
            lat: lat,
            lng: lng
          )
        })
    }
  }

  /// `callback(nil)` = berjaya; selainnya kod ralat (`no-location`, `no-route`, `unavailable`).
  func openPlace(_ place: CarPlace, callback: @escaping (String?) -> Void) {
    guard let channel else {
      callback("unavailable")
      return
    }
    channel.invokeMethod(
      Method.openPlace,
      arguments: [
        "name": place.name,
        "subtitle": place.subtitle,
        "lat": place.lat,
        "lng": place.lng,
      ]
    ) { result in
      if let error = result as? FlutterError {
        callback(error.message ?? error.code)
      } else if let object = result as? NSObject, object === FlutterMethodNotImplemented {
        callback("unavailable")
      } else {
        callback(result as? String)
      }
    }
  }

  func endNavigation() {
    channel?.invokeMethod(Method.endNavigation, arguments: nil)
  }

  func recenter() {
    channel?.invokeMethod(Method.recenter, arguments: nil)
  }

  func pan() {
    channel?.invokeMethod(Method.pan, arguments: nil)
  }
}

struct CarPlace {
  let name: String
  let subtitle: String
  let lat: Double
  let lng: Double
}
