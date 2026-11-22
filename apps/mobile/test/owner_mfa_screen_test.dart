import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/errors/app_exception.dart';
import 'package:halisaha/core/l10n/strings.dart';
import 'package:halisaha/features/auth/data/auth_repository.dart';
import 'package:halisaha/features/auth/presentation/auth_providers.dart';
import 'package:halisaha/features/owner/presentation/owner_mfa_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.pending = true});

  bool pending;
  final List<String> attempts = [];

  @override
  Future<AuthLevel> assuranceLevel() async => pending
      ? const AuthLevel(current: AssuranceLevel.aal1, next: AssuranceLevel.aal2)
      : const AuthLevel.satisfied();

  @override
  Future<void> verifyTotp(String code) async {
    attempts.add(code);
    if (code != '123456') throw const AppException('mfa_invalid', S.mfaInvalidCode);
    pending = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('wrong code shows the error, right code verifies', (tester) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        // The real provider watches Supabase; the screen only invalidates it.
        mfaPendingProvider.overrideWith((ref) async => (await repo.assuranceLevel()).mfaPending),
      ],
      child: const MaterialApp(home: OwnerMfaScreen()),
    ));

    expect(find.text(S.mfaTitle), findsOneWidget);
    expect(find.text(S.mfaSubtitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text(S.mfaSubmit));
    await tester.pumpAndSettle();
    expect(find.text(S.mfaInvalidCode), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text(S.mfaSubmit));
    await tester.pumpAndSettle();
    expect(find.text(S.mfaInvalidCode), findsNothing);
    expect(repo.attempts, ['000000', '123456']);
    expect(repo.pending, isFalse);
  });

  testWidgets('short code is rejected without calling the repository', (tester) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: OwnerMfaScreen()),
    ));
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text(S.mfaSubmit));
    await tester.pump();
    expect(find.text(S.mfaCodeIncomplete), findsOneWidget);
    expect(repo.attempts, isEmpty);
  });
}
