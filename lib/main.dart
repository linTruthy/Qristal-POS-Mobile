import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/tables/screens/floor_plan_screen.dart';
import 'services/websocket_service.dart';

void main() {
  runApp(const ProviderScope(child: QristalApp()));
}

class QristalApp extends ConsumerWidget { // Change to ConsumerWidget
  const QristalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(webSocketProvider); 
    return MaterialApp(
      title: 'Qristal POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
      routes: {'/home': (context) => const FloorPlanScreen()},
    );
  }
}
