import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/urls.dart';
import '../../../../core/widgets/network_image_box.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/venue_summary.dart';

/// Venue card per docs/DESIGN.md: 16:9 cover, name, today's hours, district,
/// price badge top-right and a full-width primary button.
class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});

  final VenueSummary venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = venue.minHourlyPriceKurus;
    final hours = venue.isOpenToday ? S.todayHours(venue.openTime!, venue.closeTime!) : S.closedToday;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkImageBox(url: venuePhotoUrl(venue.coverPhotoPath), title: venue.name),
                    if (price != null)
                      Positioned(
                        top: AppSpacing.m,
                        right: AppSpacing.m,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(AppRadius.button),
                          ),
                          child: Text(
                            S.pricePerHour(formatTry(price)),
                            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.onAccent),
                          ),
                        ),
                      ),
                    if (venue.isFavorite)
                      const Positioned(
                        top: AppSpacing.m,
                        left: AppSpacing.m,
                        child: Icon(Icons.favorite, color: AppColors.danger),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.s),
                  _InfoRow(icon: Icons.schedule, text: hours),
                  const SizedBox(height: AppSpacing.xs),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: venue.distanceKm == null
                        ? venue.district
                        : '${venue.district} · ${formatDistanceKm(venue.distanceKm!)}',
                  ),
                  const SizedBox(height: AppSpacing.l),
                  PrimaryButton(label: S.viewVenue, onPressed: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}
