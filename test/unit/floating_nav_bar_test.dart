import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/views/widgets/floating_bottom_nav_bar.dart';

void main() {
  group('FloatingBottomNavBar Widget Tests', () {
    testWidgets('renders all navigation items and center paw button', (WidgetTester tester) async {
      int tappedIndex = -1;
      bool pawPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FloatingBottomNavBar(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
              onPawPressed: () => pawPressed = true,
              notificationCount: 3,
            ),
          ),
        ),
      );

      // Verify labels
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('Premios'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);

      // Verify badge count
      expect(find.text('3'), findsOneWidget);

      // Verify center paw button icon
      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);

      // Tap on 'Explorar' (index 1)
      await tester.tap(find.text('Explorar'));
      expect(tappedIndex, equals(1));

      // Tap on center paw button
      await tester.tap(find.byIcon(Icons.pets_rounded));
      expect(pawPressed, isTrue);
    });
  });
}
