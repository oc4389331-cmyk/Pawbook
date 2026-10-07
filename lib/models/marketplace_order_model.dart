class MarketplaceOrderModel {
  final String id;
  final String userId;
  final String? userEmail;
  final String productId;
  final String productName;
  final String productImage;
  final int quantity;
  final String paymentMethod; // 'SOL', 'SKR', 'POINTS'
  final double totalPriceUsd;
  final String totalPaidFormatted; // e.g. "0.082 SOL", "4,500 $SKR", "15,000 pts"
  final String? transactionSignature;

  // Datos de Envío del Paquete (Shipping Details)
  final String recipientName;
  final String phoneNumber;
  final String country;
  final String address;
  final String city;
  final String stateProvince;
  final String postalCode;
  final String? deliveryNotes;

  // Estado del Pedido y Envío (Fulfillment & Tracking)
  final String status; // 'pending' | 'shipped'
  final DateTime? shippedAt; // Fecha en la que el admin envió el paquete
  final String? trackingNumber; // Guía de rastreo
  final String? shippingCarrier; // DHL, FedEx, etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  MarketplaceOrderModel({
    required this.id,
    required this.userId,
    this.userEmail,
    required this.productId,
    required this.productName,
    required this.productImage,
    this.quantity = 1,
    required this.paymentMethod,
    required this.totalPriceUsd,
    required this.totalPaidFormatted,
    this.transactionSignature,
    required this.recipientName,
    required this.phoneNumber,
    required this.country,
    required this.address,
    required this.city,
    required this.stateProvince,
    required this.postalCode,
    this.deliveryNotes,
    this.status = 'pending',
    this.shippedAt,
    this.trackingNumber,
    this.shippingCarrier,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isShipped => status.toLowerCase() == 'shipped';

  factory MarketplaceOrderModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrderModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userEmail: json['user_email']?.toString(),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      productImage: json['product_image']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      paymentMethod: json['payment_method']?.toString() ?? 'SOL',
      totalPriceUsd: (json['total_price_usd'] as num?)?.toDouble() ?? 0.0,
      totalPaidFormatted: json['total_paid_formatted']?.toString() ?? '',
      transactionSignature: json['transaction_signature']?.toString(),
      recipientName: json['recipient_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      stateProvince: json['state_province']?.toString() ?? '',
      postalCode: json['postal_code']?.toString() ?? '',
      deliveryNotes: json['delivery_notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      shippedAt: json['shipped_at'] != null ? DateTime.tryParse(json['shipped_at'].toString()) : null,
      trackingNumber: json['tracking_number']?.toString(),
      shippingCarrier: json['shipping_carrier']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'quantity': quantity,
      'payment_method': paymentMethod,
      'total_price_usd': totalPriceUsd,
      'total_paid_formatted': totalPaidFormatted,
      'transaction_signature': transactionSignature,
      'recipient_name': recipientName,
      'phone_number': phoneNumber,
      'country': country,
      'address': address,
      'city': city,
      'state_province': stateProvince,
      'postal_code': postalCode,
      'delivery_notes': deliveryNotes,
      'status': status,
      'shipped_at': shippedAt?.toIso8601String(),
      'tracking_number': trackingNumber,
      'shipping_carrier': shippingCarrier,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MarketplaceOrderModel copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? productId,
    String? productName,
    String? productImage,
    int? quantity,
    String? paymentMethod,
    double? totalPriceUsd,
    String? totalPaidFormatted,
    String? transactionSignature,
    String? recipientName,
    String? phoneNumber,
    String? country,
    String? address,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? deliveryNotes,
    String? status,
    DateTime? shippedAt,
    String? trackingNumber,
    String? shippingCarrier,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MarketplaceOrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      quantity: quantity ?? this.quantity,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      totalPriceUsd: totalPriceUsd ?? this.totalPriceUsd,
      totalPaidFormatted: totalPaidFormatted ?? this.totalPaidFormatted,
      transactionSignature: transactionSignature ?? this.transactionSignature,
      recipientName: recipientName ?? this.recipientName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      country: country ?? this.country,
      address: address ?? this.address,
      city: city ?? this.city,
      stateProvince: stateProvince ?? this.stateProvince,
      postalCode: postalCode ?? this.postalCode,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      status: status ?? this.status,
      shippedAt: shippedAt ?? this.shippedAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      shippingCarrier: shippingCarrier ?? this.shippingCarrier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
