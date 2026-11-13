allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The Firebase Android SDK version, i.e. the Firebase BOM every FlutterFire
// plugin already applies to itself (`platform("com.google.firebase:firebase-bom")`).
// This property is the supported way to choose it: firebase_core reads
// `FlutterFire["FirebaseSDKVersion"]` first and otherwise falls back to the
// default in its own gradle.properties (35.1.0 for firebase_core 5.1.0).
//
// Setting it here makes the version visible instead of buried inside a plugin,
// keeps Common/Crashlytics/Sessions/Installations on one tested train, and takes
// a BOM patch or minor release without waiting for a FlutterFire release.
//
// It also wins over whatever the plugins ship, including a newer default: if a
// future firebase_core expects a higher BOM, bump this line with it or the
// plugins are held back. The Crashlytics Gradle plugin in settings.gradle.kts
// must stay compatible with the Crashlytics SDK from this BOM (21.1.0 here).
extra.set("FlutterFire", mapOf("FirebaseSDKVersion" to "35.2.0"))

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
