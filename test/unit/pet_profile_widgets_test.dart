import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/views/widgets/pet_attribute_bar.dart';
import 'package:pawtbook/views/widgets/pet_analytics_curve_card.dart';

void main() {
  testWidgets('PetAttributeBar renders icon, label, and percentage', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetAttributeBar(
            icon: Icons.directions_run_rounded,
            iconColor: Colors.orange,
            label: 'Nivel 12 Explorador',
            progress: 0.75,
            percentageText: '75%',
          ),
        ),
      ),
    );

    expect(find.text('Nivel 12 Explorador'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
  });

  testWidgets('PetAnalyticsCurveCard renders followers, popularity and score', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PetAnalyticsCurveCard(
              followersCount: 23059,
              totalScore: 340,
              popularityPercent: 94.0,
              earningsText: '\$33,900',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('23059'), findsOneWidget);
    expect(find.text('Popularidad'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('\$33,900'), findsOneWidget);
  });
}
