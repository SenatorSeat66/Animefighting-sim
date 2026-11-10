import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.serialization") version "2.4.0"
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.starreader.starreader"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    buildFeatures { buildConfig = true }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.maxHeapSize = "768m"
            // Robolectric API36 models ApplicationSharedMemory through JDK file descriptors.
            it.jvmArgs("--add-opens=java.base/jdk.internal.access=ALL-UNNAMED")
            it.systemProperty(
                "robolectric.dependency.repo.url",
                "https://repo.maven.apache.org/maven2",
            )
            System.getenv("STARREADER_QUICKJS_HOST_LIB")?.let { directory ->
                it.systemProperty("java.library.path", directory)
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.starreader.starreader"
        externalNativeBuild { cmake { arguments += "-DANDROID_STL=c++_static" } }
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter.
        // (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P
        // force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val props = Properties()
            val signingPath =
                System.getenv("STARREADER_SIGNING_PROPERTIES")
                    ?: error(
                        "Set STARREADER_SIGNING_PROPERTIES to your private signing properties file"
                    )
            file(signingPath).inputStream().use { props.load(it) }
            storeFile = file(props.getProperty("storeFile"))
            storePassword = props.getProperty("storePassword")
            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        jvmDefault = org.jetbrains.kotlin.gradle.dsl.JvmDefaultMode.ENABLE
        freeCompilerArgs.add("-Xcontext-parameters")
    }
}

flutter {
    source = "../.."
}

// Runtime classes referenced by separately compiled Mihon extensions.
dependencies {
    implementation("com.squareup.okhttp3:okhttp:5.5.1")
    implementation("com.squareup.okhttp3:logging-interceptor:5.5.1")
    implementation("com.squareup.okhttp3:okhttp-brotli:5.5.1")
    implementation("com.squareup.okhttp3:okhttp-zstd:5.5.1")
    implementation("com.squareup.okhttp3:okhttp-dnsoverhttps:5.5.1")
    implementation("org.jsoup:jsoup:1.24.1")
    implementation("io.reactivex:rxjava:1.3.8")
    implementation("uy.kohesive.injekt:injekt-core:1.16.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json-okio:1.12.0")
    implementation("androidx.work:work-runtime-ktx:2.12.0")
    implementation("androidx.preference:preference-ktx:1.2.1")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
}

// Flutter writes assets into the directory consumed by AGP's JVM test packaging.
tasks
    .matching { it.name == "packageDebugUnitTestForUnitTest" }
    .configureEach {
        dependsOn("copyFlutterAssetsDebug")
    }
