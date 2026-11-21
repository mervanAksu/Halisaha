/// A venue the signed-in owner manages.
class OwnerVenue {
  const OwnerVenue({required this.id, required this.name, required this.district});

  factory OwnerVenue.fromJson(Map<String, dynamic> json) => OwnerVenue(
        id: json['id'] as String,
        name: json['name'] as String,
        district: (json['district'] as String?) ?? '',
      );

  final String id;
  final String name;
  final String district;
}

/// Opening hours of one ISO weekday (1 = Monday ... 7 = Sunday) in Istanbul wall-clock minutes.
/// A closed day has no `venue_hours` row. `closeMinutes <= openMinutes` means the day runs past midnight.
class DayHours {
  const DayHours({
    required this.isoWeekday,
    required this.closed,
    required this.openMinutes,
    required this.closeMinutes,
  });

  const DayHours.closed(this.isoWeekday)
      : closed = true,
        openMinutes = defaultOpenMinutes,
        closeMinutes = defaultCloseMinutes;

  /// 09:00 - 23:00 is offered as the starting point when a closed day is opened.
  static const int defaultOpenMinutes = 9 * 60;
  static const int defaultCloseMinutes = 23 * 60;

  final int isoWeekday;
  final bool closed;
  final int openMinutes;
  final int closeMinutes;

  /// The business day extends past midnight ("Gece yarısını aşar"). Closing exactly at 00:00 only
  /// reaches midnight, so it is not flagged.
  bool get overnight => !closed && closeMinutes > 0 && closeMinutes <= openMinutes;

  DayHours copyWith({bool? closed, int? openMinutes, int? closeMinutes}) => DayHours(
        isoWeekday: isoWeekday,
        closed: closed ?? this.closed,
        openMinutes: openMinutes ?? this.openMinutes,
        closeMinutes: closeMinutes ?? this.closeMinutes,
      );

  /// "HH:mm" for a minutes-after-midnight value.
  static String hhmm(int minutes) {
    final m = minutes % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// Parses "HH:mm" or "HH:mm:ss" (Postgres `time`) into minutes after midnight.
  static int parseMinutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Postgres `time` literal for upserts.
  String get openSql => '${hhmm(openMinutes)}:00';
  String get closeSql => '${hhmm(closeMinutes)}:00';
}

/// Name and phone of an app customer, from RPC `owner_customer_contacts`.
class OwnerContact {
  const OwnerContact({required this.userId, required this.fullName, this.phone});

  factory OwnerContact.fromJson(Map<String, dynamic> json) => OwnerContact(
        userId: json['user_id'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        phone: json['phone'] as String?,
      );

  final String userId;
  final String fullName;
  final String? phone;
}

/// Filter chips of the "Rezervasyonlar" tab.
enum OwnerBookingFilter { all, app, phone, blocked, pending }
