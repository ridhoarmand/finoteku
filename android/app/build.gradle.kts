import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: one keystore for CI and local builds, so every release can be
// installed over the previous one. CI passes env vars; locally android/key.properties
// (gitignored) points at ~/.finoteku-keys. See CLAUDE.md "Release".
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(env: String, prop: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keyProps.getProperty(prop)

val releaseStoreFile = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")
val buildsRelease = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (buildsRelease && releaseStoreFile == null) {
    throw GradleException(
        "No release keystore: set ANDROID_KEYSTORE_* env vars or create android/key.properties. " +
            "A debug-signed release cannot be installed over the previous version."
    )
}

android {
    namespace = "id.ridhoarmand.finoteku"
    compileSdk = flutter.compileSdkVersion
    ndkVersion =  "28.2.13676358"

    compileOptions {
    // Upgrade to Java 17 (required by newer Android Gradle Plugin & recommended by Flutter 3.22+)
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
    // Match Kotlin JVM target with Java 17
    jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.ridhoarmand.finoteku"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
    // Kotlin DSL uses the property name `minSdk` instead of the Groovy method style `minSdkVersion`.
    // The previous line caused a script compilation error.
    minSdk = flutter.minSdkVersion  // Minimum untuk exact alarms
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
