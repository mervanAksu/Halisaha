'use client';

import { useActionState } from 'react';
import { savePayout } from '@/actions/payout';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';

export function PayoutForm({
  venueId,
  initial,
}: {
  venueId: string;
  initial: { legal_name: string; tax_number: string; iban: string } | null;
}) {
  const [state, action] = useActionState<ActionState, FormData>(savePayout, null);
  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="venueId" value={venueId} />
      <div>
        <label htmlFor="legal_name" className="label">Ünvan / ad soyad</label>
        <input id="legal_name" name="legal_name" required defaultValue={initial?.legal_name ?? ''} className="input" />
      </div>
      <div>
        <label htmlFor="tax_number" className="label">Vergi no (10 hane) veya TC kimlik no (11 hane)</label>
        <input id="tax_number" name="tax_number" required inputMode="numeric" pattern="\d{10}|\d{11}" maxLength={11} defaultValue={initial?.tax_number ?? ''} className="input" />
      </div>
      <div>
        <label htmlFor="iban" className="label">IBAN</label>
        <input id="iban" name="iban" required autoComplete="off" defaultValue={initial?.iban ?? ''} className="input" placeholder="TR00 0000 0000 0000 0000 0000 00" />
        <p className="hint">Boşluklu yazabilirsin; kaydederken otomatik düzeltilir.</p>
      </div>
      <FormMessage state={state} />
      <SubmitButton>Kaydet</SubmitButton>
    </form>
  );
}
