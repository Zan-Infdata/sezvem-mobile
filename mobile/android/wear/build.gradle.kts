plugins {
    id("com.android.application")
    id("kotlin-android")
}

android {
    namespace = "com.ixland.ixland_mobile.wear"
    compileSdk = 36

    defaultConfig {
        // The Data Layer matches the mobile package name and signing certificate.
        applicationId = "com.ixland.ixland_mobile"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    implementation("androidx.health:health-services-client:1.1.0")
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
    implementation("com.google.guava:guava:32.0.1-android")
}
