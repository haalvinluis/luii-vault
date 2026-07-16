pluginManagement {
    val flutterProperties = java.util.Properties()
    val flutterPropertiesFile = settingsDir.resolve("local.properties")
    if (flutterPropertiesFile.exists()) {
        flutterPropertiesFile.inputStream().use { flutterProperties.load(it) }
    }

    val flutterSdkPath = flutterProperties.getProperty("flutter.sdk")
        ?: throw GradleException("flutter.sdk not set in local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.1" apply false
    id("com.android.library") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")