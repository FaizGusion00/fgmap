# Prompt untuk Claude — FGMaps feature pack (kamera, along-route, multi-stop, widget, sejarah, cuaca, CarPlay)

> Salin SEMUA dari `=== PROMPT START ===` hingga `=== PROMPT END ===` ke Claude (Fable / Opus / Sonnet — mana yang anda guna).
> Repo: `/Users/faiznasir00/Development/fg/fgmap`
> App: `app/` · Package Android: `com.fguniversalempire.fgmaps` · iOS bundle: semak `PRODUCT_BUNDLE_IDENTIFIER` sedia ada
> Baca dahulu: `README.md`, `docs/PELAN.md`, `docs/adr/0003`, `0005`, `0007`, `0009`, `0010`, `0012` (jika ada), kod `RouteQuery.via`, `nearby_search.dart`, `trip_store.dart`, Android Auto (`FgMapCarService`, `car_session_hub.dart`)

---

=== PROMPT START ===

# Mission: Ship an honest, production-quality FGMaps feature pack for Malaysian drivers

You are a senior Flutter engineer working in the **FGMaps** repository. Implement **all** features listed below end-to-end: beautiful UX, clear Malay+English copy, free-forever data only, no lies about accuracy, tests, docs/ADR updates, and no regressions to navigation/offline/privacy.

**Do not** ask endless clarifying questions. Decide using: (1) driving safety, (2) simplicity for elders / map-illiterate users, (3) free forever / no billing APIs, (4) existing ADRs & serverless philosophy, (5) honesty in UI about data limits.

If a perfect free live API does **not** exist, implement the **best honest** version and label it correctly in the UI (e.g. “AwAS rasmi (JPJ)” not “semua kamera Malaysia”).

---

## 0) Product north star (never lose this)

FGMaps = Malaysia navigation, offline-capable, BM+EN voice, toll/fuel estimates, free, no ads, no account required, privacy-first, RM0 APIs (OSM / MapLibre / Valhalla / Photon / Overpass / OpenFreeMap / data.gov.my / GitHub tile packs).

Users: everyday drivers, elders, people bad at maps. UI must stay glanceable while driving.

**Forbidden:** paid Google Places / HERE / TomTom billing keys, camera scrapers that violate ToS, fake “100% complete” claims, AdMob, forced accounts, breaking Android Auto that already exists.

---

## 1) Delivery order (execute in this sequence)

1. **Along-route POIs engine** (shared foundation) → R&R, petrol, surau, toilets  
2. **AwAS / speed camera alerts** (curated official + optional OSM, honest labels)  
3. **Multi-stop / waypoints** UI + `RouteQuery.via` end-to-end  
4. **Trip history + monthly stats**  
5. **Weather** (destination + along route summary)  
6. **Home screen widgets** ETA Home/Work (Android first; iOS if feasible in same pass)  
7. **CarPlay** (iOS) mirroring the quality bar of existing Android Auto  
8. Harden: analyze, tests, l10n, ADR, privacy/Data safety updates if needed  

Ship working software. Prefer incremental PRs/commits only if the human asks; otherwise complete the pack coherently.

---

## 2) Shared foundation — “Along route” POI engine

### Problem today
Nearby search (`NearbyCategory` + Overpass) is **point-radius around GPS/map center**, not along the chosen route polyline. Users need “next R&R / petrol / surau / toilet **on my route**”.

### Build
Create a reusable domain+data layer, e.g. `app/lib/features/along_route/` (name to match repo style):

**Inputs:** selected `RouteOption` geometry (polyline / shape points), category set, max detour / corridor width.

**Algorithm (required):**
1. Sample the route polyline every ~1–2 km (and denser near maneuvers if cheap).
2. Query Overpass (reuse patterns from `nearby_search.dart` / ADR 0007) with a **corridor** or batched bbox/around queries — respect rate limits, cache on device, debounce, cancel in-flight.
3. Project each POI onto the route: compute **distance along route**, **side** (if known), **detour cost** (optional short Valhalla/local estimate or straight-line gate).
4. Filter: only POIs within corridor (e.g. 300–800 m from polyline; tune per category; R&R can be wider).
5. Sort by distance-along-route remaining / upcoming.
6. Deduplicate by OSM id / proximity.

**Categories & OSM tags (minimum):**
| UX category | Primary OSM tags |
|---|---|
| R&R / RSA / Lay-by | `highway=services`, `highway=rest_area` (+ name, toilets, fuel if tagged) |
| Petrol | `amenity=fuel` |
| Surau / mosque | `amenity=place_of_worship` + `religion=muslim` OR `building=mosque` / common MY tags used elsewhere in app |
| Toilets | `amenity=toilets` **and** toilets implied on services/rest_area (`toilets=yes`) |

Optional enrichment: LLM official Rest & Service Area ArcGIS layer (`gis02.llm.gov.my` … `Rest_and_Service_Area_MHA`) **only if** it is freely queryable, stable enough, cached, attributed, and fails soft — never block routing if LLM is down.

