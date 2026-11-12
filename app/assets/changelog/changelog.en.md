# 1.8.3 | 2026-11-11
This release fixes Android Auto, based on tester reports.

## Android Auto works without opening the phone app
Before: If FGMaps was opened straight from the car screen, the map was empty. Search and Nearby said "Check your internet connection" even with internet, and prayer times and other features did not appear. With the phone screen off, the car map stopped following the car, and free-drive mode never started on the car screen.
After: The car screen starts FGMaps by itself, so the phone app does not need to be opened. The car map follows your location even with the phone screen off, and free-drive mode (speed, speed limit and camera alerts) works as on the phone. Error messages now give the real reason: FGMaps is starting, location not available yet, search failed, or no results.
How to use: Connect your phone to the car and open FGMaps from the car screen. Allow location for FGMaps on the phone once if you have not yet.

## More features on the car screen
Before: The car screen only had Search and Nearby. Choosing a place started a route straight away with no choice, and FGMaps music did not appear in Android Auto.
After: The Places button opens a grid with Home, Work, Nearby, Favourites, Recent, Report and Settings. Search and Nearby results now appear on the map with numbered pins and distances. Before driving, you can choose between routes (time, distance and toll estimate), and the chosen route is shown on the map. The Report button sends a police, accident, traffic jam, flood or other report with one tap. Car settings: voice guidance, avoid tolls, speed camera alerts and satellite map. During navigation there is a mute button beside the map. FGMaps music (Malaysian radio, favourite radio, songs on your phone and imported songs) is now in the Android Auto media section.
How to use: On the car screen, tap Places or Search. Pick a place, pick a route, then tap Go. For music, open FGMaps from the Android Auto media apps. Songs on your phone only appear if music permission was already given in the phone app.

# 1.8.2 | 2026-11-11
This release comes from tester reports: more complete speed camera alerts, faster GPS location, and lower battery use.

## Speed camera alerts
Before: Camera alerts only appeared during navigation to a destination. The app had only 30 camera locations, most of them estimates far from the road, and cameras on diagonal highways (for example PLUS at Pagoh) never triggered an alert.
After: The app carries 95 speed and red-light camera locations placed on the road, and they work without internet. Alerts also appear when driving without a destination, with a banner at the top of the screen and the voice prompt "Camera ahead — observe the speed limit".
How to use: On by default. Turn it on or off and pick the alert distance (400, 800 or 1,200 m) in Navigation settings. The list does not yet cover every camera in Malaysia; keep to the speed limit on every road.

## Faster GPS location
Before: Planning a route right after opening the app sometimes failed with "location not available yet" even though the blue dot was showing. The map took up to 12 seconds to follow you, and the blue dot froze after GPS was turned off and on from quick settings.
After: Routes are calculated from the location the phone already has (navigation corrects it as soon as GPS is precise). The map follows the first blue dot straight away. GPS that is turned back on reconnects at once, and phones with "approximate" location permission still get a location.
How to use: Nothing to do. For the best accuracy, allow "precise" location for the app.

## Battery and smoothness
Before: Free-drive mode switched on at 9 km/h (for example brisk walking or a GPS jump), sent an internet request every second and kept the screen on. The map kept drawing at full rate even when the car was stopped, GPS kept running on other pages, and navigation saved the route almost every second.
After: Free-drive mode switches on at about 20 km/h, with road snapping every 3 seconds (5 seconds in Lite mode) and one request at a time. Map drawing pauses when the car is stopped or has arrived, GPS stops when another page covers the map, and the trip is saved at most every 10 seconds. The CCTV page only refreshes while it is visible, and the FG AI model loads when you start typing.
How to use: Happens on its own. If an FG AI model ever closed the app while answering, it is no longer used and the app tells you; pick that model again in FG AI settings to retry once.

# 1.8.1 | 2026-11-09
This release comes from user feedback: plan a trip from anywhere, and choose for yourself whether to use tolls.

## Searchable starting point
Before: Routes always started from your GPS location. You could not study a trip starting somewhere else, and without GPS no route could be calculated at all.
After: The "From" field can be tapped and searched. Route, time, tolls and road choices are shown from the place you pick, with a start marker on the map.
How to use: Tap "From" in Plan a trip, or the "From" row on the route summary. This is a preview only: real navigation can only start from your location, so the main button becomes "Use my location". Simulation lets you watch that trip. If the place is not in search, pick from history or saved places, search Google in the planner, or type coordinates. Links from other apps are always calculated from your location.

## With toll and No toll choices
Before: A toll-free route only appeared as one of the cards and had to be picked every time.
After: The route summary has All, With toll and No toll choices. "No toll" is remembered for your next trips, including when a route is recalculated and on the Android Auto screen.
How to use: The choice appears when a trip involves tolls. If there is no toll-free road for that trip, the app tells you and still shows every route it found, with a short message on the car screen. Change the choice on your phone; Android Auto follows it.

