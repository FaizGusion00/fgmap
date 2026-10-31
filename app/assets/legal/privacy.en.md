# FGMaps Privacy Policy

Version {{version}} · Effective {{effective}}

## 1. Who we are

FGMaps (the "app") is operated by **{{entity}}** (registration no. {{regNo}}), {{address}}. Developer: {{developer}}. For any privacy question, contact **{{email}}**.

## 2. Summary

- No accounts, no ads, no analytics and no tracking.
- Your search history, saved places (Home, Work, favourites), trip history, reports and settings stay on your phone. We run no server that stores them.
- To show maps, search places and calculate routes, the app sends requests directly to third-party public services (section 4). We do not operate those services and do not receive a copy of your requests.
- You can erase all local data at any time: Settings > Privacy > Delete all my data.

## 3. Data kept on your phone only

- App settings (theme, language, navigation voice, vehicle type and so on).
- Search history and recent destinations.
- Trip history (optional summaries of completed journeys: distance, duration, destination name, and toll/fuel estimates if known). Kept for the retention period you choose in Settings (default 90 days; or 30 days, forever, or off). Never uploaded.
- Favourite radio stations (name and stream address) and which stations failed to connect in the last 24 hours, kept on your phone only.
- Saved places: Home, Work and favourites, including the coordinates you choose or the current location you save.
- Road reports (accidents, closures and so on) you create. For now they are stored only on your phone and are not shared with other users.
- Temporary caches: nearby search results (up to 30 days), map styles, offline maps you download, and a coarse position (rounded to about 11 km) used to compute sunrise and sunset for the automatic theme.
- A short error log on the phone (if enabled) that contains no coordinates or URLs and is not sent anywhere unless you copy and send it yourself.
- Prayer times (Azan): a coarse position (rounded to about 1 km) or the city you choose is stored to determine prayer times and schedule notifications. Prayer times come from the official JAKIM timetable (section 4) or are calculated on your phone if you are offline or turn that option off; the monthly timetable fetched is cached on the phone.
- Music: audio files you import from your phone are copied into the app's storage; player settings (equalizer, behaviour while the navigation voice speaks) are stored here too.

This data is not backed up to the cloud (Android backup is disabled).

## 4. Data sent to third parties

The app must contact the following services to work. Each also receives your IP address and ordinary connection details, and processes them under its own privacy policy.

- **Maps (OpenFreeMap):** map tile and style requests. They reveal the area you are viewing.
- **Place search (Photon by komoot, Germany; fallback Nominatim by the OpenStreetMap Foundation, UK):** the text you type and your approximate position as a ranking hint. When you choose "Use current location" for Home or Work, your exact position is sent once to obtain an address name.
- **Routes and speed limits (Valhalla by FOSSGIS e.V., Germany):** your current GPS position as the origin, the destination, direction of travel, vehicle type and route options. During navigation the app recalculates the route if you leave it, and sends the route shape to obtain speed limits. During route preview, the shapes of a few candidate routes are also sent (with no identifiers) to learn their road classes, so the recommended route prefers main roads over village roads.
- **Nearby places and toll plazas (Overpass API; mirrors in Europe):** the centre point or bounding box of the area searched.
- **Offline maps (GitHub Releases):** downloads of the map packs you choose. Only your IP address and download details are involved.
- **Fuel prices (data.gov.my, Government of Malaysia):** requests carry no personal data; only your IP address.
- **Short map links (maps.app.goo.gl, Google):** only when you open a link shared with you; the app requests it to learn the destination.
- **Official prayer times (WaktuSolat API, api.waktusolat.app):** only when Azan is turned on or the prayer times sheet is opened and the "Official JAKIM times" option is active. This community API relays the JAKIM e-Solat timetable; it receives your coarse position (rounded to about 1 km) plus the year and month, and returns the monthly timetable for your JAKIM zone. No identifiers are sent. Turn the option off to stop the requests (times are then calculated on the phone).
- **Weather (Open-Meteo, api.open-meteo.com):** only when you preview or navigate a route and the weather strip is shown. It receives the destination and up to four sample points along the route, each rounded to about 100 m (3 decimals), and returns temperature, weather code and rain probability. No account, API key or identifier is sent. If the request fails or you are offline, the weather strip is simply hidden (soft-fail) and nothing else changes.
- **Music: Audius (the Audius API and content nodes operated by third parties):** only when you open Music and search for or play a song; the search text and the ID of the song being played are sent (no location). Songs are streamed and not stored.
- **Music: Radio Browser (community mirrors in Europe) and the radio stations' own streaming servers:** only when you open the Radio tab or play a station; the list of stations for the region you pick is requested and one anonymous "play" count is sent each time you play a station. For stations the directory lists only over plain HTTP, the app also checks (up to 30 per list, response headers only, no audio downloaded) whether the same station answers over HTTPS, and shows it only if it does; this contacts those stations' servers, which see your IP address and the app name, exactly as they would when you play them. The stream comes directly from the station's server (HTTPS only).

These services are operated outside Malaysia (mostly in Europe, and GitHub in the United States).

When you tap **Share** or **Emergency**, the app prepares text (destination name, arrival time or your coordinates) to send through another app you choose, or opens the phone dialler. The app does not see who receives it and never places a call without your confirmation.

## 5. Permissions requested

- **Location (precise and approximate):** to show your position, as the route origin and for turn-by-turn navigation. Used only while the app is open or while navigation is active (a foreground service with a visible notification).
- **Keep screen on and notifications:** so navigation is not interrupted and you can see it is running; notifications are also used for prayer times (Azan) if you turn them on.
- **Exact alarms (Android 12+) and reboot:** so the azan notification fires exactly on time and is rescheduled after the phone restarts. Only if Azan is turned on; without the exact-alarm permission the notification may be a few minutes late.
- **Background media playback:** so Music keeps playing when the screen is locked, with lock-screen controls.
- **File access (system picker):** only the audio files you yourself choose to import into Music.
- **Internet:** for section 4.

You can withdraw permissions at any time in your phone settings. Some features will not work without location.

## 6. Basis and purpose of processing

We process data only with your consent (you grant location permission and use the relevant feature) and only to perform the app functions you ask for. We do not use data for advertising or profiling and do not sell it.

## 7. How long data is kept

Local data stays until you delete it or uninstall the app. Temporary caches expire automatically. Third parties keep data under their own policies; we do not control that period.

## 8. Transfers outside Malaysia

Because the servers in section 4 are outside Malaysia, data sent to them is transferred across borders. By using the relevant feature you agree to that transfer.

## 9. Your rights

Under the Personal Data Protection Act 2010 (Malaysia) and its principles, you may request access to and correction of your personal data, and withdraw consent. Because we do not keep your data on servers, you can view, change and delete all of it directly in the app. For any other request, contact {{email}}.

## 10. Security

All network communication uses HTTPS. Local data is kept in the app's isolated storage and is not backed up to the cloud. No system is perfectly secure; use a phone screen lock, especially if you save Home and Work.

## 11. Children

The app is not directed at children under 13 and we do not knowingly collect their data.

## 12. Changes to this policy

If this policy changes, the version and effective date above are updated, and material changes will be announced in the app.

## 13. Contact

{{entity}}
{{address}}
Email: {{email}}
