import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/security/secure_local_storage.dart';
import 'package:halisaha/demo/demo_repositories.dart';
import 'package:halisaha/demo/demo_store.dart';
import 'package:halisaha/features/venues/presentation/home_screen.dart';
import 'package:halisaha/features/venues/presentation/venues_providers.dart';

void main() {
  testWidgets('picking İzmir then Bornova shows only the Bornova venue', (tester) async {
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
    expect(find.text('Bornova Gol Park'), findsNothing);

    // Step 1: provinces.
    await tester.tap(find.text('Tüm Türkiye'));
    await tester.pumpAndSettle();
    expect(find.text('İl seç'), findsOneWidget);
    expect(find.text('İzmir'), findsOneWidget);
    expect(find.text('Aydın'), findsOneWidget);

    // Step 2: districts of İzmir.
    await tester.tap(find.text('İzmir'));
    await tester.pumpAndSettle();
    expect(find.text('İzmir ilçeleri'), findsOneWidget);
    expect(find.text('Bornova'), findsOneWidget);
    expect(find.text('1 sahayı göster'), findsOneWidget);

    await tester.tap(find.text('Bornova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 sahayı göster'));
    await tester.pumpAndSettle();

    expect(find.text('İzmir · Bornova'), findsOneWidget);
    expect(find.text('Bornova Gol Park'), findsOneWidget);
    expect(find.text('Mavi Çim Spor Tesisleri'), findsNothing);
    expect(find.text('Efeler Spor Sahası'), findsNothing);
    expect(await store.read(locationFilterStorageKey), contains('Bornova'));

    // Clearing from the bar goes back to the full list.
    await tester.tap(find.byTooltip('Konum filtresini temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Tüm Türkiye'), findsOneWidget);
    expect(find.text('Bornova Gol Park'), findsNothing);
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
