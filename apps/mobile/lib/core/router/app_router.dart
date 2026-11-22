import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/booking/domain/booking_draft.dart';
import '../../features/booking/domain/payment_session.dart';
import '../../features/booking/presentation/booking_summary_screen.dart';
import '../../features/booking/presentation/payment_result_screen.dart';
import '../../features/booking/presentation/payment_webview_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/matches/presentation/matches_screen.dart';
import '../../features/owner/presentation/not_owner_screen.dart';
import '../../features/owner/presentation/owner_login_screen.dart';
import '../../features/owner/presentation/owner_shell.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/profile_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/venues/presentation/home_screen.dart';
import '../../features/venues/presentation/venue_detail_screen.dart';
import '../../demo/demo_payment_screen.dart';
import '../app_mode/app_mode.dart';
import '../config/app_config.dart';
import '../l10n/strings.dart';
import '../supabase/supabase_providers.dart';
import '../widgets/empty_state.dart';
import 'app_routes.dart';
import 'redirect_policy.dart';
import 'shell_scaffold.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Lets go_router re-run `redirect` when the app mode, auth or profile state changes.
class _RouterRefresh extends ChangeNotifier {
  bool _disposed = false;

  void ping() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  // Demo: authStateProvider is overridden with an empty stream, Supabase is never touched.
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, __) => refresh.ping());
  ref.listen<AsyncValue<Profile?>>(profileProvider, (_, __) => refresh.ping());
  ref.listen<AsyncValue<AppMode?>>(appModeProvider, (_, __) => refresh.ping());
  ref.listen<String?>(currentUserIdProvider, (_, __) => refresh.ping());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) => OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.favorites, builder: (context, state) => const FavoritesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.matches, builder: (context, state) => const MatchesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.support, builder: (context, state) => const SupportScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationSettingsScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.venueDetail,
        builder: (context, state) => VenueDetailScreen(venueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.bookingSummary,
        builder: (context, state) {
          final draft = state.extra;
          if (draft is! BookingDraft) return const _MissingArgumentsScreen();
          return BookingSummaryScreen(draft: draft);
        },
      ),
      GoRoute(
        path: AppRoutes.payment,
        builder: (context, state) {
          final args = state.extra;
          if (args is! PaymentArgs) return const _MissingArgumentsScreen();
          if (AppConfig.demoMode) return DemoPaymentScreen(args: args);
          if (kIsWeb) return const _WebPaymentUnsupportedScreen();
          return PaymentWebViewScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.bookingResult,
        builder: (context, state) => PaymentResultScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.owner, builder: (context, state) => const OwnerShell()),
      GoRoute(path: AppRoutes.ownerLogin, builder: (context, state) => const OwnerLoginScreen()),
      GoRoute(path: AppRoutes.ownerNotOwner, builder: (context, state) => const NotOwnerScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Mode + auth + onboarding gate; the decision table lives in [decideRedirect].
String? _redirect(Ref ref, GoRouterState state) {
  final mode = ref.read(appModeProvider);
  final userId = ref.read(currentUserIdProvider);
  final profile = userId == null ? null : ref.read(profileProvider).valueOrNull;
  return decideRedirect(RedirectInput(
    location: state.matchedLocation,
    modeRestored: mode.hasValue,
    mode: mode.valueOrNull,
    signedIn: userId != null,
    profileLoaded: profile != null,
    needsOnboarding: profile?.needsOnboarding ?? false,
    isOwner: profile?.isOwner ?? false,
  ));
}

/// Shown when a route that needs `extra` is opened without it (e.g. after process restore).
class _MissingArgumentsScreen extends StatelessWidget {
  const _MissingArgumentsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.search_off,
        message: S.errGeneric,
        actionLabel: S.goHome,
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}

/// Real PayTR payment needs a native WebView; the web build only supports demo payments.
class _WebPaymentUnsupportedScreen extends StatelessWidget {
  const _WebPaymentUnsupportedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.securePayment)),
      body: EmptyState(
        icon: Icons.phone_iphone,
        message: S.webPaymentUnsupported,
        actionLabel: S.goHome,
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}
