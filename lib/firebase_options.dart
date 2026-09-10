// File configured for Bee Talk Firebase instance
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDjubRpVMJjlj7jFqm2oVovgO7h7upnR6s",
    authDomain: "bee-talk-bd4a6.firebaseapp.com",
    databaseURL: "https://bee-talk-bd4a6-default-rtdb.firebaseio.com",
    projectId: "bee-talk-bd4a6",
    storageBucket: "bee-talk-bd4a6.firebasestorage.app",
    messagingSenderId: "994926166121",
    appId: "1:994926166121:web:7e5a347ab1a1924b1962f8",
    measurementId: "G-Z6WKLFNY0G",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDjubRpVMJjlj7jFqm2oVovgO7h7upnR6s",
    authDomain: "bee-talk-bd4a6.firebaseapp.com",
    databaseURL: "https://bee-talk-bd4a6-default-rtdb.firebaseio.com",
    projectId: "bee-talk-bd4a6",
    storageBucket: "bee-talk-bd4a6.firebasestorage.app",
    messagingSenderId: "994926166121",
    appId: "1:994926166121:web:7e5a347ab1a1924b1962f8",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyDjubRpVMJjlj7jFqm2oVovgO7h7upnR6s",
    authDomain: "bee-talk-bd4a6.firebaseapp.com",
    databaseURL: "https://bee-talk-bd4a6-default-rtdb.firebaseio.com",
    projectId: "bee-talk-bd4a6",
    storageBucket: "bee-talk-bd4a6.firebasestorage.app",
    messagingSenderId: "994926166121",
    appId: "1:994926166121:web:7e5a347ab1a1924b1962f8",
    iosBundleId: "com.beetalk.app",
  );
}

