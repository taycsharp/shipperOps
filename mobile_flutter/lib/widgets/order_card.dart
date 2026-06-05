import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
  final AppLocalizations l10n;

  const OrderCard({
    super.key,
    required this.order,
    required this.onItemStatus,
    required this.onOrderStatus,
    required this.onUploadProof,
    required this.onCallCustomer,
    required this.onNavigatePickup,
    required this.onNavigateDelivery,
    required this.l10n,
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

  List<Widget> _workflowButtons(AppLocalizations l10n) {
    final status = order.status.toUpperCase();
    final buttons = <Widget>[];

    if (status == 'ASSIGNED') {
      buttons.add(FilledButton.icon(
        onPressed: () => onOrderStatus(order.id, 'PICKED_UP'),
        icon: const Icon(Icons.inventory_2_outlined),
        label: Text(l10n.t('markPickedUp')),
      ));
    } else if (status == 'PICKED_UP') {
      buttons.add(FilledButton.icon(
        onPressed: () => onOrderStatus(order.id, 'IN_TRANSIT'),
        icon: const Icon(Icons.delivery_dining),
        label: Text(l10n.t('startDelivery')),
      ));
    } else if (status == 'IN_TRANSIT') {
      buttons.add(FilledButton.icon(
        onPressed: () => onOrderStatus(order.id, 'DELIVERED'),
        icon: const Icon(Icons.check_circle_outline),
        label: Text(l10n.t('delivered')),
      ));
      buttons.add(OutlinedButton.icon(
        onPressed: () => onOrderStatus(order.id, 'FAILED'),
        icon: const Icon(Icons.report_problem_outlined),
        label: Text(l10n.t('failed')),
      ));
      buttons.add(OutlinedButton.icon(
        onPressed: () => onOrderStatus(order.id, 'RETURNED'),
        icon: const Icon(Icons.assignment_return_outlined),
        label: Text(l10n.t('returned')),
      ));
    }

    if (status == 'DELIVERED' || status == 'PARTIALLY_DELIVERED' || order.needsProof) {
      buttons.add(OutlinedButton.icon(
        onPressed: onUploadProof,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(order.proofImageUrl.isEmpty ? l10n.t('uploadProof') : l10n.t('replaceProof')),
      ));
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(label: l10n.displayStatus(order.status), color: _statusColor(order.status)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _InfoRow(icon: Icons.call_outlined, text: order.customerPhone.isEmpty ? l10n.t('phoneNotSet') : order.customerPhone)),
                const SizedBox(width: 8),
                _CodBadge(amount: order.codRemaining, collected: order.codCollected, l10n: l10n),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on, text: order.deliveryAddress),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.storefront, text: order.pickupAddress.isEmpty ? l10n.t('pickupAddressNotSet') : order.pickupAddress),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: onCallCustomer, icon: const Icon(Icons.call_outlined), label: Text(l10n.t('callCustomer'))),
                OutlinedButton.icon(onPressed: onNavigatePickup, icon: const Icon(Icons.storefront_outlined), label: Text(l10n.t('pickupMap'))),
                OutlinedButton.icon(onPressed: onNavigateDelivery, icon: const Icon(Icons.near_me_outlined), label: Text(l10n.t('openMap'))),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _Metric(label: l10n.t('codTotal'), value: money(order.codAmount))),
                  Expanded(child: _Metric(label: l10n.t('collected'), value: order.codCollected ? money(order.codCollectedAmount) : l10n.t('no'))),
                  Expanded(child: _Metric(label: l10n.t('items'), value: '${order.totalItems}')),
                  Expanded(child: _Metric(label: l10n.t('weight'), value: order.totalWeight > 0 ? '${order.totalWeight.toStringAsFixed(1)} kg' : '-')),
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
                    if (order.receiverName.isNotEmpty) Text(l10n.receiver(order.receiverName), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (order.failedReason.isNotEmpty) Text(l10n.reason(l10n.displayStatus(order.failedReason)), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    if (order.deliveryNote.isNotEmpty) Text(l10n.note(order.deliveryNote)),
                    if (order.proofImageUrl.isNotEmpty) Text(l10n.t('proofUploaded'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
            if (_workflowButtons(l10n).isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: _workflowButtons(l10n)),
            ],
            if (order.items.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                l10n.t('packageItems'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => _OrderItemTile(item: item, onItemStatus: onItemStatus, l10n: l10n)),
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
  final AppLocalizations l10n;

  const _OrderItemTile({required this.item, required this.onItemStatus, required this.l10n});

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
                  '${item.sku.isEmpty ? l10n.t('noSku') : item.sku} • ${money(item.lineTotal)} • ${l10n.displayStatus(item.status)} • ${l10n.deliveredQuantity(item.deliveredQuantity, item.quantity)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.t('updateItem'),
            onSelected: (status) => onItemStatus(item.id, status),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'PICKED_UP', child: Text(l10n.t('pickedUp'))),
              PopupMenuItem(value: 'IN_TRANSIT', child: Text(l10n.t('inTransit'))),
              PopupMenuItem(value: 'DELIVERED', child: Text(l10n.t('delivered'))),
              PopupMenuItem(value: 'FAILED', child: Text(l10n.t('failed'))),
              PopupMenuItem(value: 'RETURNED', child: Text(l10n.t('returned'))),
            ],
          ),
        ],
      ),
    );
  }
}


class _CodBadge extends StatelessWidget {
  final double amount;
  final bool collected;
  final AppLocalizations l10n;

  const _CodBadge({required this.amount, required this.collected, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final color = collected ? Colors.green : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        l10n.codBadge(money(amount), collected),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
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
