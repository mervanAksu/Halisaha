// Refund job: refunds payments in status 'refund_required' through PayTR's refund API.
// Triggered by pg_cron + pg_net (see docs/PAYMENTS_PAYTR.md) with header `x-cron-secret: $CRON_SECRET`.
// Rows are claimed atomically (refund_processing, SKIP LOCKED) so overlapping runs never double-refund.
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
  const { data: claimed, error } = await db.rpc("claim_refunds", { p_limit: 20 });
  if (error) return json({ error: error.message }, 500);

  const rows = (claimed ?? []) as Array<{ payment_id: string; merchant_oid: string; refund_amount_kurus: number }>;
  const results: Array<{ merchant_oid: string; ok: boolean; reason?: string }> = [];

  for (const p of rows) {
    const returnAmount = kurusToTl(p.refund_amount_kurus);
    const token = await hmacBase64(cfg.merchantId + p.merchant_oid + returnAmount + cfg.merchantSalt, cfg.merchantKey);
    let body: { status?: string; err_msg?: string } = {};
    try {
      const res = await fetch(PAYTR_REFUND_URL, {
        method: "POST",
        body: new URLSearchParams({
          merchant_id: cfg.merchantId, merchant_oid: p.merchant_oid, return_amount: returnAmount, paytr_token: token,
        }),
      });
      body = await res.json();
    } catch (e) {
      // Unknown outcome (network): leave it in refund_processing for a human to check — never auto-retry blindly.
      console.error("paytr refund: network error, left in refund_processing", { merchant_oid: p.merchant_oid, e: String(e) });
      results.push({ merchant_oid: p.merchant_oid, ok: false, reason: "network_unknown_outcome" });
      continue;
    }

    if (body.status === "success") {
      const { error: markErr } = await db.rpc("mark_refunded", { p_payment_id: p.payment_id, p_payload: body });
      if (markErr) {
        // Money went back but DB not updated: stays refund_processing (not re-sent). Alert via logs.
        console.error("paytr refund: refunded at PayTR but mark_refunded failed", { merchant_oid: p.merchant_oid, message: markErr.message });
      }
      results.push({ merchant_oid: p.merchant_oid, ok: true });
    } else {
      await db.rpc("release_refund_claim", { p_payment_id: p.payment_id, p_reason: body.err_msg ?? "rejected" });
      results.push({ merchant_oid: p.merchant_oid, ok: false, reason: body.err_msg });
    }
  }
  console.log("paytr refunds", results);
  return json({ processed: results.length, results });
});
