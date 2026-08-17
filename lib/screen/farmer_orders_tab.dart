import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/order_service.dart';

// Body-only widget — it renders inside the FarmerHomeScreen Scaffold
// (which already provides the AgriTrade+ app bar and bottom nav).
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  static const Color _dark = Color(0xFF1B5E20);
  static const Color _accent = Color(0xFFDCEDC8);

  final OrderService _orderService = OrderService();

  // 'pending' | 'confirmed' | 'completed'
  String _filter = 'pending';

  // Format a number with thousands separators, e.g. 12500 -> ₱12,500
  String _peso(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱$buf';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _dark,
        content: Text(message),
      ),
    );
  }

  Future<void> _confirm(String id) async {
    final err = await _orderService.updateStatus(id, 'confirmed');
    if (!mounted) return;
    _snack(err ?? 'Order confirmed.');
  }

  Future<void> _reject(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Order?'),
        content: const Text('This will decline the buyer\u2019s order.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _orderService.updateStatus(id, 'rejected');
    if (!mounted) return;
    _snack(err ?? 'Order rejected.');
  }

  void _showDetails(Map<String, dynamic> d) {
    final name = d['productName']?.toString() ?? d['name']?.toString() ?? 'Product';
    final buyer = d['buyerName']?.toString() ?? 'Buyer';
    final status = (d['status'] ?? 'pending').toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buyer: $buyer'),
            const SizedBox(height: 6),
            Text('Status: ${status[0].toUpperCase()}${status.substring(1)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (status == 'confirmed')
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final err = await _orderService.updateStatus(d['id'].toString(), 'completed');
                if (!mounted) return;
                _snack(err ?? 'Order marked complete.');
              },
              child: const Text('Mark Complete', style: TextStyle(color: _dark, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text('Orders',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterTab('Pending', 'pending'),
              const SizedBox(width: 8),
              _filterTab('Confirmed', 'confirmed'),
              const SizedBox(width: 8),
              _filterTab('Completed', 'completed'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _orderService.farmerOrdersStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _dark));
              }
              if (snap.hasError) {
                return const Center(child: Text('Could not load orders.'));
              }
              final all = snap.data?.docs ?? [];
              final docs = all
                  .where((d) => (d.data()['status'] ?? 'pending').toString() == _filter)
                  .toList();
              if (docs.isEmpty) return _emptyState();
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: docs.length,
                itemBuilder: (context, i) => _orderCard(docs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterTab(String label, String value) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _dark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? _dark : Colors.grey.shade300),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c;
    switch (status) {
      case 'confirmed':
        c = _dark;
        break;
      case 'completed':
        c = Colors.blueGrey;
        break;
      case 'rejected':
        c = Colors.red;
        break;
      default:
        c = const Color(0xFFB8860B); // amber for pending
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
    );
  }

  Widget _orderCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final id = doc.id;
    final name = d['productName']?.toString() ?? d['name']?.toString() ?? 'Product';
    final unit = d['unit']?.toString() ?? '';
    final qtyLabel = d['quantityLabel']?.toString() ?? '${d['quantity'] ?? ''} $unit'.trim();
    final buyer = d['buyerName']?.toString() ?? 'Buyer';
    final totalRaw = d['total'];
    final total = totalRaw is num ? totalRaw : (num.tryParse('$totalRaw') ?? 0);
    final status = (d['status'] ?? 'pending').toString();
    final imageUrl = d['imageUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _thumbFallback(name))
                      : _thumbFallback(name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(qtyLabel, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(buyer, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text(_peso(total),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _dark)),
                ],
              ),
              const Spacer(),
              ..._actionButtons(id, status, {...d, 'id': id}),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _actionButtons(String id, String status, Map<String, dynamic> data) {
    if (status == 'pending') {
      return [
        OutlinedButton(
          onPressed: () => _reject(id),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Reject'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _confirm(id),
          style: ElevatedButton.styleFrom(
            backgroundColor: _dark,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Confirm'),
        ),
      ];
    }
    // confirmed or completed
    return [
      OutlinedButton(
        onPressed: () => _showDetails(data),
        style: OutlinedButton.styleFrom(
          foregroundColor: _dark,
          side: BorderSide(color: Colors.grey.shade400),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Details'),
      ),
    ];
  }

  Widget _thumbFallback(String name) {
    return Container(
      color: _accent,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _dark),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_outlined, size: 48, color: _dark),
          ),
          const SizedBox(height: 18),
          Text('No $_filter orders yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          Text('Orders from buyers will appear here.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}