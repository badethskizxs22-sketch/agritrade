import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Web dashboard for a DA officer (admin) to review and act on
/// pending farmer verification applications.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();

  // Simple loading flag so we can disable buttons while an
  // approve/reject request is in flight (prevents double-tapping).
  bool _actionInProgress = false;

  Future<void> _handleApprove(String uid, String name) async {
    final confirmed = await _confirm(
      title: 'Approve $name?',
      message: 'This farmer will be able to log in and post products.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await _authService.approveFarmer(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name approved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleReject(String uid, String name) async {
    final confirmed = await _confirm(
      title: 'Reject $name?',
      message: 'This farmer will see a rejected status and cannot proceed.',
      confirmLabel: 'Reject',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _actionInProgress = true);
    try {
      await _authService.rejectFarmer(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: isDestructive ? Colors.red : AppTheme.dark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Fetches the Base64 certification photo for a given uid from the
  // separate verificationDocs collection.
  Future<String?> _fetchCertificationImage(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('verificationDocs')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return doc.data()?['document'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.dark,
        title: const Text(
          'Admin Dashboard — Pending Farmers',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign out',
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _authService.getPendingFarmers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No pending farmer applications right now.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final uid = docs[index].id;
              final name = data['fullName'] ?? 'Unknown';
              final email = data['email'] ?? '';
              final barangay = data['barangay'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Barangay: $barangay'),
                      const SizedBox(height: 12),

                      // Certification photo, loaded on demand per card.
                      FutureBuilder<String?>(
                        future: _fetchCertificationImage(uid),
                        builder: (context, imgSnapshot) {
                          if (imgSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final base64Data = imgSnapshot.data;
                          if (base64Data == null || base64Data.isEmpty) {
                            return const Text(
                              'No certification photo submitted.',
                              style: TextStyle(color: Colors.red),
                            );
                          }
                          // Manual decode used here. If you already have a
                          // Base64Image widget (with base64Data/fallback
                          // params), share it and we'll swap this block to
                          // use that instead, for consistency.
                          try {
                            final bytes = base64Decode(base64Data);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                bytes,
                                height: 160,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Text(
                                  'Could not load image.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            );
                          } catch (e) {
                            return const Text(
                              'Could not decode certification photo.',
                              style: TextStyle(color: Colors.red),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _actionInProgress
                                ? null
                                : () => _handleReject(uid, name),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _actionInProgress
                                ? null
                                : () => _handleApprove(uid, name),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.mid,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}