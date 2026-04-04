import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBj5saonwhbsbRYvbNx-ghO-qxLYkh4lt4',
    appId: '1:1927525578:android:7298cf220a31f9d4af3033',
    messagingSenderId: '1927525578',
    projectId: 'govchat-2a5dc',
    storageBucket: 'govchat-2a5dc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3Y6n9OE_77lRt1A951ntC_wabVEGTuqc',
    appId: '1:1927525578:ios:cd9bd22a10dee9f1af3033',
    messagingSenderId: '1927525578',
    projectId: 'govchat-2a5dc',
    storageBucket: 'govchat-2a5dc.firebasestorage.app',
    iosBundleId: 'com.GovChat.projects',
  );
}
