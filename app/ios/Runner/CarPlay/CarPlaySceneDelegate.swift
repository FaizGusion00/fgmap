import CarPlay
import MapKit
import UIKit

/// Hos CarPlay untuk FGMaps (parit minimum dengan Android Auto).
///
/// Adegan ini HANYA dicipta oleh iOS jika binari ditandatangani dengan entitlement
/// `com.apple.developer.carplay-maps`. Tanpa entitlement (build dev/CI biasa) kelas ini tidak pernah
/// dipanggil, jadi pelancaran app biasa tidak terjejas. Lihat docs/carplay-setup.md.
///
/// Kandungan:
/// - Navigasi: CPMapTemplate + CPNavigationSession (teks manuver, jarak, ETA) dan butang Tamat
///   yang memanggil `endNavigation` ke Flutter.
/// - Browse: butang Cari (CPSearchTemplate -> `search` / `openPlace`) dan butang Pusatkan (`recenter`).
/// - Peta sebenar TIDAK dilukis di sini (belum ada MapLibre native untuk CPWindow); lihat susulan dalam ADR 0013.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private var interfaceController: CPInterfaceController?
  private var carWindow: CPWindow?
  private var mapTemplate: CPMapTemplate?
  private let placeholder = CarPlayPlaceholderController()

  private var navSession: CPNavigationSession?
  private var trip: CPTrip?
  private var sessionRouteVersion: Int?
  private var currentManeuver: CPManeuver?
  private var currentManeuverText: String?

  // MARK: - CPTemplateApplicationSceneDelegate

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController,
    to window: CPWindow
  ) {
    self.interfaceController = interfaceController
    carWindow = window
    window.rootViewController = placeholder

    let template = CPMapTemplate()
    template.mapDelegate = self
    mapTemplate = template
    interfaceController.setRootTemplate(template, animated: false, completion: nil)

    CarBridge.shared.onSession = { [weak self] session in
      DispatchQueue.main.async { self?.render(session) }
    }
    render(CarBridge.shared.session)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController,
    from window: CPWindow
  ) {
    CarBridge.shared.onSession = nil
    finishNavigation()
    mapTemplate = nil
    carWindow = nil
    self.interfaceController = nil
  }

  // MARK: - Render

  private func render(_ session: [String: Any]) {
    guard let template = mapTemplate else { return }
    guard CarBridge.shared.ready else {
      placeholder.show(CarText.openPhone)
      configureBrowse(template)
      return
    }
    let mode = session["mode"] as? String ?? "browse"
    if mode == "navigating" {
      renderNavigation(template, session)
    } else {
      finishNavigation()
      placeholder.show(CarText.idleText(mode: mode, session: session))
      configureBrowse(template)
    }
  }

  private func configureBrowse(_ template: CPMapTemplate) {
    template.leadingNavigationBarButtons = [
      CPBarButton(title: CarText.search) { [weak self] _ in self?.pushSearch() },
      CPBarButton(title: CarText.nearby) { [weak self] _ in self?.pushNearby() },
    ]
    template.trailingNavigationBarButtons = []
    let recenter = CPMapButton { _ in CarBridge.shared.recenter() }
    recenter.image = UIImage(systemName: "location.fill")
    template.mapButtons = [recenter]
  }

  private func renderNavigation(_ template: CPMapTemplate, _ session: [String: Any]) {
    let routeVersion = (session["routeVersion"] as? NSNumber)?.intValue ?? 0
    if navSession == nil || sessionRouteVersion != routeVersion {
      startNavigation(template, session, routeVersion: routeVersion)
    }
    guard let navSession, let trip else { return }

    let remainingM = (session["remainingM"] as? NSNumber)?.doubleValue ?? 0
    let remainingS = (session["remainingS"] as? NSNumber)?.doubleValue ?? 0
    let toManeuverM = (session["distanceToManeuverM"] as? NSNumber)?.doubleValue ?? 0
    let text = (session["maneuver"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? CarText.follow
    let kind = session["maneuverKind"] as? String

    // Anggaran masa ke manuver: nisbah jarak daripada baki masa (CarPlay perlukan nilai masa).
    let toManeuverS = remainingM > 1 ? remainingS * min(1, toManeuverM / remainingM) : 0
    let maneuverEstimates = CPTravelEstimates(
      distanceRemaining: Measurement(value: toManeuverM, unit: UnitLength.meters),
      timeRemaining: toManeuverS
    )
    // Ayat sisi ("Guna lorong paling kanan") datang kemudian daripada teks manuver (dalam 700 m),
    // jadi ia sebahagian daripada kunci perubahan. Lorong grafik (CPLaneGuidance) sengaja tidak
    // dihantar: konvensyen sudut CPLane tidak didokumenkan dan tidak dapat disahkan tanpa CarPlay
    // sebenar; lorong tercermin lebih buruk daripada tiada lorong.
    let laneHint = (session["laneHint"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let maneuverKey = text + "|" + (laneHint ?? "")
    if currentManeuver == nil || currentManeuverText != maneuverKey {
      let maneuver = CPManeuver()
      maneuver.instructionVariants = laneHint.map { ["\(text). \($0)", text] } ?? [text]
      maneuver.symbolImage = CarManeuverSymbol.image(for: kind)
      maneuver.initialTravelEstimates = maneuverEstimates
      navSession.upcomingManeuvers = [maneuver]
      currentManeuver = maneuver
      currentManeuverText = maneuverKey
    } else if let maneuver = currentManeuver {
      navSession.updateEstimates(maneuverEstimates, for: maneuver)
    }

    template.update(
      CPTravelEstimates(
        distanceRemaining: Measurement(value: remainingM, unit: UnitLength.meters),
        timeRemaining: remainingS
      ),
      for: trip,
      with: .default
    )

    // ETA jam dinding dipaparkan sebagai butang (tidak interaktif) di sebelah kiri.
    if let etaMs = (session["etaEpochMs"] as? NSNumber)?.doubleValue {
      let eta = CPBarButton(title: "ETA \(CarText.clock(Date(timeIntervalSince1970: etaMs / 1000)))") { _ in }
      eta.isEnabled = false
      template.leadingNavigationBarButtons = [eta]
    }
  }

  private func startNavigation(
    _ template: CPMapTemplate, _ session: [String: Any], routeVersion: Int
  ) {
    finishNavigation()
    let route = CarBridge.shared.route
    let lat = (session["lat"] as? NSNumber)?.doubleValue
    let lng = (session["lng"] as? NSNumber)?.doubleValue
    var fallback: CLLocationCoordinate2D?
    if let lat, let lng { fallback = CLLocationCoordinate2D(latitude: lat, longitude: lng) }
    guard let origin = route.first ?? fallback else { return }
    let destination = route.last ?? origin

    let choice = CPRouteChoice(
      summaryVariants: ["FGMaps"],
      additionalInformationVariants: [],
      selectionSummaryVariants: []
    )
    let trip = CPTrip(
      origin: MKMapItem(placemark: MKPlacemark(coordinate: origin)),
      destination: MKMapItem(placemark: MKPlacemark(coordinate: destination)),
      routeChoices: [choice]
    )
    self.trip = trip
    sessionRouteVersion = routeVersion
    navSession = template.startNavigationSession(for: trip)

    let end = CPBarButton(title: CarText.end) { _ in CarBridge.shared.endNavigation() }
    template.trailingNavigationBarButtons = [end]
    template.mapButtons = []
  }

  private func finishNavigation() {
    navSession?.finishTrip()
    navSession = nil
    trip = nil
    sessionRouteVersion = nil
    currentManeuver = nil
    currentManeuverText = nil
  }

  // MARK: - Carian

  private func pushSearch() {
    guard CarBridge.shared.ready else { return }
    let search = CPSearchTemplate()
    search.delegate = self
    interfaceController?.pushTemplate(search, animated: true, completion: nil)
  }

  // MARK: - Berdekatan

  /// Kategori yang paling kerap dicari pemandu (minyak, makan, surau...). Satu ketukan, tanpa menaip.
  private func pushNearby() {
    guard CarBridge.shared.ready else { return }
    let list = CPListTemplate(title: CarText.nearby, sections: [])
    list.emptyViewTitleVariants = [CarText.searching]
    interfaceController?.pushTemplate(list, animated: true, completion: nil)
    CarBridge.shared.categories { [weak self, weak list] categories in
      DispatchQueue.main.async {
        guard let self, let list else { return }
        if categories.isEmpty { list.emptyViewTitleVariants = [CarText.noResults] }
        let items = categories.prefix(CPListTemplate.maximumItemCount).map { category in
          let item = CPListItem(
            text: category.label, detailText: nil,
            image: CarCategorySymbol.image(for: category.id),
            accessoryImage: nil, accessoryType: .disclosureIndicator)
          item.handler = { [weak self] _, completion in
            self?.pushPlaces(for: category)
            completion()
          }
          return item
        }
        list.updateSections([CPListSection(items: items)])
      }
    }
  }

  /// Tempat terdekat bagi satu kategori, tersusun ikut jarak. Ketik untuk mula navigasi ke sana.
  private func pushPlaces(for category: CarCategory) {
    let list = CPListTemplate(title: category.label, sections: [])
    list.emptyViewTitleVariants = [CarText.searching]
    interfaceController?.pushTemplate(list, animated: true, completion: nil)
    CarBridge.shared.nearby(category.id) { [weak self, weak list] places in
      DispatchQueue.main.async {
        guard let self, let list else { return }
        if places.isEmpty { list.emptyViewTitleVariants = [CarText.noResults] }
        let items = places.prefix(CPListTemplate.maximumItemCount).map { place in
          let item = CPListItem(
            text: place.name.isEmpty ? CarText.place : place.name,
            detailText: place.subtitle.isEmpty ? nil : place.subtitle)
          item.handler = { [weak self] _, completion in
            self?.open(place)
            completion()
          }
          return item
        }
        list.updateSections([CPListSection(items: items)])
      }
    }
  }

  private func open(_ place: CarPlace) {
    CarBridge.shared.openPlace(place) { [weak self] error in
      DispatchQueue.main.async {
        // "tolls": navigasi sudah bermula, cuma "Tanpa tol" tidak dapat dipenuhi.
        if error == nil || error == "tolls" {
          self?.interfaceController?.popToRootTemplate(animated: true, completion: nil)
          if error != nil { self?.placeholder.show(CarText.tollsOnRoute) }
        } else {
          self?.placeholder.show(CarText.cannotOpen)
        }
      }
    }
  }
}

// MARK: - CPMapTemplateDelegate

extension CarPlaySceneDelegate: CPMapTemplateDelegate {
  /// Pemandu menekan Tamat bawaan CarPlay semasa navigasi.
  func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
    CarBridge.shared.endNavigation()
  }
}

// MARK: - CPSearchTemplateDelegate

extension CarPlaySceneDelegate: CPSearchTemplateDelegate {
  func searchTemplate(
    _ searchTemplate: CPSearchTemplate,
    updatedSearchText searchText: String,
    completionHandler: @escaping ([CPListItem]) -> Void
  ) {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 2 else {
      completionHandler([])
      return
    }
    CarBridge.shared.search(query) { places in
      DispatchQueue.main.async {
        completionHandler(
          places.prefix(CPListTemplate.maximumItemCount).map { place in
            let item = CPListItem(text: place.name, detailText: place.subtitle)
            item.userInfo = place
            return item
          })
      }
    }
  }

  func searchTemplate(
    _ searchTemplate: CPSearchTemplate,
    selectedResult item: CPListItem,
    completionHandler: @escaping () -> Void
  ) {
    guard let place = item.userInfo as? CarPlace else {
      completionHandler()
      return
    }
    CarBridge.shared.openPlace(place) { [weak self] error in
      DispatchQueue.main.async {
        // "tolls": navigasi sudah bermula, cuma "Tanpa tol" tidak dapat dipenuhi.
        if error == nil || error == "tolls" {
          self?.interfaceController?.popToRootTemplate(animated: true, completion: nil)
          if error != nil { self?.placeholder.show(CarText.tollsOnRoute) }
        } else {
          self?.placeholder.show(CarText.cannotOpen)
        }
        completionHandler()
      }
    }
  }
}

// MARK: - Pembantu

/// Paparan ringkas pada CPWindow (belum ada peta native).
final class CarPlayPlaceholderController: UIViewController {
  private let label = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(red: 0.09, green: 0.23, blue: 0.47, alpha: 1)  // biru jenama #173B78
    label.textColor = .white
    label.font = .systemFont(ofSize: 28, weight: .semibold)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
    ])
    if label.text == nil { label.text = "FGMaps" }
  }

  func show(_ text: String) {
    loadViewIfNeeded()
    label.text = text
  }
}