### UX
- On **route preview sheet**: section “Sepanjang laluan” with chips (R&R, Minyak, Surau, Tandas) + count upcoming.
- List rows: name, distance along route (“dalam 42 km”), ETA-ish if easy, open → preview on map / set as via / navigate detour.
- During **active navigation**: optional upcoming chip / voice (“R&R dalam 5 km”) behind a setting (default on for R&R+petrol, quieter for toilets).
- Empty / sparse: honest copy — *“Data daripada OpenStreetMap; mungkin tak lengkap.”*
- Easy mode: larger rows, fewer categories visible by default (R&R + Minyak).

### Honesty rules
Never claim Google-level completeness. Prefer “berdasarkan peta terbuka”.

### Tests
Unit tests for corridor sampling, projection, sorting, dedupe; repository tests with fixture Overpass JSON; widget tests for list/chips.

---

## 3) Feature — Amaran kamera laju (AwAS-first, honest)

### Reality (do not ignore)
There is **no** free forever API that equals Waze’s full camera network. Official JPJ publishes **AwAS fixed locations** (PDF lists). OSM `highway=speed_camera` is incomplete (~tens of points). Mobile/police cameras cannot be promised.

### Required product
1. **Primary dataset: JPJ AwAS curated**
   - Ingest official locations into a versioned asset in-repo or generated JSON under `app/assets/` (e.g. `assets/cameras/awas_my.json`) with: id, name/description, lat,lng (geocode KM markers carefully), direction/bound if known, type (speed vs red-light if distinguishable), source=`jpj_awas`, `asOf` date.
   - Document geocoding method in ADR. If a KM marker cannot be geocoded confidently, **omit** or mark low-confidence — do not invent precise pins.
   - Provide a maintainer script under `tools/` to refresh from the latest JPJ PDF/CSV when possible.
2. **Secondary (optional toggle, off by default or clearly labeled):** OSM `highway=speed_camera` via Overpass/cache — UI label “Komuniti OSM (mungkin tak lengkap)”.
3. **Alerts while navigating**
   - When approaching within configurable distance (default e.g. 800 m / 400 m), show HUD banner + optional chime/TTS (“Kamera AwAS di hadapan”).
   - Setting: on/off, distance, sound level; respect Easy mode (clearer, fewer false alarms).
   - **Do not** use this as an excuse to enable illegal “detector” claims; frame as **safety / speed awareness** aligned with posted limits you already show.
4. **Legal / store**
   - Re-read ADR 0005 note on camera alerts. Keep copy educational (“patuhi had laju”), not “elak saman” as primary marketing in-app.
   - Update privacy only if new network hosts are contacted (OSM Overpass already used).

### Forbidden
Scraping proprietary camera apps, paying for camera APIs, claiming “semua kamera Malaysia”.

### Tests
Distance-along-route alert trigger unit tests; settings persistence; fixture dataset parsing.

---

## 4) Feature — Multi-stop / waypoints (tambah perhentian)

### Already in engine
`RouteQuery.via` exists (`route_option.dart` / Valhalla codec). Detour internals use vias — **users cannot add stops in trip planner UI yet**.

### Build full UX
1. Trip planner supports ordered stops: Origin → Stop1 → Stop2 → … → Destination (cap e.g. 5 vias for UX/perf).
2. Add stop: from search, map long-press, along-route POI, or Favorites/Home/Work.
3. Reorder (drag), remove, edit.
4. Route preview shows total time/distance/toll **with stops**; alternatives still work if feasible.
5. Active navigation: progress across legs; clear “next stop” card; skip stop; arrive-at-stop confirmation then continue.
6. Deep link / share: optional later — at least restore multi-stop from `trip_store` if navigation interrupted.
7. Easy mode: big “Tambah perhentian” button, max 2 stops suggested in copy.

### Tests
`RouteQuery` encoding with vias; planner widget flows; navigation leg transitions; Valhalla request shape.

---

## 5) Feature — Sejarah trip + statistik

### Today
`trip_store` / `trip_record` restore **active** navigation — not a history of completed trips or monthly stats.

### Build
1. On trip end (arrive / user stop after meaningful distance, e.g. >1 km or >3 min moving): save a **TripSummary** locally (start/end names, path bounds optional, distance_m, duration_s, vehicle, toll estimate if known, fuel estimate if known, completed_at). No raw high-frequency GPS trail required unless cheap/privacy-safe; prefer summaries.
2. UI: Settings or dedicated “Perjalanan” page — list recent trips; monthly rollup: km, time, estimated toll, trip count.
3. Privacy: local only; retention setting (30/90/forever/off); delete all; export optional JSON.
4. Charts: simple, readable (not dashboard clutter) — one monthly summary card is enough for v1.
5. Easy mode: one card “Bulan ini: X km · Y jam · Tol ~RM Z”.

### Tests
Persistence, retention purge, monthly aggregation, end-of-trip save conditions.

---

## 6) Feature — Cuaca di destinasi / sepanjang laluan

### Free forever constraint
Pick a **no-key or free-forever** weather source. Preferred: **Open-Meteo** (no API key for non-commercial/reasonable use — verify current terms; cache aggressively; soft-fail offline).

