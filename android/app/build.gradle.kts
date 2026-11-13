import java.io.FileInputStream
import java.util.Properties


plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material lives in `android/key.properties`, which is gitignored
// along with every *.jks. Without the file - a fresh clone, CI, a contributor's
// machine - the release build falls back to the debug key so it still runs.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val hasUploadKey =
    keystorePropertiesFile.exists() && keystoreProperties.getProperty("storeFile") != null

// --- Android SDK levels ------------------------------------------------------
// Which SDK, build-tools and NDK this app builds against, read from
// android/gradle.properties (where the defaults live, so they are visible and
// versioned) and then from android/local.properties (gitignored, already holds
// flutter.sdk and sdk.dir), which wins so a machine can pin its own toolchain
// without touching the repository.
//
// The key names are the ones Flutter itself uses for these values, so a
// local.properties block written for another Flutter project works as it is.
// Anything missing falls back to what the Flutter Gradle plugin ships.
val localProperties = Properties().apply {
    val local = rootProject.file("local.properties")
    if (local.exists()) {
        FileInputStream(local).use { load(it) }
    }
}

fun sdkSetting(name: String): String? =
    localProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }
        ?: (project.findProperty(name) as String?)?.trim()?.takeIf { it.isNotEmpty() }

fun sdkSetting(name: String, fallback: Int): Int =
    sdkSetting(name)?.toInt() ?: fallback

fun sdkSetting(name: String, fallback: String): String =
    sdkSetting(name) ?: fallback

android {
    namespace = "io.github.under3415.wikitreeviewer"
    compileSdk = sdkSetting("flutter.compileSdk", flutter.compileSdkVersion)
    compileSdkMinor = sdkSetting("flutter.compileSdkMinor", 0)
    compileSdkExtension = sdkSetting("flutter.sdkExtension", 0)
    ndkVersion = sdkSetting("flutter.ndkVersion", flutter.ndkVersion)
    // Optional: left to AGP's own default when the key is absent.
    sdkSetting("flutter.buildToolsVersion")?.let { buildToolsVersion = it }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent: this ID cannot be changed after the first Play Store upload.
        applicationId = "io.github.under3415.wikitreeviewer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = sdkSetting("flutter.minSdk", flutter.minSdkVersion)
        targetSdk = sdkSetting("flutter.targetSdk", flutter.targetSdkVersion)
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // The store rejects anything signed with the debug certificate, so the
            // upload key is used whenever it is configured.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