# 1.8.0 | 2026-11-06
This release focuses on real driving in Malaysia: multi-level junctions, getting to the right door, voice guidance that keeps working without internet, and a route line that no longer disappears.

## Lane view and roundabout picture
Before: Lane guidance was a small icon or the text "Use the right lane". At roundabouts the card only showed the exit number, with no picture of the roundabout.
After: Before a junction, a perspective view shows the road ahead with an arrow for each lane, and the lane you should take is highlighted in blue. In a "straight + right" lane, only the arrow you need lights up. At roundabouts, a top-down picture shows the exit to take. Motorcycle riders see the view earlier than cars because changing lanes is riskier for them.
How to use: It appears on its own before a junction (portrait only; landscape keeps the compact strip). Most Malaysian roads have no real lane data, so the view is drawn from the turn type and labelled "Estimated lane": it only points to a side (left or right), not an exact lane.

## Direction arrows, street names and places on the map
Before: The route on the map was a plain line with no direction cues. The street you were turning into was only in the card, and place icons were small and hard to recognise.
After: White arrows on the route show the direction, the street you will turn into is shown at the turn point, and during navigation places are drawn as coloured pins with names (fuel, food, shops, schools, clinics, banks, mosques, hotels and parking).
How to use: They appear on their own during navigation. Place pins only show while navigating and when the map is zoomed in enough.

## Android Auto and CarPlay: lanes and a clearer map
Before: The car screen showed turn instructions without lane guidance. The Android Auto map was always the standard map with one thin blue line that was hard to see on the dark map.
After: Android Auto shows real lanes when data exists, and the car map follows the Satellite choice on your phone. The route is thicker with a white edge and direction arrows ahead of the car. Android Auto and CarPlay also show "Use the rightmost lane" as a turn approaches.
How to use: Estimated lanes are not sent to the car because the car lane screen cannot mark them as estimates. CarPlay still has no map and no lane picture; it only shows instructions and the lane sentence.

## The blue route line stays visible and sticks to the car
Before: On some phones and roads, the blue line disappeared in front of the car and reappeared far ahead. On the dark, offline and satellite maps it was also hidden under flyovers, elevated highways and ramps, and came back after the flyover.
After: The blue line is now drawn above every road and flyover (street names still sit on top). It starts right under the car and moves smoothly with it, including through corners. A backup line that always starts just ahead of the car keeps the route visible even if a phone fails to draw the trimmed part.

## Flyovers and the road below
Before: At multi-level junctions the app only said "Keep right" or "Take the ramp", without saying whether to go up the flyover or stay on the road below. Many drivers went up the wrong flyover.
After: The instruction card and voice now say "Take the flyover", "Stay on the lower road, not the flyover" or "Take the underpass". The same hint is shown on the car screen (Android Auto).
How to use: It appears on its own at forks and slip roads. "Take the flyover" and "underpass" come from the route data, so they work without internet. "Stay on the lower road" needs internet.

## Navigation to the entrance
Before: The route ended at the destination pin, which is sometimes in the middle of a building or at the wrong door. Drivers had to circle around looking for the entrance or the car park.
After: The route preview now lists the main entrance, guardhouse or visitor gate, car park entrance, loading bay and building doors. Tap one and the route goes straight there. You can make one entrance the default for that place, or tap "Save my spot as the entrance" when you arrive. Next time FGMaps goes straight to that entrance.
How to use: Tap an entrance to route there, long-press to make it the default. The first time needs internet, then it is kept for 30 days. Entrance data may be incomplete, so some places only have a pin or a gate.

## Voice guidance without internet
Before: Voice guidance depended on the phone's settings. If the Malay voice needed internet, instructions could go silent in areas without coverage, with no warning.
After: FGMaps now picks a voice that is already installed on the phone. Navigation settings show "Offline voice: ready" or "not installed" with an Install button. If the voice is not installed, a warning appears once when navigation starts.
How to use: Navigation settings > Offline voice > Install, then download the voice for your language once (for example in Google Text-to-Speech). On iPhone it depends on Apple's voices.

## Back online, data refreshes by itself
Before: Anything that failed to load while offline (route, weather, fuel prices, speed limits) stayed empty until you redid it yourself.
After: The app tells you when you are offline. When the internet comes back it reloads the failed route, weather, fuel prices and places along the route by itself. During navigation it also reloads speed limits, flyovers and cameras, without changing your route.

## Resume the offline map download
Before: If the app was closed while downloading the map pack (510 MB), the card showed "Not downloaded" and the download seemed to start over.
After: The card now shows "Download paused at X%" with a "Resume download" button, and the download continues from there.
How to use: The offline map pack is downloaded once. Offline search covers the places in that pack, so not every place on Google will be found.

