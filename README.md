# auto cpufreq — client app

Cross-platform power-manager client for the auto-cpufreq engine. One codebase
targets Linux desktop (local, over D-Bus) and Android/remote (over the HTTP/S
gateway). Over D-Bus the app has full access including user management; over
HTTP/S the UI adapts to the logged-in user's permission matrix — features
without `read` are hidden, features with `read` but not `write` render
read-only with a lock indicator.

## Screens

Devices (entry) · Login (with trust-on-first-use fingerprint) · Dashboard
(live CPU/temp/power, per-core grid, quick actions) · Controls (governor/turbo
override) · Configuration (charger/battery profiles, frequency range, ignore
list, bluetooth-on-boot) · Battery (thresholds, conservation mode) · Users &
Permissions (D-Bus only) · Settings · Software update.

Dark/light themes, four accent colors, and English + Arabic (RTL).

## Architecture

```
lib/
  models/          plain data models (permissions, cpu/cores/power, config, users…)
  data/
    engine_repository.dart      transport-agnostic interface + EngineSnapshot
    mock_engine_repository.dart  in-memory engine for dev/demo (live ticking)
  state/           Riverpod controllers: settings, connection/flow, engine, config draft
  theme/           palette (dark/light), typography (Fira Sans/Code)
  l10n/            en/ar string tables
  widgets/         shared UI (cards, segmented control, switch, charts)
  screens/         one file per screen + the shell (sidebar / bottom nav)
  app.dart         MaterialApp, theming, RTL, top-level flow routing
```

State management is **Riverpod**. All screens talk only to `EngineRepository`
— never to a concrete transport. The current implementation is
`MockEngineRepository`, which reproduces the reference design's simulated
telemetry. The real `DbusEngineRepository` (dart `dbus`) and
`HttpEngineRepository` (REST + WSS with TLS fingerprint pinning) implement the
same interface and slot in without touching the UI.

## Run

```sh
flutter pub get
flutter run           # pick a device (linux, android, …)
flutter analyze
flutter test
```

The launcher icon and app name are generated from `assets/icon.png` via
`dart run flutter_launcher_icons`.
