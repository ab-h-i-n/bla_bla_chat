plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bla_bla"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.bla_bla"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "default_web_client_id", "830134928616-rb2tnnnf11mnd0sk20hjnm5aco9hqqsq.apps.googleusercontent.com")

        manifestPlaceholders["appAuthRedirectScheme"] = "io.supabase.flutterquickstart"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Add if needed for Google Auth:
    // implementation("androidx.credentials:credentials:1.2.2")
    // implementation("androidx.credentials:credentials-play-services-auth:1.2.2")
    // implementation("com.google.android.gms:play-services-auth:21.0.0")
}
