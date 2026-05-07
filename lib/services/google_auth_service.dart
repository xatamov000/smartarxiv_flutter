import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {

  static Future<User?> signIn() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn().signIn();

      if (googleUser == null) return null;

      final googleAuth =
          await googleUser.authentication;

      final credential =
          GoogleAuthProvider.credential(
        accessToken:
            googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance
              .signInWithCredential(
                  credential);

      return userCredential.user;
    } catch (e, st) {
      debugPrint("Google login error: $e");
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }
}
