class WithdrawalModel {
  final String id;
  final String petId;
  final String userId;
  final int amountSkr;
  final double amountSol;
  final double amountUsd;
  final String destinationWallet;
  final String? txHash;
  final String status; // 'completed', 'pending_audit'
  final List<String> sponsorshipIds;
  final DateTime createdAt;

  WithdrawalModel({
    required this.id,
    required this.petId,
    required this.userId,
    required this.amountSkr,
    this.amountSol = 0.0,
    this.amountUsd = 0.0,
    required this.destinationWallet,
    this.txHash,
    this.status = 'completed',
    this.sponsorshipIds = const [],
    required this.createdAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalModel(
      id: json['id'] ?? '',
      petId: json['pet_id'] ?? '',
      userId: json['user_id'] ?? '',
      amountSkr: (json['amount_skr'] ?? 0) as int,
      amountSol: (json['amount_sol'] is num) ? (json['amount_sol'] as num).toDouble() : 0.0,
      amountUsd: (json['amount_usd'] is num) ? (json['amount_usd'] as num).toDouble() : 0.0,
      destinationWallet: json['destination_wallet'] ?? '',
      txHash: json['tx_hash'],
      status: json['status'] ?? 'completed',
      sponsorshipIds: json['sponsorship_ids'] != null
          ? List<String>.from(json['sponsorship_ids'])
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'user_id': userId,
      'amount_skr': amountSkr,
      'amount_sol': amountSol,
      'amount_usd': amountUsd,
      'destination_wallet': destinationWallet,
      'tx_hash': txHash,
      'status': status,
      'sponsorship_ids': sponsorshipIds,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
