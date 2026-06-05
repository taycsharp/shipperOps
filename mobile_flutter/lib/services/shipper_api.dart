import 'dart:io';

import '../models/delivery_models.dart';
import 'api_client.dart';

class ShipperApi {
  final ApiClient client;
  ShipperApi(this.client);

  Future<AuthSession> login(String email, String password) async {
    final data = await client.postJson('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final session = AuthSession.fromJson(data as Map<String, dynamic>);
    client.token = session.accessToken;
    return session;
  }

  Future<AppUser> me() async {
    final data = await client.getJson('/auth/me');
    return AppUser.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ShipperProfile>> getShippers() async {
    final data = await client.getJson('/shippers');
    final list = data is List ? data : (data['shippers'] ?? []) as List<dynamic>;
    return list.map((e) => ShipperProfile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ShipperProfile> getShipper(int shipperId) async {
    final data = await client.getJson('/shippers/$shipperId');
    return ShipperProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<ShipperProfile> updateStatus(int shipperId, ShipperStatus status) async {
    final data = await client.postJson('/shippers/$shipperId/status', {
      'status': statusToApi(status),
    });
    return ShipperProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<void> sendLocation({
    required int shipperId,
    required double lat,
    required double lng,
    double? speed,
    double? heading,
    int? battery,
  }) async {
    await client.postJson('/locations/update', {
      'shipper_id': shipperId,
      'lat': lat,
      'lng': lng,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (battery != null) 'battery': battery,
    });
  }

  Future<List<DeliveryOrder>> getAssignedOrders(int shipperId) async {
    final data = await client.getJson('/orders/shipper/$shipperId');
    final list = data is List ? data : (data['orders'] ?? data['items'] ?? []) as List<dynamic>;
    return list.map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DeliveryOrder>> getMyActiveOrders() async {
    final data = await client.getJson('/orders?active_only=true&limit=100');
    final list = data is List ? data : (data['items'] ?? data['orders'] ?? []) as List<dynamic>;
    return list.map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DeliveryOrder> updateOrderStatus(
    int orderId,
    String status, {
    String? note,
    String? failedReason,
    String? receiverName,
    bool? codCollected,
    double? codCollectedAmount,
    String? paymentMethod,
  }) async {
    final data = await client.postJson('/orders/$orderId/status', {
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'delivery_note': note.trim(),
      if (failedReason != null && failedReason.trim().isNotEmpty) 'failed_reason': failedReason.trim(),
      if (receiverName != null && receiverName.trim().isNotEmpty) 'receiver_name': receiverName.trim(),
      if (codCollected != null) 'cod_collected': codCollected,
      if (codCollectedAmount != null) 'cod_collected_amount': codCollectedAmount,
      if (paymentMethod != null && paymentMethod.trim().isNotEmpty) 'payment_method': paymentMethod,
    });
    return DeliveryOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateItemStatus(
    int orderId,
    int itemId,
    String status, {
    int? deliveredQuantity,
    String? note,
  }) async {
    await client.postJson('/orders/$orderId/items/$itemId/status', {
      'status': status,
      if (deliveredQuantity != null) 'delivered_quantity': deliveredQuantity,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<String> uploadProof(
    int orderId,
    File file, {
    String? receiverName,
    String? deliveryNote,
  }) async {
    final data = await client.multipartPost('/orders/$orderId/proof', file: file, fileField: 'file', fields: {
      if (receiverName != null && receiverName.trim().isNotEmpty) 'receiver_name': receiverName.trim(),
      if (deliveryNote != null && deliveryNote.trim().isNotEmpty) 'delivery_note': deliveryNote.trim(),
    });
    return (data['proof_image_url'] ?? '').toString();
  }
}
