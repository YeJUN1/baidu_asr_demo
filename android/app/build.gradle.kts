plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter 插件应在 Android 和 Kotlin 插件之后
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.android_voice"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.android_voice"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 启用 .aar 所需的 multiDex（可选，看你项目大小）
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // TODO: 换成正式签名
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.arthenica:ffmpeg-kit-full-gpl:5.1.LTS")
    // ✅ 官方要求的 Java 异常库
    implementation("com.arthenica:smart-exception-java:0.2.1")

    // 其他常用依赖
    implementation("androidx.core:core-ktx:1.10.1")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.8.0")
}
