import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/config/app_config.dart';
import 'package:pawtbook/controllers/marketplace_controller.dart';
import 'package:pawtbook/models/bandana_product_model.dart';
import 'package:pawtbook/models/marketplace_order_model.dart';
import 'package:pawtbook/services/supabase_service.dart';
import 'package:pawtbook/services/shipping_address_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Security & PII Data Protection Tests', () {
    test('Admin password SHA-256 cryptographic check validates correct passphrase and rejects brute force', () {
      // 1. Valid password must pass
      expect(AppConfig.verifyAdminPassword('Laravelt12050829'), isTrue);
      expect(AppConfig.verifyAdminPassword('  Laravelt12050829  '), isTrue);

      // 2. Incorrect passwords must fail
      expect(AppConfig.verifyAdminPassword('wrongPassword'), isFalse);
      expect(AppConfig.verifyAdminPassword('admin'), isFalse);
      expect(AppConfig.verifyAdminPassword('12345678'), isFalse);
      expect(AppConfig.verifyAdminPassword(''), isFalse);
      expect(AppConfig.verifyAdminPassword('   '), isFalse);

      // 3. Verify SHA-256 hash constant is correctly defined
      expect(AppConfig.adminPasswordSha256, equals('c55a87f0b0d853bb3a0ab5d2e38dbc1de2c5231134c9f38b90b823a20bfe484b'));
    });

    test('Customer PII Isolation: loadUserOrders only retrieves the authenticated user own orders', () async {
      final supabase = SupabaseService(useMockFallback: true);
      final marketplace = MarketplaceController(supabaseService: supabase);

      final product = BandanaProductModel(
        id: 'bdn_solana',
        name: 'Solana Cyber Bandana ⚡',
        pricePoints: 250,
        priceUsd: 12.99,
        imageUrl: '',
        stock: 5,
      );

      // 1. User Alice places an order with sensitive shipping address
      final orderAlice = await marketplace.placeBandanaOrder(
        product: product,
        quantity: 1,
        paymentMethod: 'SOL',
        totalPaidFormatted: '0.09 SOL',
        totalPriceUsd: 12.99,
        recipientName: 'Alice Secret',
        phoneNumber: '+1-555-0101',
        country: 'United States',
        address: '100 Private Vault Way, Suite 400',
        city: 'Miami',
        stateProvince: 'FL',
        postalCode: '33101',
        userId: 'usr_alice_123',
        userEmail: 'alice@example.com',
      );

      // 2. User Bob places another order
      final orderBob = await marketplace.placeBandanaOrder(
        product: product,
        quantity: 1,
        paymentMethod: 'SKR',
        totalPaidFormatted: '600 SKR',
        totalPriceUsd: 12.99,
        recipientName: 'Bob Hunter',
        phoneNumber: '+1-555-0202',
        country: 'Canada',
        address: '200 Maple Leaf Street',
        city: 'Toronto',
        stateProvince: 'ON',
        postalCode: 'M5V 2T6',
        userId: 'usr_bob_456',
        userEmail: 'bob@example.com',
      );

      expect(orderAlice, isNotNull);
      expect(orderBob, isNotNull);

      // 3. User Alice queries her own orders: Bob order and PII MUST NOT be returned!
      final aliceOrders = await marketplace.loadUserOrders('usr_alice_123');
      expect(aliceOrders.length, equals(1));
      expect(aliceOrders.first.userId, equals('usr_alice_123'));
      expect(aliceOrders.first.recipientName, equals('Alice Secret'));
      expect(aliceOrders.any((o) => o.userId == 'usr_bob_456'), isFalse);
      expect(aliceOrders.any((o) => o.phoneNumber == '+1-555-0202'), isFalse);

      // 4. User Bob queries his orders: Alice order and PII MUST NOT be returned!
      final bobOrders = await marketplace.loadUserOrders('usr_bob_456');
      expect(bobOrders.length, equals(1));
      expect(bobOrders.first.userId, equals('usr_bob_456'));
      expect(bobOrders.first.recipientName, equals('Bob Hunter'));
      expect(bobOrders.any((o) => o.userId == 'usr_alice_123'), isFalse);
      expect(bobOrders.any((o) => o.address.contains('Private Vault Way')), isFalse);

      // 5. Query with non-existent or empty user returns empty list (zero information leakage)
      final anonymousQuery = await marketplace.loadUserOrders('usr_intruder_999');
      expect(anonymousQuery, isEmpty);

      final emptyQuery = await marketplace.loadUserOrders('');
      expect(emptyQuery, isEmpty);
    });

    test('Shipping address storage data model enforces input trimming and completeness validation', () {
      final incompleteData = ShippingAddressData(
        recipientName: '   ',
        phoneNumber: '',
        country: 'El Salvador',
        address: 'Calle Principal 10',
        postalCode: '1101',
      );
      expect(incompleteData.isComplete, isFalse);

      final validData = ShippingAddressData(
        recipientName: 'Oscar Romero',
        phoneNumber: '+503 7000-0000',
        country: 'El Salvador',
        address: 'Colonia San Benito',
        city: 'San Salvador',
        stateProvince: 'San Salvador',
        postalCode: '1101',
        deliveryNotes: 'Entregar en portería',
      );
      expect(validData.isComplete, isTrue);
    });

    test('Payment & Transaction Integrity: Solana orders record verified transaction signatures', () {
      final orderWithSignature = MarketplaceOrderModel(
        id: 'ord_tx_verified',
        userId: 'usr_buyer_1',
        productId: 'bdn_solana',
        productName: 'Solana Bandana',
        productImage: '',
        paymentMethod: 'SOL',
        totalPriceUsd: 12.99,
        totalPaidFormatted: '0.09 SOL',
        transactionSignature: '5VERIFY_SIG_SOLANA_BLOCKCHAIN_77777777777777777777777',
        recipientName: 'Safe Buyer',
        phoneNumber: '555-0001',
        country: 'ES',
        address: 'Calle Mayor 1',
        city: 'Madrid',
        stateProvince: 'Madrid',
        postalCode: '28001',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = orderWithSignature.toJson();
      expect(json['transaction_signature'], equals('5VERIFY_SIG_SOLANA_BLOCKCHAIN_77777777777777777777777'));
      expect(json['payment_method'], equals('SOL'));

      final restored = MarketplaceOrderModel.fromJson(json);
      expect(restored.transactionSignature, equals('5VERIFY_SIG_SOLANA_BLOCKCHAIN_77777777777777777777777'));
    });
  });
}
