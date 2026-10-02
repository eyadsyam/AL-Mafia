import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is mandatory. Credentials remain in ignored local files.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.mafiamaster.mafia_master"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {

        applicationId = "com.mafiamaster.mafia_master"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Supplied by ORG_GRADLE_PROJECT_ADMOB_APP_ID in tool/build_apk.ps1.
        // Google's documented sample id is safe for local/test builds; the
        // Dart layer does not load an ad without a rewarded unit id.
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("ADMOB_APP_ID") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"

        // Keep every ABI selected by Flutter for the universal release APK.
    }



    // Phase 100: a release built with ads switched off must not carry the ad
    // SDK's advertising-ID / AdServices permissions (merged from
    // google_mobile_ads), so the Play Advertising ID and Data safety answers
    // can truthfully say the build does not use them. tool/build_apk.ps1 sets
    // ADS_PERMISSIONS=strip whenever ADS_ENABLED is not true; the test-ad and
    // ads-enabled builds keep them.
    if (project.findProperty("ADS_PERMISSIONS") == "strip") {
        sourceSets.getByName("release").manifest.srcFile("src/noAds/AndroidManifest.xml")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
            // See proguard-rules.pro: the startup crash in R8 full mode.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (project.findProperty("TEST_ADS_SUFFIX") == "true") {
                applicationIdSuffix = ".adstest"
                versionNameSuffix = "-ads-test"
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

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        check(keystorePropertiesFile.exists()) {
            "Release signing requires android/key.properties and the established release key."
        }
    }
}
