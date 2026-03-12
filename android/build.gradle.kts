allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(rootDir.resolve("../build"))

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(name))
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}