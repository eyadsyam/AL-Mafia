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

    // resValue below (invite push); off by default in newer Gradle plugins.
    buildFeatures {
        resValues = true
    }

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

        // Invite push (docs/PUSH-SETUP.md): the four values Firebase reads at
        // start, taken from google-services.json once the owner has put it
        // next to this file — what the google-services plugin would generate,
        // without the plugin (so a build without the file still builds, with
        // push simply off).
        val googleServices = file("google-services.json")
        if (googleServices.exists()) {
            @Suppress("UNCHECKED_CAST")
            val json = groovy.json.JsonSlurper().parse(googleServices) as Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val info = json["project_info"] as Map<String, Any?>
            @Suppress("UNCHECKED_CAST")
            val clients = json["client"] as List<Map<String, Any?>>
            @Suppress("UNCHECKED_CAST")
            fun packageOf(client: Map<String, Any?>): Any? =
                ((client["client_info"] as Map<String, Any?>)["android_client_info"]
                    as Map<String, Any?>)["package_name"]
            val client = clients.firstOrNull { packageOf(it) == applicationId } ?: clients.first()
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
