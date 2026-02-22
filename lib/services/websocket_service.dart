import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../features/sync/providers/sync_provider.dart';

class WebSocketService {
  late IO.Socket socket;
  final Ref ref;

  WebSocketService(this.ref) {
    _init();
  }

  void _init() {
    // Replace this with your actual Render URL
    final String serverUrl = ApiConstants.baseUrl;

    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      if (kDebugMode) {
        print('✅ Connected to WebSocket Server');
      }
    });

    // Listen for new orders (This is where the magic happens for the KDS)
    socket.on('newOrder', (data) {
      if (kDebugMode) {
        print('🔥 New order received via WebSocket! Forcing sync...');
      }
      // When the server says a new order arrived, tell our local DB to pull it!
      ref.read(syncControllerProvider.notifier).performSync();
    });

    socket.onDisconnect((_) => print('❌ Disconnected from WebSocket'));
  }

  void dispose() {
    socket.dispose();
  }
}

// Provider
final webSocketProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(ref);
});
