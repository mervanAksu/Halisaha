'use server';

import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { fail, type ActionState } from '@/lib/action-state';
import { str } from '@/lib/form';

export type EnrollResult =
  | { ok: true; factorId: string; qrCode: string; secret: string }
  | { ok: false; message: string };

/** Starts TOTP enrollment (drops stale unverified factors first). The factor is inactive until verified. */
export async function enrollTotp(): Promise<EnrollResult> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false, message: 'Devam etmek için giriş yapmalısın.' };

  const { data: factors } = await supabase.auth.mfa.listFactors();
  for (const f of factors?.all ?? []) {
    if (f.factor_type === 'totp' && f.status === 'unverified') {
      await supabase.auth.mfa.unenroll({ factorId: f.id });
    }
  }

  const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp' });
  if (error || !data) return { ok: false, message: 'Doğrulama kurulumu başlatılamadı. Tekrar dene.' };
  return { ok: true, factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret };
}

const NEXT_PATHS = ['/calendar', '/security'];

/** Challenge + verify a 6-digit code, upgrading the session to aal2. */
export async function verifyTotp(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const factorId = str(formData, 'factorId');
  const code = str(formData, 'code').replace(/\s/g, '');
  const requested = str(formData, 'next');
  const next = NEXT_PATHS.includes(requested) ? requested : '/calendar';

  if (!factorId) return fail('Geçersiz istek.');
  if (!/^\d{6}$/.test(code)) return fail('6 haneli kodu gir.');

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return fail('Devam etmek için giriş yapmalısın.');

  const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
  if (error) return fail('Kod hatalı veya süresi dolmuş. Tekrar dene.');

  redirect(next);
}
