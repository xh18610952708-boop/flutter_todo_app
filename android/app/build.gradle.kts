plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ruitu.flutter_todo_app"
    // 固定 compileSdk=36：部分新版插件（如 flutter_plugin_android_lifecycle）要求 >= 36
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    // 与 compileSdk=36 配套，已安装
    buildToolsVersion = "36.1.0"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 等插件需要核心库脱糖（desugaring）
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.ruitu.flutter_todo_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
