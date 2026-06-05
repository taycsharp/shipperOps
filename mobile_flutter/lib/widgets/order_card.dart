import 'package:flutter/material.dart';

import '../models/delivery_models.dart';
import '../utils/formatters.dart';
import 'status_pill.dart';

class OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final Future<void> Function(int itemId, String status) onItemStatus;
  final Future<void> Function(int orderId, String status) onOrderStatus;
  final Future<void> Function() onUploadProof;
  final Future<void> Function() onCallCustomer;
  final Future<void> Function() onNavigatePickup;
  final Future<void> Function() onNavigateDelivery;

  const OrderCard({
    super.key,
    required this.order,
    required this.onItemStatus,
    required this.onOrderStatus,
    required this.onUploadProof,
    required this.onCallCustomer,
    required this.onNavigatePickup,
    required this.onNavigateDelivery,
  });

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.blueGrey;
      case 'ASSIGNED':
        return Colors.indigo;
      case 'PICKED_UP':
        return Colors.deepPurple;
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'DELIVERED':
      case 'PARTIALLY_DELIVERED':
        return Colors.green;
      case 'FAILED':
      case 'RETURNED':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Widget> _workflowButtons() {
    final status = order.status.toUpperCase();
    final buttons = <Widget>[];

    if (status == 'ASSIGNED') {
      buttons.add(FilledButton.icon(
        onPressed: () => onOrderStatus(order.id, 'PICKED_UP'),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Mark picked up'),
      ));
    } else if (status == 'PICKED_UP') {
      buttons.add(FilledButton.icon(
        onPressed: () => onOrderStatus(order.id, 'IN_TRANSIT'),
        icon: const Icon(Icons.delivery_dining),
        label: const Text('Start delivery'),
      ));
    } else if (status == 'IN_TRANSIT') {
      buttons.add(FilledButton.icon(
        onPressed: () => onOrderStatus(order.id, 'DELIVERED'),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Delivered'),
      ));
      buttons.add(OutlinedButton.icon(
        onPressed: () => onOrderStatus(order.id, 'FAILED'),
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Failed'),
      ));
      buttons.add(OutlinedButton.icon(
        onPressed: () => onOrderStatus(order.id, 'RETURNED'),
        icon: const Icon(Icons.assignment_return_outlined),
        label: const Text('Returned'),
      ));
    }

    if (status == 'DELIVERED' || status == 'PARTIALLY_DELIVERED' || order.needsProof) {
      buttons.add(OutlinedButton.icon(
        onPressed: onUploadProof,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(order.proofImageUrl.isEmpty ? 'Upload proof' : 'Replace proof'),
      ));
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderCode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(label: order.status, color: _statusColor(order.status)),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.person, text: '${order.customerName}  ${order.customerPhone}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: onCallCustomer, icon: const Icon(Icons.call_outlined), label: const Text('Call customer')),
                OutlinedButton.icon(onPressed: onNavigatePickup, icon: const Icon(Icons.storefront_outlined), label: const Text('Pickup map')),
                OutlinedButton.icon(onPressed: onNavigateDelivery, icon: const Icon(Icons.near_me_outlined), label: const Text('Customer map')),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.storefront, text: order.pickupAddress.isEmpty ? 'Pickup address not set' : order.pickupAddress),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.location_on, text: order.deliveryAddress),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _Metric(label: 'COD', value: money(order.codAmount))),
                  Expanded(child: _Metric(label: 'Collected', value: order.codCollected ? money(order.codCollectedAmount) : 'No')),
                  Expanded(child: _Metric(label: 'Items', value: '${order.totalItems}')),
                  Expanded(child: _Metric(label: 'Weight', value: order.totalWeight > 0 ? '${order.totalWeight.toStringAsFixed(1)} kg' : '-')),
                ],
              ),
            ),
            if (order.proofImageUrl.isNotEmpty || order.receiverName.isNotEmpty || order.failedReason.isNotEmpty || order.deliveryNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.receiverName.isNotEmpty) Text('Receiver: ${order.receiverName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (order.failedReason.isNotEmpty) Text('Reason: ${compactStatus(order.failedReason)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    if (order.deliveryNote.isNotEmpty) Text('Note: ${order.deliveryNote}'),
                    if (order.proofImageUrl.isNotEmpty) const Text('Proof uploaded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
            if (_workflowButtons().isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: _workflowButtons()),
            ],
            if (order.items.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                'Package items',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => _OrderItemTile(item: item, onItemStatus: onItemStatus)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final DeliveryOrderItem item;
  final Future<void> Function(int itemId, String status) onItemStatus;

  const _OrderItemTile({required this.item, required this.onItemStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.name} x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${item.sku.isEmpty ? 'No SKU' : item.sku} • ${money(item.lineTotal)} • ${compactStatus(item.status)} • delivered ${item.deliveredQuantity}/${item.quantity}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Update item',
            onSelected: (status) => onItemStatus(item.id, status),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'PICKED_UP', child: Text('Picked up')),
              PopupMenuItem(value: 'IN_TRANSIT', child: Text('In transit')),
              PopupMenuItem(value: 'DELIVERED', child: Text('Delivered')),
              PopupMenuItem(value: 'FAILED', child: Text('Failed')),
              PopupMenuItem(value: 'RETURNED', child: Text('Returned')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    );
  }
}
