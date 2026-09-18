import 'solana_web_bridge.dart';

class SolanaWebBridgeStub implements SolanaWebBridge {
  @override
  String? generateSolanaKeypair(String seed) => null;

  @override
  Future<Map<String, dynamic>> connectWallet(String methodName) async {
    return {'success': false, 'error': 'Not supported on this platform'};
  }

  @override
  Future<Map<String, dynamic>> sendSolanaTransaction(Map<String, dynamic> params) async {
    return {'success': false, 'error': 'Not supported on this platform'};
  }

  @override
  Future<double> getSkrBalance(String walletAddress, {bool isDevnet = false}) async {
    return 0.0;
  }

  @override
  Future<Map<String, dynamic>> getWalletBalance(String walletAddress, {bool isDevnet = false}) async {
    return {'success': true, 'sol': 0.0, 'lamports': 0};
  }
}

SolanaWebBridge getSolanaWebBridge() => SolanaWebBridgeStub();
