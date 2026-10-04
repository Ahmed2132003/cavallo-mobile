# Part P-107 - R8 / ProGuard rules for release builds.
# Flutter's Gradle plugin and the plugins in pubspec.yaml (firebase_messaging,
# sentry_flutter, flutter_secure_storage, image_picker, share_plus) ship their own
# consumer rules, so only generic safety rules live here. If a release build ever
# crashes with ClassNotFoundException / NoSuchMethodException that debug does not,
# add a targeted -keep rule below with a comment saying why.

# Flutter deferred components reference Play Core classes that are not bundled.
-dontwarn com.google.android.play.core.**

# Keep generated plugin registration (reflection-style lookups by the engine).
-keep class io.flutter.plugins.** { *; }

# Stack traces / annotations used by Sentry and Firebase.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes SourceFile, LineNumberTable