import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../profile/presentation/profile_providers.dart';
import 'auth_providers.dart';

/// Shown while the profile loads after sign-in; offers retry / sign-out when it fails.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      body: SafeArea(
        child: profile.hasError && !profile.isLoading
            ? Column(
                children: [
                  Expanded(
                    child: ErrorView(
                      message: AppException.from(profile.error!).message,
                      onRetry: () => ref.invalidate(profileProvider),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text(S.signOut),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppConfig.appName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  SizedBox(height: 24),
                  SizedBox(height: 40, child: LoadingView()),
                ],
              ),
      ),
    );
  }
}
