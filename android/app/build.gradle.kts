plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingStoreFile = System.getenv("TAGER2_KEYSTORE_PATH")
val signingKeyAlias = System.getenv("TAGER2_KEY_ALIAS")
val signingStorePassword = System.getenv("TAGER2_STORE_PASSWORD")
val signingKeyPassword = System.getenv("TAGER2_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    signingStoreFile,
    signingKeyAlias,
    signingStorePassword,
    signingKeyPassword,
).all { !it.isNullOrBlank() }
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Release build requires TAGER2_KEYSTORE_PATH, TAGER2_KEY_ALIAS, " +
            "TAGER2_STORE_PASSWORD, and TAGER2_KEY_PASSWORD."
    )
}

android {
    namespace = "com.infintykey.tager2"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.infintykey.tager2"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(signingStoreFile!!)
                storePassword = signingStorePassword!!
                keyAlias = signingKeyAlias!!
                keyPassword = signingKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
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
