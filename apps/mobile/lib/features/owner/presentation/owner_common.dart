import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/empty_state.dart';
import '../../booking/domain/booking.dart';
import '../domain/owner_logic.dart';
import '../domain/owner_models.dart';
import 'owner_providers.dart';

/// Loads the owner's venues, resolves the selected one and hands it to [builder] together with a
/// venue switcher widget (a plain title when there is only one venue).
class OwnerVenueScope extends ConsumerWidget {
  const OwnerVenueScope({super.key, required this.builder});

  final Widget Function(BuildContext context, OwnerVenue venue, Widget switcher) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(ownerVenuesProvider);
    final selectedId = ref.watch(selectedOwnerVenueIdProvider);
    return AsyncValueWidget<List<OwnerVenue>>(
      value: venues,
      onRetry: () => ref.invalidate(ownerVenuesProvider),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(icon: Icons.storefront_outlined, message: S.ownerNoVenues);
        }
        final venue = list.firstWhere((v) => v.id == selectedId, orElse: () => list.first);
        final Widget switcher = list.length == 1
            ? _VenueTitle(venue: venue)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final v in list)
                      ChoiceChip(
                        label: Text(v.name),
                        selected: v.id == venue.id,
                        onSelected: (_) => ref.read(selectedOwnerVenueIdProvider.notifier).state = v.id,
                      ),
                  ],
                ),
              );
        return builder(context, venue, switcher);
      },
    );
  }
}

class _VenueTitle extends StatelessWidget {
  const _VenueTitle({required this.venue});

  final OwnerVenue venue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Row(
        children: [
          Icon(Icons.storefront_outlined, size: 20, color: context.tokens.brand),
          const SizedBox(width: AppSpacing.s),
          Expanded(child: Text(venue.name, style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
    );
  }
}

/// Visual style of one booking on the owner calendar (docs/DESIGN.md "İşletmeci modu").
class OwnerBookingStyle {
  const OwnerBookingStyle({
    required this.background,
    required this.foreground,
    required this.border,
    required this.label,
    this.striped = false,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final String label;
  final bool striped;

  /// App booking = action, phone booking = primary, closed slot = grey striped,
  /// unpaid hold = warning.
  static OwnerBookingStyle of(Booking b, AppTokens t) {
    if (isBlockBooking(b)) {
      return OwnerBookingStyle(
        background: t.disabledSlot,
        foreground: t.onDisabledSlot,
        border: t.border,
        label: S.legendBlocked,
        striped: true,
      );
    }
    if (b.status == BookingStatus.pendingPayment) {
      return OwnerBookingStyle(
        background: t.warningSoft,
        foreground: t.warning,
        border: t.warning,
        label: S.legendPending,
      );
    }
    if (isManualBooking(b)) {
      return OwnerBookingStyle(
        background: t.primary,
        foreground: t.onPrimary,
        border: t.primary,
        label: S.legendPhone,
      );
    }
    return OwnerBookingStyle(
      background: t.action,
      foreground: t.onAction,
      border: t.action,
      label: S.legendApp,
    );
  }
}

/// Paints thin diagonal lines (the "gri çizgili" closed-slot look).
class StripePainter extends CustomPainter {
  const StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const gap = 8.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) => oldDelegate.color != color;
}

/// Colour legend under the calendar.
class OwnerLegend extends StatelessWidget {
  const OwnerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    Widget item(Color fill, Color border, String label, {bool striped = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border),
            ),
            child: striped ? ClipRRect(borderRadius: BorderRadius.circular(4), child: CustomPaint(painter: StripePainter(border))) : null,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Wrap(
        spacing: AppSpacing.l,
        runSpacing: AppSpacing.xs,
        children: [
          item(t.action, t.action, S.legendApp),
          item(t.primary, t.primary, S.legendPhone),
          item(t.warningSoft, t.warning, S.legendPending),
          item(t.disabledSlot, t.neutral, S.legendBlocked, striped: true),
          item(t.card, t.border, S.legendFree),
        ],
      ),
    );
  }
}
