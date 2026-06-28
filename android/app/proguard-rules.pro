# Flutter Wrapper rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.im.** { *; }

# Keep system attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep standard Android library classes
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.** { *; }

# Prevent shrinking on standard serialization models
-keep class com.edusphere.app.** { *; }

# Ignore missing Google Play Core Split / Deferred Components references
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
