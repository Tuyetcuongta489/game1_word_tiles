import java.text.SimpleDateFormat
import java.util.Date
import java.io.FileInputStream
import java.util.Properties
import com.android.build.gradle.internal.api.BaseVariantOutputImpl

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


// ============================================================================
// Android Versioning: Tăng số này khi build Android bằng Android Studio / IDE
// ============================================================================
val androidVersionCode = 106
val androidVersionName = "1.0.6"

android {
    namespace = "com.fw.word.connect.puzzle"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fw.word.connect.puzzle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        
        versionCode = androidVersionCode
        versionName = androidVersionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            val storeFilePath = keystoreProperties["storeFile"] as String?
            storeFile = if (storeFilePath != null) rootProject.file(storeFilePath) else null
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            excludes += listOf("**/libapplovin-native-crash-reporter.so")
        }
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this
            if (output is BaseVariantOutputImpl) {
                val date = SimpleDateFormat("yyyyMMdd").format(Date())
                val vName = variant.versionName ?: androidVersionName
                val vCode = variant.versionCode ?: androidVersionCode
                output.outputFileName = "FW27_Mobgame_v${vName}_c${vCode}_${date}.apk"
            }
        }
    }
}

tasks.matching { it.name.startsWith("bundle") && it.name.endsWith("Bundle") }.configureEach {
    doLast {
        val date = SimpleDateFormat("yyyyMMdd").format(Date())
        val vName = android.defaultConfig.versionName ?: androidVersionName
        val vCode = android.defaultConfig.versionCode ?: androidVersionCode
        val bundleDir = layout.buildDirectory.dir("outputs/bundle").get().asFile
        if (bundleDir.exists()) {
            bundleDir.walkTopDown().filter { it.extension == "aab" }.forEach { aabFile ->
                if (!aabFile.name.startsWith("FW27_Mobgame")) {
                    val targetName = "FW27_Mobgame_v${vName}_c${vCode}_${date}.aab"
                    val targetFile = File(aabFile.parentFile, targetName)
                    aabFile.copyTo(targetFile, overwrite = true)
                }
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

dependencies {
    // AppLovin MAX Mediation Adapters (14 networks for Game Client)
    implementation("com.applovin.mediation:google-adapter:+")
    implementation("com.applovin.mediation:google-ad-manager-adapter:+")
    implementation("com.applovin.mediation:facebook-adapter:+")
    implementation("com.applovin.mediation:mintegral-adapter:+")
    implementation("com.applovin.mediation:unityads-adapter:+")
    implementation("com.applovin.mediation:fyber-adapter:+")
    implementation("com.applovin.mediation:vungle-adapter:+")
    implementation("com.applovin.mediation:bytedance-adapter:+")
    implementation("com.applovin.mediation:ironsource-adapter:+")
    implementation("com.applovin.mediation:inmobi-adapter:+")
    implementation("com.applovin.mediation:yandex-adapter:+")
    implementation("com.applovin.mediation:bigoads-adapter:+")
    implementation("com.applovin.mediation:bidmachine-adapter:+")
    implementation("com.applovin.mediation:moloco-adapter:+")
}

