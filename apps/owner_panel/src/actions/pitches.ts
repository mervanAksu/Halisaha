'use server';

import { revalidatePath } from 'next/cache';
import { actionClient } from '@/lib/context';
import { fail, ok, type ActionState } from '@/lib/action-state';
import { PITCH_FORMATS, SLOT_MINUTES } from '@/lib/constants';
import { toTurkishError } from '@/lib/errors';
import { bool, str } from '@/lib/form';
import { parseTryToKurus } from '@/lib/money';

export async function savePitch(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const id = str(formData, 'id');
  const venueId = str(formData, 'venueId');
  const name = str(formData, 'name');
  const format = str(formData, 'format');
  const slotMinutes = Number(str(formData, 'slot_minutes'));
  const price = parseTryToKurus(str(formData, 'price'));
  const deposit = parseTryToKurus(str(formData, 'deposit'));

  if (!venueId) return fail(toTurkishError({ message: 'forbidden' }));
  if (name.length < 1 || name.length > 40) return fail('Saha adı 1 ile 40 karakter arasında olmalı.');
  if (!(PITCH_FORMATS as readonly string[]).includes(format)) return fail('Geçerli bir format seç.');
  if (!(SLOT_MINUTES as readonly number[]).includes(slotMinutes)) return fail('Slot süresi 60, 90 veya 120 dakika olmalı.');
  if (price === null || price <= 0) return fail('Saatlik ücreti TL olarak gir (ör. 3500).');
  if (deposit === null) return fail('Kaporayı TL olarak gir (ör. 500). Kapora yoksa 0 yaz.');
  // Same rule as the DB constraint deposit_not_above_price (integer division like Postgres).
  if (deposit > Math.floor((price * slotMinutes) / 60)) return fail('Kapora, slot ücretini aşamaz.');

  const payload = {
    name,
    format,
    is_indoor: bool(formData, 'is_indoor'),
    hourly_price_kurus: price,
    deposit_kurus: deposit,
    slot_minutes: slotMinutes,
    is_active: bool(formData, 'is_active'),
  };

  if (id) {
    const { data, error } = await client.supabase.from('pitches').update(payload).eq('id', id).select('id');
    if (error) return fail(toTurkishError(error));
    if (!data || data.length === 0) return fail(toTurkishError({ message: 'forbidden' }));
  } else {
    const { error } = await client.supabase.from('pitches').insert({ ...payload, venue_id: venueId });
    if (error) return fail(toTurkishError(error));
  }

  revalidatePath(`/venues/${venueId}`);
  revalidatePath('/calendar');
  return ok(id ? 'Saha güncellendi.' : 'Saha eklendi.');
}

export async function deletePitch(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const id = str(formData, 'id');
  const venueId = str(formData, 'venueId');
  const { data, error } = await client.supabase.from('pitches').delete().eq('id', id).select('id');
  if (error) {
    if (error.code === '23503') return fail('Bu sahaya ait rezervasyonlar var. Silmek yerine sahayı pasif yap.');
    return fail(toTurkishError(error));
  }
  if (!data || data.length === 0) return fail(toTurkishError({ message: 'forbidden' }));

  revalidatePath(`/venues/${venueId}`);
  revalidatePath('/calendar');
  return ok('Saha silindi.');
}