enum CarManeuverSymbol {
  /// Nama `ManeuverKind` Flutter -> simbol SF (ikon manuver asas; sandaran teks sentiasa ada).
  static func image(for kind: String?) -> UIImage? {
    let name: String
    switch kind {
    case "right", "rampRight", "exitRight", "mergeRight": name = "arrow.turn.up.right"
    case "left", "rampLeft", "exitLeft", "mergeLeft": name = "arrow.turn.up.left"
    case "slightRight", "keepRight": name = "arrow.up.right"
    case "slightLeft", "keepLeft": name = "arrow.up.left"
    case "sharpRight": name = "arrow.turn.down.right"
    case "sharpLeft": name = "arrow.turn.down.left"
    case "uTurn": name = "arrow.uturn.down"
    case "roundabout": name = "arrow.triangle.turn.up.right.circle"
    case "arrive", "arriveRight", "arriveLeft": name = "mappin.circle.fill"
    default: name = "arrow.up"
    }
    return UIImage(systemName: name) ?? UIImage(systemName: "arrow.up")
  }
}

enum CarCategorySymbol {
  /// Id kategori Flutter (`NearbyCategory.name`) -> simbol SF. Sandaran: penanda lokasi.
  static func image(for id: String) -> UIImage? {
    let name: String
    switch id {
    case "fuel": name = "fuelpump.fill"
    case "food": name = "fork.knife"
    case "mosque": name = "moon.stars.fill"
    case "toilets": name = "figure.2"
    case "atm", "bank": name = "banknote.fill"
    case "pharmacy", "clinic", "hospital": name = "cross.case.fill"
    case "evCharging": name = "bolt.car.fill"
    case "parking": name = "parkingsign"
    case "hotel": name = "bed.double.fill"
    case "barber": name = "scissors"
    case "carWash": name = "drop.fill"
    case "workshop", "tyres": name = "wrench.and.screwdriver.fill"
    case "convenience", "supermarket", "mall": name = "cart.fill"
    case "laundry": name = "tshirt.fill"
    case "police": name = "shield.fill"
    case "postOffice": name = "envelope.fill"
    case "trainStation": name = "tram.fill"
    default: name = "mappin.circle.fill"
    }
    return UIImage(systemName: name) ?? UIImage(systemName: "mappin.circle.fill")
  }
}

