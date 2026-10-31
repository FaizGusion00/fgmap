# Prompt untuk Claude Fable — FGMaps optimize + UX + features baharu

> Salin SEMUA di bawah (dari `=== PROMPT START ===` hingga `=== PROMPT END ===`) ke Claude Fable.
> Repo: `/Users/faiznasir00/Development/fg/fgmap` · App Flutter: `app/` · Package: `com.fguniversalempire.fgmaps`

---

=== PROMPT START ===

# Mission: Make FGMaps the easiest, clearest Malaysia navigation app — then ship two free forever features (Azan + in-app music)

You are Claude Fable working inside the **FGMaps / FGMap** repository. Your job is to **think first, then implement end-to-end**, with production quality: clean architecture, no regressions, full tests, and UX that even map-illiterate users and older adults can use while driving or preparing a trip.

Do **not** ask endless clarifying questions. Make sensible product decisions that match the app purpose below. If something is ambiguous, pick the option that is: **safer while driving**, **simpler UI**, **free forever (no paid APIs / no API keys that can bill)**, and **consistent with existing ADRs**.

---

## 0) Product purpose (NEVER lose this)

**FGMaps** is a **community navigation app for Malaysia** (scope: Malaysia(+SG/BN map pack where already supported)).

Core promise:
- Fast, stable, beautiful turn-by-turn navigation
- **Offline-capable** after one map pack download
- Voice in **Bahasa Melayu + English**
- Toll & fuel estimates, alternative routes, nearby search, Home/Work
- **Free**: no ads, no account required, no tracking / no advertising ID
- Privacy-first: data stays on device where possible (PDPA-aware)
- Serverless / RM0 API philosophy: OpenStreetMap + MapLibre + Valhalla (on-device + public FOSSGIS), Photon/Nominatim, Overpass, OpenFreeMap, data.gov.my, GitHub Releases for tiles — see `README.md`, `docs/PELAN.md`, `docs/adr/`

**Primary users to optimize for (priority order):**
1. Drivers who are **bad at reading maps**
2. **Older adults** (larger type, high contrast, fewer steps, plain Malay language)
3. Everyday Malaysian drivers (tolls, highways, roundabouts, R&R, petrol)
4. Power users (offline, themes, simulate drive, Android Auto) — do not break them

**Non-goals / do not introduce:**
- Paid APIs, API keys that require billing accounts, AdMob, analytics trackers, forced accounts
- Scope creep outside Malaysia navigation + the two approved new features below
- Dark-pattern UX, tiny tap targets, jargon-heavy copy

Read before coding: `README.md`, `docs/PELAN.md`, ADRs especially `0003`, `0007`, `0009`, `0010`, and existing navigation HUD / search / settings code under `app/lib/features/`.

---

## 1) Hard requirement — Roundabout / junction icons must be dead simple

### Current problem
Maneuver icons (especially **bulatan / roundabout**) are hard to understand quickly. Today roundabouts use Material `Icons.roundabout_right_rounded` plus a separate exit number badge (`_RoundaboutExitBadge` in `app/lib/features/navigation/presentation/navigation_hud.dart`). That is too busy / not intuitive at a glance while driving.

### Required design (exact intent)
For a roundabout with exit number **N** (example: exit **2**):

- Icon = **one simple circular “road ring”** (the roundabout itself)
- **Large clear number N in the center** of that circle
- No decorative arrows cluttering the meaning unless absolutely necessary
- User should instantly read: “bulatan, ambil keluar nombor 2”

Apply the same philosophy to **all** maneuver icons in the HUD banner + “Kemudian / Then” strip:
- Prefer **one symbol = one meaning**
- High contrast on the blue HUD
- Larger hit/visual weight for the next action
- Roundabout exit number must remain correct from Valhalla/`roundaboutExit` data

### Implementation expectations
- Replace / redesign roundabout rendering (custom painter or crisp vector widget — not a confusing Material glyph + tiny overlay)
- Audit every `ManeuverKind` icon in `maneuverIcon(...)` for glanceability
- Keep landscape + portrait HUD layouts readable
- Update golden/widget tests for HUD / navigation that assert icons or roundabout exit display
- Malay + English instruction text must still match the icon (e.g. “Ambil keluar ke-2” / “Take the 2nd exit”)

