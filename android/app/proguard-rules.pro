# Keep main entry points
-keep class com.privacyvpn.privacy_vpn_controller.MainActivity
-keep class com.privacyvpn.privacy_vpn_controller.MainApplication

# Keep VPN service classes
-keep class com.privacyvpn.privacy_vpn_controller.vpn.** { *; }
-keep class com.privacyvpn.privacy_vpn_controller.proxy.** { *; }

# Keep method channel handlers (Flutter needs these)
-keep class com.privacyvpn.privacy_vpn_controller.channels.** { *; }

# Keep Flutter plugin classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep WireGuard native library interfaces
-keep class com.wireguard.** { *; }
-keepclassmembers class com.wireguard.** { *; }

# Keep native method signatures
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep serialization classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Remove debug and logging code in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

-assumenosideeffects class timber.log.Timber {
    public static void v(...);
    public static void d(...);
    public static void i(...);
    public static void w(...);
    public static void e(...);
}

# Optimize and obfuscate
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
-repackageclasses ''
-flattenpackagehierarchy ''

# Remove unused code
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn kotlin.jvm.internal.**

# Keep crash reporting integration points (if added later)
# -keep class com.crashlytics.** { *; }
# -keep class com.google.firebase.crashlytics.** { *; }

# Security: Remove source file names and line numbers from stack traces
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Keep security-critical classes from being renamed (for easier debugging)
-keepnames class com.privacyvpn.privacy_vpn_controller.business_logic.services.SecurityService
-keepnames class com.privacyvpn.privacy_vpn_controller.data.repositories.ConfigurationRepository

# Network security - keep certificate pinning classes
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep custom exceptions for better error reporting
-keep class com.privacyvpn.privacy_vpn_controller.core.exceptions.** { *; }

# Privacy protection - remove sensitive debug information
-assumenosideeffects class java.lang.System {
    public static void out.print*(...);
    public static void err.print*(...);
}

# Remove test code from release builds
-assumenosideeffects class junit.** { *; }
-assumenosideeffects class org.junit.** { *; }
-assumenosideeffects class androidx.test.** { *; }
-assumenosideeffects class org.mockito.** { *; }