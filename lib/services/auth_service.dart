import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _kName = 'auth_user_name';
  static const _kEmail = 'auth_user_email';
  static const _kPhotoUrl = 'auth_user_photo_url';

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }

    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google Sign-In did not return an ID token. Check OAuth configuration.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }

    await _firebaseAuth.signOut();
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Ignore disconnect failures when account is not connected.
    }
    await _googleSignIn.signOut();
  }

  Future<void> cacheUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, user.displayName ?? '');
    await prefs.setString(_kEmail, user.email ?? '');
    await prefs.setString(_kPhotoUrl, user.photoURL ?? '');
  }

  Future<Map<String, String>> getCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_kName) ?? '',
      'email': prefs.getString(_kEmail) ?? '',
      'photoUrl': prefs.getString(_kPhotoUrl) ?? '',
    };
  }

  Future<void> clearCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kName);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPhotoUrl);
  }
}
