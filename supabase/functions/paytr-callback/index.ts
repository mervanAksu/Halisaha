// PayTR server-to-server notification ("Bildirim URL"). No JWT: deploy with --no-verify-jwt.
// Trust comes only from the HMAC hash. Must answer plain "OK" or PayTR keeps retrying.
import { adminClient } from "../_shared/http.ts";
import { callbackHash, paytrConfig, safeEqual } from "../_shared/paytr.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  // S-08: bounded, well-formed input only.
  const ct = req.headers.get("content-type") ?? "";
  const len = Number(req.headers.get("content-length") ?? "-1");
  if (!ct.startsWith("application/x-www-form-urlencoded") || !(len >= 0 && len <= 8192)) {
    return new Response("bad request", { status: 400 });
  }
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return new Response("bad request", { status: 400 });
  }
  const field = (k: string) => String(form.get(k) ?? "").slice(0, 512);
  const merchantOid = field("merchant_oid");
  const status = field("status");             // "success" | "failed"
  const totalAmount = field("total_amount");  // kuruş, may include installment interest
  const hash = field("hash");

  if (!/^[A-Za-z0-9]{1,64}$/.test(merchantOid) || !/^\d{1,12}$/.test(totalAmount)) {
    return new Response("bad request", { status: 400 });
  }

  const cfg = paytrConfig();
  const expected = await callbackHash(cfg, merchantOid, status, totalAmount);
  if (!safeEqual(expected, hash)) {
    console.warn("paytr callback: bad hash", { merchantOid });
    return new Response("PAYTR notification failed: bad hash", { status: 400 });
  }

  // Keep a non-sensitive copy of the notification (PayTR never sends card data here).
  const payload: Record<string, string> = {};
  for (const k of ["status", "total_amount", "payment_amount", "payment_type", "currency",
                   "installment_count", "failed_reason_code", "failed_reason_msg", "test_mode"]) {
    if (form.has(k)) payload[k] = field(k);
  }

  // S-01: a test-mode notification must never confirm a booking on a live configuration.
  const testOnLive = cfg.testMode === "0" && field("test_mode") === "1";
  if (testOnLive) {
    console.error("paytr callback: test-mode notification on live config", { merchantOid });
    payload.failed_reason_msg = "test_mode_on_live";
  }

  const { data, error } = await adminClient().rpc("confirm_payment", {
    p_merchant_oid: merchantOid,
    p_success: status === "success" && !testOnLive,
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
