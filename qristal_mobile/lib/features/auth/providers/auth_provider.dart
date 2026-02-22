import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

// 1. Provider for the Service
final authServiceProvider = Provider((ref) => AuthService());

// 2. State Controller for the Login Screen
class LoginState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final String? userId;

  LoginState({
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.userId,
  });
}

class AuthController extends StateNotifier<LoginState> {
  final AuthService _authService;

  AuthController(this._authService) : super(LoginState());

  Future<void> login(String userId, String pin) async {
    state = LoginState(isLoading: true);
    try {
      await _authService.login(userId, pin);
      state = LoginState(isAuthenticated: true, userId: userId);
    } catch (e) {
      state = LoginState(error: e.toString().replaceAll('Exception: ', ''));
    }
  }
  
  Future<void> logout() async {
    await _authService.logout();
    state = LoginState(isAuthenticated: false);
  }
}

// 3. Provider for the Controller
final authControllerProvider = StateNotifierProvider<AuthController, LoginState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
