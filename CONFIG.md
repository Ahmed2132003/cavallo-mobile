# Configuration — Flutter (`cavallo-mobile`)

The Flutter app has no `.env` file — Flutter build-time config is passed via
`--dart-define` flags and read through `lib/core/config/app_config.dart`
(`AppConfig`). This avoids bundling any secret inside the compiled app binary
(anything baked in at build time can be extracted from the APK/IPA, so no real
secret should ever go through `--dart-define` either — this mechanism is for
non-secret config like API URLs and environment names only).

## Values

| Value | Read via | Purpose |
| --- | --- | --- |
| `API_BASE_URL` | `AppConfig.apiBaseUrl` | Base URL the Dio client (P-010+) will call for all backend requests |
| `ENVIRONMENT` | `AppConfig.environment` | Which backend environment this build targets: `dev` \| `staging` \| `prod` |

## Running locally (no flags needed)

```bash
flutter run
```

With no `--dart-define` at all, `AppConfig` defaults to `environment = dev` and
picks `apiBaseUrl` automatically per platform, since the backend (Django dev
server, from `cavallo-app`'s `docker-compose.yml`) is exposed on the **host
machine's port 8090**, and `localhost` doesn't mean "the host machine" from
every target the same way:

| Target | Default `apiBaseUrl` | Why |
| --- | --- | --- |
| Android Emulator | `http://10.0.2.2:8090` | The emulator's own `localhost` refers to the emulator, not the host — `10.0.2.2` is Android's documented alias for the host machine |
| iOS Simulator | `http://localhost:8090` | The iOS Simulator shares the host's network stack directly |
| Web / desktop | `http://localhost:8090` | Same as above |
| A real device (Android or iOS) on the same Wi-Fi | **Neither default works** — see below | Real devices aren't the host machine at all |

## Overriding `API_BASE_URL` (real devices, staging, prod)

Always pass it explicitly:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8090
```

Find your host machine's LAN IP (`ipconfig` on Windows / `ifconfig` or
`ip addr` on macOS/Linux) and make sure the phone is on the same network and
the backend's host firewall allows inbound connections on port 8090.

## Setting the environment for staging/prod builds

```bash
flutter build apk --dart-define=ENVIRONMENT=staging --dart-define=API_BASE_URL=https://staging-api.example.com
flutter build apk --dart-define=ENVIRONMENT=prod --dart-define=API_BASE_URL=https://api.example.com
```

`AppConfig.apiBaseUrl` deliberately **throws** if `ENVIRONMENT` is `staging` or
`prod` and `API_BASE_URL` wasn't also passed — this is intentional, to fail a
staging/prod build loudly at first use rather than silently falling back to a
local dev URL nobody meant to ship.

## Adding a new config value later

Add it to the table above, add a matching getter on `AppConfig`, and document
the `--dart-define` flag here — don't read `String.fromEnvironment` directly
from feature code.

## Backend side

See the backend repo's own `CONFIG.md` (`cavallo-app`) for the Django-side
environment variables (database, Redis, JWT, Sentry, object storage, FCM,
Paymob) — unrelated to this file, which only covers the Flutter build-time
config above.