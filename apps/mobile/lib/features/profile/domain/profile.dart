import '../../../core/utils/json_utils.dart';

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.marketingConsent = false,
    this.kvkkAckAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      marketingConsent: (json['marketing_consent'] as bool?) ?? false,
      kvkkAckAt: parseUtcOrNull(json['kvkk_ack_at']),
    );
  }

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final bool marketingConsent;
  final DateTime? kvkkAckAt;

  /// First login: name missing or the KVKK aydınlatma metni not yet acknowledged.
  bool get needsOnboarding => fullName.trim().isEmpty || kvkkAckAt == null;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }
}
