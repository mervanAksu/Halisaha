'use server';

import { revalidatePath } from 'next/cache';
import { actionClient } from '@/lib/context';
import { fail, ok, type ActionState } from '@/lib/action-state';
import { toTurkishError } from '@/lib/errors';
import { optStr, parseNumber, str } from '@/lib/form';
import type { VenueStatus } from '@/lib/database.types';

const STATUSES: VenueStatus[] = ['pending', 'active', 'suspended'];

export async function adminUpdateVenue(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const venueId = str(formData, 'venueId');
  const intent = str(formData, 'intent');
  let status: VenueStatus | undefined;
  if (intent === 'approve') status = 'active';
  else if (intent === 'suspend') status = 'suspended';
  else {
    const s = str(formData, 'status');
    status = STATUSES.find((x) => x === s);
  }

  let commissionBps: number | undefined;
  const pct = str(formData, 'commission_pct');
  if (pct !== '') {
    const n = parseNumber(pct);
    if (n === null || n < 0 || n > 50) return fail('Komisyon oranı % 0 ile % 50 arasında olmalı.');
    commissionBps = Math.round(n * 100);
  }
  // admin_update_venue uses coalesce(): an empty key leaves the stored key unchanged.
  const key = optStr(formData, 'paytr_submerchant_key');

  const { error } = await client.supabase.rpc('admin_update_venue', {
    p_venue_id: venueId,
    p_status: status,
    p_commission_bps: commissionBps,
    p_paytr_submerchant_key: key,
  });
  if (error) return fail(toTurkishError(error));

  revalidatePath('/admin/venues');
  revalidatePath('/', 'layout');
  return ok('Tesis güncellendi.');
}
