import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawtbook/views/widgets/live_comment_bubbles.dart';
import 'package:pawtbook/views/widgets/spinning_vinyl_disc.dart';

void main() {
  testWidgets('LiveCommentBubbles renders comment text and username', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveCommentBubbles(
            comments: [
              LiveCommentItem(
                username: 'SolanaKing',
                comment: 'Chico on Solana 👑🐾',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('@SolanaKing: '), findsOneWidget);
    expect(find.text('Chico on Solana 👑🐾'), findsOneWidget);
  });

  testWidgets('SpinningVinylDisc renders with custom size', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpinningVinylDisc(
            isPlaying: true,
            size: 36.0,
          ),
        ),
      ),
    );

    expect(find.byType(SpinningVinylDisc), findsOneWidget);
  });
}
