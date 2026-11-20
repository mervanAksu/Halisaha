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

/** Extracts a stable error code raised by our RPCs (`raise exception 'slot_taken'`). */
export function rpcErrorCode(err: { message?: string } | null): string {
  const m = err?.message ?? "";
  return /^[a-z_]+$/.test(m) ? m : "unknown_error";
}
