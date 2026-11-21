import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/phone.dart';
import '../../../core/utils/urls.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../booking/domain/booking.dart';
import '../../venues/domain/pitch.dart';
import '../domain/owner_logic.dart';
import 'owner_providers.dart';

/// Bottom sheet for a free slot: add a phone booking or close the slot.
Future<void> showOwnerEmptySlotSheet(
  BuildContext context, {
  required Pitch pitch,
  required DateTime start,
  required DateTime end,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EmptySlotSheet(pitch: pitch, start: start, end: end),
  );
}

/// Bottom sheet with the details and actions of one booking.
Future<void> showOwnerBookingSheet(BuildContext context, {required Booking booking, required String pitchName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BookingSheet(booking: booking, pitchName: pitchName),
  );
}

class _EmptySlotSheet extends ConsumerStatefulWidget {
  const _EmptySlotSheet({required this.pitch, required this.start, required this.end});

  final Pitch pitch;
  final DateTime start;
  final DateTime end;

  @override
  ConsumerState<_EmptySlotSheet> createState() => _EmptySlotSheetState();
}

class _EmptySlotSheetState extends ConsumerState<_EmptySlotSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _saveManual() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final national = normalizeTrPhoneInput(_phone.text);
    _run(
      () => ref.read(ownerActionsProvider).createManual(
            pitch: widget.pitch,
            startsAt: widget.start,
            customerName: _name.text.trim(),
            customerPhone: national == null ? null : toE164Tr(national),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
      S.manualBookingCreated,
    );
  }

  void _closeSlot() {
    _run(
      () => ref.read(ownerActionsProvider).closeSlot(
            pitch: widget.pitch,
            startsAt: widget.start,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
      S.slotClosedDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(S.sourceManual, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.pitch.name} · ${formatIstanbulDateWithWeekday(widget.start)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                formatTimeRange(widget.start, widget.end),
                style: numericStyle(context, size: 24, weight: FontWeight.w700, color: tokens.brand),
              ),
              const SizedBox(height: AppSpacing.l),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: appInputDecoration(context, label: S.customerNameLabel, counterText: ''),
                validator: (v) => (v ?? '').trim().length < 2 ? S.customerNameRequired : null,
              ),
              const SizedBox(height: AppSpacing.m),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: appInputDecoration(
                  context,
                  label: S.customerPhoneLabel,
                  hint: S.phoneHint,
                  prefixText: '${S.phonePrefix} ',
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  return normalizeTrPhoneInput(text) == null ? S.phoneInvalid : null;
                },
              ),
              const SizedBox(height: AppSpacing.m),
              TextFormField(
                controller: _note,
                maxLength: 500,
                maxLines: 2,
                decoration: appInputDecoration(context, label: S.noteLabel, counterText: ''),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger)),
              ],
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(label: S.sourceManual, loading: _busy, onPressed: _busy ? null : _saveManual),
              const SizedBox(height: AppSpacing.m),
              OutlinedButton.icon(
                onPressed: _busy ? null : _closeSlot,
                icon: const Icon(Icons.block),
                label: const Text(S.closeSlot),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({required this.booking, required this.pitchName});

  final Booking booking;
  final String pitchName;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancel() async {
    final booking = widget.booking;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.cancelDialogTitle),
        content: Text(isAppBooking(booking) ? S.ownerCancelWarnApp : S.ownerCancelWarnOther),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text(S.cancelDismiss)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.tokens.danger,
              foregroundColor: dialogContext.tokens.onDanger,
              minimumSize: const Size(0, 48),
            ),
            child: const Text(S.cancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(ownerActionsProvider).cancel(booking), S.ownerCancelled);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final now = DateTime.now();
    final isApp = isAppBooking(booking);
    final contact = isApp && booking.userId != null ? ref.watch(ownerContactProvider(booking.userId!)) : null;

    String? name;
    String? phone;
    if (isApp) {
      name = contact?.valueOrNull?.fullName;
      phone = contact?.valueOrNull?.phone;
    } else {
      name = booking.customerName;
      phone = booking.customerPhone;
    }
    final callUrl = telUrl(phone);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(ownerSourceLabelOf(booking), style: theme.textTheme.headlineSmall)),
                StatusChip(status: booking.displayStatus(now)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${widget.pitchName} · ${formatIstanbulDateWithWeekday(booking.startsAt)}', style: theme.textTheme.bodySmall),
            Text(
              formatTimeRange(booking.startsAt, booking.endsAt),
              style: numericStyle(context, size: 24, weight: FontWeight.w700, color: tokens.brand),
            ),
            const SizedBox(height: AppSpacing.l),
            if (!isBlockBooking(booking)) ...[
              _InfoRow(
                label: S.customerLabel,
                child: contact != null && contact.isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        (name == null || name.isEmpty) ? (isApp ? S.contactUnavailable : '-') : name,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
              ),
              if (phone != null && phone.isNotEmpty)
                _InfoRow(
                  label: S.phoneRowLabel,
                  child: Text(formatPhoneDisplay(phone), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              _InfoRow(
                label: S.priceRowLabel,
                child: Text(formatTry(booking.priceKurus), style: numericStyle(context, size: 18)),
              ),
              if (isApp)
                _InfoRow(
                  label: S.depositRowLabel,
                  child: Text(formatTry(booking.depositKurus), style: numericStyle(context, size: 18)),
                ),
            ],
            if (booking.note != null && booking.note!.isNotEmpty)
              _InfoRow(label: S.noteRowLabel, child: Text(booking.note!, style: theme.textTheme.bodyMedium)),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger)),
            ],
            const SizedBox(height: AppSpacing.l),
            if (callUrl != null)
              OutlinedButton.icon(
                onPressed: () => openExternalOrWarn(context, callUrl),
                icon: const Icon(Icons.phone_outlined),
                label: const Text(S.callCustomer),
              ),
            if (canMarkAttendance(booking, now)) ...[
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: S.attended,
                      icon: Icons.check,
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => ref.read(ownerActionsProvider).markAttendance(booking, attended: true),
                                S.attendanceSaved,
                              ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                                () => ref.read(ownerActionsProvider).markAttendance(booking, attended: false),
                                S.attendanceSaved,
                              ),
                      child: const Text(S.notAttended),
                    ),
                  ),
                ],
              ),
            ],
            if (canOwnerCancel(booking, now)) ...[
              const SizedBox(height: AppSpacing.m),
              OutlinedButton.icon(
                onPressed: _busy ? null : _confirmCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.danger,
                  side: BorderSide(color: tokens.danger),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(S.cancelBooking),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Name for the sheet header; manual bookings read "Telefon rezervasyonu", closed slots "Kapalı saat".
String ownerSourceLabelOf(Booking b) {
  if (isBlockBooking(b)) return S.sourceBlock;
  if (isManualBooking(b)) return S.sourceManual;
  return S.sourceApp;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: child),
        ],
      ),
    );
  }
}
