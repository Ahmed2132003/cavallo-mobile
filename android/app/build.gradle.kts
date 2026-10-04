import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Part P-107: release-signing STRUCTURE.
// Real credentials live ONLY in android/key.properties (git-ignored; template:
// android/key.properties.example). That file does not exist yet because no
// Google Play Console account / upload keystore exists (master plan Section 7
// item 8, BLOCKED). Without it, release builds fall back to the DEBUG key so the
// build still completes structurally. Such a build can NOT be uploaded to the
// Play Store.
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach { key ->
        require(keystoreProperties.containsKey(key)) { "android/key.properties is missing '$key'" }
    }
}

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { it.name.contains("Release", ignoreCase = true) }
    if (releaseRequested && !hasReleaseKeystore) {
        logger.warn(
            "P-107 WARNING: android/key.properties not found - the release build is signed " +
                "with the DEBUG key and CANNOT be uploaded to the Play Store (Section 7 item 8)."
        )
    }
}

android {
    namespace = "com.example.social_commerce_app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // P-107 PROVISIONAL: "com.example.*" is the Flutter scaffold default and the Play
        // Console rejects it. Decide the final id BEFORE registering the app in Firebase
        // (P-081) and the Play Console. Changing it means: namespace above, this value,
        // the MainActivity.kt folder + package line, and the iOS bundle identifier.
        applicationId = "com.example.social_commerce_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        // P-107: pinned explicitly. Flutter 3.29.3's flutter.targetSdkVersion is 35, but the Play
        // Console requires target API 36 for new apps and updates from 2026-08-31 (see
        // STORE_LISTING_CHECKLIST.md, A5). Revisit when Flutter is upgraded.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // P-107: filled in only when android/key.properties exists.
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // P-107: real upload key when android/key.properties exists, otherwise the
            // debug key (structural build only, NOT store-uploadable).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // P-107: R8 code shrinking + resource shrinking. Rules: android/app/proguard-rules.pro
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
