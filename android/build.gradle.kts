allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// ---------------------------------------------------------------------
// Selaraskan target JVM di SELURUH plugin.
//
// MENGAPA PERLU
//
// Sebagian plugin Flutter menyetel target Java dan Kotlin secara terpisah,
// dan pada Gradle/Kotlin versi baru ketidaksesuaiannya menjadi galat, bukan
// peringatan:
//
//   Execution failed for task ':tflite_flutter:compileReleaseKotlin'.
//   > Inconsistent JVM-target compatibility detected for tasks
//     'compileReleaseJavaWithJavac' (11) and 'compileReleaseKotlin' (21).
//
// Sumbernya kode plugin, bukan kode aplikasi ini — jadi tidak bisa
// diperbaiki di app/build.gradle.kts. Yang bisa dilakukan pemilik proyek
// adalah memaksakan satu nilai untuk semuanya, di sini.
//
// Dipilih 17 karena itu yang dipakai modul :app dan yang diminta AGP 8.
// Sumber plugin yang ditulis untuk Java 11 tetap terkompilasi di bawah 17.
//
// TANPA afterEvaluate, dan itu penting: blok `evaluationDependsOn(":app")`
// di bawah sudah memaksa subproyek dievaluasi, sehingga afterEvaluate
// gagal dengan "Cannot run Project.afterEvaluate(Action) when the project
// is already evaluated". `configureEach` sudah lazy — ia mengonfigurasi
// task saat task itu dibutuhkan, jadi tidak perlu menunggu evaluasi.
// ---------------------------------------------------------------------
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
            )
        }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
