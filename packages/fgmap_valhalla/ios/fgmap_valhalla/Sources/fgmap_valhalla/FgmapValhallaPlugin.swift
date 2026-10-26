import Flutter
import Foundation
import UIKit
import Valhalla
import ValhallaConfigModels

/// Jambatan nipis ke enjin Valhalla dalam peranti (valhalla-mobile). Kontrak sama dengan Android:
/// `open(tarPath)`, `route(request)` (JSON masuk, JSON keluar) dan `close()`. Lihat FgmapValhallaPlugin.kt.
public class FgmapValhallaPlugin: NSObject, FlutterPlugin {
  // Satu antrian siri: Valhalla menyirikan permintaan pada satu instance, dan open/close tidak boleh
  // berlumba dengan route yang sedang berjalan. Semua akses `engine` berlaku di antrian ini.
  private let worker = DispatchQueue(label: "fgmap-valhalla", qos: .userInitiated)
  private var engine: Valhalla?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "fgmap_valhalla", binaryMessenger: registrar.messenger())
    let instance = FgmapValhallaPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "open":
      guard let path = args?["tarPath"] as? String else {
        return result(FlutterError(code: "bad_args", message: "tarPath is required", details: nil))
      }
      run(result) { try self.open(path) }
    case "route":
      guard let json = args?["request"] as? String else {
        return result(FlutterError(code: "bad_args", message: "request is required", details: nil))
      }
      run(result) { try self.route(json) }
    case "traceAttributes":
      guard let json = args?["request"] as? String else {
        return result(FlutterError(code: "bad_args", message: "request is required", details: nil))
      }
      run(result) { try self.traceAttributes(json) }
    case "close":
      run(result) { self.closeEngine(); return nil }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private struct EngineError: Error {
    let code: String
    let message: String
  }

  private func open(_ tarPath: String) throws -> Any? {
    let attrs = try? FileManager.default.attributesOfItem(atPath: tarPath)
    guard let size = attrs?[.size] as? NSNumber, size.intValue > 0 else {
      throw EngineError(code: "tiles_missing", message: "Tile file not found or empty: \(tarPath)")
    }
    closeEngine()
    do {
      let config = try ValhallaConfig(tileExtractTar: URL(fileURLWithPath: tarPath))
      engine = try Valhalla(config)
    } catch {
      throw EngineError(code: "open_failed", message: Self.describe(error))
    }
    return nil
  }

  private func route(_ requestJson: String) throws -> Any? {
    guard let engine = engine else {
      throw EngineError(code: "not_open", message: "Offline engine is not open")
    }
    do {
      return try engine.route(rawRequest: requestJson)
    } catch {
      throw EngineError(code: "route_failed", message: Self.describe(error))
    }
  }

  private func traceAttributes(_ requestJson: String) throws -> Any? {
    guard let engine = engine else {
      throw EngineError(code: "not_open", message: "Offline engine is not open")
    }
    do {
      return try engine.traceAttributes(rawRequest: requestJson)
    } catch {
      throw EngineError(code: "route_failed", message: Self.describe(error))
    }
  }

  private func closeEngine() {
    engine?.close()
    engine = nil
  }

  /// Menyeragamkan ralat Valhalla kepada JSON `{"error_code":N,"error":"..."}` supaya penghurai Dart
  /// (valhallaErrorCodeFromText) menerima bentuk yang sama seperti di Android, tempat mesej
  /// pengecualian membawa JSON ralat Valhalla.
  private static func describe(_ error: Error) -> String {
    if let v = error as? ValhallaError, case let .valhallaError(code, message) = v {
      let escaped = (try? JSONSerialization.data(withJSONObject: [message], options: []))
        .flatMap { String(data: $0, encoding: .utf8) }
        .map { String($0.dropFirst().dropLast()) } ?? "\"\""
      return "{\"error_code\":\(code),\"error\":\(escaped)}"
    }
    return String(describing: error)
  }

  private func run(_ result: @escaping FlutterResult, _ block: @escaping () throws -> Any?) {
    worker.async {
      do {
        let value = try block()
        DispatchQueue.main.async { result(value) }
      } catch let e as EngineError {
        DispatchQueue.main.async { result(FlutterError(code: e.code, message: e.message, details: nil)) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "internal", message: String(describing: error), details: nil))
        }
      }
    }
  }
}
