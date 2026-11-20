// POST {} (customer JWT) → 204. In-app account deletion (Apple 5.1.1(v), KVKK).
import { adminClient, callerId, corsHeaders, errorResponse, rpcErrorCode } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("method_not_allowed", 405);

  const userId = await callerId(req);
  if (!userId) return errorResponse("not_authenticated", 401);

  const db = adminClient();
  const { error: prepErr } = await db.rpc("prepare_account_deletion", { p_user_id: userId });
  if (prepErr) return errorResponse(rpcErrorCode(prepErr), 409);

  // Cascades: profiles, favorites, device_tokens. bookings/payments keep anonymised rows.
  const { error: delErr } = await db.auth.admin.deleteUser(userId);
  if (delErr) {
    console.error("delete-account: deleteUser failed", { userId, message: delErr.message });
    return errorResponse("unknown_error", 500);
  }
  return new Response(null, { status: 204, headers: corsHeaders });
});
