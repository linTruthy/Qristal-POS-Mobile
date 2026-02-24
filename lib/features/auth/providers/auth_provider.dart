import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/role_constants.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final userRoleProvider = FutureProvider<UserRole>((ref) async {
  return ref.watch(authServiceProvider).getRole();
});

class AuthState {
  final bool isAuthenticated;
  final String? userId;

  AuthState({required this.isAuthenticated, this.userId});
}

class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService)
      : super(AuthState(isAuthenticated: false, userId: null));

  Future<void> login(String userId, String pin) async {
    final data = await _authService.login(userId, pin);
    state = AuthState(isAuthenticated: true, userId: data['user']['id']);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState(isAuthenticated: false, userId: null);
  }

  Future<void> checkAuthStatus() async {
    final token = await _authService.getToken();
    if (token != null) {
      // Here you might want to decode the token to get user info
      // For now, let's assume if a token exists, the user is authenticated.
      // A better approach would be to verify the token with the backend.
      // And get user ID from there.
      state = AuthState(isAuthenticated: true, userId: 'some_user_id'); // Placeholder
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
