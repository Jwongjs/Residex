# Release Signing Guide for SplitLah

## Important: Before Publishing to Production

The app is currently configured to use debug signing keys. For production release, you **must** create a proper keystore and configure release signing.

### Step 1: Create a Keystore

Run the following command to create a keystore:

```bash
keytool -genkey -v -keystore ~/splitlah-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias splitlah
```

When prompted:
- Enter a strong password (save it securely!)
- Fill in your organization details
- Remember the key alias (splitlah)

### Step 2: Create key.properties File

Create a file at `android/key.properties`:

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=splitlah
storeFile=<path-to-your-keystore-file>
```

Example:
```properties
storePassword=mySecurePassword123
keyPassword=mySecurePassword123
keyAlias=splitlah
storeFile=/Users/yourname/splitlah-release-key.jks
```

**⚠️ IMPORTANT: Add `key.properties` to `.gitignore`!**

### Step 3: Update build.gradle.kts

Update `android/app/build.gradle.kts` to use the keystore:

1. Add at the top (before `android {`):
```kotlin
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

2. Add signing config inside `android {`:
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String
    }
}
```

3. Update `buildTypes` release section:
```kotlin
release {
    signingConfig = signingConfigs.getByName("release")
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro"
    )
}
```

### Step 4: Build Release APK

```bash
flutter build apk --release
```

### Step 5: Build App Bundle (For Google Play)

```bash
flutter build appbundle --release
```

### Security Checklist

- [ ] Keystore file is stored securely (NOT in version control)
- [ ] `key.properties` is added to `.gitignore`
- [ ] Passwords are strong and stored securely
- [ ] Keystore backup is created and stored safely
- [ ] ProGuard rules are tested
- [ ] App has been tested in release mode

### Additional Resources

- [Flutter Android Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)

### Current Configuration Status

✅ Application ID: `com.splitlah.app`
✅ App Name: `SplitLah`
✅ ProGuard Rules: Configured
✅ Code Shrinking: Enabled
⚠️ Release Signing: Using debug keys (UPDATE BEFORE PRODUCTION!)

---

**Remember:** Never commit your keystore or passwords to version control!
