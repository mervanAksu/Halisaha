/** Trimmed string value of a form field ('' when missing or a File). */
export function str(fd: FormData, key: string): string {
  const v = fd.get(key);
  return typeof v === 'string' ? v.trim() : '';
}

/** Trimmed string or undefined when empty (for optional RPC args). */
export function optStr(fd: FormData, key: string): string | undefined {
  const v = str(fd, key);
  return v === '' ? undefined : v;
}

export function bool(fd: FormData, key: string): boolean {
  return fd.get(key) === 'on';
}

/** Parses a decimal number typed with '.' or ',' ; null when empty/invalid. */
export function parseNumber(input: string): number | null {
  const s = input.trim().replace(',', '.');
  if (s === '') return null;
  if (!/^-?\d+(\.\d+)?$/.test(s)) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}
