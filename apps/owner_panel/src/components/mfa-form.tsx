'use client';

import { useActionState, useState } from 'react';
import { enrollTotp, verifyTotp } from '@/actions/mfa';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';

type Props = {
  /** Existing verified TOTP factor (challenge flow). When null the user enrolls a new one. */
  factorId: string | null;
  next: string;
};

function CodeForm({ factorId, next }: { factorId: string; next: string }) {
  const [state, action] = useActionState<ActionState, FormData>(verifyTotp, null);
  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="factorId" value={factorId} />
      <input type="hidden" name="next" value={next} />
      <div>
        <label htmlFor="code" className="label">6 haneli doğrulama kodu</label>
        <input
          id="code"
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          pattern="\d{6}"
          maxLength={6}
          required
          className="input"
        />
      </div>
      <FormMessage state={state} />
      <SubmitButton className="btn-primary w-full" pendingLabel="Doğrulanıyor…">Doğrula</SubmitButton>
    </form>
  );
}

export function MfaForm({ factorId, next }: Props) {
  const [enroll, setEnroll] = useState<{ factorId: string; qrCode: string; secret: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (factorId) return <CodeForm factorId={factorId} next={next} />;

  if (enroll) {
    return (
      <div className="space-y-4">
        <p className="text-sm">
          Authenticator uygulamanla (Google Authenticator, Microsoft Authenticator vb.) QR kodu tara, sonra
          uygulamadaki 6 haneli kodu gir.
        </p>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={enroll.qrCode} alt="İki adımlı doğrulama QR kodu" width={192} height={192} className="mx-auto rounded-xl border border-border" />
        <p className="text-xs text-textSecondary">
          QR kodu okutamıyorsan bu anahtarı elle gir: <code className="break-all">{enroll.secret}</code>
        </p>
        <CodeForm factorId={enroll.factorId} next={next} />
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {error ? <p role="alert" className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">{error}</p> : null}
      <button
        type="button"
        className="btn-primary w-full"
        disabled={busy}
        onClick={async () => {
          setBusy(true);
          setError(null);
          const res = await enrollTotp();
          setBusy(false);
          if (res.ok) setEnroll({ factorId: res.factorId, qrCode: res.qrCode, secret: res.secret });
          else setError(res.message);
        }}
      >
        {busy ? 'Hazırlanıyor…' : 'Kurulumu başlat'}
      </button>
    </div>
  );
}
