import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/security/secure_local_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSecureStore implements SecureKeyValueStore {
  final Map<String, String> data = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async => data.remove(key);
}

void main() {
  late FakeSecureStore store;
  late SecureLocalStorage storage;

  setUp(() {
    store = FakeSecureStore();
    storage = SecureLocalStorage(store);
  });

  test('is a supabase LocalStorage', () {
    expect(storage, isA<LocalStorage>());
  });

  test('starts empty', () async {
    await storage.initialize();
    expect(await storage.hasAccessToken(), isFalse);
    expect(await storage.accessToken(), isNull);
  });

  test('persists and reads back the session string', () async {
    const session = '{"access_token":"a","refresh_token":"r"}';
    await storage.persistSession(session);
    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), session);
    expect(store.data[SecureLocalStorage.defaultKey], session);
  });

  test('overwrites the previous session', () async {
    await storage.persistSession('one');
    await storage.persistSession('two');
    expect(await storage.accessToken(), 'two');
    expect(store.writes, 2);
  });

  test('removePersistedSession clears it', () async {
    await storage.persistSession('x');
    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
    expect(await storage.accessToken(), isNull);
    expect(store.data, isEmpty);
  });

  test('an empty stored value does not count as a session', () async {
    store.data[SecureLocalStorage.defaultKey] = '';
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('a custom key isolates storages', () async {
    final other = SecureLocalStorage(store, persistSessionKey: 'other.key');
    await storage.persistSession('a');
    expect(await other.hasAccessToken(), isFalse);
    await other.persistSession('b');
    expect(await storage.accessToken(), 'a');
    expect(await other.accessToken(), 'b');
  });
}
