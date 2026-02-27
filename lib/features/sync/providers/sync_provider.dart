import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../services/sync_service.dart';


// Service Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

// State Controller
class SyncController extends StateNotifier<AsyncValue<void>> {
  final SyncService _service;

  SyncController(this._service) : super(const AsyncData(null));

  Future<void> performSync() async {
    state = const AsyncLoading();
    try {
      await _service.syncData();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// Global Provider
final syncControllerProvider = StateNotifierProvider<SyncController, AsyncValue<void>>((ref) {
  return SyncController(ref.watch(syncServiceProvider));
});