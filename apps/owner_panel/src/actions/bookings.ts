'use server';

import { revalidatePath } from 'next/cache';
import { actionClient } from '@/lib/context';
import { fail, ok, type ActionState } from '@/lib/action-state';
import { toTurkishError } from '@/lib/errors';
import { optStr, str } from '@/lib/form';

function refresh() {
  revalidatePath('/calendar');
  revalidatePath('/bookings');
  revalidatePath('/admin/refunds');
}

export async function createManualBooking(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const pitchId = str(formData, 'pitchId');
  const startsAt = str(formData, 'startsAt');
  const endsAt = str(formData, 'endsAt');
  const mode = str(formData, 'mode');
  const source = mode === 'block' ? 'block' : 'manual';
  const name = optStr(formData, 'customerName');
  const phone = optStr(formData, 'customerPhone');
  const note = optStr(formData, 'note');

  if (!pitchId || Number.isNaN(Date.parse(startsAt)) || Number.isNaN(Date.parse(endsAt))) {
    return fail(toTurkishError({ message: 'invalid_range' }));
  }
  if (source === 'manual' && !name) return fail('Müşteri adını gir.');
  if (name && name.length > 80) return fail('Müşteri adı en fazla 80 karakter olabilir.');
  if (phone && phone.length > 20) return fail('Telefon en fazla 20 karakter olabilir.');
  if (note && note.length > 500) return fail('Not en fazla 500 karakter olabilir.');

  const { error } = await client.supabase.rpc('owner_create_manual_booking', {
    p_pitch_id: pitchId,
    p_starts_at: new Date(startsAt).toISOString(),
    p_ends_at: new Date(endsAt).toISOString(),
    p_source: source,
    p_customer_name: source === 'manual' ? name : undefined,
    p_customer_phone: source === 'manual' ? phone : undefined,
    p_note: note,
  });
  if (error) return fail(toTurkishError(error));

  refresh();
  return ok(source === 'block' ? 'Saat kapatıldı.' : 'Rezervasyon kaydedildi.');
}

export async function cancelBooking(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const bookingId = str(formData, 'bookingId');
  const reason = optStr(formData, 'reason');
  if (!bookingId) return fail(toTurkishError({ message: 'booking_not_found' }));
  if (reason && reason.length > 300) return fail('İptal nedeni en fazla 300 karakter olabilir.');

  const { error } = await client.supabase.rpc('owner_cancel_booking', {
    p_booking_id: bookingId,
    p_reason: reason,
  });
  if (error) return fail(toTurkishError(error));

  refresh();
  return ok('Rezervasyon iptal edildi.');
}

export async function markAttendance(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const bookingId = str(formData, 'bookingId');
  const status = str(formData, 'status');
  if (!bookingId || (status !== 'completed' && status !== 'no_show')) {
    return fail(toTurkishError({ message: 'invalid_status' }));
  }

  const { error } = await client.supabase.rpc('owner_mark_attendance', {
    p_booking_id: bookingId,
    p_status: status,
  });
  if (error) return fail(toTurkishError(error));

  refresh();
  return ok(status === 'completed' ? 'Geldi olarak işaretlendi.' : 'Gelmedi olarak işaretlendi.');
}
