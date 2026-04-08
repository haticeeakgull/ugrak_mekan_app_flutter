allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build dizini ayarların
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    val project = this
    
    // Android Ayarları: Java 17 ve Namespace
    val androidExtension = project.extensions.findByName("android")
    if (androidExtension != null) {
        val android = androidExtension as com.android.build.gradle.BaseExtension
        if (android.namespace == null) {
            android.namespace = project.group.toString()
        }
        android.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }

  project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)

        freeCompilerArgs.addAll(
            "-Xskip-prerelease-check",
            "-Xallow-jvm-ir-dependencies"
        )
    }
}
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}