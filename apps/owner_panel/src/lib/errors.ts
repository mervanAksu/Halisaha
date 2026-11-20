// Same table as docs/API_CONTRACT.md ("Hata kodları → kullanıcı mesajı"), plus panel-specific codes.
const MESSAGES: Record<string, string> = {
  not_authenticated: 'Devam etmek için giriş yapmalısın.',
  pitch_not_found: 'Bu saha artık rezervasyona açık değil.',
  slot_in_past: 'Bu saat geçti veya çok yakın, başka bir saat seç.',
  too_far_ahead: 'En fazla 30 gün sonrası için rezervasyon yapılabilir.',
  outside_opening_hours: 'Seçilen saat sahanın çalışma saatleri dışında.',
  too_many_pending_holds:
    'Ödemesi tamamlanmamış rezervasyonların var. Önce onları tamamla ya da iptal et.',
  slot_taken: 'Bu saat az önce doldu. Başka bir saat seç.',
  hold_expired: 'Ödeme süresi doldu. Saati yeniden seçmelisin.',
  booking_not_found: 'Rezervasyon bulunamadı.',
  not_cancellable: 'Bu rezervasyon iptal edilemez.',
  forbidden: 'Bu işlem için yetkin yok.',
  invalid_range: 'Geçersiz istek.',
  invalid_status: 'Geçersiz istek.',
  invalid_source: 'Geçersiz istek.',
  payment_provider_error: 'Ödeme altyapısına ulaşılamadı. Biraz sonra tekrar dene.',
  slot_started: "Bu maç başladığı için iptal edilemez; gerekiyorsa 'Gelmedi' olarak işaretle.",
  too_many_payment_attempts: 'Çok fazla ödeme denemesi yapıldı. Biraz sonra tekrar dene.',
  too_many_recent_holds: 'Kısa sürede çok fazla rezervasyon denemesi yapıldı. Biraz sonra tekrar dene.',
  too_many_active_bookings: 'Aktif rezervasyon sınırına ulaşıldı.',
  owner_account: 'Bu işlem işletme hesabıyla yapılamaz.',
  // Not in API_CONTRACT yet (raised by admin_update_venue / confirm_payment):
  venue_not_found: 'Tesis bulunamadı.',
  payment_not_found: 'Ödeme kaydı bulunamadı.',
};

// Direct table writes surface Postgres constraint names / codes instead of RPC codes.
const CONSTRAINTS: Record<string, string> = {
  deposit_not_above_price: 'Kapora, slot ücretini aşamaz.',
  venue_payout_accounts_iban_check: 'IBAN geçersiz. TR ile başlayan 26 karakterlik IBAN gir.',
};

const FALLBACK = 'Bir şeyler ters gitti. Tekrar dene.';

type ErrorLike = { message?: string | null; code?: string | null } | null | undefined;

export function toTurkishError(err: ErrorLike): string {
  if (!err) return FALLBACK;
  const message = err.message ?? '';
  const exact = MESSAGES[message.trim()];
  if (exact) return exact;
  for (const [code, text] of Object.entries(MESSAGES)) {
    if (new RegExp(`\\b${code}\\b`).test(message)) return text;
  }
  for (const [name, text] of Object.entries(CONSTRAINTS)) {
    if (message.includes(name)) return text;
  }
  switch (err.code) {
    case '42501':
      return MESSAGES.forbidden;
    case '23503':
      return 'Bu kayda bağlı başka kayıtlar var, işlem yapılamadı.';
    case '23505':
      return 'Bu kayıt zaten mevcut.';
    case '23514':
      return 'Girilen değerler kabul edilmedi. Alanları kontrol et.';
    default:
      return FALLBACK;
  }
}
