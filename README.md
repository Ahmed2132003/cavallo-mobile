# social_commerce_app — Part P-001 skeleton

## Status: PARTIALLY VALIDATED (same caveat pattern as backend Part P-000)

No Flutter SDK is installed in this environment, and outbound network access
is restricted to a fixed domain allowlist that does **not** include
`pub.dev` or the Flutter SDK's download host (`storage.googleapis.com`).
That means the real `flutter create`, `flutter pub get`, `flutter analyze`,
and `flutter run` commands could not actually be executed here.

To avoid a fake completion claim, this part was built by hand instead:

| What P-001 asked for                                            | What actually exists here                                                                 | Verified how |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------- |
| Feature-first folder skeleton (Section 12)                        | ✅ Created exactly: `lib/core/{network,storage,config,widgets}/`, `lib/features/{9 features}/{data,domain,presentation}/`, `lib/routing/` | Directory listing, matches the spec list item-for-item |
| `pubspec.yaml` with pinned `flutter_riverpod`, `dio`, `flutter_secure_storage` | ✅ Hand-written, versions looked up live (flutter_riverpod ^3.4.3, dio ^5.11.0, flutter_secure_storage ^10.3.1 — current stable as of Sep 2026) | Checked against pub.dev search results, **not** installed/resolved |
| `main.dart` — `ProviderScope` + placeholder `MaterialApp`         | ✅ Hand-written                                                                               | Read for correctness, **not** compiled |
| `flutter create --platforms=ios,android` (native `android/`, `ios/` project files, Xcode/Gradle config) | ❌ **NOT done** — this needs the actual Flutter SDK/toolchain to generate correctly; fabricating native project files by hand would be unreliable and is exactly the kind of fake-completion this repo's process rules against | — |
| `flutter analyze` → 0 issues                                     | ❌ Not run (no SDK)                                                                           | — |
| `flutter run` on iOS simulator + Android emulator                 | ❌ Not run (no SDK, no simulators/emulators available)                                        | — |

## What you need to do to actually finish P-001

1. On a machine with the Flutter SDK installed, run:
   ```bash
   flutter create social_commerce_app --platforms=ios,android --org <your_org>
   ```
   in a scratch directory, then copy the generated `android/`, `ios/`,
   `test/`, and platform config files into this repo (they don't exist here
   yet).
2. Copy this `lib/`, `pubspec.yaml`, `analysis_options.yaml`, and
   `.gitignore` over the freshly-generated ones (the generated `lib/main.dart`
   and `pubspec.yaml` should be replaced with these).
3. Run `flutter pub get`, then `flutter analyze` (expect 0 issues) and
   `flutter run` on both an iOS simulator and an Android emulator to confirm
   the placeholder screen launches.
4. Update `PROJECT_PROGRESS.md` to flip P-001 from PARTIALLY VALIDATED to
   COMPLETE once step 3 passes on your machine.

## Folder structure delivered

```
lib/
  core/
    network/      (empty — P-010+)
    storage/      (empty — P-010+)
    config/       (empty — P-010+)
    widgets/      (empty — P-010+)
  features/
    auth/{data,domain,presentation}/
    feed/{data,domain,presentation}/
    stories/{data,domain,presentation}/
    search/{data,domain,presentation}/
    business_profile/{data,domain,presentation}/
    products/{data,domain,presentation}/
    chat/{data,domain,presentation}/
    notifications/{data,domain,presentation}/
    business_console/{data,domain,presentation}/
  routing/         (empty — later parts)
  main.dart
pubspec.yaml
analysis_options.yaml
.gitignore
```

No top-level `screens/` or `models/` folder was added, per the
architecture rule against layer-first organization.
