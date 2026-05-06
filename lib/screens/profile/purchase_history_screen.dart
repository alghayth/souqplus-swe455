import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:souqplus/components/page_header_title.dart';
import 'package:souqplus/main.dart';
import 'package:souqplus/screens/profile/order_tracking_map_screen.dart';
import 'package:souqplus/services/admin_order_service.dart';

class PurchaseHistoryScreen extends StatelessWidget {
  const PurchaseHistoryScreen({super.key});

  static String routeName = '/purchase_history';
  static const Duration _estimatedDeliveryWindow = Duration(days: 5);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const PageHeaderTitle('Purchase History')),
      body: user == null
          ? const Center(child: Text('Please login first'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load orders: ${snapshot.error}'),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    .where(
                      (doc) =>
                          (doc.data()['userId'] as String? ?? '') == user.uid,
                    )
                    .where(
                      (doc) =>
                          (doc.data()['paymentStatus'] as String? ?? '')
                              .trim()
                              .toLowerCase() ==
                          'paid',
                    )
                    .where(
                      (doc) => (doc.data()['paymentIntentId'] as String? ?? '')
                          .trim()
                          .isNotEmpty,
                    )
                    .toList();
                docs.sort((a, b) {
                  final aDate = _readDate(a.data());
                  final bDate = _readDate(b.data());
                  return bDate.compareTo(aDate);
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('You have not placed any orders yet.'),
                    ),
                  );
                }

                final totalSpent = docs.fold<double>(
                  0,
                  (runningTotal, doc) => runningTotal + _readTotal(doc.data()),
                );

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: docs.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B3A68),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Orders',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Review your past purchases and payment details.',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _SummaryChip(label: '${docs.length} Orders'),
                                _SummaryChip(
                                  label:
                                      'SAR ${totalSpent.toStringAsFixed(2)} Spent',
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    final order = docs[index - 1];
                    final data = order.data();
                    final items = _readItems(data);
                    final orderTitle = items.isEmpty
                        ? 'Order #${order.id.substring(0, 6).toUpperCase()}'
                        : items.first['title']?.toString().trim().isNotEmpty ==
                              true
                        ? items.first['title'].toString().trim()
                        : 'Order #${order.id.substring(0, 6).toUpperCase()}';
                    final status = _normalizedOrderStatus(data);
                    final paymentStatus =
                        (data['paymentStatus'] as String?)?.trim().isNotEmpty ==
                            true
                        ? (data['paymentStatus'] as String).trim()
                        : 'unknown';
                    final deliveryAddress =
                        (data['deliveryAddress'] as String? ?? '').trim();
                    final total = _readTotal(data);
                    final deliveryEstimate = _deliveryEstimate(data, status);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD7E0EA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF1F8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Color(0xFF1B3A68),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderTitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(_readDate(data)),
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'SAR ${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF1B3A68),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusChip(
                                label: 'Order: ${_statusLabel(status)}',
                                color: _statusColor(status),
                              ),
                              _StatusChip(
                                label:
                                    'Payment: ${paymentStatus.toUpperCase()}',
                                color: paymentStatus.toLowerCase() == 'paid'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFB45309),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _OrderProgressTracker(status: status),
                          const SizedBox(height: 12),
                          _DeliveryEstimateRow(estimate: deliveryEstimate),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OrderTrackingMapScreen(
                                      orderId: order.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Track Order On Map'),
                            ),
                          ),
                          if (deliveryAddress.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Delivery: $deliveryAddress',
                              style: const TextStyle(color: Color(0xFF4B5563)),
                            ),
                          ],
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Items',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...items
                                .take(3)
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      item['title']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true
                                          ? item['title'].toString().trim()
                                          : 'Product',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            if (items.length > 3)
                              Text(
                                '+${items.length - 3} more items',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  static DateTime _readDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _readTotal(Map<String, dynamic> data) {
    final total = data['totalPriceSar'] ?? data['total'] ?? data['subtotalSar'];
    if (total is num) {
      return total.toDouble();
    }
    if (total is String) {
      return double.tryParse(total.trim()) ?? 0;
    }
    return 0;
  }

  static _DeliveryEstimate _deliveryEstimate(
    Map<String, dynamic> data,
    String status,
  ) {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus == 'delivered') {
      return const _DeliveryEstimate(
        label: 'Delivered',
        color: Color(0xFF16A34A),
      );
    }

    final estimateDate = _readEstimatedDeliveryDate(data);
    if (estimateDate == null) {
      return const _DeliveryEstimate(
        label: 'Estimated delivery unavailable',
        color: Color(0xFF6B7280),
      );
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final estimateOnly = DateTime(
      estimateDate.year,
      estimateDate.month,
      estimateDate.day,
    );
    final remainingDays = estimateOnly.difference(todayOnly).inDays;

    if (remainingDays < 0) {
      return _DeliveryEstimate(
        label: 'Estimated delivery passed: ${_formatDate(estimateDate)}',
        color: const Color(0xFFB45309),
      );
    }

    if (remainingDays == 0) {
      return const _DeliveryEstimate(
        label: 'Estimated delivery: today',
        color: Color(0xFF2563EB),
      );
    }

    final dayLabel = remainingDays == 1 ? '1 day' : '$remainingDays days';
    return _DeliveryEstimate(
      label:
          'Estimated delivery: ${_formatDate(estimateDate)} ($dayLabel left)',
      color: const Color(0xFF2563EB),
    );
  }

  static DateTime? _readEstimatedDeliveryDate(Map<String, dynamic> data) {
    final estimatedDeliveryAt = data['estimatedDeliveryAt'];
    if (estimatedDeliveryAt is Timestamp) {
      return estimatedDeliveryAt.toDate();
    }

    final createdAt = _readDate(data);
    if (createdAt.millisecondsSinceEpoch == 0) {
      return null;
    }

    return createdAt.add(_estimatedDeliveryWindow);
  }

  static List<Map<String, dynamic>> _readItems(Map<String, dynamic> data) {
    final rawItems = data['products'] ?? data['items'];
    if (rawItems is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return 'Date unavailable';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _normalizedOrderStatus(Map<String, dynamic> data) {
    final rawStatus = (data['status'] as String? ?? '').trim();
    if (rawStatus.isEmpty) {
      return 'ordered';
    }

    final normalized = AdminOrderService.normalizeOrderStatus(rawStatus);
    return normalized.isEmpty ? 'ordered' : normalized;
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'ordered' => const Color(0xFFF59E0B),
      'in transit' => const Color(0xFF2563EB),
      'delivered' => const Color(0xFF16A34A),
      _ => const Color(0xFF6B7280),
    };
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'ordered' => 'ORDERED',
      'in transit' => 'IN TRANSIT',
      'delivered' => 'DELIVERED',
      _ => status.toUpperCase(),
    };
  }
}

