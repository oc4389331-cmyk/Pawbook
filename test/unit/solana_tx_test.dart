import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/services/dynamic_auth_service.dart';
import 'package:pawtbook/config/app_config.dart';
import 'package:solana/solana.dart';
import 'package:solana/encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Solana MWA Transaction & Transfer Unit Tests', () {
    test('compiles native SOL transfer message correctly', () {
      final sender = Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111');
      final recipient = Ed25519HDPublicKey.fromBase58(AppConfig.marketplaceTreasuryWallet);
      final instruction = SystemInstruction.transfer(
        fundingAccount: sender,
        recipientAccount: recipient,
        lamports: 1000000,
      );
      final message = Message(instructions: [instruction]);
      final compiled = message.compile(
        recentBlockhash: '4sR4rP7k47r8rX4X4X4X4X4X4X4X4X4X4X4X4X4X4X4X',
        feePayer: sender,
      );
      final dummySignature = Signature(List.filled(64, 0), publicKey: sender);
      final signedTx = SignedTx(compiledMessage: compiled, signatures: [dummySignature]);
      final bytes = signedTx.toByteArray();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('compiles SKR SPL token transferChecked message correctly', () async {
      final sender = Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111');
      final recipient = Ed25519HDPublicKey.fromBase58(AppConfig.marketplaceTreasuryWallet);
      final mint = Ed25519HDPublicKey.fromBase58(AppConfig.skrTokenMintAddress);

      final sourceAta = await findAssociatedTokenAddress(owner: sender, mint: mint);
      final destAta = await findAssociatedTokenAddress(owner: recipient, mint: mint);

      final instructions = <Instruction>[
        AssociatedTokenAccountInstruction.createAccount(
          funder: sender,
          address: destAta,
          owner: recipient,
          mint: mint,
        ),
        TokenInstruction.transferChecked(
          source: sourceAta,
          destination: destAta,
          owner: sender,
          amount: 1000000,
          decimals: 6,
          mint: mint,
        ),
      ];

      final message = Message(instructions: instructions);
      final compiled = message.compile(
        recentBlockhash: '4sR4rP7k47r8rX4X4X4X4X4X4X4X4X4X4X4X4X4X4X4X',
        feePayer: sender,
      );
      final dummySignature = Signature(List.filled(64, 0), publicKey: sender);
      final signedTx = SignedTx(compiledMessage: compiled, signatures: [dummySignature]);
      final bytes = signedTx.toByteArray();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('sendWalletTransfer succeeds in test environment without deserialization crash', () async {
      final service = DynamicAuthService();
      final result = await service.sendWalletTransfer(
        walletType: 'Seeker',
        recipientAddress: AppConfig.marketplaceTreasuryWallet,
        tokenType: 'SKR',
        skrAmount: 50.0,
      );
      expect(result.isSuccess, isTrue);
      expect(result.signature, isNotNull);
      expect(result.solscanUrl, contains('solscan.io'));
    });
  });
}
