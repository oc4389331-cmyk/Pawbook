import 'solana_web_bridge_stub.dart'
    if (dart.library.html) 'solana_web_bridge_web.dart';

abstract class SolanaWebBridge {
  static final SolanaWebBridge instance = getSolanaWebBridge();

  String? generateSolanaKeypair(String seed);
  Future<Map<String, dynamic>> connectWallet(String methodName);
  Future<Map<String, dynamic>> sendSolanaTransaction(Map<String, dynamic> params);
  Future<double> getSkrBalance(String walletAddress, {bool isDevnet = false});
  Future<Map<String, dynamic>> getWalletBalance(String walletAddress, {bool isDevnet = false});
}
