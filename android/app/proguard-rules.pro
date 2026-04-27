# ÇiftlikPRO ProGuard rules.
# Flutter ve Firebase için zorunlu keep kuralları + güvenli optimizasyon.

# ─── Flutter çekirdek ──────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase ──────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore POJOs (model serialization)
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <methods>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.IgnoreExtraProperties <methods>;
}

# ─── In-App Purchase (BillingClient) ───────────────────────────────────────
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.api.**

# ─── Crashlytics ───────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ─── SQLite (sqflite) ──────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ─── Image picker / Camera plugin ──────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.camera.** { *; }

# ─── Geolocator ────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─── Mobile scanner (mlkit barcode) ────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ─── PDF (printing) ────────────────────────────────────────────────────────
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn net.nfet.flutter.printing.**

# ─── Local notifications ───────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ─── Connectivity Plus ─────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ─── Local Auth (biometric) ────────────────────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ─── Webview ───────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.webviewflutter.** { *; }

# ─── Genel — Kotlin metadata ───────────────────────────────────────────────
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.jvm.internal.**

# Annotation processing
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Enum
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}
