/// Normalises user input to the 10-digit national number of a Turkish mobile
/// ("5551234567"), or returns null when it is not valid.
/// Accepts spaces/dashes and a leading 0, 90 or +90.
String? normalizeTrPhoneInput(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 12 && digits.startsWith('90')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 10 && digits.startsWith('5')) return digits;
  return null;
}

/// "+905551234567" for Supabase Auth.
String toE164Tr(String nationalNumber10) => '+90$nationalNumber10';

/// Display form of a stored phone ("905551234567" or "+905551234567") -> "+90 555 123 45 67".
String formatPhoneDisplay(String? stored) {
  if (stored == null || stored.isEmpty) return '';
  final digits = stored.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 12 && digits.startsWith('90')) {
    final n = digits.substring(2);
    return '+90 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6, 8)} ${n.substring(8)}';
  }
  return stored.startsWith('+') ? stored : '+$digits';
}
