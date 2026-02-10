# Privacy VPN Controller - Consumer ProGuard Rules
# This file contains ProGuard rules that will be applied to consumers of this library.

# Keep WireGuard classes
-keep class com.wireguard.** { *; }
-keepclassmembers class com.wireguard.** { *; }

# Keep VPN service classes
-keep class * extends android.net.VpnService
-keepclassmembers class * extends android.net.VpnService {
   public <methods>;
}

# Keep native method implementations
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep JSON serialization classes
-keepclassmembers class ** {
    @com.squareup.moshi.Json <fields>;
}

# Keep tunnel configuration classes
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}