**Acceptance:** A person who is bad at maps can glance at the HUD for 0.5s and know what to do at the next roundabout without reading a paragraph.

---

## 2) UX overhaul — “senang pakai” for map-illiterate & older users

Audit and improve the **whole user journey** with driving safety + elderly usability in mind. Focus on:

### 2.1 First-run & trip start (fewer steps)
- Onboarding: shorter, larger text, skip-friendly, clear Malay
- Trip planner: one obvious primary path — “Ke mana?” big search, Home/Work huge buttons
- Reduce cognitive load: hide advanced options behind “Lanjut”, not in the first screen
- Confirm destination with a huge map pin + big “Mula” button

### 2.2 During navigation (safety)
- Bigger next-maneuver icon + distance
- Plain language instructions (BM first quality)
- Stronger “Bersedia / Get ready” cue before turn
- Avoid tiny controls; stop button must remain obvious but not easy to fat-finger mid-turn
- Lane / roundabout / ramp language must be simple
- If GPS weak: calm, large banner — what to do next

### 2.3 Search & discovery
- Keep paste coordinates / Maps links
- Nearby chips already exist — make labels clearer for elders (icons + text, not icon-only)
- Empty states that teach (“Taip nama tempat, atau pilih Rumah”)

### 2.4 Settings
- Group for elders: **Suara**, **Paparan (besar)**, **Azan**, **Muzik**, **Privasi**
- Add an optional **“Mod mudah / Easy mode”** (or strengthen defaults) that:
  - Larger HUD text/icons
  - Higher contrast
  - Fewer secondary panels while navigating
  - Speaks more / earlier prompts if already supported by settings

### 2.5 Accessibility
- Respect system text scale (already partly handled — do not regress)
- Semantics / TalkBack labels for key HUD actions
- Contrast AA where practical on HUD

Ship concrete UI changes, not a long doc. Update `app/lib/l10n` ARB (ms + en) for any new strings; run `make l10n` / `flutter gen-l10n`.

---

## 3) New feature A — Waktu Azan (prayer times) for current location

### Goal
Muslim drivers / users can see **prayer times for their current location** (or last known location), configure notifications, and hear **azan**.

### Defaults (important)
- **By default: play full azan** (not a short beep) when notification fires — user can change later
- User can configure:
  - Which prayers notify (Subuh, Zohor, Asar, Maghrib, Isyak — and optional Syuruk/Dhuha if you include them)
  - Sound: **Full azan (default)** / short tone / silent
  - Advance reminder (e.g. 0 / 5 / 10 / 15 minutes before)
  - Enable/disable master switch
- Must work with **location permission already used by the app**; if no location, allow pick city / last fix / manual coordinates fallback
- Do **not** interrupt active turn-by-turn guidance dangerously: if navigating, prefer notification + optional softer behavior; document the rule you choose (e.g. show banner + notification; delay loud azan until safe / user setting “play during navigation”)

### Free forever constraint (mandatory)
Research and implement using **free forever** approaches only. Preferred order:
1. **On-device calculation** (best): e.g. well-known open prayer-time algorithms / Dart package that needs **no API key** (Aladhan-compatible methods: Muslim World League, Singapore, Egypt, etc.) — pick a method sensible for **Malaysia** as default (document why; allow user change)
2. If network fetch is used: only **free, no billing, no hard quota kill-switch** public APIs (e.g. Aladhan-style) with **on-device fallback** if offline

**Forbidden:** paid prayer APIs, anything requiring credit card, opaque freemium that can suddenly charge.

### UX placement
- Easy entry from map / settings / optional home chip — do not bury it
- Clear list of today’s times for current place name
- Notification channels on Android that comply with existing FGS/notification patterns; do not abuse `FOREGROUND_SERVICE_LOCATION` for azan — use normal notifications / alarm scheduling appropriately
- Legal/privacy: mention in privacy docs if new data flows appear (usually none if on-device)

### Tests
- Unit tests for calculation / scheduling helpers
- Widget tests for settings + prayer list
- Edge: timezone, midnight rollover, no GPS, offline

---

## 4) New feature B — Search & listen to free music in-app (complete player)

### Goal
Inside FGMaps, user can **search a song and listen immediately** — a real music experience for drives / waiting, not a toy.

