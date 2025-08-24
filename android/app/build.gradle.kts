plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bla_bla"
    compileSdk = 36 // Updated for Google Sign-In compatibility
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bla_bla"
        minSdk = flutter.minSdkVersion  // Keep original if needed
        targetSdk = flutter.targetSdkVersion  // Keep original if needed
        targetSdk = 36 // Updated target SDK
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Add your Google Web Client ID here
        resValue("string", "default_web_client_id", "830134928616-rb2tnnnf11mnd0sk20hjnm5aco9hqqsq.apps.googleusercontent.com")

        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "io.supabase.flutterquickstart"
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Only add if you continue to have credential manager issues
    // implementation("androidx.credentials:credentials:1.2.2")
    // implementation("androidx.credentials:credentials-play-services-auth:1.2.2")
    // implementation("com.google.android.gms:play-services-auth:21.0.0")
}
