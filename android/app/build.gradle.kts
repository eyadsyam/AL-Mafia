import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.crashlytics")
}

// The test-ads build is another package (release + ".adstest", see
// buildTypes) that google-services.json does not list, and the Google
// Services plugin refuses a package it cannot find. The store build takes
// Firebase's values (push, Crashlytics) from the plugin; the test-ads build
// keeps the hand-written values in defaultConfig below.
val testAdsBuild = project.findProperty("TEST_ADS_SUFFIX") == "true"
if (!testAdsBuild) {
    apply(plugin = "com.google.gms.google-services")
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

    // resValue below (test-ads build's Firebase values); off by default in
    // newer Gradle plugins.
    buildFeatures {
        resValues = true
    }

    // The web build plays .mp3 twins of every .ogg (Safari cannot decode
    // Ogg); Android plays the .ogg, so the twins stay out of the APK. AGP's
    // default ignore list plus "*.mp3". Set reflectively so a Gradle plugin
    // without the property still builds (it then only ships ~5 MB more).
    // Check: `unzip -l app-release.apk | findstr .mp3` prints nothing.
    runCatching {
        androidResources.javaClass
            .getMethod("setIgnoreAssetsPattern", String::class.java)
            .invoke(
                androidResources,
                "!.svn:!.git:!.ds_store:!*.scc:.*:!CVS:!thumbs.db:!picasa.ini:!*~:!*.mp3",
            )
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (invite push) needs java.time on old Android.
        isCoreLibraryDesugaringEnabled = true
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

        // Test-ads build only: the four values Firebase reads at start, taken
        // from google-services.json by hand (the store build gets them from
        // the Google Services plugin). The release app's values are used.
        val googleServices = file("google-services.json")
        if (testAdsBuild && googleServices.exists()) {
            @Suppress("UNCHECKED_CAST")
            val json = groovy.json.JsonSlurper().parse(googleServices) as Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val info = json["project_info"] as Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val client = (json["client"] as List<Map<String, Any?>>).first()
            @Suppress("UNCHECKED_CAST")
            val appId = (client["client_info"] as Map<String, Any?>)["mobilesdk_app_id"] as String
            @Suppress("UNCHECKED_CAST")
            val apiKey = ((client["api_key"] as List<Map<String, Any?>>).first())["current_key"] as String
            resValue("string", "google_app_id", appId)
            resValue("string", "google_api_key", apiKey)
            resValue("string", "gcm_defaultSenderId", info["project_number"].toString())
            resValue("string", "project_id", info["project_id"].toString())
        }
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
            firebaseCrashlytics {
                // Store builds only: the test-ads package has no Firebase app.
                mappingFileUploadEnabled = !testAdsBuild
                nativeSymbolUploadEnabled = false
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
