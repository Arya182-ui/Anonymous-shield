# Privacy VPN Controller - Production ProGuard Rules
# Comprehensive obfuscation and optimization for security and performance

# ====== FLUTTER & DART SPECIFIC RULES ======
# Keep Flutter engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.DefaultLifecycleObserver

# Keep method channel classes and methods
-keep class * extends io.flutter.plugin.common.MethodCallHandler { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# ====== VPN & WIREGUARD SPECIFIC RULES ======
# Keep WireGuard native interface
-keep class com.wireguard.** { *; }
-keep class golang.org.x.** { *; }
-keep interface com.wireguard.** { *; }

# Keep VPN service classes
-keep class * extends android.net.VpnService { *; }
-keep class * extends android.app.Service { *; }

# Keep our VPN implementation
-keep class com.privacyvpn.privacy_vpn_controller.vpn.** { *; }
-keep class com.privacyvpn.privacy_vpn_controller.proxy.** { *; }
-keep class com.privacyvpn.privacy_vpn_controller.security.** { *; }
-keep class com.privacyvpn.privacy_vpn_controller.anonymity.** { *; }

# Keep method channel handlers
-keep class com.privacyvpn.privacy_vpn_controller.channels.** { *; }

# Keep main application entry points
-keep class com.privacyvpn.privacy_vpn_controller.MainActivity { *; }

# ====== SECURITY & ENCRYPTION RULES ======
# Keep BouncyCastle crypto providers
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Keep security crypto classes
-keep class androidx.security.crypto.** { *; }

# Keep native cryptographic methods
-keepclassmembers class * {
    native <methods>;
}

# ====== NETWORKING RULES ======
# Keep OkHttp classes
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep networking security
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

# ====== JSON & SERIALIZATION RULES ======
# Keep Moshi classes
-keep class com.squareup.moshi.** { *; }
-keep interface com.squareup.moshi.** { *; }
-keepnames @com.squareup.moshi.JsonClass class *

# Keep data classes and models
-keep @com.squareup.moshi.JsonClass class * { *; }
-keep class * extends java.lang.Enum { *; }

# Keep serialization classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ====== COROUTINES & KOTLIN RULES ======
# Keep Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Keep Kotlin metadata
-keepattributes *Annotation*
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# ====== ANDROID SYSTEM RULES ======
# Keep Android Parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Android Service and BroadcastReceiver
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ====== PERFORMANCE OPTIMIZATION ======
# Enable aggressive optimization
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Remove debug information in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Remove Timber logging in release
-assumenosideeffects class timber.log.Timber {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# ====== SECURITY HARDENING ======
# Obfuscate class names aggressively
-repackageclasses 'a'

# Remove unused code
-dontwarn **

# Security: Remove source file names and line numbers
-renamesourcefileattribute SourceFile

# ====== THIRD-PARTY LIBRARY RULES ======
# AndroidX rules
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# ====== REMOVE DEBUG CODE ======
# Remove debug and testing code
-assumenosideeffects class * {
    public void debug(...);
    public void trace(...);
}

# Remove BuildConfig debug fields
-assumenosideeffects class *.BuildConfig {
    public static final boolean DEBUG return false;
}

# Remove test frameworks
-assumenosideeffects class junit.** { *; }
-assumenosideeffects class org.junit.** { *; }
-assumenosideeffects class androidx.test.** { *; }
-assumenosideeffects class org.mockito.** { *; }

# Remove sensitive debug information
-assumenosideeffects class java.lang.System {
    public static void out.print*(...);
    public static void err.print*(...);
}