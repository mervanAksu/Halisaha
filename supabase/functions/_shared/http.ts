import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(code: string, status = 400): Response {
  return json({ error: code }, status);
}

/** Service-role client. Never expose this key to clients. */
export function adminClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Resolves the calling user from the Authorization header, or null. */
export async function callerId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const { data, error } = await adminClient().auth.getUser(auth.slice("Bearer ".length));
  if (error || !data.user) return null;
  return data.user.id;
}

/**
 * S-09: client IP for PayTR's fraud checks. The left-most X-Forwarded-For entry is client-controlled;
 * prefer the platform-set header, else the right-most XFF hop. VERIFY on Supabase which header carries it.
 */
export function clientIp(req: Request): string {
  const real = req.headers.get("x-real-ip") ?? req.headers.get("cf-connecting-ip");
  if (real && /^[0-9a-fA-F:.]{3,45}$/.test(real)) return real;
  const hops = (req.headers.get("x-forwarded-for") ?? "").split(",").map((h) => h.trim()).filter(Boolean);
  const last = hops.at(-1);
  return last && /^[0-9a-fA-F:.]{3,45}$/.test(last) ? last : "127.0.0.1";
}

/** Claims of the caller's JWT (already verified by the gateway / getUser). */
export function jwtClaims(req: Request): Record<string, unknown> {
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
    const payload = token.split(".")[1] ?? "";
    return JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")));
  } catch {
    return {};
  }
}

/** S-12: true when the caller completed an OTP/password sign-in within the last `maxAgeSec` seconds. */
export function recentlyAuthenticated(req: Request, maxAgeSec = 600): boolean {
  const amr = jwtClaims(req).amr as Array<{ method?: string; timestamp?: number }> | undefined;
  const now = Math.floor(Date.now() / 1000);
  return Array.isArray(amr) && amr.some((m) => typeof m.timestamp === "number" && now - m.timestamp <= maxAgeSec);
}

/** Extracts a stable error code raised by our RPCs (`raise exception 'slot_taken'`). */
export function rpcErrorCode(err: { message?: string } | null): string {
  const m = err?.message ?? "";
  return /^[a-z_]+$/.test(m) ? m : "unknown_error";
}
