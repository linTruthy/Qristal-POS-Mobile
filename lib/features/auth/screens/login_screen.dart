import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qristal_mobile/core/theme/app_theme.dart';
import '../../kitchen/screens/kitchen_screen.dart';
import '../../sync/providers/sync_provider.dart';
import '../../tables/screens/floor_plan_screen.dart';
import '../providers/auth_provider.dart';
import 'package:sentry/sentry.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // Listen to state changes
  void _listenToAuthChanges() {
    ref.listen(authControllerProvider, (previous, next) async {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppTheme.error),
        );
      }

      if (next.isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Authentication successful. Syncing data..."),
          ),
        );

        await ref.read(syncControllerProvider.notifier).performSync();

        if (context.mounted) {
          // --- ROLE-BASED ROUTING ---
          if (next.role == 'KITCHEN') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const KitchenScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FloorPlanScreen()),
            );
          }
        }
      }
    });
  }
  
  void _handleLogin() {
    final userId =
        '20e712c3-e030-4bc5-ac2b-cafd92dc055f'; // _userController.text.trim();
    final pin = _pinController.text
        .trim(); // '1234'; // _pinController.text.trim();

    if (userId.isEmpty || pin.isEmpty) return;

    ref.read(authControllerProvider.notifier).login(userId, pin);
  }

  @override
  Widget build(BuildContext context) {
    _listenToAuthChanges();
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Row(
        children: [
          // LEFT SIDE: Branding / Art
          Expanded(
            flex: 2,
            child: Container(
              color: AppTheme.surface,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.point_of_sale,
                      size: 100,
                      color: AppTheme.qristalBlue,
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Qristal POS",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Enterprise Grade. Startup Ready.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // RIGHT SIDE: Login Form
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Staff Access",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 30),

                  // User ID Input (Paste your seeded UUID here)
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: "Operator ID",
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PIN Input
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Access PIN",
                      prefixIcon: Icon(Icons.lock),
                    ),
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      throw StateError('This is test exception');
                    },
                    child: const Text('Verify Sentry Setup'),
                  ),
                  // Login Button
                  SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
                      child: authState.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("UNLOCK TERMINAL"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
