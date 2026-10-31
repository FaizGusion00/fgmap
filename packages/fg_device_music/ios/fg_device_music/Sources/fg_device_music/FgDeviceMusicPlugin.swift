import Flutter
import MediaPlayer
import UIKit

/// Jambatan senarai lagu pada iPhone (MPMediaLibrary). Saluran `fgmaps/device_music`:
/// `access` | `request` -> "notDetermined" | "denied" | "authorized";
/// `list` -> senarai {id, title, artist?, durationMs, uri}. Hanya metadata dibaca. Lagu Apple Music
/// yang dimuat turun atau berada di awan tidak mempunyai `assetURL` (DRM), jadi dilangkau: hanya lagu
/// yang disalin/dibeli tanpa DRM boleh dimain oleh pemain audio app.
/// Kebenaran tidak pernah diminta tanpa panggilan `request`.
public final class FgDeviceMusicPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "fgmaps/device_music", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FgDeviceMusicPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "access":
      result(Self.name(MPMediaLibrary.authorizationStatus()))
    case "request":
      MPMediaLibrary.requestAuthorization { status in
        DispatchQueue.main.async { result(Self.name(status)) }
      }
    case "list":
      DispatchQueue.global(qos: .userInitiated).async {
        guard MPMediaLibrary.authorizationStatus() == .authorized else {
          DispatchQueue.main.async {
            result(FlutterError(code: "denied", message: "Akses muzik tidak dibenarkan", details: nil))
          }
          return
        }
        let songs = Self.songs()
        DispatchQueue.main.async { result(songs) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func name(_ status: MPMediaLibraryAuthorizationStatus) -> String {
    switch status {
    case .authorized: return "authorized"
    case .notDetermined: return "notDetermined"
    case .denied, .restricted: return "denied"
    @unknown default: return "denied"
    }
  }

  private static func songs() -> [[String: Any]] {
    var out: [[String: Any]] = []
    for item in MPMediaQuery.songs().items ?? [] {
      // Tanpa assetURL = lagu awan/DRM; muzik kurang 30 saat = bukan lagu.
      guard let url = item.assetURL, item.playbackDuration >= 30 else { continue }
      var song: [String: Any] = [
        "id": String(item.persistentID),
        "title": item.title ?? url.deletingPathExtension().lastPathComponent,
        "durationMs": Int(item.playbackDuration * 1000),
        "uri": url.absoluteString,
      ]
      if let artist = item.artist, !artist.isEmpty { song["artist"] = artist }
      out.append(song)
    }
    out.sort {
      (($0["title"] as? String) ?? "").localizedCaseInsensitiveCompare(
        ($1["title"] as? String) ?? "") == .orderedAscending
    }
    return out
  }
}
