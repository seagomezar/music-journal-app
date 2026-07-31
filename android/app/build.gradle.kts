import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val isUnsignedRelease = project.hasProperty("unsigned") || System.getenv("BUILD_UNSIGNED") == "true"
val isReleaseRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { input ->
        keystoreProperties.load(input)
    }
}

android {
    namespace = "com.seagomezar.flutepracticecoach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.seagomezar.flutepracticecoach"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { path -> project.file(path) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (isUnsignedRelease) {
                null
            } else if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

if (isReleaseRequested && !isUnsignedRelease && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Release signing is not configured. Provide android/key.properties or set BUILD_UNSIGNED=true."
    )
}

flutter {
    source = "../.."
}
