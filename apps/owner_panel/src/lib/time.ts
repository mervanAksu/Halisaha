// Turkey is fixed UTC+3 (no DST). Store UTC, display Europe/Istanbul.
export const TZ = 'Europe/Istanbul';
export const TZ_OFFSET = '+03:00';
export const DAY_MS = 24 * 60 * 60 * 1000;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isDateString(v: string | null | undefined): v is string {
  if (!v || !DATE_RE.test(v)) return false;
  const d = new Date(`${v}T12:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
}

/** Today's date (YYYY-MM-DD) in Istanbul. */
export function todayIstanbul(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** ISO weekday of a calendar date: 1 = Monday … 7 = Sunday. */
export function isoWeekday(date: string): number {
  const day = new Date(`${date}T12:00:00Z`).getUTCDay();
  return day === 0 ? 7 : day;
}

/** 'HH:MM' | 'HH:MM:SS' -> 'HH:MM:SS' */
export function normalizeTime(t: string): string {
  return t.length === 5 ? `${t}:00` : t;
}

/** 'HH:MM:SS' -> 'HH:MM' */
export function shortTime(t: string): string {
  return t.slice(0, 5);
}

/** Local Istanbul date + time -> timestamptz string with explicit offset. */
export function toTimestamptz(date: string, time: string): string {
  return `${date}T${normalizeTime(time)}${TZ_OFFSET}`;
}

export function toEpoch(date: string, time: string): number {
  return Date.parse(toTimestamptz(date, time));
}

type DateInput = string | number | Date;

export function formatTime(value: DateInput): string {
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(value));
}

export function formatDateTime(value: DateInput): string {
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: TZ,
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(value));
}

/** "Cuma, 20 Kasım 2026" for a YYYY-MM-DD business date. */
export function formatDateLong(date: string): string {
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: TZ,
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(new Date(`${date}T12:00:00${TZ_OFFSET}`));
}
