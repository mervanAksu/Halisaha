import { DAY_MS, normalizeTime, toEpoch } from '@/lib/time';

export const ROW_MINUTES = 30;
export const ROW_MS = ROW_MINUTES * 60_000;

export type DayWindow = { openMs: number; closeMs: number };
export type Slot = { startMs: number; endMs: number };

/** Business-day window for a date; close <= open means closing after midnight. */
export function dayWindow(date: string, openTime: string, closeTime: string): DayWindow {
  const openMs = toEpoch(date, openTime);
  let closeMs = toEpoch(date, closeTime);
  if (normalizeTime(closeTime) <= normalizeTime(openTime)) closeMs += DAY_MS;
  return { openMs, closeMs };
}

/** Same slot generation as the DB's get_availability(): open, open+step, … while slot fits before close. */
export function generateSlots(win: DayWindow, slotMinutes: number): Slot[] {
  const step = slotMinutes * 60_000;
  const slots: Slot[] = [];
  for (let s = win.openMs; s + step <= win.closeMs; s += step) {
    slots.push({ startMs: s, endMs: s + step });
  }
  return slots;
}
