plugins {
    // Plugin Android Gradle
    id("com.android.application") version "8.7.0" apply false // Thay đổi phiên bản nếu cần
    id("com.google.gms.google-services") version "4.4.2" apply false // Thêm plugin Google Services
}

buildscript {
    repositories {
        google()  // Thêm Google repository
        mavenCentral()  // Thêm Maven repository
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")  
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

