import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../venues/domain/pitch.dart';
import '../domain/owner_logic.dart';
import '../domain/owner_models.dart';
import 'owner_common.dart';
import 'owner_providers.dart';
import 'owner_account_button.dart';

/// "Sahalarım": price, deposit and active switch of each pitch.
class OwnerPitchesScreen extends ConsumerWidget {
  const OwnerPitchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.ownerTabPitches), actions: const [OwnerAccountButton()]),
      body: OwnerVenueScope(
        builder: (context, venue, switcher) => Column(
          children: [
            switcher,
            const SizedBox(height: AppSpacing.s),
            Expanded(child: _PitchList(venue: venue)),
          ],
        ),
      ),
    );
  }
}

class _PitchList extends ConsumerWidget {
  const _PitchList({required this.venue});

  final OwnerVenue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pitchesAsync = ref.watch(ownerPitchesProvider(venue.id));
    return pitchesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: AppException.from(e).message,
        onRetry: () => ref.invalidate(ownerPitchesProvider(venue.id)),
      ),
      data: (pitches) {
        if (pitches.isEmpty) {
          return const EmptyState(icon: Icons.sports_soccer, message: S.ownerNoPitches);
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownerPitchesProvider(venue.id));
            try {
              await ref.read(ownerPitchesProvider(venue.id).future);
            } catch (_) {
              // The error state is rendered by the list itself.
            }
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.l),
            itemCount: pitches.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.m),
            itemBuilder: (context, i) => _PitchCard(pitch: pitches[i]),
          ),
        );
      },
    );
  }
}

class _PitchCard extends ConsumerStatefulWidget {
  const _PitchCard({required this.pitch});

  final Pitch pitch;

  @override
  ConsumerState<_PitchCard> createState() => _PitchCardState();
}

class _PitchCardState extends ConsumerState<_PitchCard> {
  bool _busy = false;

  Future<void> _toggleActive(bool value) async {
    final pitch = widget.pitch;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(ownerActionsProvider).updatePitch(
            pitch: pitch,
            hourlyPriceKurus: pitch.hourlyPriceKurus,
            depositKurus: pitch.depositKurus,
            isActive: value,
          );
      messenger.showSnackBar(const SnackBar(content: Text(S.pitchUpdated)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditPitchSheet(pitch: widget.pitch),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.pitchUpdated)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pitch = widget.pitch;
    final t = context.tokens;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
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
              Expanded(child: Text(S.pitchLabel(pitch.name, pitch.format), style: theme.textTheme.titleMedium)),
              Switch(value: pitch.isActive, onChanged: _busy ? null : _toggleActive),
            ],
          ),
          Text(pitch.isActive ? S.activeLabel : S.inactiveLabel, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(child: _Amount(label: S.hourlyPriceLabel, kurus: pitch.hourlyPriceKurus)),
              Expanded(child: _Amount(label: S.depositLabel, kurus: pitch.depositKurus)),
              IconButton(
                tooltip: S.editPitch,
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.kurus});

  final String label;
  final int kurus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(formatTry(kurus), style: numericStyle(context, size: 22, weight: FontWeight.w700)),
      ],
    );
  }
}

class _EditPitchSheet extends ConsumerStatefulWidget {
  const _EditPitchSheet({required this.pitch});

  final Pitch pitch;

  @override
  ConsumerState<_EditPitchSheet> createState() => _EditPitchSheetState();
}

class _EditPitchSheetState extends ConsumerState<_EditPitchSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _price = TextEditingController(text: '${widget.pitch.hourlyPriceKurus ~/ 100}');
  late final TextEditingController _deposit = TextEditingController(text: '${widget.pitch.depositKurus ~/ 100}');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(ownerActionsProvider).updatePitch(
            pitch: widget.pitch,
            hourlyPriceKurus: parseLiraToKurus(_price.text)!,
            depositKurus: parseLiraToKurus(_deposit.text)!,
            isActive: widget.pitch.isActive,
          );
      navigator.pop(true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text(widget.pitch.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.l),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: appInputDecoration(context, label: S.hourlyPriceLabel),
                validator: (v) {
                  final kurus = parseLiraToKurus(v ?? '');
                  return kurus == null || kurus <= 0 ? S.amountInvalid : null;
                },
              ),
              const SizedBox(height: AppSpacing.m),
              TextFormField(
                controller: _deposit,
                keyboardType: TextInputType.number,
                decoration: appInputDecoration(context, label: S.depositLabel),
                validator: (v) {
                  final deposit = parseLiraToKurus(v ?? '');
                  final price = parseLiraToKurus(_price.text);
                  if (deposit == null) return S.amountInvalid;
                  if (price != null &&
                      !depositWithinPrice(
                        depositKurus: deposit,
                        hourlyPriceKurus: price,
                        slotMinutes: widget.pitch.slotMinutes,
                      )) {
                    return S.depositTooHigh;
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s),
                Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.danger)),
              ],
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(label: S.save, loading: _busy, onPressed: _busy ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}
