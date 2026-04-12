import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions has not been configured for web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions is not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAgaTIivpwjQlMJ8H0hv9dGkd4VvO7dVo4',
    appId: '1:301096952142:android:564887373f1d86d71f1e1f',
    messagingSenderId: '301096952142',
    projectId: 'slimfit-5d2f6',
    databaseURL: 'https://slimfit-5d2f6-default-rtdb.firebaseio.com',
    storageBucket: 'slimfit-5d2f6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgaTIivpwjQlMJ8H0hv9dGkd4VvO7dVo4',
    appId: '1:301096952142:ios:1c892cc13344752e1efe1f',
    messagingSenderId: '301096952142',
    projectId: 'slimfit-5d2f6',
    databaseURL: 'https://slimfit-5d2f6-default-rtdb.firebaseio.com',
    storageBucket: 'slimfit-5d2f6.firebasestorage.app',
    iosBundleId: 'com.slimfitness.slimFitnessFlutter',
  );
}
