plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.go.sumutprov.disdik.jargon"
    // compileSdk dipatok, bukan mengikuti flutter.compileSdkVersion (36).
    //
    // flutter_secure_storage dan permission_handler_android menuntut
    // dikompilasi terhadap SDK 37; dengan 36 build gagal. Menaikkan
    // compileSdk hanya mengubah API yang tersedia SAAT KOMPILASI - versi
    // Android minimum yang didukung tetap ditentukan minSdk di bawah.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.go.sumutprov.disdik.jargon"

        // minSdk 26 (Android 8.0), bukan nilai bawaan Flutter.
        //
        // Dua paket menuntutnya: google_mlkit_face_detection (minSdk 21 tetapi
        // model on-device baru stabil di 8.0) dan flutter_secure_storage yang
        // memakai Keystore dengan EncryptedSharedPreferences. Selain itu,
        // inferensi TFLite pada perangkat di bawah Android 8 terlalu lambat
        // untuk antrean absensi pagi.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // GANTI sebelum distribusi ke sekolah: buat keystore sendiri dan
            // rujuk di sini. Menandatangani APK produksi dengan kunci debug
            // membuat pembaruan aplikasi tidak bisa dipasang di atas versi
            // sebelumnya.
            signingConfig = signingConfigs.getByName("debug")

            // Model TFLite tidak boleh dikompresi: interpreter memetakannya
            // langsung dari APK (mmap), dan berkas terkompresi memaksa
            // penyalinan penuh ke memori pada setiap start.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            // Beberapa paket ML membawa berkas META-INF yang bertabrakan.
            excludes += setOf("META-INF/DEPENDENCIES", "META-INF/LICENSE*")
        }
    }

    androidResources {
        noCompress += "tflite"
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
