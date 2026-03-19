import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/database_provider.dart';
=======
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_theme.dart';
>>>>>>> origin/main
import '../../../database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../sync/providers/sync_provider.dart';

<<<<<<< HEAD
class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
=======
const _kdsAreas = <String>['ALL', 'KITCHEN', 'BARISTA', 'BAR', 'RETAIL', 'OTHER'];

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  late String _selectedArea;
  Set<String> _knownOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    final assigned = ref.read(authControllerProvider).kdsProductionAreas;
    _selectedArea = assigned.isNotEmpty ? assigned.first : 'ALL';
  }

  Future<List<_OrderTicketData>> _buildTicketData(
    AppDatabase db,
    List<Order> orders,
  ) async {
    final results = <_OrderTicketData>[];

    for (final order in orders) {
      final items = await db.getOrderItems(order.id);
      final area = _selectedArea;
      final visible = area == 'ALL'
          ? items
          : items
              .where((item) => _itemBelongsToArea(item, area))
              .toList(growable: false);

      if (visible.isNotEmpty) {
        results.add(_OrderTicketData(order: order, items: visible));
      }
    }

    final currentIds = results.map((entry) => entry.order.id).toSet();
    final hasIncoming = currentIds.difference(_knownOrderIds).isNotEmpty;
    _knownOrderIds = currentIds;

    if (hasIncoming) {
      await SystemSound.play(SystemSoundType.alert);
    }

    return results;
  }

  bool _itemBelongsToArea(TypedOrderItem item, String area) {
    bool matches(String? route) => (route == null || route.isEmpty ? 'KITCHEN' : route) == area;

    if (matches(item.item.routeTo)) return true;
    if (item.modifiers.any((modifier) => matches(modifier.routeTo))) return true;
    if (item.sides.any((side) => matches(side.routeTo))) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final assignedAreas = ref.watch(authControllerProvider).kdsProductionAreas;
    final allowedAreas = assignedAreas.isEmpty
        ? _kdsAreas
        : ['ALL', ...assignedAreas.where((area) => _kdsAreas.contains(area))];

    if (!allowedAreas.contains(_selectedArea)) {
      _selectedArea = allowedAreas.first;
    }
>>>>>>> origin/main

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Display System"),
        backgroundColor: AppTheme.surface,
        actions: [
<<<<<<< HEAD
=======
          if (allowedAreas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedArea,
                  dropdownColor: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  items: allowedAreas
                      .toSet()
                      .map(
                        (area) => DropdownMenuItem(
                          value: area,
                          child: Text(area, style: const TextStyle(color: Colors.white)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedArea = value;
                      _knownOrderIds = <String>{};
                    });
                  },
                ),
              ),
            ),
>>>>>>> origin/main
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Force Sync",
            onPressed: () {
              ref.read(syncControllerProvider.notifier).performSync();
<<<<<<< HEAD
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Syncing...")));
            },
          ),
          const SizedBox(width: 16),
          // ADD LOGOUT BUTTON HERE
          TextButton.icon(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label:
                const Text("LOGOUT", style: TextStyle(color: AppTheme.error)),
=======
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Syncing...")),
              );
            },
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            label: const Text("LOGOUT", style: TextStyle(color: AppTheme.error)),
>>>>>>> origin/main
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: db.watchKitchenOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final orders = snapshot.data ?? [];

<<<<<<< HEAD
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No pending orders. Good job!",
                    style: TextStyle(color: Colors.grey, fontSize: 24),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal, // KDS usually scrolls sideways
            itemCount: orders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              return KitchenTicket(order: orders[index]);
=======
          return FutureBuilder<List<_OrderTicketData>>(
            future: _buildTicketData(db, orders),
            builder: (context, filteredSnapshot) {
              if (!filteredSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tickets = filteredSnapshot.data ?? const [];

              if (tickets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        "No pending $_selectedArea orders.",
                        style: const TextStyle(color: Colors.grey, fontSize: 24),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tickets.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  return KitchenTicket(
                    order: tickets[index].order,
                    items: tickets[index].items,
                  );
                },
              );
>>>>>>> origin/main
            },
          );
        },
      ),
    );
  }
}

<<<<<<< HEAD
class KitchenTicket extends ConsumerStatefulWidget {
  final Order order;
  const KitchenTicket({super.key, required this.order});

