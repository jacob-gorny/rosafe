# Rosafe for iPhone

Rosafe is the project's iPhone app. It shows what the model says about 850 Dallas-Fort Worth roads (the roads with a
map shape) on one day. Home has three words: Daily score (how the model expects the whole network to run against a normal day, the day's
rain, days since rain and high, why, and the busiest roads predicted against what happened), Roads to avoid (the roads
the model flagged that day, worst first; a tap shows why) and Map. The weather symbols around them are picked from
whether that day had rain, ice, fog or thunder at DFW Airport. With location and notifications allowed, the app watches in the background: when you
drive faster than about 20 mph toward a flagged road and are within half a mile of it, it sends one notification
("Approaching risky road / I-35E · 66% more crashes than normal today") over whatever app is in front, Apple Maps
included. It never navigates and never asks for a route. Roads are flagged only on days with rain or ice. The app
replays past days: the day picker makes any 2023 or 2024 day "today" (2024 is the test year the model never saw; 2023
is the practice year). There is no live weather yet.

All the numbers come from the files in the repo's `data/` folder, which the app bundles (formats:
`docs/app-data-contract.md`).

## Build and run

- Xcode 27 (built with 27.2), iOS 18 or later.
- Open `app/SameRain.xcodeproj`, choose the scheme `SameRain` and any iPhone Simulator, then Product → Run.
- The project, target and folders are still named SameRain; the app's name on the phone is Rosafe.
- On a real iPhone, set your own team under Signing & Capabilities first. No signing files are in the repo.

## Run the tests

In Xcode, Product → Test. Or from the repo root, with any iPhone Simulator you have:

```bash
xcodebuild test -project app/SameRain.xcodeproj -scheme SameRain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The tests use Swift Testing and run inside the app on the Simulator, against the bundled data files.

## Debug launch arguments

Debug builds only. Set them in the scheme (Product → Scheme → Edit Scheme → Run → Arguments), or pass them to
`xcrun simctl launch booted com.samerain.SameRain`:

- `-date 2024-09-23` makes that day "today" (if it is in the data).
- `-page score`, `-page roads` or `-page map` opens Daily score, Roads to avoid or Map at launch.
- `-road state-ih35e-asphalt_over_concrete` opens that road's popup, the way a tap on its notification does.

## Simulate a drive

On the Map page, "Simulate a drive" lists the five demo drives from `data/routes.gpx`, each with how many alerts it
will send on the chosen day. Picking one replays it at 5 times real speed (65 mph on the route's own clock) through the
same alert code a real drive uses, with a moving dot on the map; the notification arrives as it would on the road.
While it runs, the phone's own location is left out. "End drive" stops it. If the phone was never asked about
notifications, the app asks first and starts the drive once that is answered. On screen it always says "Simulated
drive".

## Privacy

Our code makes no network calls; the Map page uses Apple's MapKit, which loads map tiles from Apple. Each location is compared in memory with the day's flagged roads and then dropped:
it is never stored, logged or sent. The notification is a local one, with no push server and no account.

## Dev script

`app/tools/video-route.swift` is a Mac-only dev script, not part of the app. It asks Apple Maps for driving directions
and writes the points of the filmed drive in the video, which the Simulator then plays with `xcrun simctl location`.
The app never runs it.

## Credits

The Archivo typeface, under the SIL Open Font License (`app/SameRain/Resources/OFL-Archivo.txt`); Apple's SwiftUI,
MapKit, Core Location and UserNotifications; SF Symbols for the in-app symbols. The app icon is our own drawing, made from simple shapes by
`app/tools/draw_icon.py`.
