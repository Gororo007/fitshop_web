import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._authRepository);

  final AuthRepository _authRepository;

  AppUser? _user;
  AuthStatus _status = AuthStatus.unknown;
  String? _error;
  bool _busy = false;

  AppUser? get user => _user;
  AuthStatus get status => _status;
  String? get error => _error;
  bool get isBusy => _busy;
  bool get isAuthenticated => _user != null;

  Future<void> restore() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.restoreSession();
      _status = _user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } on ApiException catch (e) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = e.message;
      await _authRepository.logout();
    } catch (e) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String identity,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.login(
        identity: identity,
        password: password,
      );
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _user = null;
      _status = AuthStatus.unauthenticated;
      return false;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    UserRole role = UserRole.customer,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _authRepository.register(
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
        name: name,
        role: role,
      );
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = '$e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      _user = await _authRepository.refreshUser();
      notifyListeners();
    } on UnauthorizedException {
      await logout();
    }
  }
}
