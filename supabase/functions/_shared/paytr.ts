// PayTR helpers shared by the paytr-* functions. Reference: docs/PAYMENTS_PAYTR.md
// Secrets (supabase secrets set ...): PAYTR_MERCHANT_ID, PAYTR_MERCHANT_KEY, PAYTR_MERCHANT_SALT, PAYTR_TEST_MODE

const enc = new TextEncoder();

export interface PaytrConfig {
  merchantId: string;
  merchantKey: string;
  merchantSalt: string;
  testMode: "0" | "1";
}

export function paytrConfig(): PaytrConfig {
  const merchantId = Deno.env.get("PAYTR_MERCHANT_ID");
  const merchantKey = Deno.env.get("PAYTR_MERCHANT_KEY");
  const merchantSalt = Deno.env.get("PAYTR_MERCHANT_SALT");
  if (!merchantId || !merchantKey || !merchantSalt) {
    throw new Error("PayTR secrets are not configured");
  }
  // S-01: never default silently — a missing/typo'd value must stop payments, not run them in test mode.
  const mode = Deno.env.get("PAYTR_TEST_MODE");
  if (mode !== "0" && mode !== "1") throw new Error("PAYTR_TEST_MODE must be explicitly '0' or '1'");
  return { merchantId, merchantKey, merchantSalt, testMode: mode };
}

/** base64(HMAC-SHA256(message, key)) — PayTR's token/hash format. */
export async function hmacBase64(message: string, key: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw", enc.encode(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(message)));
  let bin = "";
  for (const b of sig) bin += String.fromCharCode(b);
  return btoa(bin);
}

/** Constant-time string comparison (avoid leaking hash prefixes through timing). */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** UTF-8 safe base64 for the user_basket JSON (Turkish characters). */
export function base64Utf8(s: string): string {
  let bin = "";
  for (const b of enc.encode(s)) bin += String.fromCharCode(b);
  return btoa(bin);
}

/** 50000 kuruş → "500.00" (PayTR basket and refund amounts use TL with a dot). */
export function kurusToTl(kurus: number): string {
  return `${Math.floor(kurus / 100)}.${String(kurus % 100).padStart(2, "0")}`;
}

/** Hex SHA-256 (for pseudonymous identifiers sent to third parties). */
export async function sha256Hex(s: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)));
  return Array.from(d, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Hash PayTR sends to the callback URL. */
export function callbackHash(
  cfg: PaytrConfig, merchantOid: string, status: string, totalAmount: string,
): Promise<string> {
  return hmacBase64(merchantOid + cfg.merchantSalt + status + totalAmount, cfg.merchantKey);
}
