import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/owner_models.dart';
import 'owner_common.dart';
import 'owner_providers.dart';
import 'owner_account_button.dart';

/// "Saatler": weekly opening hours editor. Closed days have no row; an overnight day
/// (closing at or before the opening time) is allowed and flagged "Gece yarısını aşar".
class OwnerHoursScreen extends StatelessWidget {
  const OwnerHoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.ownerTabHours), actions: const [OwnerAccountButton()]),
      body: OwnerVenueScope(
        builder: (context, venue, switcher) => _HoursBody(venueId: venue.id, switcher: switcher),
      ),
    );
  }
}

class _HoursBody extends ConsumerWidget {
  const _HoursBody({required this.venueId, required this.switcher});

  final String venueId;
  final Widget switcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoursAsync = ref.watch(ownerHoursProvider(venueId));
    return Column(
      children: [
        switcher,
        const SizedBox(height: AppSpacing.s),
        Expanded(
          child: hoursAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: AppException.from(e).message,
              onRetry: () => ref.invalidate(ownerHoursProvider(venueId)),
            ),
            // Keyed by venue so switching venues rebuilds the editor state.
            data: (days) => _HoursEditor(key: ValueKey(venueId), venueId: venueId, initial: days),
          ),
        ),
      ],
    );
  }
}

class _HoursEditor extends ConsumerStatefulWidget {
  const _HoursEditor({super.key, required this.venueId, required this.initial});

  final String venueId;
  final List<DayHours> initial;

  @override
  ConsumerState<_HoursEditor> createState() => _HoursEditorState();
}

class _HoursEditorState extends ConsumerState<_HoursEditor> {
  late final List<DayHours> _days = List<DayHours>.of(widget.initial);
  bool _busy = false;

  void _update(int index, DayHours value) => setState(() => _days[index] = value);

  Future<void> _pick(int index, {required bool open}) async {
    final day = _days[index];
    final current = open ? day.openMinutes : day.closeMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (current ~/ 60) % 24, minute: current % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    _update(index, open ? day.copyWith(openMinutes: minutes) : day.copyWith(closeMinutes: minutes));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(ownerActionsProvider).saveHours(widget.venueId, _days);
      messenger.showSnackBar(const SnackBar(content: Text(S.hoursSaved)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        for (var i = 0; i < _days.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: t.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(S.weekdayNames[_days[i].isoWeekday - 1], style: theme.textTheme.titleMedium)),
                    Text(S.closedLabel, style: theme.textTheme.bodySmall),
                    Switch(
                      value: _days[i].closed,
                      onChanged: _busy ? null : (closed) => _update(i, _days[i].copyWith(closed: closed)),
                    ),
                  ],
                ),
                if (!_days[i].closed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: S.openLabel,
                          minutes: _days[i].openMinutes,
                          onTap: _busy ? null : () => _pick(i, open: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _TimeButton(
                          label: S.closeLabel,
                          minutes: _days[i].closeMinutes,
                          onTap: _busy ? null : () => _pick(i, open: false),
                        ),
                      ),
                    ],
                  ),
                  if (_days[i].overnight)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s),
                      child: Row(
                        children: [
                          Icon(Icons.nightlight_outlined, size: 16, color: t.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            S.overnightHint,
                            style: theme.textTheme.bodySmall?.copyWith(color: t.warning, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
        const SizedBox(height: AppSpacing.m),
        PrimaryButton(label: S.save, loading: _busy, onPressed: _busy ? null : _save),
        const SizedBox(height: AppSpacing.l),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.minutes, required this.onTap});

  final String label;
  final int minutes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(DayHours.hhmm(minutes), style: numericStyle(context, size: 20, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
