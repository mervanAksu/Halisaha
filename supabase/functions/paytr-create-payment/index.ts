// POST { booking_id } (customer JWT) → { iframe_url, merchant_oid, hold_expires_at }
// Starts a PayTR iFrame payment for a held booking. Amount always comes from the DB.
import { adminClient, callerId, clientIp, corsHeaders, errorResponse, json, rpcErrorCode } from "../_shared/http.ts";
import { base64Utf8, hmacBase64, kurusToTl, paytrConfig, sha256Hex } from "../_shared/paytr.ts";

const PAYTR_TOKEN_URL = "https://www.paytr.com/odeme/api/get-token";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("method_not_allowed", 405);

  const userId = await callerId(req);
  if (!userId) return errorResponse("not_authenticated", 401);

  let bookingId: string | undefined;
  try {
    bookingId = (await req.json())?.booking_id;
  } catch { /* fallthrough */ }
  if (!bookingId) return errorResponse("booking_not_found", 400);

  const db = adminClient();
  const cfg = paytrConfig();

  // 1) Register the attempt (validates owner, status, hold expiry) — atomic in SQL.
  const { data: payment, error: startErr } = await db.rpc("start_payment", {
    p_booking_id: bookingId, p_user_id: userId,
  }).single<{ id: string; merchant_oid: string; amount_kurus: number }>();
  if (startErr || !payment) return errorResponse(rpcErrorCode(startErr), 409);

  // 2) Context for the basket and the payer fields PayTR requires.
  const { data: booking } = await db
    .from("bookings")
    .select("starts_at, hold_expires_at, pitches(name), venues(name)")
    .eq("id", bookingId)
    .single<{ starts_at: string; hold_expires_at: string; pitches: { name: string }; venues: { name: string } }>();
  const { data: profile } = await db
    .from("profiles").select("full_name, phone, email").eq("id", userId)
    .single<{ full_name: string; phone: string | null; email: string | null }>();

  const userIp = clientIp(req);
  // PayTR requires an e-mail; phone-only users get a pseudonymous placeholder (S-16: no raw user id leaves us).
  const alias = (await sha256Hex(userId + (Deno.env.get("PSEUDONYM_SALT") ?? ""))).slice(0, 20);
  const email = profile?.email ?? `u${alias}@${Deno.env.get("PAYTR_PLACEHOLDER_EMAIL_DOMAIN") ?? "users.example.com"}`;
  const amount = String(payment.amount_kurus);
  const basket = base64Utf8(JSON.stringify([
    [`Kapora - ${booking?.venues.name ?? "Halı saha"} ${booking?.pitches.name ?? ""}`.trim(), kurusToTl(payment.amount_kurus), 1],
  ]));
  const noInstallment = "1";
  const maxInstallment = "0";
  const currency = "TL";

  const token = await hmacBase64(
    cfg.merchantId + userIp + payment.merchant_oid + email + amount + basket + noInstallment +
      maxInstallment + currency + cfg.testMode + cfg.merchantSalt,
    cfg.merchantKey,
  );

  const resultBase = Deno.env.get("PAYMENT_RESULT_BASE_URL") ?? "https://example.com/payment/result";
  const form = new URLSearchParams({
    merchant_id: cfg.merchantId,
    user_ip: userIp,
    merchant_oid: payment.merchant_oid,
    email,
    payment_amount: amount,
    paytr_token: token,
    user_basket: basket,
    debug_on: cfg.testMode,
    no_installment: noInstallment,
    max_installment: maxInstallment,
    user_name: profile?.full_name || "Halısaha Kullanıcısı",
    user_address: "Türkiye",
    user_phone: profile?.phone ?? "0000000000",
    merchant_ok_url: `${resultBase}?status=ok&oid=${payment.merchant_oid}`,
    merchant_fail_url: `${resultBase}?status=fail&oid=${payment.merchant_oid}`,
    timeout_limit: "10",
    currency,
    test_mode: cfg.testMode,
    lang: "tr",
    // VERIFY(paytr): marketplace (pazaryeri) split fields for the venue's sub-merchant go here once
    // the PayTR marketplace contract/docs are received (see docs/PAYMENTS_PAYTR.md §Pazaryeri).
  });

  let tokenRes: { status?: string; token?: string; reason?: string };
  try {
    const res = await fetch(PAYTR_TOKEN_URL, { method: "POST", body: form });
    tokenRes = await res.json();
  } catch (e) {
    console.error("paytr get-token network error", String(e));
    tokenRes = { status: "failed", reason: "network" };
  }

  if (tokenRes.status !== "success" || !tokenRes.token) {
    console.error("paytr get-token failed", { merchant_oid: payment.merchant_oid, reason: tokenRes.reason });
    await db.from("payments").update({ status: "failed", failed_reason: `get-token: ${tokenRes.reason ?? "unknown"}` })
      .eq("id", payment.id).eq("status", "initiated");
    return errorResponse("payment_provider_error", 502);
  }

  return json({
    iframe_url: `https://www.paytr.com/odeme/guvenli/${tokenRes.token}`,
    merchant_oid: payment.merchant_oid,
    hold_expires_at: booking?.hold_expires_at,
  });
});
