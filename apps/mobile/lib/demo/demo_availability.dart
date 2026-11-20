import '../core/utils/formatters.dart';
import '../features/venues/domain/pitch.dart';
import '../features/venues/domain/slot.dart';
import 'demo_data.dart';

/// Mirrors the server: slots starting within the next 15 minutes are `past`.
const Duration demoPastCutoff = Duration(minutes: 15);

/// Share of slots (percent) that the generator marks as already booked.
const int demoBookedPercent = 35;

/// Deterministic pseudo-random number in 0..99 for a slot. Pure integer maths kept below 2^40 so the
/// result is identical on the Dart VM and in dart2js.
int demoSlotRoll(String isoDate, String pitchId, DateTime slotStart) {
  final key = '$isoDate|$pitchId|${slotStart.toUtc().millisecondsSinceEpoch ~/ 60000}';
  var h = 7;
  for (final unit in key.codeUnits) {
    h = (h * 131 + unit) % 2147483647;
  }
  // Extra avalanche step so neighbouring slots do not share a pattern.
  h = (h ^ (h >> 7)) % 2147483647;
  h = (h * 31 + 17) % 2147483647;
  return (h >> 3) % 100;
}

/// Slots of one business day, like RPC `get_availability`.
///
///  * [isoDate] is the venue business day (`yyyy-MM-dd`); an overnight venue (12:00-06:00)
///    returns slots up to 05:00-06:00 of the *next* calendar day.
///  * state `past` when `start <= now + 15 min`, otherwise `booked` when [isTaken] says so
///    (the user's own demo bookings) or the seeded roll marks it, else `available`.
///  * Output depends only on the arguments, never on a clock or global state.
List<Slot> generateDemoSlots({
  required DemoVenue venue,
  required Pitch pitch,
  required String isoDate,
  required DateTime now,
  bool Function(DateTime start, DateTime end)? isTaken,
}) {
  final parts = isoDate.split('-').map(int.parse).toList();
  final midnightIstanbulAsUtc = DateTime.utc(parts[0], parts[1], parts[2]);
  final open = midnightIstanbulAsUtc.add(Duration(minutes: venue.openMinutes)).subtract(istanbulOffset);
  var close = midnightIstanbulAsUtc.add(Duration(minutes: venue.closeMinutes)).subtract(istanbulOffset);
  if (venue.closeMinutes <= venue.openMinutes) close = close.add(const Duration(days: 1));

  final step = Duration(minutes: pitch.slotMinutes);
  final price = pitch.hourlyPriceKurus * pitch.slotMinutes ~/ 60;
  final cutoff = now.toUtc().add(demoPastCutoff);
  final slots = <Slot>[];
  for (var start = open; !start.add(step).isAfter(close); start = start.add(step)) {
    final end = start.add(step);
    final SlotState state;
    if (!start.isAfter(cutoff)) {
      state = SlotState.past;
    } else if ((isTaken?.call(start, end) ?? false) || demoSlotRoll(isoDate, pitch.id, start) < demoBookedPercent) {
      state = SlotState.booked;
    } else {
      state = SlotState.available;
    }
    slots.add(Slot(
      startsAt: start,
      endsAt: end,
      state: state,
      priceKurus: price,
      depositKurus: pitch.depositKurus,
    ));
  }
  return slots;
}
