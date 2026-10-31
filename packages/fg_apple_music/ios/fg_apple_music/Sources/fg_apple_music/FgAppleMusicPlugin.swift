import Flutter
import MusicKit
import UIKit

/// Jambatan MusicKit: carian katalog dan main lagu penuh untuk pelanggan Apple Music.
///
/// Tiada token pembangun dikendalikan di sini: MusicKit (Swift) memintanya sendiri bagi identiti app
/// apabila perkhidmatan MusicKit dihidupkan pada App ID. Tanpa itu, carian dan main gagal dengan
/// ralat yang dihantar semula ke Dart (`FlutterError`); app tidak runtuh. Akaun dan langganan
/// pengguna tidak pernah dibaca selain `canPlayCatalogContent`/`canBecomeSubscriber`.
///
/// Saluran kaedah `fgmaps/apple_music`, peristiwa `fgmaps/apple_music/events` (gambar pemain
/// setiap 0.5 saat semasa ada baris gilir).
public final class FgAppleMusicPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var ticker: Timer?
  private var queueIds: [String] = []
  private var startingUntil: Date?

  private var player: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FgAppleMusicPlugin()
    let methods = FlutterMethodChannel(
      name: "fgmaps/apple_music", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "fgmaps/apple_music/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  // MARK: - Kaedah

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status":
      Task { @MainActor in result(await self.statusMap()) }
    case "authorize":
      Task { @MainActor in
        _ = await MusicAuthorization.request()
        result(await self.statusMap())
      }
    case "search":
      let term = (args["term"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let limit = min(max(args["limit"] as? Int ?? 25, 1), 50)
      Task { @MainActor in await self.search(term: term, limit: limit, result: result) }
    case "setQueue":
      let ids = (args["ids"] as? [String]) ?? []
      let start = args["startIndex"] as? Int ?? 0
      Task { @MainActor in await self.setQueue(ids: ids, startIndex: start, result: result) }
    case "play":
      Task { @MainActor in
        do {
          self.startingUntil = Date().addingTimeInterval(8)
          self.startTicker()
          try await self.player.play()
          result(nil)
        } catch {
          self.startingUntil = nil
          result(Self.failure("play_failed", error))
        }
      }
    case "pause":
      Task { @MainActor in
        self.player.pause()
        result(nil)
      }
    case "stop":
      Task { @MainActor in
        self.player.stop()
        self.stopTicker()
        self.queueIds = []
        self.emit()
        result(nil)
      }
    case "seek":
      let ms = args["positionMs"] as? Int ?? 0
      Task { @MainActor in
        self.player.playbackTime = TimeInterval(max(ms, 0)) / 1000
        result(nil)
      }
    case "next":
      Task { @MainActor in
        do {
          try await self.player.skipToNextEntry()
          result(nil)
        } catch { result(Self.failure("next_failed", error)) }
      }
    case "previous":
      Task { @MainActor in
        do {
          try await self.player.skipToPreviousEntry()
          result(nil)
        } catch { result(Self.failure("previous_failed", error)) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @MainActor
  private func statusMap() async -> [String: Any] {
    let auth = MusicAuthorization.currentStatus
    var canPlay = false
    var canBecome = false
    if auth == .authorized, let sub = try? await MusicSubscription.current {
      canPlay = sub.canPlayCatalogContent
      canBecome = sub.canBecomeSubscriber
    }
    return ["authorization": auth.rawValue, "canPlay": canPlay, "canBecomeSubscriber": canBecome]
  }

  @MainActor
  private func search(term: String, limit: Int, result: @escaping FlutterResult) async {
    guard !term.isEmpty else {
      result([[String: Any]]())
      return
    }
    do {
      var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
      request.limit = limit
      let response = try await request.response()
      result(response.songs.map(Self.encode))
    } catch {
      result(Self.failure("search_failed", error))
    }
  }

  @MainActor
  private func setQueue(ids: [String], startIndex: Int, result: @escaping FlutterResult) async {
    guard !ids.isEmpty else {
      result(FlutterError(code: "empty_queue", message: "Baris gilir kosong", details: nil))
      return
    }
    do {
      let request = MusicCatalogResourceRequest<Song>(
        matching: \.id, memberOf: ids.map { MusicItemID($0) })
      let response = try await request.response()
      var byId: [String: Song] = [:]
      for song in response.items { byId[song.id.rawValue] = song }
      let ordered = ids.compactMap { byId[$0] }
      guard let first = ordered.first else {
        result(
          FlutterError(
            code: "not_in_catalog", message: "Lagu tiada dalam katalog storefront ini", details: nil
          ))
        return
      }
      let safeStart = ids.indices.contains(startIndex) ? startIndex : 0
      let start = byId[ids[safeStart]] ?? first
      queueIds = ordered.map { $0.id.rawValue }
      player.queue = ApplicationMusicPlayer.Queue(for: ordered, startingAt: start)
      try await player.prepareToPlay()
      result(queueIds)
    } catch {
      result(Self.failure("queue_failed", error))
    }
  }

  // MARK: - Pengekodan

  private static func encode(_ song: Song) -> [String: Any] {
    var map: [String: Any] = [
      "id": song.id.rawValue,
      "title": song.title,
      "artist": song.artistName,
    ]
    if let album = song.albumTitle { map["album"] = album }
    if let url = song.artwork?.url(width: 300, height: 300) { map["artwork"] = url.absoluteString }
    if let seconds = song.duration { map["durationMs"] = Int(seconds * 1000) }
    return map
  }

  private static func failure(_ code: String, _ error: Error) -> FlutterError {
    FlutterError(code: code, message: error.localizedDescription, details: nil)
  }

  // MARK: - Peristiwa pemain

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func startTicker() {
    guard ticker == nil else { return }
    ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      self?.emit()
    }
  }

  private func stopTicker() {
    ticker?.invalidate()
    ticker = nil
    startingUntil = nil
  }

  /// Gambar pemain: `status` (loading|playing|paused|idle), `positionMs`, dan lagu semasa
  /// (`id`, `durationMs`) supaya Dart boleh memetakannya ke indeks baris gilir.
  private func emit() {
    guard let sink = sink else { return }
    var status: String
    switch player.state.playbackStatus {
    case .playing, .seekingForward, .seekingBackward:
      status = "playing"
      startingUntil = nil
    case .paused, .interrupted:
      status = "paused"
    case .stopped:
      status = queueIds.isEmpty ? "idle" : "paused"
    @unknown default:
      status = "paused"
    }
    if status != "playing", let until = startingUntil, Date() < until { status = "loading" }
    var map: [String: Any] = [
      "status": status,
      "positionMs": Int(max(player.playbackTime, 0) * 1000),
    ]
    if let entry = player.queue.currentEntry, let item = entry.item, case .song(let song) = item {
      map["id"] = song.id.rawValue
      if let seconds = song.duration { map["durationMs"] = Int(seconds * 1000) }
    }
    sink(map)
  }
}
