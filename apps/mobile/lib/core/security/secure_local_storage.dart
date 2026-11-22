import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal async key/value store. Production uses the platform keystore
/// ([FlutterSecureKeyValueStore]); tests use an in-memory fake.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Non-persistent store (demo build, tests).
class InMemoryKeyValueStore implements SecureKeyValueStore {
  InMemoryKeyValueStore({Map<String, String>? initial}) : _data = <String, String>{...?initial};

  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Keychain (iOS) / EncryptedSharedPreferences backed by Keystore (Android).
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Where supabase_flutter persists the auth session. Replaces the default SharedPreferences
/// storage so the refresh token is encrypted at rest on the device.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage(this._store, {this.persistSessionKey = defaultKey});

  /// Same key the SDK's own storage uses, so the value stays recognisable.
  static const String defaultKey = 'supabase.auth.token';

  final SecureKeyValueStore _store;
  final String persistSessionKey;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final value = await _store.read(persistSessionKey);
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _store.read(persistSessionKey);

  @override
  Future<void> removePersistedSession() => _store.delete(persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) => _store.write(persistSessionKey, persistSessionString);
}
