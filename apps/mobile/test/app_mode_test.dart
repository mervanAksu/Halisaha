import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/app_mode/app_mode.dart';
import 'package:halisaha/core/security/secure_local_storage.dart';
import 'package:halisaha/features/venues/presentation/venues_providers.dart';

/// A keystore that never answers.
class _HangingStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) => Completer<String?>().future;

  @override
  Future<void> write(String key, String value) => Completer<void>().future;

  @override
  Future<void> delete(String key) => Completer<void>().future;
}

ProviderContainer containerWith(SecureKeyValueStore store) {
  final c = ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('parses only known mode names', () {
    expect(AppMode.tryParse('player'), AppMode.player);
    expect(AppMode.tryParse('owner'), AppMode.owner);
    expect(AppMode.tryParse('admin'), isNull);
    expect(AppMode.tryParse(null), isNull);
  });

  test('nothing saved restores to null (not chosen)', () async {
    final c = containerWith(InMemoryKeyValueStore());
    expect(await c.read(appModeProvider.future), isNull);
    expect(c.read(appModeProvider).hasValue, isTrue);
  });

  test('set persists under app_mode_v1 and a new container restores it', () async {
    final store = InMemoryKeyValueStore();
    final first = containerWith(store);
    await first.read(appModeProvider.future);
    await first.read(appModeProvider.notifier).set(AppMode.owner);
    expect(first.read(appModeProvider).valueOrNull, AppMode.owner);
    expect(await store.read('app_mode_v1'), 'owner');

    final second = containerWith(store);
    expect(await second.read(appModeProvider.future), AppMode.owner);

    await second.read(appModeProvider.notifier).set(AppMode.player);
    expect(await store.read(appModeStorageKey), 'player');
    expect(await containerWith(store).read(appModeProvider.future), AppMode.player);
  });

  test('an unknown saved value is treated as not chosen', () async {
    final c = containerWith(InMemoryKeyValueStore(initial: {appModeStorageKey: 'banana'}));
    expect(await c.read(appModeProvider.future), isNull);
  });

  testWidgets('a hanging keystore falls back to null after the timeout', (tester) async {
    final c = containerWith(_HangingStore());
    final sub = c.listen(appModeProvider, (_, __) {});
    addTearDown(sub.close);
    expect(c.read(appModeProvider).isLoading, isTrue);
    await tester.pump(const Duration(seconds: 3));
    final value = c.read(appModeProvider);
    expect(value.hasValue, isTrue);
    expect(value.valueOrNull, isNull);
  });
}
