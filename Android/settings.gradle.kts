import java.util.Properties

val githubProperties = Properties()
githubProperties.load(file("github.properties").inputStream())

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()
        mavenCentral()
        maven {
            name = "GitHubPackages"

            url = uri("https://maven.pkg.github.com/populimited/popguide_sdk_android")
            credentials {
                username = (githubProperties["gpr.usr"] ?: System.getenv("GPR_USER")).toString()
                password = (githubProperties["gpr.key"] ?: System.getenv("GPR_API_KEY")).toString()
            }
        }
    }
}

rootProject.name = "PopguideSdk"
include(":app")
