import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/controllers/oracle_controller.dart';
import 'package:pawtbook/models/pet_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Verified Badge & Dynamic Oracle Tests', () {
    test('OracleController calculates SOL price and converts USD to SOL and SKR correctly', () {
      final oracle = OracleController();

      // Default rates: priceUsd = 0.0215, priceSol = 0.00014
      // solUsdPrice = 0.0215 / 0.00014 = ~153.57 USD per SOL
      expect(oracle.solUsdPrice, greaterThan(150.0));
      expect(oracle.solUsdPrice, lessThan(160.0));

      // $10 USD to SOL conversion: 10.0 / ~153.57 = ~0.0651 SOL
      final solAmountForTenUsd = oracle.convertUsdToSol(10.0);
      expect(solAmountForTenUsd, greaterThan(0.06));
      expect(solAmountForTenUsd, lessThan(0.07));

      // $10 USD to SKR conversion: 10.0 / 0.0215 = ~465.11 SKR
      final skrAmountForTenUsd = oracle.convertUsdToSkr(10.0);
      expect(skrAmountForTenUsd, greaterThan(460.0));
      expect(skrAmountForTenUsd, lessThan(470.0));

      // Verify formatted SOL price is valid
      expect(oracle.formattedSolPriceUsd.startsWith('\$'), isTrue);
    });

    test('PetModel.isVerified detects verification prefixes and mint certificates', () {
      final unverifiedPet = PetModel(
        id: 'pet_chico',
        ownerId: 'usr_owner_1',
        name: 'Chico',
        bio: 'Mi perrito',
        avatarUrl: 'https://example.com/chico.jpg',
        nftMintAddress: null,
        createdAt: DateTime.now(),
      );
      expect(unverifiedPet.isVerified, isFalse);

      final mockMintPet = unverifiedPet.copyWith(
        nftMintAddress: 'SolMint_1720000000_pet_chico',
      );
      expect(mockMintPet.isVerified, isFalse);

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final recentVerifiedPet = unverifiedPet.copyWith(
        nftMintAddress: 'SolVerified_${nowMs}_pet_chico',
      );
      expect(recentVerifiedPet.isVerified, isTrue);
      expect(recentVerifiedPet.isVerificationExpired, isFalse);
      expect(recentVerifiedPet.verificationDaysRemaining, greaterThanOrEqualTo(39));

      final standardVerifiedPet = unverifiedPet.copyWith(
        nftMintAddress: 'Verified_${nowMs}_chico_badge',
      );
      expect(standardVerifiedPet.isVerified, isTrue);

      final realSolanaNftPet = unverifiedPet.copyWith(
        nftMintAddress: '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU', // 44-char base58 Solana mint
      );
      expect(realSolanaNftPet.isVerified, isTrue);
    });

    test('PetModel 40-day expiration deactivates verified badge when older than 40 days', () {
      final unverifiedPet = PetModel(
        id: 'pet_chico',
        ownerId: 'usr_owner_1',
        name: 'Chico',
        bio: 'Mi perrito',
        avatarUrl: 'https://example.com/chico.jpg',
        nftMintAddress: null,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      );

      // Verified 41 days ago -> EXPIRED!
      final expiredMs = DateTime.now().subtract(const Duration(days: 41)).millisecondsSinceEpoch;
      final expiredPet = unverifiedPet.copyWith(
        nftMintAddress: 'SolVerified_${expiredMs}_pet_chico',
      );
      expect(expiredPet.isVerifiedBase, isTrue);
      expect(expiredPet.isVerificationExpired, isTrue);
      expect(expiredPet.isVerified, isFalse); // Deactivated automatically!
      expect(expiredPet.verificationDaysRemaining, equals(0));

      // Verified 15 days ago -> ACTIVE with ~25 days remaining
      final activeMs = DateTime.now().subtract(const Duration(days: 15)).millisecondsSinceEpoch;
      final activePet = unverifiedPet.copyWith(
        nftMintAddress: 'SolVerified_${activeMs}_pet_chico',
      );
      expect(activePet.isVerifiedBase, isTrue);
      expect(activePet.isVerificationExpired, isFalse);
      expect(activePet.isVerified, isTrue);
      expect(activePet.verificationDaysRemaining, inInclusiveRange(24, 25));

      // Renewing (new timestamp) -> ACTIVE again for 40 days
      final renewedMs = DateTime.now().millisecondsSinceEpoch;
      final renewedPet = expiredPet.copyWith(
        nftMintAddress: 'SolVerified_${renewedMs}_pet_chico',
      );
      expect(renewedPet.isVerificationExpired, isFalse);
      expect(renewedPet.isVerified, isTrue);
      expect(renewedPet.verificationDaysRemaining, greaterThanOrEqualTo(39));
    });
  });
}
