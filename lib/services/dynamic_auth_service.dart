import 'dart:math';

class DynamicAuthResult {
  final bool isSuccess;
  final String? walletAddress;
  final String? email;
  final String? jwtToken;
  final String? errorMessage;

  DynamicAuthResult({
    required this.isSuccess,
    this.walletAddress,
    this.email,
    this.jwtToken,
    this.errorMessage,
  });
}

class DynamicAuthService {
  /// Simulates Dynamic.xyz Login via Solana Mobile Wallet (Phantom / Solflare) or Email Embedded Wallet
  Future<DynamicAuthResult> authenticateWithSolanaWallet({
    String walletType = 'Phantom',
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final randomHex = List.generate(8, (_) => Random().nextInt(16).toRadixString(16)).join();
    final mockWalletAddress = 'PawSol${randomHex}WalletAddress';

    return DynamicAuthResult(
      isSuccess: true,
      walletAddress: mockWalletAddress,
      jwtToken: 'dyn_jwt_solana_$mockWalletAddress',
    );
  }

  /// Simulates Dynamic.xyz Login via Email with Embedded Solana Wallet
  Future<DynamicAuthResult> authenticateWithEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!email.contains('@')) {
      return DynamicAuthResult(
        isSuccess: false,
        errorMessage: 'Invalid email address provided',
      );
    }
    final hash = email.hashCode.abs().toRadixString(16);
    final mockEmbeddedWallet = 'PawEmb${hash}SolanaWallet';

    return DynamicAuthResult(
      isSuccess: true,
      email: email,
      walletAddress: mockEmbeddedWallet,
      jwtToken: 'dyn_jwt_email_$hash',
    );
  }
}
