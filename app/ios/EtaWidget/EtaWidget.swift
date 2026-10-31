import SwiftUI
import WidgetKit

// STUB: belum ada dalam Runner.xcodeproj. Untuk mengaktifkan:
//  1. Xcode > File > New > Target > Widget Extension, nama "EtaWidget" (nyahtanda Live Activity/Configuration).
//  2. Gantikan fail yang dijana dengan fail ini.
//  3. Tambah capability "App Groups" = group.com.fguniversalempire.fgmaps pada Runner DAN EtaWidget.
//  4. `cd app/ios && pod install` (home_widget). Lihat docs/adr/0013-along-route-cameras-widgets-carplay.md.
// Kunci mesti sama dengan app/lib/features/widgets/eta_widget_payload.dart; `kind` = HomeWidgetSink.iosKind.

private let appGroup = "group.com.fguniversalempire.fgmaps"

struct EtaEntry: TimelineEntry {
  let date: Date
  let homeLabel: String
  let homeValue: String
  let workLabel: String
  let workValue: String
}

struct EtaProvider: TimelineProvider {
  func placeholder(in context: Context) -> EtaEntry {
    EtaEntry(date: Date(), homeLabel: "Home", homeValue: "12 min", workLabel: "Work", workValue: "25 min")
  }

  func getSnapshot(in context: Context, completion: @escaping (EtaEntry) -> Void) {
    completion(read())
  }

  /// Tiada kemas kini berkala: Flutter memanggil `WidgetCenter.reloadTimelines` melalui home_widget.
  func getTimeline(in context: Context, completion: @escaping (Timeline<EtaEntry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .never))
  }

  private func read() -> EtaEntry {
    let d = UserDefaults(suiteName: appGroup)
    return EtaEntry(
      date: Date(),
      homeLabel: d?.string(forKey: "eta_home_label") ?? "Home",
      homeValue: d?.string(forKey: "eta_home_value") ?? "—",
      workLabel: d?.string(forKey: "eta_work_label") ?? "Work",
      workValue: d?.string(forKey: "eta_work_value") ?? "—"
    )
  }
}

struct EtaWidgetView: View {
  let entry: EtaEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      row(entry.homeLabel, entry.homeValue)
      row(entry.workLabel, entry.workValue)
    }
    .padding()
    .containerBackground(Color(red: 0.09, green: 0.23, blue: 0.47), for: .widget)
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).font(.caption).foregroundColor(.white.opacity(0.8))
      Spacer()
      Text(value).font(.headline).foregroundColor(.white)
    }
  }
}

@main
struct FgmapEtaWidget: Widget {
  let kind = "FgmapEtaWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: EtaProvider()) { entry in
      EtaWidgetView(entry: entry)
    }
    .configurationDisplayName("FGMaps ETA")
    .description("ETA Rumah / Kerja")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
