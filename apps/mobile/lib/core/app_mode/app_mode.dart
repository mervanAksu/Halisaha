import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/venues/presentation/venues_providers.dart' show keyValueStoreProvider;

/// Which audience this install serves (ADR-12). Only decides which screens are shown; authority is
/// server-side (RLS / RPC checks), so choosing [owner] grants nothing.
enum AppMode {
  player,
  owner;

  /// `null` for anything that is not a known mode name.
  static AppMode? tryParse(String? raw) {
    for (final mode in AppMode.values) {
      if (mode.name == raw) return mode;
    }
    return null;
  }
}

/// Storage key of the chosen [AppMode].
const String appModeStorageKey = 'app_mode_v1';

/// How long a hanging keystore may block the start before we fall back to "not chosen".
const Duration appModeRestoreTimeout = Duration(seconds: 2);

/// Chosen mode. The value is `null` when the user has not chosen yet; while the saved value is still
/// being restored the provider is loading, and the router keeps the splash on screen.
class AppModeNotifier extends AsyncNotifier<AppMode?> {
  bool _touched = false;
  AppMode? _chosen;

  @override
  Future<AppMode?> build() async {
    AppMode? restored;
    try {
      final raw = await ref.read(keyValueStoreProvider).read(appModeStorageKey).timeout(appModeRestoreTimeout);
      restored = AppMode.tryParse(raw);
    } catch (_) {
      // Unreadable or hanging keystore: behave as "not chosen yet".
    }
    // A choice made while the restore was still running wins over the saved value.
    return _touched ? _chosen : restored;
  }

  /// Sets and persists the mode (persistence is best-effort).
  Future<void> set(AppMode mode) async {
    _touched = true;
    _chosen = mode;
    state = AsyncData<AppMode?>(mode);
    try {
      await ref.read(keyValueStoreProvider).write(appModeStorageKey, mode.name).timeout(appModeRestoreTimeout);
    } catch (_) {}
  }
}

final appModeProvider = AsyncNotifierProvider<AppModeNotifier, AppMode?>(AppModeNotifier.new);
