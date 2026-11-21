import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/strings.dart';

/// Public URL of an object in the `venue-photos` bucket, or null when there is no path.
String? venuePhotoUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  final base = AppConfig.supabaseUrl.endsWith('/')
      ? AppConfig.supabaseUrl.substring(0, AppConfig.supabaseUrl.length - 1)
      : AppConfig.supabaseUrl;
  final encoded = path.split('/').map(Uri.encodeComponent).join('/');
  return '$base/storage/v1/object/public/${AppConfig.venuePhotosBucket}/$encoded';
}

/// Universal maps link (opens the Maps app on both platforms, browser as fallback).
String mapsUrl({double? lat, double? lng, required String query}) {
  if (lat != null && lng != null) {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
}

/// Schemes the app may hand to the OS. Only URLs the app builds itself (maps, support contacts,
/// legal pages, `tel:` for a venue phone) are ever launched; `http`, `intent`, `file`, `javascript`
/// and custom schemes are refused. Server-provided strings must pass this check first.
bool isSafeExternalUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  switch (uri.scheme) {
    case 'https':
      return uri.host.isNotEmpty;
    case 'tel':
    case 'mailto':
      return uri.path.isNotEmpty;
    default:
      return false;
  }
}

/// `tel:` link from a phone number; null when it has no digits.
String? telUrl(String? phone) {
  if (phone == null) return null;
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final digits = cleaned.replaceAll('+', '');
  if (digits.length < 7 || digits.length > 15) return null;
  return 'tel:$cleaned';
}

/// Opens [url] in the external browser/app. Returns false on failure or when the URL is not safe.
Future<bool> openExternalUrl(String url) async {
  if (!isSafeExternalUrl(url)) return false;
  final uri = Uri.parse(url.trim());
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Same as [openExternalUrl] but tells the user when nothing could be opened.
Future<void> openExternalOrWarn(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await openExternalUrl(url);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text(S.linkOpenFailed)));
  }
}
