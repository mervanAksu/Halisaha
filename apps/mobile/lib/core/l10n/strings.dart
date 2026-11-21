import '../../features/booking/domain/booking.dart';
import '../../features/venues/domain/slot_groups.dart';

/// All user-facing text (Turkish). Code, identifiers and commit messages stay English.
abstract final class S {
  // --- Generic ---------------------------------------------------------------
  static const String retry = 'Tekrar dene';
  static const String save = 'Kaydet';
  static const String close = 'Kapat';
  static const String clear = 'Temizle';
  static const String refresh = 'Yenile';
  static const String continueLabel = 'Devam et';
  static const String goHome = 'Ana sayfaya dön';
  static const String goToMatches = "Maçlarım'a git";
  static const String searchVenue = 'Saha ara';
  static const String linkOpenFailed = 'Bağlantı açılamadı.';
  static const String openSettings = 'Ayarları aç';
  static const String today = 'Bugün';
  static const String lastNight = 'Dün gece';
  static const String yesterday = 'Dün';
  static const String date = 'Tarih';
  static const String time = 'Saat';
  static const String pitch = 'Saha';
  static const String configMissing =
      'Uygulama yapılandırması eksik. Uygulamayı --dart-define-from-file=env/local.json ile başlat.';

  // --- Navigation ------------------------------------------------------------
  static const String navFavorites = 'Favorilerim';
  static const String navMatches = 'Maçlarım';
  static const String navDiscover = 'Keşfet';
  static const String navSupport = 'Destek';
  static const String navProfile = 'Profilim';

  // --- Errors (docs/API_CONTRACT.md "Hata kodları") ----------------------------
  static const String errNotAuthenticated = 'Devam etmek için giriş yapmalısın.';
  static const String errPitchNotFound = 'Bu saha artık rezervasyona açık değil.';
  static const String errSlotInPast = 'Bu saat geçti veya çok yakın, başka bir saat seç.';
  static const String errTooFarAhead = 'En fazla 30 gün sonrası için rezervasyon yapılabilir.';
  static const String errOutsideOpeningHours = 'Seçilen saat sahanın çalışma saatleri dışında.';
  static const String errTooManyPendingHolds =
      'Ödemesi tamamlanmamış rezervasyonların var. Önce onları tamamla ya da iptal et.';
  static const String errSlotTaken = 'Bu saat az önce doldu. Başka bir saat seç.';
  static const String errHoldExpired = 'Ödeme süresi doldu. Saati yeniden seçmelisin.';
  static const String errBookingNotFound = 'Rezervasyon bulunamadı.';
  static const String errNotCancellable = 'Bu rezervasyon iptal edilemez.';
  static const String errForbidden = 'Bu işlem için yetkin yok.';
  static const String errInvalidRequest = 'Geçersiz istek.';
  static const String errPaymentProvider = 'Ödeme altyapısına ulaşılamadı. Biraz sonra tekrar dene.';
  static const String errGeneric = 'Bir şeyler ters gitti. Tekrar dene.';
  // Client-side additions (not in the contract table).
  static const String errNetwork = 'İnternet bağlantını kontrol edip tekrar dene.';
  static const String errVenueNotFound = 'Tesis bulunamadı.';
  static const String errOwnerAccount = 'Saha sahibi hesapları uygulamadan silinemez. Destek ekibiyle iletişime geç.';
  static const String errPaymentNotFound = 'Ödeme kaydı bulunamadı.';
  static const String errTooManyRecentHolds = 'Kısa sürede çok fazla rezervasyon denemesi yaptın. Biraz sonra tekrar dene.';
  static const String errTooManyActiveBookings = 'Aynı anda en fazla 4 aktif rezervasyonun olabilir.';
  static const String errTooManyPaymentAttempts = 'Bu rezervasyon için çok fazla ödeme denemesi yapıldı. Yeni bir saat seç.';
  static const String errSlotStarted = 'Bu maç başladığı için işlem yapılamaz.';
  static const String errProfileMissing = 'Profil bilgilerin yüklenemedi. Tekrar dene.';
  static const String errOtpInvalid = 'Kod hatalı veya süresi dolmuş. Yeni bir kod isteyebilirsin.';
  static const String errTooManyRequests = 'Çok fazla deneme yaptın. Biraz bekleyip tekrar dene.';
  static const String errAuthGeneric = 'Giriş yapılamadı. Tekrar dene.';

