import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/controllers/language_controller.dart';
import 'package:pawtbook/controllers/marketplace_controller.dart';
import 'package:pawtbook/controllers/oracle_controller.dart';
import 'package:pawtbook/models/bandana_product_model.dart';
import 'package:pawtbook/models/marketplace_order_model.dart';
import 'package:pawtbook/models/profile_model.dart';
import 'package:pawtbook/services/shipping_address_storage.dart';
import 'package:pawtbook/views/screens/admin_orders_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarketplaceOrderModel Tests', () {
    test('Serializes and deserializes correctly with shipping details', () {
      final now = DateTime.now();
      final order = MarketplaceOrderModel(
        id: 'ord_test_123',
        userId: 'user_456',
        userEmail: 'cliente@test.com',
        productId: 'bdn_solana',
        productName: 'Solana Cyber Bandana ⚡',
        productImage: 'https://images.unsplash.com/test.jpg',
        quantity: 2,
        paymentMethod: 'SOL',
        totalPriceUsd: 25.98,
        totalPaidFormatted: '0.180 SOL',
        recipientName: 'Carlos Mendoza',
        phoneNumber: '+525512345678',
        country: 'México',
        address: 'Av. Insurgentes Sur 123, Depto 4B',
        city: 'CDMX',
        stateProvince: 'CDMX',
        postalCode: '03100',
        deliveryNotes: 'Dejar en recepción',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      final json = order.toJson();
      expect(json['id'], 'ord_test_123');
      expect(json['recipient_name'], 'Carlos Mendoza');
      expect(json['phone_number'], '+525512345678');
      expect(json['address'], 'Av. Insurgentes Sur 123, Depto 4B');
      expect(json['postal_code'], '03100');
      expect(json['country'], 'México');
      expect(json['status'], 'pending');

      final fromJson = MarketplaceOrderModel.fromJson(json);
      expect(fromJson.id, order.id);
      expect(fromJson.recipientName, order.recipientName);
      expect(fromJson.phoneNumber, order.phoneNumber);
      expect(fromJson.address, order.address);
      expect(fromJson.isPending, isTrue);
      expect(fromJson.isShipped, isFalse);
    });

    test('copyWith updates status and shippedAt correctly', () {
      final order = MarketplaceOrderModel(
        id: 'ord_test_1',
        userId: 'user_1',
        productId: 'bdn_golden',
        productName: 'Gold Bandana',
        productImage: '',
        paymentMethod: 'POINTS',
        totalPriceUsd: 24.99,
        totalPaidFormatted: '25,000 pts',
        recipientName: 'Ana Gomez',
        phoneNumber: '555-1234',
        country: 'España',
        address: 'Calle Gran Vía 10',
        city: 'Madrid',
        stateProvince: 'Madrid',
        postalCode: '28013',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final shippedDate = DateTime(2026, 10, 8, 14, 30);
      final shipped = order.copyWith(
        status: 'shipped',
        shippedAt: shippedDate,
        trackingNumber: 'DHL987654321',
        shippingCarrier: 'DHL',
      );

      expect(shipped.isShipped, isTrue);
      expect(shipped.shippedAt, shippedDate);
      expect(shipped.trackingNumber, 'DHL987654321');
      expect(shipped.shippingCarrier, 'DHL');
    });
  });

  group('MarketplaceController Order Flow Tests', () {
    test('Placing an order adds to pending and markOrderAsShipped moves to shipped', () async {
      final controller = MarketplaceController();
      final product = BandanaProductModel(
        id: 'bdn_neon_test',
        name: 'Neon Glow Bandana',
        pricePoints: 10000,
        priceUsd: 9.99,
        imageUrl: '',
        stock: 5,
      );

      final placedOrder = await controller.placeBandanaOrder(
        product: product,
        quantity: 2,
        paymentMethod: 'SOL',
        totalPaidFormatted: '0.12 SOL',
        totalPriceUsd: 19.98,
        recipientName: 'Juan Lopez',
        phoneNumber: '+525500001111',
        country: 'México',
        address: 'Calle Sol 45',
        city: 'Monterrey',
        stateProvince: 'Nuevo León',
        postalCode: '64000',
        userId: 'usr_test_99',
      );

      expect(placedOrder, isNotNull);
      expect(controller.pendingOrders.any((o) => o.id == placedOrder!.id), isTrue);

      // Now mark as shipped with explicit date
      final shippedAt = DateTime(2026, 10, 7, 18, 0);
      final success = await controller.markOrderAsShipped(
        orderId: placedOrder!.id,
        shippedAt: shippedAt,
        trackingNumber: 'FEDEX12345',
        shippingCarrier: 'FedEx',
      );

      expect(success, isTrue);
      expect(controller.pendingOrders.any((o) => o.id == placedOrder.id), isFalse);
      expect(controller.shippedOrders.any((o) => o.id == placedOrder.id), isTrue);
      final shipped = controller.shippedOrders.firstWhere((o) => o.id == placedOrder.id);
      expect(shipped.shippedAt, shippedAt);
      expect(shipped.trackingNumber, 'FEDEX12345');
    });
  });

  group('ShippingAddressData Tests', () {
    test('isComplete validates all required fields', () {
      final incomplete = ShippingAddressData(
        recipientName: 'Carlos',
        phoneNumber: '',
        country: 'México',
        address: '',
        postalCode: '12345',
      );
      expect(incomplete.isComplete, isFalse);

      final complete = ShippingAddressData(
        recipientName: 'Carlos',
        phoneNumber: '555-999',
        country: 'México',
        address: 'Calle 1 #2',
        postalCode: '12345',
      );
      expect(complete.isComplete, isTrue);
    });
  });

  group('AdminOrdersDashboardScreen Security Guard Widget Tests', () {
    testWidgets('Non-admin user sees access denied screen', (WidgetTester tester) async {
      final auth = AuthController();
      // Regular user profile
      auth.setProfileForTesting(ProfileModel(
        id: 'usr_regular',
        walletAddress: '0x123',
        username: 'regular_user',
        email: 'regular@user.com',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => LanguageController()),
            ChangeNotifierProvider(create: (_) => MarketplaceController()),
            ChangeNotifierProvider(create: (_) => OracleController()),
          ],
          child: const MaterialApp(
            home: AdminOrdersDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Acceso Restringido al Admin'), findsOneWidget);
      expect(find.textContaining('wernesto66@gmail.com'), findsOneWidget);
    });
  });
}
