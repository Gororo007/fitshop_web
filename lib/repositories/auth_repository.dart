import '../models/app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser> login({required String identity, required String password});

  Future<AppUser> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    UserRole role,
  });

  /// Restores session from stored token / record, or returns null if absent.
  Future<AppUser?> restoreSession();

  Future<AppUser> refreshUser();

  Future<void> logout();
}
