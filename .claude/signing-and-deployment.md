# Gem Game Signing & Deployment

## Keystore Configuration

The app uses a release keystore for signing. Configuration is in `android/key.properties`:

```
storeFile=/home/ben/vault/vault_app/android/app/upload-keystore.jks
keyAlias=gems
storePassword=<stored in key.properties>
keyPassword=<stored in key.properties>
```

The keystore contains two aliases:
- `gems` - for Gem Game (created Nov 28, 2025)
- `vault` - for Vault app (created Nov 23, 2025)

## Building & Deploying

### Debug vs Release Signing

- **Debug builds** (`flutter run`) use the default debug keystore at `~/.android/debug.keystore`
- **Release builds** use the upload-keystore.jks with the `gems` alias

If the device has a release-signed version installed, debug builds will fail with:
```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package signatures do not match
```

### Solutions

**Option 1: Run in release mode**
```bash
cd /home/ben/vault/gem_game
~/flutter/bin/flutter run --release -d RFCW50PR00D
```

**Option 2: Build and install manually (recommended)**
```bash
cd /home/ben/vault/gem_game
~/flutter/bin/flutter build apk --release
~/Android/Sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The manual `adb install -r` approach is more reliable than Flutter's built-in install.

## Verifying Signatures

To check what key signed an APK:

```bash
# Check installed app
~/Android/Sdk/platform-tools/adb shell pm path ai.positronic.gem_game
~/Android/Sdk/platform-tools/adb pull <path> /tmp/installed.apk
~/Android/Sdk/build-tools/33.0.1/apksigner verify --print-certs /tmp/installed.apk

# Check built APK
~/Android/Sdk/build-tools/33.0.1/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The `gems` key fingerprint:
- SHA-256: `60115eb71cd53a6975bbf6cc7dee5e6aad38015bc0ee841cf08ae99007dd39f1`
- SHA-1: `b50b70432e33ffcf3c7dd65c491242610fbddd7b`

## Listing Keystore Contents

```bash
keytool -list -v -keystore /home/ben/vault/vault_app/android/app/upload-keystore.jks
```

## Google Play Store

When uploading to Play Store, use the same `gems` alias from the upload-keystore.jks. The Play Store will verify the signature matches for updates.
