class SponsorshipModel {
  final String id;
  final String sponsorId;
  final String petId;
  final int amount;
  final String paymentMethod; // 'stripe' or 'solana_pay'
  final String? txHash;
  final DateTime createdAt;

  SponsorshipModel({
    required this.id,
    required this.sponsorId,
    required this.petId,
    required this.amount,
    this.paymentMethod = 'stripe',
    this.txHash,
    required this.createdAt,
  });

  factory SponsorshipModel.fromJson(Map<String, dynamic> json) {
    return SponsorshipModel(
      id: json['id'] ?? '',
      sponsorId: json['sponsor_id'] ?? '',
      petId: json['pet_id'] ?? '',
      amount: (json['amount'] ?? 0) as int,
      paymentMethod: json['payment_method'] ?? 'stripe',
      txHash: json['tx_hash'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sponsor_id': sponsorId,
      'pet_id': petId,
      'amount': amount,
      'payment_method': paymentMethod,
      'tx_hash': txHash,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