class _DeliveryEstimate {
  const _DeliveryEstimate({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class _DeliveryEstimateRow extends StatelessWidget {
  const _DeliveryEstimateRow({required this.estimate});

  final _DeliveryEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: 20,
          color: estimate.color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            estimate.label,
            style: TextStyle(
              color: estimate.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _OrderProgressTracker extends StatelessWidget {
  const _OrderProgressTracker({required this.status});

  final String status;

  static const List<String> _steps = ['ordered', 'in transit', 'delivered'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(status);
    final safeIndex = currentIndex >= 0 ? currentIndex : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery progress',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_steps.length, (index) {
            final step = _steps[index];
            final completed = index <= safeIndex;
            final isLast = index == _steps.length - 1;

            return Expanded(
              child: Row(
                children: [
                  _ProgressStep(
                    label: PurchaseHistoryScreen._statusLabel(step),
                    completed: completed,
                    isCurrent: index == safeIndex,
                    color: PurchaseHistoryScreen._statusColor(step),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: completed
                              ? PurchaseHistoryScreen._statusColor(step)
                              : const Color(0xFFD7E0EA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.completed,
    required this.isCurrent,
    required this.color,
  });

  final String label;
  final bool completed;
  final bool isCurrent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCurrent ? 30 : 24,
          height: isCurrent ? 30 : 24,
          decoration: BoxDecoration(
            color: completed ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: completed ? color : const Color(0xFFD7E0EA),
              width: 2,
            ),
          ),
          child: Icon(
            completed ? Icons.check : Icons.circle_outlined,
            size: 14,
            color: completed ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: completed
                ? const Color(0xFF111827)
                : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