## Sharper satellite imagery in towns
Before: The satellite map was capped at zoom level 18, so it looked blurry when zoomed in.
After: In towns and suburbs, native level-19 imagery now switches on by itself. It is about twice as detailed, so road markings, vehicles and trees are visible. It is only used where the imagery is confirmed to exist. Elsewhere the map stays as before, with no grey "no data" tiles.
How to use: Map layers button > Satellite, then zoom in. Very close zoom (beyond level 19) is still soft because finer imagery does not exist.

## Weather and search while offline
Before: While offline, the weather card could show saved weather for another destination up to 50 km away (for example KLIA weather for a route to KLCC). The "Search on Google" row also stayed even though it cannot work without internet.
After: Saved weather is only used for destinations within 10 km, labelled with the current destination. The "Search on Google" row is hidden when there is no internet, and offline search stays available.

## A more complete About page, and this page
Before: Data provider names were sprinkled across the screens, for example "Data: OpenStreetMap", "Weather: Open-Meteo" and "via Audius". About only showed the version and six lines of recent changes.
After: The screens are now clean, without source names. All credits are organised in About > Data sources, one line for each kind of data. About also shows the version, build number, release date and an "Open-source licences" button. This "All changes" page explains every version with a before and after comparison.
How to use: Settings > About FGMaps > See all changes.

# 1.7.0 | 2026-11-06
Highway CCTV and the official toll calculator, right inside the app.

## Highway CCTV
Before: To check traffic on a highway you had to leave FGMaps and open another website or app.
After: Real CCTV images from the Malaysian Highway Authority for 34 highways are now in the app. Images update about every minute and refresh by themselves every 30 seconds, with a timestamp on the image. From the route preview, tap "Route CCTV" to see only the cameras along your route.
How to use: These are camera images updated regularly, not live video. Needs internet.

## Official toll calculator
Before: Toll rates were only estimated from a dataset in the app, with no way to check the official rate.
After: The official toll calculator is in the app: pick a highway and plazas, and see the rate for cars, vans, lorries, taxis and buses, straight from the government calculator.

## Route toll estimate fixed
Before: Toll plazas were sometimes matched to the wrong plaza, so the toll estimate could be too low.
After: Plazas are now matched to the actual booth, and rates come straight from the official calculator. For example Setia Alam to Johor Bahru is RM38.87 (RM37.15 to Skudai plus RM1.72 at Kempas). If the entry or exit plaza is uncertain, the app tells you instead of guessing a low price.

## FG AI opens CCTV and the toll calculator
Before: FG AI did not know about CCTV or the toll calculator.
After: Try "cctv plus selatan" or "toll calculator". FG AI opens the right screen.

# 1.6.0 | 2026-11-05
The mosque and surau list for all of Malaysia, and Google search inside the app.

## Mosque and surau list (JAKIM)
Before: Mosques could only be found one at a time through map search, and there was no complete list.
After: The official list of mosques and suraus across Malaysia (about 23,000 places). Search by name, filter by state and district, then tap Directions for a route preview or Go to start navigating.
How to use: The list is official data from 2019, so some entries may have changed. About 7% have an exact location. The rest are looked up by address when tapped and marked "approximate".

## Search on Google inside the app
Before: Places missing from FGMaps search had to be found in another app and copied into FGMaps.
After: "Search on Google" opens right inside the app. Tap "Directions" or "Open in Maps" on a Google result and FGMaps routes straight to the exact location Google gives, without searching for the name again.

## FG AI opens the mosque list
Before: FG AI could only find the nearest mosque.
After: Try "senarai masjid Selangor" (mosque list Selangor). FG AI opens the list already filtered.

## More complete toll estimates
Before: Some highways such as SPE, Besraya and NPE were missing from the toll estimate.
After: Toll estimates are clearer and cover more highways, including SPE, Besraya and NPE.

# 1.5.0 | 2026-11-05
Satellite map and music that keeps playing.

## Satellite map
Before: Only the regular street map (light and dark).
After: A Satellite map type, like Google Maps: satellite imagery with roads, place names and the navigation route on top.
How to use: Tap the layers button on the map and choose Satellite. Needs internet.

## Music keeps playing in the background
Before: Music could stop when the screen was locked or the app was left.
After: Music keeps playing in the background, with play, pause and next controls on the notification and lock screen.

## Android Auto with the phone locked
Before: The map on the car screen could stop moving when the phone was locked.
After: Android Auto keeps moving and guiding even when the phone is locked.

# 1.4.0 | 2026-11-02
A new look, and pictures of the real junction before you turn.

## New logo and opening animation
Before: The early logo and opening screen.
After: The new FGMaps logo with a new, lighter opening animation.

