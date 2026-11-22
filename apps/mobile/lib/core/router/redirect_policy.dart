import '../app_mode/app_mode.dart';
import 'app_routes.dart';

/// Everything the redirect needs, as plain values (no providers, no go_router) so the decision table
/// can be unit-tested.
class RedirectInput {
  const RedirectInput({
    required this.location,
    required this.modeRestored,
    required this.mode,
    required this.signedIn,
    this.profileLoaded = false,
    this.needsOnboarding = false,
    this.isOwner = false,
    this.mfaPending = false,
  });

  /// `state.matchedLocation`.
  final String location;

  /// False until the saved mode has been read from the device.
  final bool modeRestored;
  final AppMode? mode;
  final bool signedIn;

  /// False while the profile is loading (or failed: the splash shows the retry UI).
  final bool profileLoaded;
  final bool needsOnboarding;
  final bool isOwner;

  /// Session is aal1 but the account has a verified TOTP factor (owner mode only).
  final bool mfaPending;
}

bool isOwnerPath(String location) => location == AppRoutes.owner || location.startsWith('${AppRoutes.owner}/');

/// Redirect decision: the path to go to, or null to stay. Order:
///  1. saved mode not restored -> /splash
///  2. no mode chosen -> /welcome
///  3. player: signed out -> /login|/otp; profile loading -> /splash; onboarding; no auth screens or
///     /owner* once signed in
///  4. owner: signed out -> /owner/login; profile loading -> /splash; onboarding; MFA pending ->
///     /owner/mfa (only that route); not an owner ->
///     /owner/not-owner; owner -> only /owner
String? decideRedirect(RedirectInput i) {
  final loc = i.location;
  if (!i.modeRestored) return loc == AppRoutes.splash ? null : AppRoutes.splash;

  final mode = i.mode;
  if (mode == null) return loc == AppRoutes.welcome ? null : AppRoutes.welcome;

  return mode == AppMode.player ? _player(i) : _owner(i);
}

String? _player(RedirectInput i) {
  final loc = i.location;
  if (isOwnerPath(loc)) return AppRoutes.home;

  if (!i.signedIn) {
    return (loc == AppRoutes.login || loc == AppRoutes.otp) ? null : AppRoutes.login;
  }
  if (!i.profileLoaded) return loc == AppRoutes.splash ? null : AppRoutes.splash;
  if (i.needsOnboarding) return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;

  const authOnly = {AppRoutes.login, AppRoutes.otp, AppRoutes.onboarding, AppRoutes.splash, AppRoutes.welcome};
  if (authOnly.contains(loc)) return AppRoutes.home;
  return null;
}

String? _owner(RedirectInput i) {
  final loc = i.location;
  if (!i.signedIn) return loc == AppRoutes.ownerLogin ? null : AppRoutes.ownerLogin;
  if (!i.profileLoaded) return loc == AppRoutes.splash ? null : AppRoutes.splash;
  // KVKK applies to everyone, owners included.
  if (i.needsOnboarding) return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  if (i.mfaPending) return loc == AppRoutes.ownerMfa ? null : AppRoutes.ownerMfa;
  if (!i.isOwner) return loc == AppRoutes.ownerNotOwner ? null : AppRoutes.ownerNotOwner;

  final inPanel = isOwnerPath(loc) && loc != AppRoutes.ownerLogin && loc != AppRoutes.ownerNotOwner && loc != AppRoutes.ownerMfa;
  return inPanel ? null : AppRoutes.owner;
}
