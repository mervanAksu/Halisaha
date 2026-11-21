import 'package:flutter_test/flutter_test.dart';
import 'package:halisaha/core/config/app_config.dart';
import 'package:halisaha/features/booking/domain/booking.dart';
import 'package:halisaha/features/profile/domain/profile.dart';

void main() {
  test('the app is branded Rövanş', () {
    expect(AppConfig.appName, 'Rövanş');
  });

  group('Profile.role', () {
    Map<String, dynamic> json(String? role) => {
          'id': 'u1',
          'full_name': 'Ayşe Yıldız',
          'phone': '+905550000000',
          'kvkk_ack_at': '2026-11-20T10:00:00Z',
          if (role != null) 'role': role,
        };

    test('defaults to customer when the column is absent', () {
      final p = Profile.fromJson(json(null));
      expect(p.role, 'customer');
      expect(p.isOwner, isFalse);
    });

    test('owner and admin see the owner panel, customers do not', () {
      expect(Profile.fromJson(json('owner')).isOwner, isTrue);
      expect(Profile.fromJson(json('admin')).isOwner, isTrue);
      expect(Profile.fromJson(json('customer')).isOwner, isFalse);
    });

    test('copyWith keeps unchanged fields', () {
      final p = Profile.fromJson(json('customer')).copyWith(role: 'owner');
      expect(p.isOwner, isTrue);
      expect(p.fullName, 'Ayşe Yıldız');
      expect(p.phone, '+905550000000');
      expect(p.needsOnboarding, isFalse);
    });
  });

  test('Booking.fromJson reads the venue address for the confirmation screen and manual customer fields', () {
    final b = Booking.fromJson({
      'id': 'b1',
      'pitch_id': 'p1',
      'venue_id': 'v1',
      'source': 'manual',
      'status': 'confirmed',
      'starts_at': '2026-12-06T17:00:00Z',
      'ends_at': '2026-12-06T18:00:00Z',
      'price_kurus': 400000,
      'deposit_kurus': 0,
      'customer_name': 'Ali Veli',
      'customer_phone': '+905550000001',
      'note': 'Not',
      'pitches': {'name': 'Saha 1', 'format': '7v7'},
      'venues': {
        'name': 'Mavi Çim',
        'district': 'Büyükçekmece',
        'address': 'Sahil Yolu Cd. No: 14',
        'lat': 41.0206,
        'lng': 28.5785,
        'cancellation_window_hours': 24,
      },
    });
    expect(b.venueAddress, 'Sahil Yolu Cd. No: 14');
    expect(b.venueLat, 41.0206);
    expect(b.venueLng, 28.5785);
    expect(b.customerName, 'Ali Veli');
    expect(b.customerPhone, '+905550000001');
    expect(b.note, 'Not');
    expect(b.remainderKurus, 400000);
  });
}
