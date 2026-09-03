import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/controllers/feed_controller.dart';
import 'package:pawtbook/controllers/pet_controller.dart';
import 'package:pawtbook/views/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders auth UI correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => FeedController()),
          ChangeNotifierProvider(create: (_) => PetController()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Pawtbook'), findsOneWidget);
    expect(find.text('Conectar Wallet (Solana)'), findsOneWidget);
  });
}
