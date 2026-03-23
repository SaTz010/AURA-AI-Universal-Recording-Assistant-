import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService.instance;

  final AuthService _authService;

  bool _initialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  User? _user;
  Map<String, String> _cachedUser = const {};

  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  Map<String, String> get cachedUser => _cachedUser;

  Future<void> initialize() async {
    _user = _authService.currentUser;
    _cachedUser = await _authService.getCachedUserData();

    if (_user != null) {
      await _authService.cacheUserData(_user!);
      _cachedUser = await _authService.getCachedUserData();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null || credential.user == null) {
        _errorMessage = 'Sign-in cancelled';
        return false;
      }

      _user = credential.user;
      await _authService.cacheUserData(_user!);
      _cachedUser = await _authService.getCachedUserData();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
      return false;
    } on GoogleSignInException catch (e) {
      _errorMessage = _mapGoogleSignInError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Unable to continue with Google right now';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signOut();
      await _authService.clearCachedUserData();
      _user = null;
      _cachedUser = const {};
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
    } catch (_) {
      _errorMessage = 'Unable to log out right now';
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'No internet connection';
      case 'account-exists-with-different-credential':
        return 'Account exists with a different sign-in method';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'invalid-credential':
      case 'invalid-idp-response':
      case 'missing-google-id-token':
        return 'Google Sign-In configuration is incomplete. Please check Firebase OAuth setup.';
      case 'popup-closed-by-user':
        return 'Sign-in cancelled';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  String _mapGoogleSignInError(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign-in cancelled';
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was interrupted. Please try again';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Sign-In is not configured correctly in Firebase project settings.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google Sign-In UI is unavailable on this device right now';
      default:
        return e.description ?? 'Unable to continue with Google right now';
    }
  }
}

class AuraAuthProvider extends InheritedNotifier<AuthProvider> {
  const AuraAuthProvider({
    super.key,
    required AuthProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AuthProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AuraAuthProvider>();
    assert(provider != null, 'AuraAuthProvider not found in widget tree');
    return provider!.notifier!;
  }
}
