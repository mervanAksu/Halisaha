import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Exact texts from docs/API_CONTRACT.md "Hata kodları → kullanıcı mesajı".
  const expected = <String, String>{
    'not_authenticated': 'Devam etmek için giriş yapmalısın.',
    'pitch_not_found': 'Bu saha artık rezervasyona açık değil.',
    'slot_in_past': 'Bu saat geçti veya çok yakın, başka bir saat seç.',
    'too_far_ahead': 'En fazla 30 gün sonrası için rezervasyon yapılabilir.',
    'outside_opening_hours': 'Seçilen saat sahanın çalışma saatleri dışında.',
    'too_many_pending_holds': 'Ödemesi tamamlanmamış rezervasyonların var. Önce onları tamamla ya da iptal et.',
    'slot_taken': 'Bu saat az önce doldu. Başka bir saat seç.',
    'hold_expired': 'Ödeme süresi doldu. Saati yeniden seçmelisin.',
    'booking_not_found': 'Rezervasyon bulunamadı.',
    'not_cancellable': 'Bu rezervasyon iptal edilemez.',
    'forbidden': 'Bu işlem için yetkin yok.',
    'invalid_range': 'Geçersiz istek.',
    'invalid_status': 'Geçersiz istek.',
    'invalid_source': 'Geçersiz istek.',
    'payment_provider_error': 'Ödeme altyapısına ulaşılamadı. Biraz sonra tekrar dene.',
  };

  test('every contract code maps to its Turkish message', () {
    for (final entry in expected.entries) {
      expect(messageForCode(entry.key), entry.value, reason: entry.key);
    }
    expect(knownErrorCodes.toSet(), expected.keys.toSet());
  });

  test('unknown codes fall back to the generic message', () {
    expect(messageForCode('something_else'), 'Bir şeyler ters gitti. Tekrar dene.');
  });

  test('PostgrestException message carrying a code is mapped', () {
    final e = AppException.from(PostgrestException(message: 'slot_taken', code: 'P0001'));
    expect(e.code, 'slot_taken');
    expect(e.message, 'Bu saat az önce doldu. Başka bir saat seç.');
  });

  test('code embedded in longer text is extracted', () {
    expect(extractErrorCode('ERROR: slot_in_past'), 'slot_in_past');
    expect(extractErrorCode('nothing useful'), isNull);
    expect(extractErrorCode(null), isNull);
  });

  test('unknown Postgrest errors become the generic message', () {
    final e = AppException.from(PostgrestException(message: 'permission denied for table x'));
    expect(e.message, 'Bir şeyler ters gitti. Tekrar dene.');
  });

  test('AppException passes through unchanged', () {
    const original = AppException('slot_taken', 'x');
    expect(identical(AppException.from(original), original), isTrue);
  });
}
