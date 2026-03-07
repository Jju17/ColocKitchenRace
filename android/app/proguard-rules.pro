# Keep Firestore model classes
-keep class dev.rahier.colocskitchenrace.data.model.** { *; }

# Stripe
-keep class com.stripe.** { *; }

# Firebase provides its own consumer ProGuard rules
-dontwarn com.google.firebase.**

# Firebase Cloud Functions callable data classes
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName *;
}

# Hilt provides its own consumer ProGuard rules
-keep class * extends dagger.hilt.android.internal.managers.ViewComponentManager { *; }
-dontwarn dagger.hilt.**

# Kotlin metadata (needed for reflection-based serialization)
-keep class kotlin.Metadata { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# Google Identity / Credential Manager
-keep class com.google.android.libraries.identity.** { *; }
-dontwarn com.google.android.libraries.identity.**

# OkHttp (used by Stripe/Firebase)
-dontwarn okhttp3.**
-dontwarn okio.**
