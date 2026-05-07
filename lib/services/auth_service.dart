import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bitta global GoogleSignIn instance
  final GoogleSignIn _googleSignIn =
      GoogleSignIn(
        scopes: ['email'],
      );

  // Google Login
  Future<User?> signInWithGoogle() async {
    try {
      // Eski sessionni majburiy tozalash
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();

      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential =
          GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(
        credential,
      );

      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}

    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}