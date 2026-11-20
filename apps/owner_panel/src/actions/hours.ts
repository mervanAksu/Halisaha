'use server';

import { revalidatePath } from 'next/cache';
import { actionClient } from '@/lib/context';
import { fail, ok, type ActionState } from '@/lib/action-state';
import { toTurkishError } from '@/lib/errors';
import { str } from '@/lib/form';
import { normalizeTime } from '@/lib/time';

const TIME_RE = /^\d{2}:\d{2}$/;

export async function saveVenueHours(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const venueId = str(formData, 'venueId');
  if (!venueId) return fail(toTurkishError({ message: 'forbidden' }));

  const upserts: { venue_id: string; iso_weekday: number; open_time: string; close_time: string }[] = [];
  const closedDays: number[] = [];

  for (let day = 1; day <= 7; day++) {
    if (formData.get(`closed_${day}`) === 'on') {
      closedDays.push(day);
      continue;
    }
    const open = str(formData, `open_${day}`);
    const close = str(formData, `close_${day}`);
    if (!TIME_RE.test(open) || !TIME_RE.test(close)) return fail('Açık günler için açılış ve kapanış saati gir.');
    upserts.push({ venue_id: venueId, iso_weekday: day, open_time: normalizeTime(open), close_time: normalizeTime(close) });
  }

  if (upserts.length > 0) {
    const { error } = await client.supabase.from('venue_hours').upsert(upserts, { onConflict: 'venue_id,iso_weekday' });
    if (error) return fail(toTurkishError(error));
  }
  if (closedDays.length > 0) {
    const { error } = await client.supabase
      .from('venue_hours')
      .delete()
      .eq('venue_id', venueId)
      .in('iso_weekday', closedDays);
    if (error) return fail(toTurkishError(error));
  }

  revalidatePath(`/venues/${venueId}`);
  revalidatePath('/calendar');
  return ok('Çalışma saatleri kaydedildi.');
}