  // --- Auth ------------------------------------------------------------------
  static const String loginSubtitle = 'Telefon numaranla giriş yap, birkaç dokunuşla sahanı ayır.';
  static const String phoneLabel = 'Telefon numarası';
  static const String phoneHint = '5XX XXX XX XX';
  static const String phonePrefix = '+90';
  static const String phoneInvalid = 'Geçerli bir cep telefonu numarası gir (10 hane, 5 ile başlar).';
  static const String sendCode = 'Kod gönder';
  static const String loginSmsNote = 'Numarana 6 haneli doğrulama kodu SMS ile gönderilecek.';
  static const String otpTitle = 'Doğrulama kodu';
  static const String otpHint = '------';
  static const String verify = 'Doğrula';
  static const String otpResend = 'Kodu tekrar gönder';
  static const String otpResent = 'Yeni kod gönderildi.';
  static String otpSentTo(String phone) => '$phone numarasına gönderilen 6 haneli kodu gir.';
  static String otpResendIn(int seconds) => 'Kodu tekrar göndermek için $seconds sn bekle';
  static const String onboardingTitle = 'Hoş geldin';
  static const String onboardingSubtitle = 'Rezervasyonlarda sahaya görünecek adını yaz ve aydınlatma metnini onayla.';
  static const String fullNameLabel = 'Ad soyad';
  static const String fullNameInvalid = 'Ad soyadını gir (en az 2 karakter).';
  static const String kvkkAckText = 'Kişisel verilerimin işlenmesine ilişkin aydınlatma metnini okudum.';
  static const String kvkkReadLink = 'KVKK Aydınlatma Metni\'ni oku';
  static const String marketingConsentText = 'Kampanya ve duyurulardan haberdar olmak istiyorum (isteğe bağlı).';

  // --- Home / venues -----------------------------------------------------------
  static const String searchHint = 'Saha veya ilçe ara';
  static const String allDistricts = 'Tümü';
  static const String noVenues = 'Şu an listelenecek saha yok.';
  static const String noVenuesForFilter = 'Aramana uygun saha bulunamadı.';
  static const String clearFilters = 'Filtreleri temizle';
  static const String viewVenue = 'Sahayı görüntüle';
  static const String closedToday = 'Bugün kapalı';
  static String todayHours(String open, String close) => 'Bugün $open – $close';
  static String pricePerHour(String formattedPrice) => '$formattedPrice/saat';
  static const String locationPrompt = 'Konumunu paylaşırsan sahaları yakınlığa göre sıralarız.';
  static const String locationDeniedForever = 'Konum izni kapalı. Yakın sahaları görmek için ayarlardan izin ver.';
  static const String locationServiceDisabled = 'Konum servisi kapalı. Yakın sahalar için aç.';
  static const String shareLocation = 'Paylaş';

  // --- Venue detail ------------------------------------------------------------
  static const String venueDetailTitle = 'Saha';
  static const String addFavorite = 'Favorilere ekle';
  static const String removeFavorite = 'Favorilerden çıkar';
  static const String openInMaps = 'Haritada aç';
  static const String amenities = 'Olanaklar';
  static const String selectPitch = 'Saha seç';
  static const String selectDate = 'Tarih seç';
  static const String selectTime = 'Saat seç';
  static const String noPitches = 'Bu tesiste şu an rezervasyona açık saha yok.';
  static const String noSlots = 'Bu tarihte müsait saat bulunmuyor.';
  static const String selectSlotHint = 'Bir saat seç';
  static String pitchLabel(String name, String format) => format.isEmpty ? name : '$name · $format';
  static String depositNote(String deposit) => 'Rezervasyon için şimdi $deposit kapora ödenir, kalanı sahada ödersin.';
  static String slotBookedLabel(String range) => '$range dolu';

