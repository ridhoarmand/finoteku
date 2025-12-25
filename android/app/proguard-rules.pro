# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter embedding and engine
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Google Play Core (for deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Supabase Flutter
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep all JSON serialization classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep authentication related classes
-keep class * extends io.supabase.gotrue.** { *; }

# Keep realtime related classes  
-keep class * extends io.supabase.realtime.** { *; }

# Keep postgrest related classes
-keep class * extends io.supabase.postgrest.** { *; }

# Dart/Flutter specific
-keep class * extends androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# Network security
-keep class javax.net.ssl.** { *; }
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**
-dontwarn android.net.http.**

# Don't obfuscate JSON field names
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Preserve the special static methods that are required in all enumeration classes.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep notification classes
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keep class androidx.work.** { *; }

# Flutter Local Notifications (CRITICAL FIX)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepnames class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-keep public class * extends android.content.BroadcastReceiver

# Additional optimizations for smaller APK
-optimizationpasses 5
-dontpreverify
-repackageclasses ''
-allowaccessmodification

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

# Keep native methods for Flutter
-keepclasseswithmembernames class * {
    native <methods>;
}