import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'generated_venue_image.dart';

/// Cached remote image with neutral placeholder / error states. A null [url] shows the placeholder icon.
class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({super.key, required this.url, this.fit = BoxFit.cover, this.title});

  /// Venue name; in demo mode it drives the generated placeholder (initials + gradient).
  final String? title;

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (AppConfig.demoMode && title != null) return GeneratedVenueImage(name: title!);
    final placeholder = Container(
      color: AppColors.neutralSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.sports_soccer, size: 40, color: AppColors.neutral),
    );
    final imageUrl = url;
    if (imageUrl == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, _) => const ColoredBox(color: AppColors.neutralSoft),
      errorWidget: (context, _, __) => placeholder,
    );
  }
}
