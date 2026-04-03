import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options loaded from `--dart-define` values so live config does not
/// need to be committed to source control.
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
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: _optional('FIREBASE_WEB_AUTH_DOMAIN'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    measurementId: _optional('FIREBASE_WEB_MEASUREMENT_ID'),
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_MACOS_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_MACOS_APP_ID'),
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: const String.fromEnvironment('FIREBASE_MACOS_BUNDLE_ID'),
  );

  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: const String.fromEnvironment('FIREBASE_WINDOWS_API_KEY'),
    appId: const String.fromEnvironment('FIREBASE_WINDOWS_APP_ID'),
    messagingSenderId: const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: _optional('FIREBASE_WINDOWS_AUTH_DOMAIN'),
    storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    measurementId: _optional('FIREBASE_WINDOWS_MEASUREMENT_ID'),
  );

  static String? _optional(String key) {
    switch (key) {
      case 'FIREBASE_WEB_AUTH_DOMAIN':
        const value = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
        return value.isEmpty ? null : value;
      case 'FIREBASE_WEB_MEASUREMENT_ID':
        const value = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');
        return value.isEmpty ? null : value;
      case 'FIREBASE_WINDOWS_AUTH_DOMAIN':
        const value = String.fromEnvironment('FIREBASE_WINDOWS_AUTH_DOMAIN');
        return value.isEmpty ? null : value;
      case 'FIREBASE_WINDOWS_MEASUREMENT_ID':
        const value = String.fromEnvironment(
          'FIREBASE_WINDOWS_MEASUREMENT_ID',
        );
        return value.isEmpty ? null : value;
      default:
        return null;
    }
  }
}
