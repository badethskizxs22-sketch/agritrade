import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class BuyerChatListScreen extends StatefulWidget {
  const BuyerChatListScreen({super.key});

  @override
  State<BuyerChatListScreen> createState() => _BuyerChatListScreenState();
}

class _BuyerChatListScreenState extends State<BuyerChatListScreen> {
  static const Color _dark = Color(0xFF1B5E20);
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: const Text(
            'Messages',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _dark,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                hintText: 'Search inquiries or buyers...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .where('participants', arrayContains: currentUserId)
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
                builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Something went wrong loading messages.',
                        style: TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

              if (!snapshot.hasData) {
                return const SizedBox.shrink(); 
              }

              final docs = snapshot.data?.docs ?? [];

              final filteredDocs = docs.where((doc) {
                final data = doc.data();
                final farmerName = (data['farmerName'] ?? '').toString().toLowerCase();
                final lastMessage = (data['lastMessage'] ?? '').toString().toLowerCase();
                return farmerName.contains(_searchQuery) || lastMessage.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline_rounded, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No messages found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredDocs.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey[200], indent: 76),
                itemBuilder: (context, index) {
                  final chatData = filteredDocs[index].data();
                  final chatId = filteredDocs[index].id;
                  final farmerName = chatData['farmerName'] ?? "Farmer's Harvest";
                  final farmerId = chatData['farmerId'] ?? '';
                  final lastMessage = chatData['lastMessage'] ?? 'Tap to start conversation';
                  final farmerImage = chatData['farmerImage'] ?? '';
                  final unreadCount = chatData['unreadBuyerCount'] ?? 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFDCEDC8),
                      backgroundImage: farmerImage.isNotEmpty ? NetworkImage(farmerImage) : null,
                      child: farmerImage.isEmpty ? const Icon(Icons.person, color: _dark) : null,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            farmerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimestamp(chatData['lastMessageTimestamp']),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: unreadCount > 0 ? _dark : Colors.grey[500],
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: _dark,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: chatId,
                            otherUserId: farmerId,
                            otherUserName: farmerName,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else {
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    }
  }
}