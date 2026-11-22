import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_mode/app_mode.dart';
import 'core/config/app_config.dart';
import 'core/security/secure_local_storage.dart';
import 'demo/demo_overrides.dart';
import 'demo/demo_store.dart';

// Web routing: go_router's default hash URL strategy is kept on purpose (no `usePathUrlStrategy()`),
// so deep links like `/Halisaha/#/venue/x` work on GitHub Pages without 404 rewrites.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  Intl.defaultLocale = 'tr_TR';

  if (AppConfig.demoMode) {
    // Backend-free preview: Supabase is never initialised or touched.
    // Web preview only: `?mode=player` / `?mode=owner` skips the role screen (store screenshots, demo links).
    final initialMode = kIsWeb ? AppMode.tryParse(Uri.base.queryParameters['mode']) : null;
    runApp(ProviderScope(overrides: demoOverrides(DemoStore(), initialMode: initialMode), child: const RovansApp()));
    return;
  }

  if (!AppConfig.isConfigured) {
    runApp(const ConfigErrorApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    // Mobile: the session (refresh token) lives in Keychain / Keystore instead of plain
    // SharedPreferences. Web keeps the SDK default (browser storage is the only option there).
    authOptions: FlutterAuthClientOptions(
      localStorage: kIsWeb ? null : SecureLocalStorage(FlutterSecureKeyValueStore()),
    ),
  );

  runApp(const ProviderScope(child: RovansApp()));
}