### Product requirements
- Search songs / artists / albums (depending on free source capabilities)
- Tap result → play
- Full player UI: play/pause, next/prev (if available), seek, queue, now-playing, lock-screen / notification media controls where feasible on Android
- **Equalizer** (system / app-level as feasible on Flutter — research best maintainable approach; if OS limits, provide clear in-app EQ or presets)
- Background audio while map is open / app backgrounded (use proper audio session; do not break navigation TTS — **duck or pause policy**:
  - Default recommendation: **duck music when voice guidance speaks**, resume after
  - Setting to pause music on each maneuver prompt
- Offline: if source cannot offline-cache legally, be honest in UI; prefer sources that allow streaming without login

### Free forever music source (mandatory research + pick)
You must research and choose a **free forever** (or truly free/open) music source compatible with app store policies. Candidates to evaluate (pick best legal fit; document in a short ADR under `docs/adr/`):
- **Jamendo** (CC / free API — check current terms)
- **Audius** (decentralized; check ToS for commercial app use)
- **Radio Browser** (free radio stations — good complement if on-demand tracks are hard)
- **Internet Archive / Free Music Archive** style catalogs
- **Local files** on device (always allowed) as a baseline that always works

**Do NOT** build a YouTube-downloader, pirate scraper, or ToS-violating ripper. If on-demand free catalog is limited, combine: **free catalog streaming + local files + optional free radio**, and make search UX still feel direct (“cari lagu → main”).

### UX
- Entry: search bar / “Muzik” in settings or map sheet — large, obvious
- Results list with artwork if available
- Mini player above nav controls when appropriate; full player page
- Equalizer presets: Normal, Bass, Treble, Voice (for podcasts if any), Custom
- Malay + English strings

### Tests
- Player state machine tests
- Search repository tests with fakes/mocks (no flaky live network in CI)
- Audio vs navigation TTS ducking unit/widget tests where possible

---

## 5) Engineering quality bar (non-negotiable)

### Architecture
- Follow existing feature-first layout under `app/lib/features/`
- Riverpod patterns already used in the app
- Keep serverless / free-API philosophy (`docs/adr/0004`, README)
- No secrets committed; no new paid keys

### Quality
- `flutter analyze` clean for touched code
- Add/update unit + widget tests for every behavior change
- Update goldens only when UI intentionally changes; do not blindly regenerate unrelated goldens
- Run relevant tests: navigation HUD, settings, new azan + music feature tests, search regressions if touched
- Fix any failures you introduce

### Docs
- Short ADR for music source choice + prayer calculation method
- Update privacy assets `app/assets/legal/privacy.{ms,en}.md` **only if** new third parties / data flows are introduced; keep PDPA honesty
- If store Data safety answers change, update `docs/store/play-data-safety.md`

### Out of scope unless required for the above
- iOS App Store submission polish
- Rebranding / renaming package id
- Rewriting Valhalla engine

---

## 6) Delivery plan (execute in this order)

1. **Think & inventory** — read HUD/icons, settings, audio/TTS paths, notification setup
2. **Fix maneuver / roundabout icons** + HUD glanceability (highest driving-safety impact)
3. **Easy-mode / elder UX** improvements on trip start + navigation + search empty states
4. **Azan feature** (on-device preferred) + notifications + settings defaults (full azan)
5. **Music feature** (free forever source + local files) + player + EQ + TTS ducking
6. **Harden** — analyze, tests, fix, document ADR + privacy if needed
7. Final summary for the human: what changed, how to try azan/music, remaining risks (API ToS, background audio OEM quirks)

---

## 7) Definition of Done

- [ ] Roundabout icon is a **simple circle + center exit number**; other maneuver icons are clearer
- [ ] Map-illiterate / older-user journey is noticeably easier (larger, fewer steps, clearer BM copy)
- [ ] Azan works for current location with configurable notifications; **default sound = full azan**
- [ ] User can search and play free/legal music in-app with a serious player + equalizer; navigation voice still intelligible
- [ ] Only free-forever / no-billing dependencies; ADR explains choices
- [ ] Related tests pass; analyze clean; no known crash paths in new code
- [ ] Privacy/docs updated if third parties added

Start now. Prefer working software over essays. When you must choose, choose **clarity for drivers** over visual novelty.

=== PROMPT END ===
