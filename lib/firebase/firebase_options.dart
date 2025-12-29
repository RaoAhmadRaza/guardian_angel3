/// Firebase Configuration Options (Placeholder)
/// 
/// ⚠️ IMPORTANT: This file is a PLACEHOLDER.
/// 
/// To complete Firebase setup, run the FlutterFire CLI:
/// 
/// ```bash
/// # Install FlutterFire CLI
/// dart pub global activate flutterfire_cli
/// 
/// # Configure Firebase (will generate this file with real values)
/// flutterfire configure
/// ```
/// 
/// The FlutterFire CLI will:
/// 1. Create a Firebase project (or use existing)
/// 2. Register your app for Android, iOS, and Web
/// 3. Download configuration files (google-services.json, GoogleService-Info.plist)
/// 4. Generate the real firebase_options.dart with your project's credentials
/// 
/// Until you run `flutterfire configure`, Firebase will not work.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
/// 
/// ⚠️ PLACEHOLDER VALUES - Run `flutterfire configure` to generate real values.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'run `flutterfire configure` to generate Firebase options for this platform.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'run `flutterfire configure` to generate Firebase options for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLACEHOLDER VALUES - Replace with real values from `flutterfire configure`
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER-API-KEY',
    appId: 'PLACEHOLDER-APP-ID',
    messagingSenderId: 'PLACEHOLDER-SENDER-ID',
    projectId: 'PLACEHOLDER-PROJECT-ID',
    authDomain: 'PLACEHOLDER-AUTH-DOMAIN',
    storageBucket: 'PLACEHOLDER-STORAGE-BUCKET',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER-API-KEY',
    appId: 'PLACEHOLDER-APP-ID',
    messagingSenderId: 'PLACEHOLDER-SENDER-ID',
    projectId: 'PLACEHOLDER-PROJECT-ID',
    storageBucket: 'PLACEHOLDER-STORAGE-BUCKET',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER-API-KEY',
    appId: 'PLACEHOLDER-APP-ID',
    messagingSenderId: 'PLACEHOLDER-SENDER-ID',
    projectId: 'PLACEHOLDER-PROJECT-ID',
    storageBucket: 'PLACEHOLDER-STORAGE-BUCKET',
    iosClientId: 'PLACEHOLDER-IOS-CLIENT-ID',
    iosBundleId: 'com.example.guardianAngel',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'PLACEHOLDER-API-KEY',
    appId: 'PLACEHOLDER-APP-ID',
    messagingSenderId: 'PLACEHOLDER-SENDER-ID',
    projectId: 'PLACEHOLDER-PROJECT-ID',
    storageBucket: 'PLACEHOLDER-STORAGE-BUCKET',
    iosClientId: 'PLACEHOLDER-IOS-CLIENT-ID',
    iosBundleId: 'com.example.guardianAngel',
  );
}
