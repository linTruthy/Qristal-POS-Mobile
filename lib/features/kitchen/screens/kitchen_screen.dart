import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../database/database.dart';
import '../../sync/providers/sync_provider.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Display System"),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(syncControllerProvider.notifier).performSync(),
          )
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: db.watchKitchenOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text("No Pending Orders", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal, // KDS usually scrolls sideways
            itemCount: orders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              return KitchenTicket(order: orders[index]);
            },
          );
        },
      ),
    );
  }
}

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

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPreparing ? Colors.orange : AppTheme.qristalBlue, 
          width: 2
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            color: isPreparing ? Colors.orange.withOpacity(0.2) : AppTheme.qristalBlue.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "#${widget.order.receiptNumber}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  widget.order.createdAt.toLocal().toString().split(' ')[1].substring(0, 5), // Time HH:MM
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: FutureBuilder<List<TypedOrderItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text("${itemData.item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              if (itemData.item.notes != null && itemData.item.notes!.isNotEmpty)
                                Text(
                                  "Note: ${itemData.item.notes}",
                                  style: const TextStyle(color: AppTheme.error, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Footer Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPreparing ? AppTheme.emerald : Colors.orange,
                ),
                onPressed: () async {
                  String newStatus = isPreparing ? 'READY' : 'PREPARING';
                  await db.updateOrderStatus(widget.order.id, newStatus);
                  
                  // Trigger sync to let server/cashiers know
                  ref.read(syncControllerProvider.notifier).performSync();
                },
                child: Text(isPreparing ? "MARK DONE" : "START COOKING"),
              ),
            ),
          )
        ],
      ),
    );
  }
}