class SponsorshipModel {
  final String id;
  final String sponsorId;
  final String petId;
  final int amount;
  final String paymentMethod; // 'solana_pay' or 'solana_phantom', etc.
  final String? txHash;
  final double feePercent;
  final int feeAmount;
  final int netAmount;
  final DateTime createdAt;

  SponsorshipModel({
    required this.id,
    required this.sponsorId,
    required this.petId,
    required this.amount,
    this.paymentMethod = 'solana_pay',
    this.txHash,
    this.feePercent = 10.0,
    int? feeAmount,
    int? netAmount,
    required this.createdAt,
  })  : feeAmount = feeAmount ?? (amount * 0.10).round(),
        netAmount = netAmount ?? (amount - (amount * 0.10).round());

  factory SponsorshipModel.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] ?? 0) as int;
    final feeP = (json['fee_percent'] != null) ? (json['fee_percent'] as num).toDouble() : 10.0;
    final feeA = (json['fee_amount'] != null) ? (json['fee_amount'] as num).toInt() : (amt * (feeP / 100)).round();
    final netA = (json['net_amount'] != null) ? (json['net_amount'] as num).toInt() : (amt - feeA);

    return SponsorshipModel(
      id: json['id'] ?? '',
      sponsorId: json['sponsor_id'] ?? '',
      petId: json['pet_id'] ?? '',
      amount: amt,
      paymentMethod: json['payment_method'] ?? 'solana_pay',
      txHash: json['tx_hash'],
      feePercent: feeP,
      feeAmount: feeA,
      netAmount: netA,
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
      'fee_percent': feePercent,
      'fee_amount': feeAmount,
      'net_amount': netAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
