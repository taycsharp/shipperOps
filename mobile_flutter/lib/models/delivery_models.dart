enum UserRole { admin, dispatcher, shipper }

enum ShipperStatus { available, busy, offline, suspended }

enum DeliveryStatus {
  pending,
  assigned,
  pickedUp,
  inTransit,
  delivered,
  failed,
  returned,
  cancelled,
  partiallyDelivered,
}

String roleToApi(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'ADMIN';
    case UserRole.dispatcher:
      return 'DISPATCHER';
    case UserRole.shipper:
      return 'SHIPPER';
  }
}

UserRole userRoleFromApi(String? value) {
  switch ((value ?? '').toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'DISPATCHER':
      return UserRole.dispatcher;
    case 'SHIPPER':
    default:
      return UserRole.shipper;
  }
}

String statusToApi(ShipperStatus status) {
  switch (status) {
    case ShipperStatus.available:
      return 'AVAILABLE';
    case ShipperStatus.busy:
      return 'BUSY';
    case ShipperStatus.offline:
      return 'OFFLINE';
    case ShipperStatus.suspended:
      return 'SUSPENDED';
  }
}

ShipperStatus shipperStatusFromApi(String? value) {
  switch ((value ?? '').toUpperCase()) {
    case 'AVAILABLE':
      return ShipperStatus.available;
    case 'BUSY':
      return ShipperStatus.busy;
    case 'SUSPENDED':
      return ShipperStatus.suspended;
    case 'OFFLINE':
    default:
      return ShipperStatus.offline;
  }
}

String compactStatus(String value) => value.replaceAll('_', ' ');

int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

class AppUser {
  final int id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: asInt(json['id']),
      name: (json['name'] ?? 'User').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: userRoleFromApi(json['role']?.toString()),
    );
  }
}

class AuthSession {
  final String accessToken;
  final String tokenType;
  final UserRole role;
  final int userId;

  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.role,
    required this.userId,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['access_token'] ?? '').toString(),
      tokenType: (json['token_type'] ?? 'bearer').toString(),
      role: userRoleFromApi(json['role']?.toString()),
      userId: asInt(json['user_id'] ?? json['userId']),
    );
  }
}

class ShipperUser {
  final int id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  const ShipperUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory ShipperUser.fromJson(Map<String, dynamic> json) {
    return ShipperUser(
      id: asInt(json['id']),
      name: (json['name'] ?? 'Shipper').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: userRoleFromApi(json['role']?.toString()),
    );
  }
}

class ShipperProfile {
  final int id;
  final int userId;
  final String vehicleType;
  final String vehiclePlate;
  final ShipperStatus status;
  final double? currentLat;
  final double? currentLng;
  final String? lastSeenAt;
  final ShipperUser? user;

  const ShipperProfile({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.status,
    this.currentLat,
    this.currentLng,
    this.lastSeenAt,
    this.user,
  });

  String get displayName => user?.name ?? 'Shipper #$id';
  String get phone => user?.phone ?? '';
  String get plateLabel => vehiclePlate.isEmpty ? 'No plate' : vehiclePlate;

  factory ShipperProfile.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return ShipperProfile(
      id: asInt(json['id']),
      userId: asInt(json['user_id'] ?? json['userId']),
      vehicleType: (json['vehicle_type'] ?? json['vehicleType'] ?? 'motorbike').toString(),
      vehiclePlate: (json['vehicle_plate'] ?? json['vehiclePlate'] ?? '').toString(),
      status: shipperStatusFromApi(json['status']?.toString()),
      currentLat: json['current_lat'] == null ? null : asDouble(json['current_lat']),
      currentLng: json['current_lng'] == null ? null : asDouble(json['current_lng']),
      lastSeenAt: json['last_seen_at']?.toString(),
      user: userJson is Map<String, dynamic> ? ShipperUser.fromJson(userJson) : null,
    );
  }
}

class DeliveryOrderItem {
  final int id;
  final int orderId;
  final String sku;
  final String name;
  final String description;
  final int quantity;
  final int deliveredQuantity;
  final double unitPrice;
  final double? weightKg;
  final String status;
  final String note;

  const DeliveryOrderItem({
    required this.id,
    required this.orderId,
    required this.sku,
    required this.name,
    required this.description,
    required this.quantity,
    required this.deliveredQuantity,
    required this.unitPrice,
    this.weightKg,
    required this.status,
    required this.note,
  });