  @override
  ConsumerState<KitchenTicket> createState() => _KitchenTicketState();
}

class _KitchenTicketState extends ConsumerState<KitchenTicket> {
  late Future<List<TypedOrderItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    final db = ref.read(databaseProvider);
    _itemsFuture = db.getOrderItems(widget.order.id);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final isPreparing = widget.order.status == 'PREPARING';
=======
class _OrderTicketData {
  final Order order;
  final List<TypedOrderItem> items;

  const _OrderTicketData({required this.order, required this.items});
}

class KitchenTicket extends ConsumerWidget {
  final Order order;
  final List<TypedOrderItem> items;

  const KitchenTicket({super.key, required this.order, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final isPreparing = order.status == 'PREPARING';
>>>>>>> origin/main

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPreparing ? Colors.orange : AppTheme.qristalBlue,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
<<<<<<< HEAD
          // Header
=======
>>>>>>> origin/main
          Container(
            padding: const EdgeInsets.all(12),
            color: isPreparing
                ? Colors.orange.withOpacity(0.2)
                : AppTheme.qristalBlue.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
<<<<<<< HEAD
                  "#${widget.order.receiptNumber}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  widget.order.createdAt
                      .toLocal()
                      .toString()
                      .split(' ')[1]
                      .substring(0, 5), // Time HH:MM
=======
                  "#${order.receiptNumber}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  order.createdAt.toLocal().toString().split(' ')[1].substring(0, 5),
>>>>>>> origin/main
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
<<<<<<< HEAD

          // Items List
          Expanded(
            child: FutureBuilder<List<TypedOrderItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final itemData = snapshot.data![index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${itemData.item.quantity}x",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemData.product.name,
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (itemData.item.notes != null &&
                                  itemData.item.notes!.isNotEmpty)
                                Text(
                                  "Note: ${itemData.item.notes}",
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
=======
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final itemData = items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${itemData.item.quantity}x",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  itemData.product.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              if (itemData.item.routeTo != null && itemData.item.routeTo!.isNotEmpty)
                                _RouteBadge(label: itemData.item.routeTo!),
                            ],
                          ),
                          if (itemData.modifiers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: itemData.modifiers
                                    .map(
                                      (modifier) => _TicketTag(
                                        label: modifier.name,
                                        routeTo: modifier.routeTo,
                                        prefix: '+',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (itemData.sides.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: itemData.sides
                                    .map(
                                      (side) => _TicketTag(
                                        label:
                                            side.quantity > 1 ? '${side.name} x${side.quantity}' : side.name,
                                        routeTo: side.routeTo,
                                        prefix: 'Side',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          if (itemData.item.notes != null && itemData.item.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                "Note: ${itemData.item.notes}",
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
>>>>>>> origin/main
                );
              },
            ),
          ),
<<<<<<< HEAD

          // Footer Actions
=======
>>>>>>> origin/main
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
<<<<<<< HEAD
                  backgroundColor:
                      isPreparing ? AppTheme.emerald : Colors.orange,
                ),
                onPressed: () async {
                  String newStatus = isPreparing ? 'READY' : 'PREPARING';
                  await db.updateOrderStatus(widget.order.id, newStatus);

                  // Trigger sync to let server/cashiers know
=======
                  backgroundColor: isPreparing ? AppTheme.emerald : Colors.orange,
                ),
                onPressed: () async {
                  final newStatus = isPreparing ? 'READY' : 'PREPARING';
                  await db.updateOrderStatus(order.id, newStatus);
>>>>>>> origin/main
                  ref.read(syncControllerProvider.notifier).performSync();
                },
                child: Text(isPreparing ? "MARK DONE" : "START COOKING"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
<<<<<<< HEAD
=======

class _RouteBadge extends StatelessWidget {
  final String label;

  const _RouteBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.qristalBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.qristalBlue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TicketTag extends StatelessWidget {
  final String label;
  final String? routeTo;
  final String prefix;

  const _TicketTag({required this.label, this.routeTo, required this.prefix});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        routeTo != null && routeTo!.isNotEmpty ? '$prefix $label · ${routeTo!}' : '$prefix $label',
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}
>>>>>>> origin/main
