'use client';

import { useActionState } from 'react';
import { login } from '@/actions/auth';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';

export function LoginForm({ notice }: { notice: string | null }) {
  const [state, action] = useActionState<ActionState, FormData>(login, null);
  return (
    <form action={action} className="space-y-4">
      {notice ? <p role="alert" className="rounded-xl bg-warning/15 px-3 py-2 text-sm">{notice}</p> : null}
      <div>
        <label htmlFor="email" className="label">E-posta</label>
        <input id="email" name="email" type="email" autoComplete="email" required className="input" />
      </div>
      <div>
        <label htmlFor="password" className="label">Şifre</label>
        <input id="password" name="password" type="password" autoComplete="current-password" required className="input" />
      </div>
      <FormMessage state={state} />
      <SubmitButton className="btn-primary w-full" pendingLabel="Giriş yapılıyor…">Giriş yap</SubmitButton>
    </form>
  );
}
