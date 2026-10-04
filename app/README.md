# SIAGA app

Flutter app for SIAGA (Android, iOS, web). Residents see the risk level for their own area, get evacuation guidance, and can report hazards.

## What it does

- **Live map** of sensor nodes, colour-coded by risk state, with search and per-node history charts.
- **My Risk**: a four-level indicator (Normal, Watch, Warning, Evacuate) for the node you choose, or the nearest one.
- **Evacuation**: full-screen alert with the nearest assembly point and a route, cached so it works offline.
- **Community reports**: category, location (a grid cell, not coordinates), note and optional photo.
- **English and Bahasa Malaysia**, picked from the device locale with a manual override.
- **Demo mode**: drives the whole UI from a simulated flood, and lets you set the state by hand, so everything can be shown without real data.

## Privacy

Your GPS position never leaves the phone. The app converts it to an H3 grid cell (resolution 8) on-device, subscribes to a push topic for that cell, and only ever sends the cell ID, for example with a community report. See `lib/core/h3_service.dart` and `lib/core/location_service.dart`.

## Run it

```bash
flutter pub get
flutter gen-l10n        # only needed after editing lib/l10n/*.arb
flutter run -d chrome   # or pick an Android device
flutter test
```

The app talks to the hosted API by default (`lib/core/api_client.dart`). Push notifications need a Firebase project: add your own `google-services.json` (Android) and the app will pick it up. Without it everything else still works.

## Build an Android APK

```bash
flutter build apk --release
```

The output is `build/app/outputs/flutter-apk/app-release.apk`, signed with the debug key (fine for sideloading, not for the Play Store).

## Layout

| Folder | Contents |
|---|---|
| `lib/core/` | API client, app state, H3 and location services, offline cache, theme |
| `lib/screens/` | Map, My Risk, Evacuate, Report, Settings |
| `lib/widgets/` | Risk gauge and badge, alert banner, metric cards, charts |
| `lib/demo/` | Hydrograph generator and demo controller |
| `lib/l10n/` | English and Malay strings |
| `assets/` | Assembly points |
