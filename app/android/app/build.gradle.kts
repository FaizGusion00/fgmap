import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci tandatangan release dibaca daripada android/key.properties (TIDAK dikomit; lihat .gitignore):
//   storeFile=../upload-keystore.jks   storePassword=...   keyAlias=upload   keyPassword=...
// Tanpa fail itu, build release ditandatangani dengan kunci debug supaya `flutter run --release` kekal
// berfungsi, tetapi hasilnya TIDAK boleh diterbitkan ke Play Store. Build untuk kedai (`make appbundle`
// menetapkan FGMAP_STORE_BUILD=1) GAGAL serta-merta tanpa kunci release, supaya binari bertandatangan
// debug tidak pernah tersalah terbit.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.fguniversal.fgmap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fguniversal.fgmap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Hanya `make appbundle` (FGMAP_STORE_BUILD=1) mengunci hos Android Auto.
        // APK release yang dipasang sendiri mesti tetap muncul pada unit sebenar.
        val storeBuild = System.getenv("FGMAP_STORE_BUILD") == "1"
        buildConfigField("boolean", "STORE_BUILD", storeBuild.toString())
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            // Eksplisit (bukan bergantung pada lalai Flutter): kod dikecilkan dan dikaburkan oleh R8,
            // sumber tidak digunakan dibuang. Peraturan simpan JNI valhalla ada dalam proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            // Ditambah (bukan menggantikan) peraturan lalai Flutter/AGP.
            proguardFile("proguard-rules.pro")
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseArtifact = allTasks.any {
        it.name.contains("Release") &&
            (it.name.startsWith("assemble") || it.name.startsWith("bundle"))
    }
    if (releaseArtifact && !hasReleaseKey) {
        if (System.getenv("FGMAP_STORE_BUILD") == "1") {
            throw GradleException(
                "Build kedai memerlukan android/key.properties (kunci release). " +
                    "Binari bertandatangan debug tidak boleh diterbitkan.",
            )
        }
        logger.warn(
            "AMARAN: build release ditandatangani dengan kunci DEBUG (tiada android/key.properties). " +
                "Hanya untuk ujian tempatan; jangan terbitkan.",
        )
    }
}

dependencies {
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.car.app:app-projected:1.7.0")
    // Sama dengan pemalam maplibre_gl supaya satu SDK peta sahaja.
    implementation("org.maplibre.gl:android-sdk-opengl:13.5.0")
}

flutter {
    source = "../.."
}
