plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlin-kapt")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Performance and security plugins
    id("kotlin-parcelize") 
}

android {
    namespace = "com.privacyvpn.privacy_vpn_controller"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable Java 8+ API desugaring for older Android versions
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        freeCompilerArgs += listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-Xjvm-default=all"
        )
    }

    buildFeatures {
        buildConfig = true
        aidl = true  // For VPN service communication
    }

    defaultConfig {
        applicationId = "com.privacyvpn.privacy_vpn_controller"
        minSdk = 26  // Android 8.0+ required for modern VPN features
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Security configuration
        manifestPlaceholders["usesCleartextTraffic"] = "false"
        manifestPlaceholders["allowBackup"] = "false"
        manifestPlaceholders["allowDebugging"] = "false"
        
        // NDK configuration — arm64 for production, x86_64 added for emulator testing
        // Binaries must exist in jniLibs/<abi>/ for each included ABI
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
        
        // Build configuration fields
        buildConfigField("String", "BUILD_TIMESTAMP", "\"${System.currentTimeMillis()}\"")
        buildConfigField("boolean", "ENABLE_LOGGING", "true")
        buildConfigField("boolean", "ENABLE_CRASH_REPORTING", "false")
        
        // Test runner configuration
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Signing configurations for release builds
    signingConfigs {
        create("release") {
            // Use environment variables or gradle.properties for sensitive data
            // Example: KEYSTORE_FILE=/path/to/keystore.jks
            // KEYSTORE_PASSWORD=your_keystore_password  
            // KEY_ALIAS=your_key_alias
            // KEY_PASSWORD=your_key_password
            
            if (project.hasProperty("KEYSTORE_FILE")) {
                storeFile = file(project.property("KEYSTORE_FILE") as String)
                storePassword = project.property("KEYSTORE_PASSWORD") as String
                keyAlias = project.property("KEY_ALIAS") as String
                keyPassword = project.property("KEY_PASSWORD") as String
            }
        }
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-DEBUG"
            
            // Debug-specific build config
            buildConfigField("boolean", "ENABLE_LOGGING", "true")
            buildConfigField("boolean", "ENABLE_CRASH_REPORTING", "false")
            buildConfigField("String", "SERVER_ENVIRONMENT", "\"development\"")
            
            manifestPlaceholders["usesCleartextTraffic"] = "true"  // Allow HTTP in debug
        }
        
        release {
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            
            // Security: Enable R8 full mode for maximum obfuscation
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Production build config
            buildConfigField("boolean", "ENABLE_LOGGING", "false")
            buildConfigField("boolean", "ENABLE_CRASH_REPORTING", "true")
            buildConfigField("String", "SERVER_ENVIRONMENT", "\"production\"")
            
            // Security: Additional hardening
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            manifestPlaceholders["allowBackup"] = "false"
            manifestPlaceholders["allowDebugging"] = "false"
            
            // Use release signing config if available, fallback to debug for development
            signingConfig = if (project.hasProperty("KEYSTORE_FILE")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            
            // Additional optimizations
            isJniDebuggable = false
            isRenderscriptDebuggable = false
        }
        
        // Staging build type temporarily disabled due to connectivity_plus plugin compatibility
        // create("staging") {
        //     initWith(getByName("release"))
        //     isDebuggable = true
        //     versionNameSuffix = "-STAGING"
        //     applicationIdSuffix = ".staging"
        //     
        //     buildConfigField("boolean", "ENABLE_LOGGING", "true")
        //     buildConfigField("String", "SERVER_ENVIRONMENT", "\"staging\"")
        //     
        //     // Use debug signing for easier testing
        //     signingConfig = signingConfigs.getByName("debug")
        // }
    }
    
    // Source sets for native code
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
    
    // Packaging options
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for Java 8+ APIs on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Android Core Libraries
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-service:2.8.6")
    implementation("androidx.lifecycle:lifecycle-process:2.8.6")
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    implementation("androidx.concurrent:concurrent-futures-ktx:1.2.0")
    
    // Network and Connectivity
    implementation("androidx.core:core:1.15.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("com.squareup.okio:okio:3.9.1")
    
    // JSON Processing and Serialization
    implementation("com.squareup.moshi:moshi:1.15.1")
    implementation("com.squareup.moshi:moshi-kotlin:1.15.1")
    kapt("com.squareup.moshi:moshi-kotlin-codegen:1.15.1")
    
    // Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    
    // Network Security - stable version
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    // Logging (Timber for development, structured logging for production)
    implementation("com.jakewharton.timber:timber:5.0.1")
    
    // Performance Monitoring
    implementation("androidx.tracing:tracing:1.3.0")
    
    // Permission Handling
    implementation("androidx.activity:activity-ktx:1.9.3")
    
    // Testing Dependencies
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.12.0")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.4.0")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
    
    // Android Testing
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test:rules:1.6.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    
    // UI Testing
    androidTestImplementation("androidx.test.espresso:espresso-intents:3.6.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
