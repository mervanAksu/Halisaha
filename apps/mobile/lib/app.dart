import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/demo_banner.dart';

const Locale appLocale = Locale('tr', 'TR');

const List<LocalizationsDelegate<dynamic>> _delegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class RovansApp extends ConsumerWidget {
  const RovansApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: appLocale,
      supportedLocales: const [appLocale],
      localizationsDelegates: _delegates,
      builder: AppConfig.demoMode ? (context, child) => DemoBannerFrame(child: child) : null,
    );
  }
}

/// Shown instead of crashing when the app was started without `--dart-define-from-file`.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: appLocale,
      supportedLocales: const [appLocale],
      localizationsDelegates: _delegates,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(S.configMissing, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
