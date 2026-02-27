import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/tables/screens/floor_plan_screen.dart';
import 'services/websocket_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://04c7b6ac5293308f78c72bb89a9996e7@o4510936622891008.ingest.us.sentry.io/4510936624660480';
      // Adds request headers and IP for users, for more info visit:
      // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
      options.sendDefaultPii = true;
      options.enableLogs = true;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // Configure Session Replay
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(SentryWidget(child: const ProviderScope(child: QristalApp()))),
  );
  
}

class QristalApp extends ConsumerWidget { // Change to ConsumerWidget
  const QristalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(webSocketProvider); 
    return MaterialApp(
      title: 'Qristal POS',
      navigatorObservers: [
        SentryNavigatorObserver(),
      ],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
      routes: {'/home': (context) => const FloorPlanScreen()},
    );
  }
}