### UX
1. Route preview: destination weather now + next hours (temp, rain probability, weather code icon).
2. Along route: sample 3–5 points (origin, midpoints, destination) → “Hujan dijangka dekat …” if relevant.
3. During nav: optional subtle banner only for severe rain / storm codes; setting to disable.
4. Honest attribution: “Cuaca: Open-Meteo” (or chosen source).
5. Offline: hide or show last cache with timestamp — never fake live weather.

### Tests
Parser fixtures; caching; UI empty/error states.

---

## 7) Feature — Widget home screen ETA Rumah / Kerja

### Goal
At-a-glance ETA to saved Home and Work without opening the app.

### Android (required)
- Use a maintained Flutter home widget approach (e.g. `home_widget` or current best practice compatible with the project’s Flutter SDK).
- Widgets: “Rumah”, “Kerja”, or combined.
- Data: last known location → quick route ETA via existing routing stack **with strict battery/network policy** (e.g. update on tap, periodic ~15–30 min while charging/Wi-Fi, or when app refreshes). Document policy.
- If no Home/Work saved: widget shows CTA to set in app.
- Themes roughly match app (readable outdoors).

### iOS (required if feasible in same effort)
- WidgetKit via the same plugin or thin native extension. If blocked by project tooling, ship Android fully + iOS stub/doc + issue notes — but **try hard** to ship both.

### Privacy
No upload of widget data to your servers (you have none). Clear that location is processed on device / existing public Valhalla endpoints as already used by app.

### Tests
Serialization of widget payload; fallback UI states (unit/widget where possible).

---

## 8) Feature — CarPlay

### Context
Android Auto already exists (`FgMapCarService`, `car_session_hub.dart`, STORE_BUILD host allowlist). CarPlay is **MISSING** on iOS.

### Build
1. Implement CarPlay navigation template flow aligned with Apple guidelines: map/navigation UI appropriate for CarPlay, upcoming maneuver, ETA, end trip.
2. Reuse Flutter “brain” via method channels similar to Android Auto hub — **one session owner**, no duplicate GPS wars (see existing car session design).
3. Entitlements, Info.plist, backgrounds modes as required; document setup steps in `docs/` for the human’s Apple Developer account (CarPlay entitlement may require Apple approval — implement code + checklist; do not pretend entitlement is automatic).
4. Feature parity target (minimum): show route guidance while phone navigates; start from phone still OK for v1; if CarPlay search is heavy, allow phone-planned route mirrored to car.
5. Do not regress Android Auto.

### Honesty
If Apple entitlement cannot be enabled in-repo alone, deliver complete implementation + “enable CarPlay entitlement in developer portal” runbook, and ensure the app degrades gracefully without entitlement.

### Tests
Channel contract tests; as much unit coverage as possible without full CarPlay simulator CI.

---

## 9) Cross-cutting UX / quality

- **l10n:** all new strings in `app/l10n` ARB ms+en; regenerate.
- **Easy mode:** larger controls, fewer advanced toggles exposed.
- **Navigation safety:** no modal spam while driving; prefer banners/TTS.
- **Performance:** along-route Overpass must not jank map; isolate isolates/compute if needed; cancel on route change.
- **Offline:** along-route POI/weather/cameras that need network should soft-fail; multi-stop offline routing must still work with Valhalla on-device when pack installed.
- **Privacy docs:** update `app/assets/legal/privacy.{ms,en}.md` + `docs/store/play-data-safety.md` if new hosts (Open-Meteo, LLM GIS, etc.).
- **ADR:** add `docs/adr/00xx-along-route-cameras-widgets-carplay.md` covering data sources, honesty limits, CarPlay entitlement, widget battery policy.

---

## 10) Engineering Definition of Done

- [ ] Along-route R&R, petrol, surau, toilets work from route preview + useful during nav  
- [ ] AwAS camera alerts from curated official dataset; OSM optional & labeled; no false “complete Malaysia” claim  
- [ ] Multi-stop add/reorder/remove + routing + navigation legs  
- [ ] Completed trips saved; monthly km/time/toll stats UI; privacy retention controls  
- [ ] Weather at destination + simple along-route insight via free source + attribution  
- [ ] Home/Work ETA widgets (Android required; iOS best-effort complete)  
- [ ] CarPlay implementation + developer enablement notes; Android Auto unbroken  
- [ ] `flutter analyze` clean on touched code; tests added/updated and passing for related areas  
- [ ] l10n ms+en; ADR + privacy/store docs updated as needed  

---

## 11) Final report to human

When done, summarize in Malay+English bullets:
- What shipped  
- Data honesty (what is / isn’t covered for cameras & POIs)  
- How to refresh AwAS dataset  
- CarPlay entitlement steps  
- Known gaps / follow-ups  

Start now. Optimize for real Malaysian highway trips (PLUS, ELITE, coastal highways): R&R and petrol along route + honest AwAS alerts + multi-stop family errands are the emotional core of this pack.

=== PROMPT END ===
