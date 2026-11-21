import '../../../core/utils/formatters.dart';
import 'slot.dart';

/// Part of the day a slot belongs to (Istanbul wall clock).
enum SlotPeriod {
  /// 17:00-23:59
  evening,

  /// 12:00-16:59
  afternoon,

  /// 00:00-11:59 (morning, and the after-midnight hours of overnight venues)
  night,
}

/// Display order in the slot picker: Akşam first, then Öğleden sonra, then Sabah / Gece.
const List<SlotPeriod> slotPeriodOrder = <SlotPeriod>[SlotPeriod.evening, SlotPeriod.afternoon, SlotPeriod.night];

SlotPeriod slotPeriodOf(DateTime startsAt) {
  final hour = toIstanbul(startsAt).hour;
  if (hour >= 17) return SlotPeriod.evening;
  if (hour >= 12) return SlotPeriod.afternoon;
  return SlotPeriod.night;
}

class SlotGroup {
  const SlotGroup(this.period, this.slots);

  final SlotPeriod period;
  final List<Slot> slots;
}

/// Groups slots for the picker. Past slots are hidden, empty groups are dropped, and each group is
/// in chronological order (an overnight venue's 00:00-05:00 slots therefore follow its morning ones).
List<SlotGroup> groupSlots(List<Slot> slots) {
  final visible = slots.where((s) => s.state != SlotState.past).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final groups = <SlotGroup>[];
  for (final period in slotPeriodOrder) {
    final inPeriod = visible.where((s) => slotPeriodOf(s.startsAt) == period).toList();
    if (inPeriod.isNotEmpty) groups.add(SlotGroup(period, inPeriod));
  }
  return groups;
}

/// Text scale above which the slot grid drops from 3 to 2 columns (docs/DESIGN.md "Tipografi").
const double slotGridWideTextScale = 1.3;

int slotGridColumns(double textScale) => textScale > slotGridWideTextScale ? 2 : 3;

/// True when at least one slot can still be booked.
bool hasAvailableSlot(List<Slot> slots) => slots.any((s) => s.isAvailable);
