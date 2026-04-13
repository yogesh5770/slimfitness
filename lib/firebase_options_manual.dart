import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions getOptions(String flavor) {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions has not been configured for web');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return flavor == 'admin' ? androidAdmin : androidMember;
      case TargetPlatform.iOS:
        return flavor == 'admin' ? iosAdmin : iosMember;
      default:
        throw UnsupportedError('DefaultFirebaseOptions is not supported for this platform.');
    }
  }

  static const FirebaseOptions androidAdmin = FirebaseOptions(
    apiKey: 'AIzaSyBbIgFlHeJGgfBscd44CacBCfXYSKQ6jG4',
    appId: '1:301096952142:android:512567cb1558d5b71efe1f',
    messagingSenderId: '301096952142',
    projectId: 'slimfit-5d2f6',
    databaseURL: 'https://slimfit-5d2f6-default-rtdb.firebaseio.com',
    storageBucket: 'slimfit-5d2f6.firebasestorage.app',
  );

  static const FirebaseOptions androidMember = FirebaseOptions(
    apiKey: 'AIzaSyBbIgFlHeJGgfBscd44CacBCfXYSKQ6jG4',
    appId: '1:301096952142:android:f7768057e340387e1efe1f',
    messagingSenderId: '301096952142',
    projectId: 'slimfit-5d2f6',
    databaseURL: 'https://slimfit-5d2f6-default-rtdb.firebaseio.com',
    storageBucket: 'slimfit-5d2f6.firebasestorage.app',
  );

  static const FirebaseOptions iosAdmin = FirebaseOptions(
    apiKey: 'AIzaSyAgaTIivpwjQlMJ8H0hv9dGkd4VvO7dVo4',
    appId: '1:301096952142:ios:1c892cc13344752e1efe1f',
    messagingSenderId: '301096952142',
    projectId: 'slimfit-5d2f6',
    databaseURL: 'https://slimfit-5d2f6-default-rtdb.firebaseio.com',
    storageBucket: 'slimfit-5d2f6.firebasestorage.app',
    iosBundleId: 'com.slimfitness.admin',
  );

  static const FirebaseOptions iosMember = FirebaseOptions(
    apiKey: 'AIzaSyAgaTIivpwjQlMJ8H0hv9dGkd4VvO7dVo4',
    appId: '1:301096952142:ios:1c892cc13344752e1efe1f',
    messagingSenderId: '301096952142',
    projectId: 'slimfit-5d2f6',
    databaseURL: 'https://slimfit-5d2f6-default-rtdb.firebaseio.com',
    storageBucket: 'slimfit-5d2f6.firebasestorage.app',
    iosBundleId: 'com.slimfitness.member',
  );
}
