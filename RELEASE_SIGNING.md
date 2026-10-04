# Release Signing and Store Identifiers (Part P-107)

STATUS: PREPARED, NOT EXECUTED. Everything below that needs a real account is BLOCKED on master plan Section 7 item 8 (Apple Developer Program and Google Play Console accounts). Store requirements change: re-verify every store-side step against the current official documentation before executing it.

## 1. Provisional values (replace when the real ones exist)

| Item | Current value | Where it lives |
|---|---|---|
| Android applicationId and namespace | `com.example.social_commerce_app` (PROVISIONAL, the Play Console rejects `com.example.*`) | `android/app/build.gradle.kts`; `android/app/src/main/kotlin/com/example/social_commerce_app/MainActivity.kt` (folder path and `package` line) |
| iOS bundle identifier | `com.example.socialCommerceApp` (PROVISIONAL) | `ios/Runner.xcodeproj/project.pbxproj` (Runner target, Debug/Release/Profile; RunnerTests uses the same id plus `.RunnerTests`) |
| App display name | `Social Commerce App` (PROVISIONAL) | Android: `android:label` in `AndroidManifest.xml`. iOS: `CFBundleDisplayName` in `ios/Runner/Info.plist` |
| App icons | Flutter default placeholders (pending Section 7 item 5, real brand assets) | `android/app/src/main/res/mipmap-*`; `ios/Runner/Assets.xcassets/AppIcon.appiconset` |
| Release signing | none. Android falls back to the debug key; iOS is unsigned | sections 3 and 4 |

Use ONE final id family for both platforms, lowercase letters, digits and dots only (for example `com.<company>.<app>`): underscores are not valid in iOS bundle identifiers. Decide it BEFORE creating the Firebase project (P-081) and the store records, because changing it afterwards means registering again.

## 2. Version and build number scheme

Single source of truth: `pubspec.yaml`, `version: MAJOR.MINOR.PATCH+BUILD` (currently `0.1.0+1`).

- Android: `versionName` = MAJOR.MINOR.PATCH, `versionCode` = BUILD (via `flutter.versionName` / `flutter.versionCode` in `build.gradle.kts`).
- iOS: `CFBundleShortVersionString` = MAJOR.MINOR.PATCH, `CFBundleVersion` = BUILD (via `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` in `Info.plist`).
- BUILD must go up on EVERY upload to either store, even for the same MAJOR.MINOR.PATCH. Never reuse a number.
- Override for one build without editing the file: `flutter build appbundle --release --build-name=1.0.0 --build-number=2`.

## 3. Android: upload keystore and release build

Needs: the Google Play Console account (Section 7 item 8). The keystore itself can be created at any time.

1. Create the upload keystore OUTSIDE the repository (keep two backups in different safe places; losing it complicates future updates):
   `keytool -genkeypair -v -keystore D:\Secrets\cavallo-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Copy `android/key.properties.example` to `android/key.properties` (git-ignored) and fill in `storeFile` (forward slashes), `storePassword`, `keyAlias`, `keyPassword`.
3. Build the bundle: `flutter build appbundle --release` (output: `build/app/outputs/bundle/release/app-release.aab`). Without `key.properties` the build still completes but is signed with the debug key and CANNOT be uploaded.
4. In the Play Console create the app with the final applicationId, enroll in Play App Signing (the keystore above then acts as the upload key), upload the `.aab` to an internal testing track first.

## 4. iOS: signing and release build

Needs: a Mac with the current Xcode, and a paid Apple Developer Program membership. None exists yet (Section 7 item 8).

1. Enroll in the Apple Developer Program.
2. developer.apple.com, Certificates, Identifiers and Profiles, Identifiers: register an explicit App ID equal to the FINAL bundle identifier, with the Push Notifications capability enabled.
3. App Store Connect, My Apps, New App: create the app record with the same bundle identifier.
4. Open `ios/Runner.xcworkspace` in Xcode, Runner target, Signing and Capabilities: select the Team and tick "Automatically manage signing". Xcode then creates the Apple Distribution certificate and the App Store provisioning profile. (Manual alternative: create a certificate signing request in Keychain Access, create an Apple Distribution certificate, create an App Store provisioning profile for the App ID, install both.)
5. Add the capabilities Push Notifications and Background Modes (Remote notifications). This creates `ios/Runner/Runner.entitlements` and edits `project.pbxproj`; commit both.
6. Firebase (Section 7 item 4): create an APNs authentication key (.p8) in the Apple Developer account, upload it in the Firebase console (Project settings, Cloud Messaging), add `GoogleService-Info.plist` to the Runner target in Xcode.
7. Build: `flutter build ipa --release` (output in `build/ios/ipa/`). Add `--build-name` / `--build-number` as in section 2 if needed.
8. Upload with the Transporter app or Xcode Organizer, then test through TestFlight before submitting for review.

## 5. Checklist when the final identifier is decided

1. Android: `namespace` and `applicationId` in `build.gradle.kts`; move `MainActivity.kt` to the matching folder and fix its `package` line.
2. iOS: every `PRODUCT_BUNDLE_IDENTIFIER` in `project.pbxproj` (Runner x3 configurations, RunnerTests x3 with the `.RunnerTests` suffix).
3. Firebase: register both apps with the final ids, add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
4. Remove the PROVISIONAL comments in `build.gradle.kts`, `AndroidManifest.xml` and `Info.plist`.
5. Update the display name and the purpose-string texts in `Info.plist` if the final product name differs.

## 6. Deliberately NOT done in P-107

- Push entitlements and `UIBackgroundModes` (need the App ID and Firebase, section 4 steps 2 and 5).
- `PrivacyInfo.xcprivacy` (privacy manifest): decide with the final data-collection disclosure, see `STORE_LISTING_CHECKLIST.md`.
- `ITSAppUsesNonExemptEncryption`: an export-compliance declaration for the owner to decide; not set here.
- `ios/Podfile`: absent from the repository, Flutter generates it on the first build on a Mac. After that first build confirm it contains `platform :ios, '13.0'` (Firebase needs iOS 13).
- No iOS build has ever been run (no Mac available). The iOS changes of Step 2 are verified statically only.