import 'package:flutter/material.dart';

class BuyerProfileScreen extends StatelessWidget {
  final VoidCallback onLogout;
  static const Color _dark = Color(0xFF1B5E20);

  const BuyerProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 36, backgroundColor: Color(0xFFDCEDC8), child: Icon(Icons.person, size: 36, color: _dark)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white),
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}