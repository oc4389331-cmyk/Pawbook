import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pawtbook/controllers/auth_controller.dart';
import 'package:pawtbook/controllers/oracle_controller.dart';
import 'package:pawtbook/controllers/language_controller.dart';
import 'package:pawtbook/controllers/marketplace_controller.dart';
import 'package:pawtbook/views/screens/marketplace_screen.dart';

void main() {
  testWidgets('MarketplaceScreen renders Search bar, Cart badge and Categories', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => OracleController()),
          ChangeNotifierProvider(create: (_) => LanguageController()),
          ChangeNotifierProvider(create: (_) => MarketplaceController()),
        ],
        child: const MaterialApp(
          home: MarketplaceScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Buscar bandanas, collares...'), findsOneWidget);
    expect(find.text('Bandanas'), findsOneWidget);
    expect(find.text('Collares'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // Cart badge
  });
}
