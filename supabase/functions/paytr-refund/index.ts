// Refund job: refunds payments in status 'refund_required' through PayTR's refund API.
// Triggered by pg_cron/pg_net or an external scheduler with header `x-cron-secret: $CRON_SECRET`.
import { adminClient, json } from "../_shared/http.ts";
import { hmacBase64, kurusToTl, paytrConfig, safeEqual } from "../_shared/paytr.ts";

const PAYTR_REFUND_URL = "https://www.paytr.com/odeme/iade"; // VERIFY(paytr): confirm endpoint for marketplace accounts

Deno.serve(async (req) => {
  const secret = Deno.env.get("CRON_SECRET") ?? "";
  if (!secret || !safeEqual(req.headers.get("x-cron-secret") ?? "", secret)) {
    return new Response("forbidden", { status: 403 });
  }

  const cfg = paytrConfig();
  const db = adminClient();
  const { data: pending, error } = await db
    .from("payments").select("id, merchant_oid, amount_kurus")
    .eq("status", "refund_required").order("updated_at").limit(20);
  if (error) return json({ error: error.message }, 500);

  const results: Array<{ merchant_oid: string; ok: boolean; reason?: string }> = [];
  for (const p of pending ?? []) {
    const returnAmount = kurusToTl(p.amount_kurus);
    const token = await hmacBase64(cfg.merchantId + p.merchant_oid + returnAmount + cfg.merchantSalt, cfg.merchantKey);
    try {
      const res = await fetch(PAYTR_REFUND_URL, {
        method: "POST",
        body: new URLSearchParams({
          merchant_id: cfg.merchantId, merchant_oid: p.merchant_oid, return_amount: returnAmount, paytr_token: token,
        }),
      });
      const body = await res.json() as { status?: string; err_msg?: string };
      if (body.status === "success") {
        await db.rpc("mark_refunded", { p_payment_id: p.id, p_payload: body });
        results.push({ merchant_oid: p.merchant_oid, ok: true });
      } else {
        results.push({ merchant_oid: p.merchant_oid, ok: false, reason: body.err_msg });
      }
    } catch (e) {
      results.push({ merchant_oid: p.merchant_oid, ok: false, reason: String(e) });
    }
  }
  console.log("paytr refunds", results);
  return json({ processed: results.length, results });
});
