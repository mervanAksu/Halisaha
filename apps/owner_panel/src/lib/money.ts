/** 350000 -> "3.500 ₺"; 350050 -> "3.500,50 ₺". Money is always integer kuruş. */
export function formatTry(kurus: number): string {
  const whole = kurus % 100 === 0;
  const text = new Intl.NumberFormat('tr-TR', {
    minimumFractionDigits: whole ? 0 : 2,
    maximumFractionDigits: whole ? 0 : 2,
    useGrouping: true,
  }).format(kurus / 100);
  return `${text} ₺`;
}

/**
 * Parses a TL amount typed by a person into integer kuruş without floats.
 * Accepts "3500", "3.500", "3500,50", "3500.5", "3.500,50 ₺". Returns null when invalid.
 */
export function parseTryToKurus(input: string): number | null {
  let s = input.replace(/\s|₺|TL/gi, '');
  if (s === '') return null;
  if (s.includes(',')) {
    s = s.replace(/\./g, '').replace(',', '.');
  } else if (/^\d{1,3}(\.\d{3})+$/.test(s)) {
    s = s.replace(/\./g, '');
  }
  const m = /^(\d+)(?:\.(\d{1,2}))?$/.exec(s);
  if (!m) return null;
  const lira = Number(m[1]);
  const frac = Number((m[2] ?? '').padEnd(2, '0'));
  const kurus = lira * 100 + frac;
  return Number.isSafeInteger(kurus) && kurus <= 2_000_000_000 ? kurus : null;
}

/** Kuruş -> editable text for inputs ("3500" or "3500,50"). */
export function kurusToInput(kurus: number): string {
  const lira = Math.floor(kurus / 100);
  const frac = kurus % 100;
  return frac === 0 ? String(lira) : `${lira},${String(frac).padStart(2, '0')}`;
}
