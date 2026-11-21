'use client';

import { useActionState } from 'react';
import { verifyPayout } from '@/actions/admin';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';

export function VerifyPayoutButton({ venueId }: { venueId: string }) {
  const [state, action] = useActionState<ActionState, FormData>(verifyPayout, null);
  return (
    <form action={action} className="flex items-center gap-2">
      <input type="hidden" name="venueId" value={venueId} />
      <SubmitButton className="btn-accent btn-sm" pendingLabel="…">Doğrula</SubmitButton>
      <FormMessage state={state} />
    </form>
  );
}
