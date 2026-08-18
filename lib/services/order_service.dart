import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final _orders = FirebaseFirestore.instance.collection('orders');

  // All orders where the logged-in farmer is the seller.
  Stream<QuerySnapshot<Map<String, dynamic>>> farmerOrdersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _orders.where('sellerId', isEqualTo: uid).snapshots();
  }

  // All orders created by the logged-in buyer.
  Stream<QuerySnapshot<Map<String, dynamic>>> buyerOrdersStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _orders.where('buyerId', isEqualTo: uid).snapshots();
  }

  // Creates one order document that both buyer and farmer screens read.
  Future<String?> createOrder({
    required String sellerId,
    required String sellerName,
    required String productId,
    required String productName,
    required String imageUrl,
    required num quantity,
    required String unit,
    required num unitPrice,
    required String buyerName,
    required String buyerContact,
    required String buyerAddress,
    required String deliveryMethod,
  }) async {
    try {
      final buyerId = FirebaseAuth.instance.currentUser?.uid;
      if (buyerId == null || buyerId.isEmpty) {
        return 'Please log in again before placing an order.';
      }

      final q = quantity <= 0 ? 1 : quantity;
      final price = unitPrice < 0 ? 0 : unitPrice;
      final total = q * price;

      await _orders.add({
        'sellerId': sellerId,
        'sellerName': sellerName,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerContact': buyerContact,
        'buyerAddress': buyerAddress,
        'productId': productId,
        'productName': productName,
        'imageUrl': imageUrl,
        'quantity': q,
        'unit': unit,
        'quantityLabel': '$q $unit',
        'unitPrice': price,
        'total': total,
        'deliveryMethod': deliveryMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      final reason = (e.message ?? '').trim();
      if (reason.isNotEmpty) {
        return 'Could not place your order: $reason';
      }
      return 'Could not place your order. Please try again.';
    } catch (_) {
      return 'Could not place your order. Please try again.';
    }
  }

  // Confirm / reject / complete an order.
  Future<String?> updateStatus(String id, String status) async {
    try {
      await _orders.doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Could not update the order. Please try again.';
    }
  }
}