  double get lineTotal => unitPrice * quantity;

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> json) {
    return DeliveryOrderItem(
      id: asInt(json['id']),
      orderId: asInt(json['order_id'] ?? json['orderId']),
      sku: (json['sku'] ?? '').toString(),
      name: (json['name'] ?? json['item_name'] ?? 'Item').toString(),
      description: (json['description'] ?? '').toString(),
      quantity: asInt(json['quantity'], fallback: 1),
      deliveredQuantity: asInt(json['delivered_quantity'] ?? json['deliveredQuantity']),
      unitPrice: asDouble(json['unit_price'] ?? json['unitPrice']),
      weightKg: json['weight_kg'] == null ? null : asDouble(json['weight_kg']),
      status: (json['status'] ?? 'PENDING').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class DeliveryOrder {
  final int id;
  final String orderCode;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final double codAmount;
  final double deliveryFee;
  final String status;
  final int? shipperId;
  final String proofImageUrl;
  final String deliveryNote;
  final String receiverName;
  final String failedReason;
  final bool codCollected;
  final double codCollectedAmount;
  final String paymentMethod;
  final String codSettlementStatus;
  final String? deliveredAt;
  final List<DeliveryOrderItem> items;

  const DeliveryOrder({
    required this.id,
    required this.orderCode,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    required this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    required this.codAmount,
    required this.deliveryFee,
    required this.status,
    this.shipperId,
    required this.proofImageUrl,
    required this.deliveryNote,
    required this.receiverName,
    required this.failedReason,
    required this.codCollected,
    required this.codCollectedAmount,
    required this.paymentMethod,
    required this.codSettlementStatus,
    this.deliveredAt,
    required this.items,
  });

  bool get isFinal => ['DELIVERED', 'FAILED', 'RETURNED', 'CANCELLED', 'PARTIALLY_DELIVERED'].contains(status.toUpperCase());
  bool get needsProof => proofImageUrl.isEmpty && ['DELIVERED', 'PARTIALLY_DELIVERED'].contains(status.toUpperCase());
  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);
  double get totalWeight => items.fold<double>(0, (sum, item) => sum + (item.weightKg ?? 0));
  double get codRemaining => (codAmount - codCollectedAmount).clamp(0, double.infinity).toDouble();

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] ?? []) as List<dynamic>;
    return DeliveryOrder(
      id: asInt(json['id']),
      orderCode: (json['order_code'] ?? json['orderCode'] ?? '#${json['id']}').toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? 'Customer').toString(),
      customerPhone: (json['customer_phone'] ?? json['customerPhone'] ?? '').toString(),
      pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? '').toString(),
      pickupLat: json['pickup_lat'] == null ? null : asDouble(json['pickup_lat']),
      pickupLng: json['pickup_lng'] == null ? null : asDouble(json['pickup_lng']),
      deliveryAddress: (json['delivery_address'] ?? json['deliveryAddress'] ?? '').toString(),
      deliveryLat: json['delivery_lat'] == null ? null : asDouble(json['delivery_lat']),
      deliveryLng: json['delivery_lng'] == null ? null : asDouble(json['delivery_lng']),
      codAmount: asDouble(json['cod_amount'] ?? json['codAmount']),
      deliveryFee: asDouble(json['delivery_fee'] ?? json['deliveryFee']),
      status: (json['status'] ?? 'ASSIGNED').toString(),
      shipperId: json['shipper_id'] == null ? null : asInt(json['shipper_id']),
      proofImageUrl: (json['proof_image_url'] ?? json['proofImageUrl'] ?? '').toString(),
      deliveryNote: (json['delivery_note'] ?? json['deliveryNote'] ?? '').toString(),
      receiverName: (json['receiver_name'] ?? json['receiverName'] ?? '').toString(),
      failedReason: (json['failed_reason'] ?? json['failedReason'] ?? '').toString(),
      codCollected: json['cod_collected'] == true,
      codCollectedAmount: asDouble(json['cod_collected_amount'] ?? json['codCollectedAmount']),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? '').toString(),
      codSettlementStatus: (json['cod_settlement_status'] ?? json['codSettlementStatus'] ?? 'PENDING').toString(),
      deliveredAt: json['delivered_at']?.toString(),
      items: rawItems.map((e) => DeliveryOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
