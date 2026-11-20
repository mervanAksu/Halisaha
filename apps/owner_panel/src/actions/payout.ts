'use server';

import { revalidatePath } from 'next/cache';
import { actionClient } from '@/lib/context';
import { fail, ok, type ActionState } from '@/lib/action-state';
import { toTurkishError } from '@/lib/errors';
import { str } from '@/lib/form';
import { isValidIban, isValidTaxNumber, normalizeIban } from '@/lib/validation';

export async function savePayout(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const venueId = str(formData, 'venueId');
  const legalName = str(formData, 'legal_name');
  const taxNumber = str(formData, 'tax_number');
  const iban = normalizeIban(str(formData, 'iban'));

  if (!venueId) return fail(toTurkishError({ message: 'forbidden' }));
  if (legalName.length < 2) return fail('Ünvan veya ad soyad gerekli.');
  if (!isValidTaxNumber(taxNumber)) return fail('Vergi no 10 haneli, TC kimlik no 11 haneli olmalı.');
  if (!isValidIban(iban)) return fail('IBAN geçersiz. TR ile başlayan 26 karakterlik geçerli bir IBAN gir.');

  const { error } = await client.supabase.from('venue_payout_accounts').upsert(
    {
      venue_id: venueId,
      legal_name: legalName,
      tax_number: taxNumber,
      iban,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'venue_id' },
  );
  if (error) return fail(toTurkishError(error));

  revalidatePath('/payout');
  return ok('Ödeme bilgileri kaydedildi.');
}
