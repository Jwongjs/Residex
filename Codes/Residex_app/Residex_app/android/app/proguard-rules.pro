# Flutter ProGuard Rules
# Keep Flutter Engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Fonts
-keep class com.google.fonts.** { *; }

# Keep camera plugin classes
-keep class io.flutter.plugins.camera.** { *; }

# Keep image picker plugin classes
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep permission handler plugin classes
-keep class com.baseflow.permissionhandler.** { *; }

# Keep contacts plugin classes
-keep class co.sunnyapp.flutter_contact.** { *; }

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Suppress warnings
-dontwarn io.flutter.**
-dontwarn com.google.**