## Pictures of the real junction
Before: Only a direction arrow, with no picture of the junction ahead.
After: When a turn is near, the card shows the real junction: T-junctions, crossroads and roundabouts with the exit number. A white arrow on the map shows exactly where to turn.

## Landscape mode improved
Before: When the phone was rotated to landscape, the car and the route line could drift out of place.
After: The car and the route stay aligned when the phone is rotated, and a compact junction box is shown in landscape too.

## Smoother navigation start
Before: The camera could jump when navigation started, and the zoom did not adapt to the type of road.
After: The camera moves straight to the car without jumping. Automatic zoom is smarter: closer in corners and further out on highways.

## FG AI and the latest news
Before: FG AI sometimes repeated an old answer even when asked for the latest news.
After: FG AI searches for the latest news when asked, and no longer repeats old answers.

## Android Auto
Before: The car screen map had no car icon, did not follow the car's night mode, and could not be panned.
After: A car icon on the map, night mode that follows the car, pan and zoom, and the map keeps moving even when the phone is locked.

# 1.3.0 | 2026-11-01
A smarter FG AI, and lane guidance on the map.

## FG AI understands everyday sentences
Before: FG AI sometimes did not understand normal sentences or slang, and showed odd text such as "/no_tool".
After: FG AI understands everyday sentences, slang and typos. It can find 23 kinds of places (pharmacy, barber, ATM, hotel and more), shown as cards with distance, area and a Go button.

## FG AI answers up-to-date questions from the web
Before: FG AI could only answer from knowledge on the phone.
After: FG AI can answer up-to-date questions from free web sources: news, exchange rates and fuel prices.
How to use: It can be turned off in Settings > FG AI. Only your question is sent, not your location or chat history.

## FG AI taps buttons for you, and Lite Mode
Before: FG AI only answered with text.
After: FG AI can open screens and tap buttons in the app for you, and you see every step it takes. Lite Mode reduces animations and 3D buildings on slower phones.

## Lane box and direction arrows
Before: No lane guidance on the map.
After: A lane box and direction arrows on the map while driving, so you know which lane to take before the junction.

## Android Auto
Before: The car screen could only search for places by name.
After: A Nearby button, voice search in plain sentences (for example "nearest barber"), prayer time, and real lanes on the car screen.

## More accurate place search
Before: Some Malaysian place names and abbreviations were hard to find.
After: Place search in Malaysia is more accurate and faster.

# 1.2.1 | 2026-10-31
An important fix and a real Qibla compass.

## The app no longer closes by itself
Before: On some Android phones, the app closed by itself right after opening.
After: That problem is fixed.

## A real Qibla compass
Before: The Qibla direction was only calculated from GPS.
After: The Qibla compass uses the phone's sensor and turns green when the phone faces the Qibla exactly.

## A tidier home screen
Before: Shortcuts, prayer time and tools were scattered on the home screen.
After: A tidier home screen, with shortcuts, prayer time and tools neatly arranged.

## R&R and fuel stations along the route
Before: R&R stops and fuel stations along the route sometimes did not appear.
After: They now appear reliably and faster.

## Weather icons and azan in the background
Before: Plain weather icons, and the azan needed the app to be open.
After: Colourful, animated weather icons. The azan can play in the background with one tap.

# 1.2.0 | 2026-10-31
Air quality, toll cost and EV chargers.

## Air quality (API)
Before: No air quality information.
After: The official Air Pollutant Index from the nearest monitoring station.

## Toll estimate in the route preview
Before: Toll cost was not shown before the trip.
After: An estimated toll cost in RM in the route preview.
How to use: This is an estimate, not an official bill.

## EV chargers along the route
Before: Only fuel stations and R&R stops.
After: Electric vehicle chargers along the route are shown too.

## Qibla direction
Before: No Qibla direction in the app.
After: The Qibla direction from your GPS location.

## Haze alerts
Before: No air quality alerts during a trip.
After: Haze alerts along the route, and short voice alerts on Android Auto.

# 1.1.0 | 2026-10-31
Prayer times, music and Easy mode.

## Official prayer times
Before: No prayer times in the app.
After: Official JAKIM prayer times with azan notifications, even when the app is closed.

## Music and radio in the app
Before: Music had to be played from another app.
After: Music and radio in the app (Malaysia, Indonesia, Korea and K-pop). Voice guidance always stays clear over the music.
How to use: The free song catalogue is independent music. Songs by major-label artists can be searched straight in your own Spotify or YouTube Music.

## Easy mode
Before: The same display size for everyone.
After: Easy mode with a bigger display and higher contrast, for older drivers.

## Lane guidance and night map
Before: No lane guidance, and the night map was less clear.
After: Lane guidance, and a clear blue night map.

## Clear roundabout icons
Before: Roundabouts were shown with a small icon.
After: A clear roundabout icon with the exit number in the middle.
