import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningNames = listOf(
    "RAD_RELEASE_STORE_FILE",
    "RAD_RELEASE_STORE_PASSWORD",
    "RAD_RELEASE_KEY_ALIAS",
    "RAD_RELEASE_KEY_PASSWORD",
)
val releaseSigningValues = releaseSigningNames.associateWith { name ->
    providers.environmentVariable(name).orNull
}
val releaseApplicationId = providers.environmentVariable("RAD_ANDROID_APPLICATION_ID").orNull
val missingReleaseSigning = releaseSigningNames.filter {
    releaseSigningValues[it].isNullOrBlank()
}
val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (releaseApplicationId.isNullOrBlank() ||
            releaseApplicationId == "com.example.rad_emigrate"
        ) {
            throw GradleException(
                "Android release build requires a permanent, owner-approved " +
                    "RAD_ANDROID_APPLICATION_ID. The placeholder package ID is not allowed.",
            )
        }
        if (missingReleaseSigning.isNotEmpty()) {
            throw GradleException(
                "Android release build requires " +
                    missingReleaseSigning.joinToString(", ") +
                    ". Supply signing values through the RAD_RELEASE_* environment variables.",
            )
        }
    }
}

tasks.configureEach {
    if (name.startsWith("package") && name.contains("Release") ||
        name == "bundleRelease"
    ) {
        dependsOn(verifyReleaseSigning)
    }
}

android {
    namespace = "com.example.rad_emigrate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Debug builds keep the local placeholder. Release packaging is blocked above
        // until the owner supplies the permanent identity explicitly.
        applicationId = releaseApplicationId ?: "com.example.rad_emigrate"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (missingReleaseSigning.isEmpty()) {
            create("release") {
                storeFile = file(releaseSigningValues.getValue("RAD_RELEASE_STORE_FILE")!!)
                storePassword = releaseSigningValues.getValue("RAD_RELEASE_STORE_PASSWORD")
                keyAlias = releaseSigningValues.getValue("RAD_RELEASE_KEY_ALIAS")
                keyPassword = releaseSigningValues.getValue("RAD_RELEASE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (missingReleaseSigning.isEmpty()) {
                signingConfig = signingConfigs.getByName("release")
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
