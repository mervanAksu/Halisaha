export function normalizeIban(input: string): string {
  return input.replace(/\s+/g, '').toUpperCase();
}

/** TR + 24 digits and a valid ISO 13616 mod-97 checksum. */
export function isValidIban(raw: string): boolean {
  const iban = normalizeIban(raw);
  if (!/^TR\d{24}$/.test(iban)) return false;
  const rearranged = iban.slice(4) + iban.slice(0, 4);
  let remainder = 0;
  for (const ch of rearranged) {
    const code = ch.charCodeAt(0);
    const expanded = code >= 65 ? String(code - 55) : ch; // A=10 … Z=35
    for (const d of expanded) {
      remainder = (remainder * 10 + Number(d)) % 97;
    }
  }
  return remainder === 1;
}

export function formatIban(iban: string): string {
  return normalizeIban(iban).replace(/(.{4})/g, '$1 ').trim();
}

/** VKN (10 digits) or TCKN (11 digits). */
export function isValidTaxNumber(v: string): boolean {
  return /^(\d{10}|\d{11})$/.test(v);
}
