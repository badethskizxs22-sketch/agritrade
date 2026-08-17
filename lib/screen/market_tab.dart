import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/product_service.dart';

// Body-only widget — renders inside FarmerHomeScreen's Scaffold.
//
// onNavigateToTab lets this tab jump to another bottom-nav tab in the
// parent Scaffold (tapping "Welcome back" goes to Profile). Wire it up
// in FarmerHomeScreen:
//   MarketTab(onNavigateToTab: (i) => setState(() => _selectedIndex = i))
// Index assumption, matching the rest of this build: 3=Profile — adjust
// the number below if your order differs.
class MarketTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const MarketTab({super.key, this.onNavigateToTab});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  static const Color _dark = Color(0xFF1B5E20);
  static const Color _accent = Color(0xFFDCEDC8);

  static const int _profileTabIndex = 3;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Farmer';
    final productService = ProductService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: productService.myProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _dark));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong loading products.'));
        }
        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            _welcomeHeader(name, docs.length),
            const SizedBox(height: 16),
            _statRow(docs.length),
            const SizedBox(height: 16),
            _salesPerformanceCard(),
            const SizedBox(height: 16),
            _reviewsSection(),
          ],
        );
      },
    );
  }

  // ---- Welcome header — tappable, opens Profile ----
  Widget _welcomeHeader(String name, int productCount) {
    final user = FirebaseAuth.instance.currentUser;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onNavigateToTab?.call(_profileTabIndex),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_dark, Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(user?.uid ?? '').snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  final photoUrl = data?['photoUrl']?.toString() ?? user?.photoURL;
                  final imageProvider = (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null;

                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: imageProvider,
                    child: imageProvider == null ? const Icon(Icons.person, color: _dark, size: 28) : null,
                  );
                },
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('$productCount product${productCount == 1 ? '' : 's'} listed',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(int productCount) {
    return Row(
      children: [
        Expanded(child: _statCard('TOTAL ORDERS\nTHIS WEEK', '0')),
        const SizedBox(width: 12),
        Expanded(child: _statCard('TOTAL\nPRODUCTS', '$productCount')),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 0.4, height: 1.3)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _dark)),
        ],
      ),
    );
  }

  Widget _salesPerformanceCard() {
    const months = ['MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT'];
    const heights = [34.0, 48.0, 30.0, 54.0, 70.0, 44.0];
    return Container(
      padding: const EdgeInsets.all(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sales Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20)),
                child: const Text('Month',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Monthly Revenue', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Text('₱0.00', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(months.length, (i) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 18,
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(months[i], style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Text('Revenue updates as orders come in.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _reviewsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reviews',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: const [
                    Icon(Icons.star, size: 14, color: _dark),
                    SizedBox(width: 4),
                    Text('—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _dark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Icon(Icons.reviews_outlined, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No reviews yet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 2),
                Text("Buyers' reviews of your products will appear here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}