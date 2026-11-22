import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/app.dart';
import 'package:halisaha/core/app_mode/app_mode.dart';
import 'package:halisaha/core/router/shell_scaffold.dart';
import 'package:halisaha/core/security/secure_local_storage.dart';
import 'package:halisaha/demo/demo_overrides.dart';
import 'package:halisaha/demo/demo_store.dart';
import 'package:halisaha/features/auth/presentation/login_screen.dart';
import 'package:halisaha/features/auth/presentation/welcome_screen.dart';
import 'package:halisaha/features/owner/presentation/not_owner_screen.dart';
import 'package:halisaha/features/owner/presentation/owner_login_screen.dart';
import 'package:halisaha/features/owner/presentation/owner_shell.dart';
import 'package:halisaha/features/profile/presentation/profile_screen.dart';
import 'package:halisaha/features/venues/presentation/venues_providers.dart';

void main() {
  Future<void> launch(
    WidgetTester tester, {
    AppMode? mode,
    bool signedIn = true,
    bool ownerRole = false,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = DemoStore();
    if (ownerRole) store.setOwnerMode(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // `initialMode: owner` also flips the demo user to owner; the role is set explicitly instead
          // so a customer account in owner mode can be tested.
          ...demoOverrides(store),
          keyValueStoreProvider.overrideWithValue(
            InMemoryKeyValueStore(initial: {if (mode != null) appModeStorageKey: mode.name}),
          ),
          demoSignedInProvider.overrideWith((ref) => signedIn),
        ],
        child: const RovansApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first launch shows the role screen with both choices', (tester) async {
    await launch(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Maç yapacağım'), findsOneWidget);
    expect(find.text('Saha bul, saat seç, kaporayı öde'), findsOneWidget);
    expect(find.text('Sahamı yöneteceğim'), findsOneWidget);
    expect(find.text('Rezervasyonlar, saatler ve sahalar'), findsOneWidget);
    expect(find.text('Boş saati gör, kaporayla anında tut.'), findsOneWidget);
    expect(find.text('Seçimini daha sonra Profil\'den değiştirebilirsin.'), findsOneWidget);
  });

  testWidgets('"Maç yapacağım" with a signed-in demo user lands on the player home', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Maç yapacağım'));
    await tester.pumpAndSettle();
    expect(find.byType(ShellScaffold), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('a fresh demo start is signed out: "Maç yapacağım" asks for the phone number', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Plain demoOverrides, no test overrides: the same start as the web demo.
    await tester.pumpWidget(ProviderScope(overrides: demoOverrides(DemoStore()), child: const RovansApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maç yapacağım'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ShellScaffold), findsNothing);
  });

  testWidgets('"Maç yapacağım" when signed out lands on the phone login', (tester) async {
    await launch(tester, signedIn: false);
    await tester.tap(find.text('Maç yapacağım'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('owner demo login lands on the owner shell', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Sahamı yöneteceğim'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerLoginScreen), findsOneWidget);

    // Validators first.
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    expect(find.text('Şifreni gir.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'isletme@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'herhangi');
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerShell), findsOneWidget);
    expect(find.byTooltip('Hesap'), findsWidgets);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('owner login can fall back to the player app', (tester) async {
    await launch(tester, mode: AppMode.owner, signedIn: false);
    expect(find.byType(OwnerLoginScreen), findsOneWidget);
    await tester.ensureVisible(find.text('İşletmeci değil misin? Oyuncu olarak devam et'));
    await tester.tap(find.text('İşletmeci değil misin? Oyuncu olarak devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a customer account in owner mode sees the not-owner screen', (tester) async {
    await launch(tester, mode: AppMode.owner);
    expect(find.byType(NotOwnerScreen), findsOneWidget);
    expect(find.text('Bu hesap bir işletmeci hesabı değil.'), findsOneWidget);

    await tester.tap(find.text('Başka hesapla giriş yap'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerLoginScreen), findsOneWidget);
  });

  testWidgets('not-owner: "Oyuncu olarak devam et" signs out and opens the player login', (tester) async {
    await launch(tester, mode: AppMode.owner);
    await tester.tap(find.text('Oyuncu olarak devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('owner mode: owner account opens the shell, account sheet switches to the player app', (tester) async {
    await launch(tester, mode: AppMode.owner, ownerRole: true);
    expect(find.byType(OwnerShell), findsOneWidget);

    await tester.tap(find.byTooltip('Hesap').first);
    await tester.pumpAndSettle();
    expect(find.text('Oyuncu uygulamasına geç'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
    // OWNER_PANEL_URL is not defined in tests: the row is hidden.
    expect(find.text('Web panelini aç'), findsNothing);

    await tester.tap(find.text('Oyuncu uygulamasına geç'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Profilim: "İşletmeci girişi" confirms, signs out and opens the owner login', (tester) async {
    await launch(tester, mode: AppMode.player);
    expect(find.byType(ShellScaffold), findsOneWidget);
    await tester.tap(find.text('Profilim'));
    await tester.pumpAndSettle();
    // The old demo switch and panel row are gone.
    expect(find.text('İşletmeci paneli'), findsNothing);
    expect(find.text('İşletmeci modunu dene (demo)'), findsNothing);

    await tester.scrollUntilVisible(find.text('İşletmeci girişi'), 300, scrollable: find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('İşletmeci girişi'));
    await tester.pumpAndSettle();
    expect(find.text('İşletmeci girişine geçmek için oturumun kapatılacak.'), findsOneWidget);

    // Cancel keeps everything as it was.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byType(ShellScaffold), findsOneWidget);

    await tester.tap(find.text('İşletmeci girişi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnerLoginScreen), findsOneWidget);
  });
}
