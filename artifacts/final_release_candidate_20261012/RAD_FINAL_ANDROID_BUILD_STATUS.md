# Android build

BLOCKED. `flutter build apk --debug` invoked Gradle `assembleDebug`, but `:app:mergeDebugAssets` could not resolve Flutter engine artifacts. `storage.googleapis.com/download.flutter.io` returned HTTP 403 for `armeabi_v7a_debug` and `x86_64_debug`; Flutter's automatic retry also failed. Exit code 1, no verified APK or checksum. Build infrastructure/network owner should restore artifact access and rerun; no source change is justified by this failure alone.
