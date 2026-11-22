import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/security/secure_local_storage.dart';
import 'package:halisaha/core/utils/turkish.dart';
import 'package:halisaha/demo/demo_repositories.dart';
import 'package:halisaha/demo/demo_store.dart';
import 'package:halisaha/features/venues/domain/location_filter.dart';
import 'package:halisaha/features/venues/domain/venue_location.dart';
import 'package:halisaha/features/venues/presentation/venues_providers.dart';

void main() {
  group('LocationFilter.label', () {
    test('nothing selected', () => expect(LocationFilter.none.label, 'Tüm Türkiye'));
    test('city only', () => expect(const LocationFilter(city: 'İstanbul').label, 'İstanbul'));
    test('one district', () {
      expect(const LocationFilter(city: 'İstanbul', districts: {'Kadıköy'}).label, 'İstanbul · Kadıköy');
    });
    test('several districts', () {
      expect(const LocationFilter(city: 'İstanbul', districts: {'Kadıköy', 'Ataşehir', 'Esenyurt'}).label, 'İstanbul · 3 ilçe');
    });
    test('isActive and equality ignore set order', () {
      expect(LocationFilter.none.isActive, isFalse);
      expect(const LocationFilter(city: 'İzmir').isActive, isTrue);
      expect(const LocationFilter(city: 'İstanbul', districts: {'a', 'b'}), const LocationFilter(city: 'İstanbul', districts: {'b', 'a'}));
    });
  });

  group('LocationFilter JSON', () {
    test('round trip', () {
      const filter = LocationFilter(city: 'İzmir', districts: {'Bornova', 'Karşıyaka'});
      expect(LocationFilter.fromJsonString(filter.toJsonString()), filter);
    });
    test('garbage falls back to none', () {
      expect(LocationFilter.fromJsonString(null), LocationFilter.none);
      expect(LocationFilter.fromJsonString('{not json'), LocationFilter.none);
      expect(LocationFilter.fromJsonString('[1,2]'), LocationFilter.none);
      expect(LocationFilter.fromJsonString('{"city":5}'), LocationFilter.none);
    });
  });

  group('compareTr', () {
    test('follows the Turkish alphabet', () {
      expect(compareTr('Çanakkale', 'Bursa'), greaterThan(0));
      expect(compareTr('Çanakkale', 'Denizli'), lessThan(0));
      expect(compareTr('Iğdır', 'İzmir'), lessThan(0));
      expect(compareTr('Çorum', 'Cizre'), greaterThan(0));
      expect(compareTr('Şanlıurfa', 'Samsun'), greaterThan(0));
      expect(compareTr('Şanlıurfa', 'Tokat'), lessThan(0));
      expect(compareTr('Ordu', 'Ödemiş'), lessThan(0));
      expect(compareTr('Aydın', 'Aydın'), 0);
      expect(compareTr('Ana', 'Anadolu'), lessThan(0));
    });

    test('sorts a province list', () {
      final list = ['İzmir', 'Zonguldak', 'Çanakkale', 'Iğdır', 'Bursa', 'Denizli', 'Şanlıurfa', 'Sivas', 'Aydın']
        ..sort(compareTr);
      expect(list, ['Aydın', 'Bursa', 'Çanakkale', 'Denizli', 'Iğdır', 'İzmir', 'Sivas', 'Şanlıurfa', 'Zonguldak']);
    });
  });

  group('location option helpers', () {
    const locations = [
      VenueLocation(city: 'İzmir', district: 'Bornova', venueCount: 2),
      VenueLocation(city: 'İzmir', district: 'Çiğli', venueCount: 1),
      VenueLocation(city: 'Aydın', district: 'Efeler', venueCount: 4),
      VenueLocation(city: 'İstanbul', district: 'Kadıköy', venueCount: 1),
    ];

    test('cities are unique, summed and Turkish sorted', () {
      final cities = cityOptions(locations);
      expect(cities.map((c) => c.city), ['Aydın', 'İstanbul', 'İzmir']);
      expect(cities.last.venueCount, 3);
    });

    test('districts of a city', () {
      expect(districtOptions(locations, 'İzmir').map((d) => d.district), ['Bornova', 'Çiğli']);
    });

    test('fromJson', () {
      final l = VenueLocation.fromJson({'city': 'İzmir', 'district': 'Bornova', 'venue_count': 3});
      expect((l.city, l.district, l.venueCount), ('İzmir', 'Bornova', 3));
    });
  });

  group('DemoVenuesRepository location filtering', () {
    late DemoVenuesRepository repo;
    setUp(() => repo = DemoVenuesRepository(DemoStore()));

    test('derives locations from demo venues', () async {
      final locations = await repo.listVenueLocations();
      expect(cityOptions(locations).map((c) => c.city), ['Aydın', 'İstanbul', 'İzmir']);
      expect(locations.where((l) => l.city == 'İzmir').single.district, 'Bornova');
      expect(locations.firstWhere((l) => l.district == 'Büyükçekmece').venueCount, 2);
    });

    test('filters by city', () async {
      final izmir = await repo.listVenues(city: 'İzmir');
      expect(izmir.map((v) => v.name), ['Bornova Gol Park']);
      final istanbul = await repo.listVenues(city: 'İstanbul');
      expect(istanbul, hasLength(6));
      expect(istanbul.every((v) => v.city == 'İstanbul'), isTrue);
    });

    test('filters by several districts', () async {
      final list = await repo.listVenues(city: 'İstanbul', districts: ['Kadıköy', 'Büyükçekmece']);
      expect(list.map((v) => v.district).toSet(), {'Kadıköy', 'Büyükçekmece'});
      expect(list, hasLength(3));
    });

    test('districts of another city do not match', () async {
      expect(await repo.listVenues(city: 'Aydın', districts: ['Kadıköy']), isEmpty);
    });

    test('search combines with the filter', () async {
      expect(await repo.listVenues(city: 'İstanbul', search: 'bornova'), isEmpty);
      expect((await repo.listVenues(city: 'İzmir', search: 'bornova')), hasLength(1));
    });
  });

  group('location filter persistence', () {
    late InMemoryKeyValueStore store;
    late DemoVenuesRepository repo;

    setUp(() {
      store = InMemoryKeyValueStore();
      repo = DemoVenuesRepository(DemoStore());
    });

    ProviderContainer make() {
      final container = ProviderContainer(overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        venuesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    Future<LocationFilter> start(ProviderContainer c) async {
      c.read(locationFilterProvider);
      await c.read(locationFilterProvider.notifier).ready;
      return c.read(locationFilterProvider);
    }

    test('saves and restores', () async {
      final first = make();
      expect(await start(first), LocationFilter.none);
      await first.read(locationFilterProvider.notifier).apply(city: 'İzmir', districts: {'Bornova'});
      expect(await store.read(locationFilterStorageKey), isNotNull);

      final second = make();
      expect(await start(second), const LocationFilter(city: 'İzmir', districts: {'Bornova'}));
    });

    test('clear removes the saved value', () async {
      final c = make();
      await start(c);
      await c.read(locationFilterProvider.notifier).apply(city: 'Aydın');
      await c.read(locationFilterProvider.notifier).clear();
      expect(c.read(locationFilterProvider), LocationFilter.none);
      expect(await store.read(locationFilterStorageKey), isNull);
    });

    test('unknown saved city falls back to all', () async {
      await store.write(locationFilterStorageKey, const LocationFilter(city: 'Ankara').toJsonString());
      expect(await start(make()), LocationFilter.none);
      expect(await store.read(locationFilterStorageKey), isNull);
    });

    test('unknown saved districts are dropped', () async {
      await store.write(
        locationFilterStorageKey,
        const LocationFilter(city: 'İzmir', districts: {'Bornova', 'Yokilce'}).toJsonString(),
      );
      expect(await start(make()), const LocationFilter(city: 'İzmir', districts: {'Bornova'}));
    });
  });
}
