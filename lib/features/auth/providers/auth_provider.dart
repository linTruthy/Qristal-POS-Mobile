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
  final String? role;
  final bool isLoading;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    this.userId,
    this.role,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? role,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error, // We allow error to be nullified
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService)
      : super(AuthState(isAuthenticated: false));

  Future<void> login(String userId, String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _authService.login(userId, pin);
      state = AuthState(
        isAuthenticated: true, 
        userId: data['user']['id'],
        role: data['user']['role'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState(isAuthenticated: false);
  }

  Future<void> checkAuthStatus() async {
    final token = await _authService.getToken();
    if (token != null) {
      // For now, let's assume if a token exists, the user is authenticated.
      state = AuthState(isAuthenticated: true, userId: 'some_user_id', role: 'admin'); // Placeholder
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});