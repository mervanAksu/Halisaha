import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/security/secure_local_storage.dart';
import 'package:halisaha/demo/demo_repositories.dart';
import 'package:halisaha/demo/demo_store.dart';
import 'package:halisaha/features/venues/presentation/home_screen.dart';
import 'package:halisaha/features/venues/presentation/venues_providers.dart';
import 'package:halisaha/features/venues/presentation/widgets/venue_card.dart';

/// Finds text inside the open bottom sheet only (the list underneath can show the same district names).
Finder inSheet(String text) => find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  testWidgets('picking İzmir then Bornova shows only the Bornova venue', (tester) async {
    // Tall surface so every card is built and "findsNothing" really means filtered out.
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = InMemoryKeyValueStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venuesRepositoryProvider.overrideWithValue(DemoVenuesRepository(DemoStore())),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tüm Türkiye'), findsOneWidget);
    final allCards = tester.widgetList(find.byType(VenueCard)).length;
    expect(allCards, greaterThan(1));
    expect(find.text('Bornova Gol Park'), findsOneWidget);

    // Step 1: provinces.
    await tester.tap(find.text('Tüm Türkiye'));
    await tester.pumpAndSettle();
    expect(inSheet('İl seç'), findsOneWidget);
    expect(inSheet('İzmir'), findsOneWidget);
    expect(inSheet('Aydın'), findsOneWidget);

    // Step 2: districts of İzmir.
    await tester.tap(inSheet('İzmir'));
    await tester.pumpAndSettle();
    expect(inSheet('İzmir ilçeleri'), findsOneWidget);
    expect(inSheet('Bornova'), findsOneWidget);
    expect(inSheet('1 sahayı göster'), findsOneWidget);

    await tester.tap(inSheet('Bornova'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet('1 sahayı göster'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('İzmir · Bornova'), findsOneWidget);
    expect(find.byType(VenueCard), findsOneWidget);
    expect(find.text('Bornova Gol Park'), findsOneWidget);
    expect(find.text('Mavi Çim Spor Tesisleri'), findsNothing);
    expect(find.text('Efeler Spor Sahası'), findsNothing);
    expect(await store.read(locationFilterStorageKey), contains('Bornova'));

    // Clearing from the bar goes back to the full list.
    await tester.tap(find.byTooltip('Konum filtresini temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Tüm Türkiye'), findsOneWidget);
    expect(tester.widgetList(find.byType(VenueCard)).length, allCards);
  });

  testWidgets('a saved filter is restored on start and applied to the list', (tester) async {
    final store = InMemoryKeyValueStore();
    await store.write(locationFilterStorageKey, '{"city":"Aydın","districts":[]}');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venuesRepositoryProvider.overrideWithValue(DemoVenuesRepository(DemoStore())),
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aydın'), findsOneWidget);
    expect(find.text('Efeler Spor Sahası'), findsOneWidget);
  });
}
