import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import 'sync_provider.dart';

enum ConnectionStatus { online, offline, syncing, error }

class SyncQueueState {
  final ConnectionStatus status;
  final int pendingOrders;

  SyncQueueState({
    this.status = ConnectionStatus.online,
    this.pendingOrders = 0,
  });

  SyncQueueState copyWith({ConnectionStatus? status, int? pendingOrders}) {
    return SyncQueueState(
      status: status ?? this.status,
      pendingOrders: pendingOrders ?? this.pendingOrders,
    );
  }
}

class SyncQueueManager extends StateNotifier<SyncQueueState> {
  final Ref ref;
  Timer? _timer;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _dbSubscription;

  SyncQueueManager(this.ref) : super(SyncQueueState()) {
    _init();
  }

  void _init() {
    // 1. Listen to Network Connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.contains(ConnectivityResult.none)) {
        state = state.copyWith(status: ConnectionStatus.offline);
      } else {
        state = state.copyWith(status: ConnectionStatus.online);
        _triggerSync(); // Device came online -> attempt sync!
      }
    });

    // 2. Listen to Database for Unsynced Orders
    final db = ref.read(databaseProvider);
    _dbSubscription =
        (db.select(
          db.orders,
        )..where((t) => t.isSynced.equals(false))).watch().listen((orders) {
          state = state.copyWith(pendingOrders: orders.length);
          if (orders.isNotEmpty && state.status == ConnectionStatus.online) {
            _triggerSync(); // New order added -> attempt sync!
          }
        });

    // 3. Fallback Heartbeat Timer (Retry every 30 seconds if something is pending)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.pendingOrders > 0 && state.status != ConnectionStatus.offline) {
        _triggerSync();
      }
    });
  }

  Future<void> _triggerSync() async {
    // Prevent overlapping syncs
    if (state.status == ConnectionStatus.syncing || state.pendingOrders == 0) {
      return;
    }

    state = state.copyWith(status: ConnectionStatus.syncing);
    try {
      await ref.read(syncServiceProvider).syncData();
      state = state.copyWith(status: ConnectionStatus.online);
    } catch (e) {
      state = state.copyWith(status: ConnectionStatus.error);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    _dbSubscription?.cancel();
    super.dispose();
  }
}

// Global Provider
final syncQueueProvider =
    StateNotifierProvider<SyncQueueManager, SyncQueueState>((ref) {
      return SyncQueueManager(ref);
    });
