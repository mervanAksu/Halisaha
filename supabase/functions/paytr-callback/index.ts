// PayTR server-to-server notification ("Bildirim URL"). No JWT: deploy with --no-verify-jwt.
// Trust comes only from the HMAC hash. Must answer plain "OK" or PayTR keeps retrying.
import { adminClient } from "../_shared/http.ts";
import { callbackHash, paytrConfig, safeEqual } from "../_shared/paytr.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const form = await req.formData();
  const field = (k: string) => String(form.get(k) ?? "");
  const merchantOid = field("merchant_oid");
  const status = field("status");             // "success" | "failed"
  const totalAmount = field("total_amount");  // kuruş, may include installment interest
  const hash = field("hash");

  const cfg = paytrConfig();
  const expected = await callbackHash(cfg, merchantOid, status, totalAmount);
  if (!merchantOid || !safeEqual(expected, hash)) {
    console.warn("paytr callback: bad hash", { merchantOid });
    return new Response("PAYTR notification failed: bad hash", { status: 400 });
  }

  // Keep a non-sensitive copy of the notification (PayTR never sends card data here).
  const payload: Record<string, string> = {};
  for (const k of ["status", "total_amount", "payment_amount", "payment_type", "currency",
                   "installment_count", "failed_reason_code", "failed_reason_msg", "test_mode"]) {
    if (form.has(k)) payload[k] = field(k);
  }

  const { data, error } = await adminClient().rpc("confirm_payment", {
    p_merchant_oid: merchantOid,
    p_success: status === "success",
    p_total_amount_kurus: Number.parseInt(totalAmount, 10) || 0,
    p_payload: payload,
  });

  if (error) {
    // Unknown merchant_oid or DB outage: return non-OK so PayTR retries later.
    console.error("paytr callback: confirm_payment failed", { merchantOid, message: error.message });
    return new Response("ERROR", { status: 500 });
  }

  console.log("paytr callback processed", { merchantOid, result: data });
  // refund_required results are picked up by the paytr-refund job.
  return new Response("OK", { headers: { "Content-Type": "text/plain" } });
});