  static String amenityLabel(String key) {
    const known = <String, String>{
      'otopark': 'Otopark',
      'dus': 'Duş',
      'kafeterya': 'Kafeterya',
      'wifi': 'Wi-Fi',
      'soyunma': 'Soyunma odası',
      'soyunma_odasi': 'Soyunma odası',
      'tribun': 'Tribün',
      'krampon': 'Krampon kiralama',
      'topu': 'Top kiralama',
      'isik': 'Işıklandırma',
      'wc': 'WC',
    };
    final label = known[key.toLowerCase()];
    if (label != null) return label;
    final cleaned = key.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return key;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  // --- Booking -----------------------------------------------------------------
  static const String bookingSummaryTitle = 'Rezervasyon özeti';
  static const String totalPrice = 'Toplam ücret';
  static const String depositNow = 'Şimdi ödenecek kapora';
  static const String remainderAtVenue = 'Sahada ödenecek kalan';
  static const String holdInfo = 'Ödemeye geçtiğinde saat 10 dakika boyunca senin için tutulur. Süre dolarsa saat yeniden açılır.';
  static const String cancellationPolicyTitle = 'İptal politikası';
  static String cancellationPolicy(int hours) {
    if (hours <= 0) {
      return 'Maç başlamadan önce yaptığın iptallerde kaporan iade edilir.';
    }
    return 'Maç saatine $hours saatten fazla varsa iptalde kaporan iade edilir. '
        'Daha geç yapılan iptallerde kapora iade edilmez.';
  }

  static const String distanceSalesCheckbox = "Mesafeli Satış Sözleşmesi ve Ön Bilgilendirme Formu'nu okudum.";
  static const String distanceSalesReadLink = 'Formu oku';
  static const String confirmBooking = 'Rezervasyonu onayla';
  static String proceedToPayment(String deposit) => 'Ödemeye geç · $deposit';
  static const String securePayment = 'Güvenli ödeme';
  static String holdCountdown(String mmss) => 'Ödeme için kalan süre: $mmss';
  static const String paymentPageLoadFailed = 'Ödeme sayfası yüklenemedi. Bağlantını kontrol edip tekrar dene.';
  static const String paymentResultTitle = 'Ödeme sonucu';
  static const String paymentChecking = 'Ödeme kontrol ediliyor';
  static const String paymentCheckingHint = 'Bankadan onay beklenirken birkaç saniye sürebilir. Bu ekranı kapatma.';
  static const String paymentSuccessTitle = 'Rezervasyonun onaylandı';
  static const String paymentSuccessBody = 'Sahada görüşürüz! Rezervasyon detaylarını Maçlarım sekmesinde bulabilirsin.';
  static const String paymentFailedTitle = 'Ödeme tamamlanamadı';
  static const String paymentFailedBody =
      'Rezervasyon onaylanmadı ve saat serbest bırakıldı. Ödeme alındıysa kısa süre içinde Maçlarım sekmesinde '
      'görünür; görünmezse destek ekibimizle iletişime geç.';
  static const String paymentStillPendingTitle = 'Ödeme sonucu henüz ulaşmadı';
  static const String paymentStillPendingBody =
      'Ödemen onaylanırsa rezervasyonun Maçlarım sekmesinde görünür. Biraz sonra tekrar kontrol edebilirsin.';
  static const String paymentRefundTitle = 'Ödemen alındı';
  static const String paymentRefundBody =
      'Ödemen alındı ama saat dolduğu için rezervasyon onaylanamadı. Kaporan iade edilecek.';
  static const String retryPayment = 'Ödemeyi tekrar dene';
  static const String resultErrorTitle = 'Sonuç alınamadı';
  static const String tryAgain = 'Tekrar dene';
  static const String checkAgain = 'Tekrar kontrol et';

  // --- Matches -----------------------------------------------------------------
  static const String tabUpcoming = 'Gelecek';
  static const String tabPast = 'Geçmiş';
  static const String noUpcomingMatches = 'Yaklaşan maçın yok. Hemen bir saha ayır!';
  static const String noPastMatches = 'Henüz geçmiş maçın yok.';
  static const String unknownVenue = 'Saha';
  static const String cancelBooking = 'İptal et';
  static const String continuePayment = 'Ödemeye devam et';
  static String bookingMoneyLine(String deposit, String total) => 'Kapora $deposit · Toplam $total';

  static const String statusConfirmed = 'Onaylandı';
  static const String statusPendingPayment = 'Ödeme bekleniyor';
  static const String statusCancelled = 'İptal edildi';
  static const String statusExpired = 'Süresi doldu';
  static const String statusCompleted = 'Tamamlandı';
  static const String statusNoShow = 'Gelmedi';

  static const String cancelDialogTitle = 'Rezervasyonu iptal et';
  static const String cancelDismiss = 'Vazgeç';
  static const String cancelConfirm = 'İptal et';

  /// Tells the user in advance what happens to the deposit.
  static String cancelPreviewText(RefundPreview preview, int windowHours) {
    switch (preview) {
      case RefundPreview.notCharged:
        return 'Ödemen henüz tamamlanmadığı için ücret alınmadı. Rezervasyon ücretsiz iptal edilecek.';
      case RefundPreview.noDeposit:
        return 'Bu rezervasyon için kapora alınmadı. Rezervasyon iptal edilecek.';
      case RefundPreview.refundable:
        return 'Maça $windowHours saatten fazla var. İptal edersen kaporan iade edilecek.';
      case RefundPreview.forfeited:
        return 'Maça $windowHours saatten az kaldı. Şimdi iptal edersen kaporan iade edilmez. Yine de iptal etmek istiyor musun?';
    }
  }

  /// Result shown after the RPC answered ([refundEligible] comes from the server).
  static String cancelResultText(RefundPreview preview, bool refundEligible) {
    if (preview == RefundPreview.notCharged) return 'Rezervasyon iptal edildi.';
    if (preview == RefundPreview.noDeposit) return 'Rezervasyon iptal edildi.';
    return refundEligible
        ? 'Rezervasyon iptal edildi. Kaporan iade sürecine alındı.'
        : 'Rezervasyon iptal edildi. Kapora iade edilmeyecek.';
  }

  // --- Favorites ---------------------------------------------------------------
  static const String noFavorites = 'Henüz favori sahan yok. Beğendiğin sahaları kalp ikonuyla buraya ekle.';

  // --- Support -----------------------------------------------------------------
  static const String supportHeaderTitle = 'Yardıma mı ihtiyacın var?';
  static const String supportHeaderSubtitle = 'Bize ulaş, en kısa sürede dönüş yapalım.';
  static const String contactEmail = 'E-posta';
  static const String contactPhone = 'Telefon';
  static const String contactWhatsapp = 'WhatsApp';
  static const String contactWhatsappSubtitle = 'WhatsApp ile yaz';
  static const String contactWebsite = 'Web sitesi';
  static const String supportNoContacts = 'İletişim bilgileri şu an gösterilemiyor.';
  static const String faqTitle = 'Sık sorulan sorular';

  static const List<({String question, String answer})> faqs = [
    (
      question: 'Rezervasyonu nasıl yaparım?',
      answer: 'Keşfet sekmesinden bir saha seç, saha ve tarihi belirle, müsait saatlerden birine dokun ve özet ekranında '
          'bilgilerini kontrol et. Kaporayı ödediğinde rezervasyonun kesinleşir ve Maçlarım sekmesinde görünür.',
    ),
    (
      question: 'Kapora nedir, neden alınıyor?',
      answer: 'Kapora, saatin senin için ayrılmasını sağlayan küçük bir ön ödemedir. Böylece sahalar gelmeyen '
          'müşteriler yüzünden zarara uğramaz. Maç ücretinin kalanını sahada ödersin.',
    ),
    (
      question: 'Rezervasyonumu iptal edersem kaporam iade edilir mi?',
      answer: 'Her sahanın bir iptal süresi vardır ve rezervasyon özetinde yazar. Maç saatine bu sürenin üzerinde bir '
          'zaman varsa kaporan iade edilir. Daha geç iptallerde kapora iade edilmez. İptal etmeden önce uygulama '
          'sana iade durumunu önceden gösterir.',
    ),
    (
      question: 'Ödemem güvenli mi?',
      answer: 'Ödeme, lisanslı ödeme kuruluşunun güvenli sayfasında alınır. Kart bilgilerin bu uygulamada saklanmaz ve '
          'bize iletilmez. Rezervasyonun yalnızca ödeme kuruluşundan onay geldikten sonra kesinleşir.',
    ),
    (
      question: 'Halı sahamı uygulamaya nasıl eklerim?',
      answer: 'Saha sahipleri işletme paneli üzerinden başvurur. Başvuru için web sitemizdeki iletişim bilgilerinden '
          'veya destek e-postamızdan bize ulaşabilirsin; ekibimiz seni yönlendirir.',
    ),
    (
      question: 'Hesabımı nasıl silerim?',
      answer: 'Profilim sekmesinin en altındaki "Hesabımı Sil" seçeneğini kullanabilirsin. Gelecekteki rezervasyonların '
          'iptal edilir (iade kuralları geçerlidir), kişisel verilerin silinir. Bu işlem geri alınamaz.',
    ),
  ];

  // --- Profile -----------------------------------------------------------------
  static const String editProfile = 'Profili düzenle';
  static const String profileUpdated = 'Profilin güncellendi.';
  static const String notificationSettings = 'Bildirim ayarları';
  static const String notificationsPlaceholderNote =
      'Bildirimler yakında aktif olacak. Şimdilik bu tercihler yalnızca bu ekranda tutulur.';
  static const String notifBookingConfirmed = 'Rezervasyon onaylandığında';
  static const String notifReminder = 'Maçtan 2 saat önce hatırlatma';
  static const String notifVenueCancelled = 'İşletme rezervasyonu iptal ettiğinde';
  static const String legalAbout = 'Hakkında';
  static const String legalPrivacy = 'Gizlilik Politikası';
  static const String legalTerms = 'Kullanım Koşulları';
  static const String legalKvkk = 'KVKK Aydınlatma Metni';
  static const String legalDistanceSales = 'Mesafeli Satış Sözleşmesi';
  static String appVersionLabel(String version) => 'Sürüm $version';
  static const String signOut = 'Çıkış Yap';
  static const String signOutConfirmTitle = 'Çıkış yapılsın mı?';
  static const String signOutConfirmBody = 'Hesabından çıkış yapacaksın. Tekrar giriş için telefon numaranı kullanabilirsin.';
  static const String deleteAccount = 'Hesabımı Sil';
  static const String deleteAccountTitle = 'Hesabını silmek istiyor musun?';
  static const String deleteAccountBody =
      'Hesabın ve kişisel verilerin silinir. Gelecekteki rezervasyonların iptal edilir; iptal penceresi içindeyse '
      'kapora iade edilmez. Bu işlem geri alınamaz.';
  static const String deleteAccountFinalTitle = 'Son onay';
  static const String deleteAccountFinalBody = 'Hesabın kalıcı olarak silinecek. Emin misin?';
  static const String deleteAccountConfirm = 'Evet, hesabımı sil';

  // --- Demo / web preview ------------------------------------------------------
  static const String demoBanner = 'DEMO · gerçek ödeme alınmaz';
  static const String demoDisabled = 'Demo modunda bu işlem kapalı';
  static const String demoPaymentTitle = 'Demo ödeme';
  static const String demoPaymentIntro = 'Bu bir demo. Kart bilgisi istenmez ve hiçbir ücret alınmaz.';
  static const String demoPaymentDeposit = 'Ödenecek kapora';
  static const String demoPaymentComplete = 'Ödemeyi tamamla (demo)';
  static const String demoPaymentFail = 'Başarısız ödeme dene (demo)';
  static const String webPaymentUnsupported = "Web'de ödeme desteklenmiyor. Ödeme için mobil uygulamayı kullan.";

  // --- Slot picker, summary bar, confirmation (docs/DESIGN.md "Bileşen kuralları") --------
  static const String slotBooked = 'Dolu';
  static String slotPeriodLabel(SlotPeriod period) {
    switch (period) {
      case SlotPeriod.evening:
        return 'Akşam';
      case SlotPeriod.afternoon:
        return 'Öğleden sonra';
      case SlotPeriod.night:
        return 'Sabah / Gece';
    }
  }

  static String cancellationPolicyShort(int hours) => hours <= 0
      ? 'Maç başlamadan önce iptal edersen kapora iade edilir.'
      : 'Maça $hours saatten fazla varsa kapora iade edilir.';
  static String nearestFreeDay(String weekday) => 'En yakın boş gün: $weekday';
  static const String searchingNearestDay = 'En yakın boş gün aranıyor...';
  static const String noSlotsNearby = 'Önümüzdeki günlerde de boş saat bulunamadı.';
  static String summaryDepositNow(String deposit) => 'Şimdi $deposit kapora · kalan sahada';
  static String summaryTotal(String total) => 'Toplam $total';
  static const String securePaymentTrust = 'Güvenli ödeme · PayTR';
  static const String verifiedVenue = 'Onaylı işletme';
  static const String paidDeposit = 'Ödenen kapora';
  static const String addressLabel = 'Adres';
  static const String bookingConfirmedHint = 'Adrese dokunarak haritada açabilirsin.';

  // --- İşletmeci modu (owner) -------------------------------------------------------------
  static const String ownerPanel = 'İşletmeci paneli';
  static const String ownerPanelSubtitle = 'Takvimi, rezervasyonları ve sahaları yönet';
  static const String ownerTabBookings = 'Rezervasyonlar';
  static const String ownerTabBookingsShort = 'Rezervasyon';
  static const String ownerTabPitches = 'Sahalarım';
  static const String ownerTabHours = 'Saatler';
  static const String ownerExit = 'Müşteri uygulamasına dön';
  static const String ownerNoVenues = 'Hesabına bağlı bir işletme bulunamadı. Destek ekibiyle iletişime geç.';
  static const String ownerVenueLabel = 'Tesis';
  static const String ownerNoPitchesToday = 'Bu tesiste aktif saha yok.';
  static const String ownerClosedDay = 'Bu gün kapalı. Saatleri "Saatler" sekmesinden düzenleyebilirsin.';
  static const String legendApp = 'Uygulama';
  static const String legendPhone = 'Telefon';
  static const String legendBlocked = 'Kapalı';
  static const String legendPending = 'Ödeme bekliyor';
  static const String legendFree = 'Boş';
  static const String sourceApp = 'Uygulama rezervasyonu';
  static const String sourceManual = 'Telefon rezervasyonu';
  static const String sourceBlock = 'Kapalı saat';
  static const String closeSlot = 'Saati kapat';
  static const String customerNameLabel = 'Müşteri adı';
  static const String customerNameRequired = 'Müşteri adını gir.';
  static const String customerPhoneLabel = 'Telefon (isteğe bağlı)';
  static const String noteLabel = 'Not (isteğe bağlı)';
  static const String manualBookingCreated = 'Telefon rezervasyonu eklendi.';
  static const String slotClosedDone = 'Saat kapatıldı.';
  static const String customerLabel = 'Müşteri';
  static const String phoneRowLabel = 'Telefon';
  static const String noteRowLabel = 'Not';
  static const String priceRowLabel = 'Ücret';
  static const String depositRowLabel = 'Kapora';
  static const String callCustomer = 'Ara';
  static const String contactUnavailable = 'Müşteri bilgisi alınamadı.';
  static const String ownerCancelWarnApp =
      'Bu bir uygulama rezervasyonu. İptal edersen müşterinin kaporası tamamen iade edilir.';
  static const String ownerCancelWarnOther = 'Rezervasyon iptal edilecek ve saat yeniden açılacak.';
  static const String ownerCancelled = 'Rezervasyon iptal edildi.';
  static const String attended = 'Geldi';
  static const String notAttended = 'Gelmedi';
  static const String attendanceSaved = 'Durum güncellendi.';
  static const String filterAll = 'Tümü';
  static const String filterApp = 'Uygulama';
  static const String filterPhone = 'Telefon';
  static const String filterBlocked = 'Kapalı';
  static const String filterPending = 'Ödeme bekleyen';
  static const String ownerNoUpcoming = 'Yaklaşan rezervasyon yok.';
  static const String ownerNoMatchForFilter = 'Bu filtreye uyan rezervasyon yok.';
  static const String ownerNoPitches = 'Bu işletmede henüz saha yok. Saha eklemek için web panelini kullan.';
  static const String hourlyPriceLabel = 'Saat ücreti (₺)';
  static const String depositLabel = 'Kapora (₺)';
  static const String activeLabel = 'Rezervasyona açık';
  static const String inactiveLabel = 'Pasif';
  static const String editPitch = 'Sahayı düzenle';
  static const String amountInvalid = 'Geçerli bir tutar gir.';
  static const String depositTooHigh = 'Kapora, saat ücretinden büyük olamaz.';
  static const String pitchUpdated = 'Saha güncellendi.';
  static const List<String> weekdayNames = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  static const String closedLabel = 'Kapalı';
  static const String openLabel = 'Açılış';
  static const String closeLabel = 'Kapanış';
  static const String overnightHint = 'Gece yarısını aşar';
  static const String hoursSaved = 'Çalışma saatleri kaydedildi.';
  static const String demoOwnerSwitch = 'İşletmeci modunu dene (demo)';
  static const String demoOwnerSwitchHint = 'Demo kullanıcıyı 2 örnek tesisin işletmecisi yapar.';
  static const String statusPaymentPendingShort = 'Ödeme bekliyor';
  static const String bookedByApp = 'Uygulama';
}
