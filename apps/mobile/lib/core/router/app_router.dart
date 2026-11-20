import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/booking/domain/booking_draft.dart';
import '../../features/booking/domain/payment_session.dart';
import '../../features/booking/presentation/booking_summary_screen.dart';
import '../../features/booking/presentation/payment_result_screen.dart';
import '../../features/booking/presentation/payment_webview_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/matches/presentation/matches_screen.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/profile_providers.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/venues/presentation/home_screen.dart';
import '../../features/venues/presentation/venue_detail_screen.dart';
import '../l10n/strings.dart';
import '../supabase/supabase_providers.dart';
import '../widgets/empty_state.dart';
import 'app_routes.dart';
import 'shell_scaffold.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Lets go_router re-run `redirect` when auth or profile state changes.
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
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, __) => refresh.ping());
  ref.listen<AsyncValue<Profile?>>(profileProvider, (_, __) => refresh.ping());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
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
          return PaymentWebViewScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.bookingResult,
        builder: (context, state) => PaymentResultScreen(bookingId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Auth + onboarding gate.
///  * signed out            -> /login (or /otp)
///  * profile still loading -> /splash
///  * name empty or KVKK not acknowledged -> /onboarding
///  * otherwise             -> never stay on the auth screens
String? _redirect(Ref ref, GoRouterState state) {
  final loc = state.matchedLocation;
  final user = ref.read(supabaseClientProvider).auth.currentUser;

  if (user == null) {
    return (loc == AppRoutes.login || loc == AppRoutes.otp) ? null : AppRoutes.login;
  }

  final profileAsync = ref.read(profileProvider);
  final profile = profileAsync.valueOrNull;
  if (profile == null) {
    // Loading the profile (or it failed: the splash screen shows the retry UI).
    return loc == AppRoutes.splash ? null : AppRoutes.splash;
  }

  if (profile.needsOnboarding) {
    return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  }

  const authOnly = {AppRoutes.login, AppRoutes.otp, AppRoutes.onboarding, AppRoutes.splash};
  return authOnly.contains(loc) ? AppRoutes.home : null;
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