/// Teks UI minimum (BM jika bahasa peranti Melayu, selainnya Inggeris).
enum CarText {
  private static var malay: Bool {
    (Locale.preferredLanguages.first ?? "").hasPrefix("ms")
  }

  static var search: String { malay ? "Cari" : "Search" }
  static var nearby: String { malay ? "Berdekatan" : "Nearby" }
  static var searching: String { malay ? "Mencari…" : "Searching…" }
  static var noResults: String {
    malay ? "Tiada hasil. Semak sambungan internet." : "No results. Check your internet connection."
  }
  static var place: String { malay ? "Tempat" : "Place" }
  static var end: String { malay ? "Tamat" : "End" }
  static var follow: String { malay ? "Ikut laluan" : "Follow route" }
  static var openPhone: String { malay ? "Buka FGMaps pada iPhone" : "Open FGMaps on your iPhone" }
  static var browse: String { "FGMaps" }
  static var cruise: String { malay ? "Mod pemanduan" : "Driving mode" }
  static var tollsOnRoute: String {
    malay ? "Tiada laluan tanpa tol. Laluan ini ada tol." : "No toll-free route. This route has tolls."
  }
  static var cannotOpen: String { malay ? "Tidak dapat mulakan laluan" : "Couldn't start the route" }

  /// Skrin kereta ketika tidak bernavigasi: waktu solat seterusnya, IPU di bawahnya, atau nama app.
  static func idleText(mode: String, session: [String: Any]) -> String {
    let prayer = (session["prayerLine"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let aqi = (session["airAqi"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    if mode == "cruise" {
      let weather = (session["weatherAlert"] as? String).flatMap { $0.isEmpty ? nil : $0 }
      return [weather ?? prayer ?? cruise, weather != nil ? prayer : nil]
        .compactMap { $0 }.joined(separator: "\n")
    }
    return [prayer ?? aqi ?? browse, prayer != nil ? aqi : nil].compactMap { $0 }.joined(
      separator: "\n")
  }

  static func clock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter.string(from: date)
  }
}
