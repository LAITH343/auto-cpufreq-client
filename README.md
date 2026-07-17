# auto cpufreq — client app

Cross-platform power-manager client for the auto-cpufreq engine. One codebase
targets Linux desktop (local, over D-Bus) and — in a later pass — Android/remote
(over the HTTP/S gateway). Over D-Bus the app has full access including user
management. The remote HTTP/S transport, where the UI adapts to the logged-in
user's permission matrix (features without `read` hidden, `read`-only features
shown read-only with a lock), is planned but not yet wired.

**Current status:** the local D-Bus transport is fully implemented against the
live engine (`org.autocpufreq.Engine1` + `Users1`).

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
    engine_repository.dart       transport-agnostic interface + EngineSnapshot
    dbus_engine_repository.dart  system D-Bus transport (Engine1 + Users1)
  state/           Riverpod controllers: settings, connection/flow, engine, config draft
  theme/           palette (dark/light), typography (Fira Sans/Code)
  l10n/            en/ar string tables
  widgets/         shared UI (cards, segmented control, switch, charts)
  screens/         one file per screen + the shell (sidebar / bottom nav)
  app.dart         MaterialApp, theming, RTL, top-level flow routing
```

State management is **Riverpod**. All screens talk only to `EngineRepository`
— never to a concrete transport. `DbusEngineRepository` (dart `dbus`) talks to
the local engine on the system bus; the engine reports no rolling history, so
it's accumulated client-side from `StatsTick` frames. A future
`HttpEngineRepository` (REST + WSS with TLS fingerprint pinning) will implement
the same interface for remote devices without touching the UI.

## Run

```sh
flutter pub get
flutter run -d linux  # needs the engine running on the system bus
flutter analyze
flutter test

# quick check of the live D-Bus transport (no UI):
dart run tool/dbus_smoke.dart
```

Reaching the engine over D-Bus requires membership in the `autocpufreq-admin`
group (or root).

The launcher icon and app name are generated from `assets/icon.png` via
`dart run flutter_launcher_icons`.
