import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows icon, message and a working action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.sports_soccer,
            message: 'Yaklaşan maçın yok.',
            actionLabel: 'Saha ara',
            onAction: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
    expect(find.text('Yaklaşan maçın yok.'), findsOneWidget);
    expect(find.text('Saha ara'), findsOneWidget);

    await tester.tap(find.text('Saha ara'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('EmptyState without action renders no button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.favorite_border, message: 'Boş'),
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Boş'), findsOneWidget);
  });
}
