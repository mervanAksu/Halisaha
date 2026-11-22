'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { actionClient } from '@/lib/context';
import { fail, ok, type ActionState } from '@/lib/action-state';
import { AMENITIES } from '@/lib/constants';
import { toTurkishError } from '@/lib/errors';
import { parseNumber, str } from '@/lib/form';

function locationAwareError(error: { message?: string | null; code?: string | null }): string {
  // FK venues(city, district) -> tr_districts violated.
  if (error.code === '23503') return 'Seçilen il/ilçe geçerli değil.';
  return toTurkishError(error);
}

export async function saveVenue(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const id = str(formData, 'id');
  const name = str(formData, 'name');
  const description = str(formData, 'description');
  const city = str(formData, 'city');
  const district = str(formData, 'district');
  const address = str(formData, 'address');
  const phone = str(formData, 'phone');
  const lat = parseNumber(str(formData, 'lat'));
  const lng = parseNumber(str(formData, 'lng'));
  const windowHours = Number(str(formData, 'cancellation_window_hours'));
  const allowed = new Set(AMENITIES.map((a) => a.value));
  const amenities = formData.getAll('amenities').filter((v): v is string => typeof v === 'string' && allowed.has(v));

  if (name.length < 2 || name.length > 80) return fail('Tesis adı 2 ile 80 karakter arasında olmalı.');
  if (!city || city.length > 100) return fail('İl seçmelisin.');
  if (!district || district.length > 100) return fail('İlçe seçmelisin.');
  if (description.length > 2000) return fail('Açıklama en fazla 2000 karakter olabilir.');
  if (str(formData, 'lat') !== '' && (lat === null || lat < -90 || lat > 90)) return fail('Enlem -90 ile 90 arasında olmalı.');
  if (str(formData, 'lng') !== '' && (lng === null || lng < -180 || lng > 180)) return fail('Boylam -180 ile 180 arasında olmalı.');
  if (!Number.isInteger(windowHours) || windowHours < 0 || windowHours > 168) {
    return fail('İptal süresi 0 ile 168 saat arasında tam sayı olmalı.');
  }

  const payload = {
    name,
    description,
    city,
    district,
    address,
    lat,
    lng,
    phone: phone || null,
    amenities,
    cancellation_window_hours: windowHours,
  };

  if (!id) {
    const { data, error } = await client.supabase.from('venues').insert(payload).select('id').single();
    if (error) return fail(locationAwareError(error));
    revalidatePath('/', 'layout');
    redirect(`/venues/${data.id}?venue=${data.id}&created=1`);
  }

  const { data, error } = await client.supabase.from('venues').update(payload).eq('id', id).select('id');
  if (error) return fail(locationAwareError(error));
  if (!data || data.length === 0) return fail(toTurkishError({ message: 'forbidden' }));
  revalidatePath('/', 'layout');
  return ok('Tesis bilgileri kaydedildi.');
}

/** Called directly from the photo manager after the browser uploaded files to Storage. */
export async function saveVenuePhotos(
  venueId: string,
  coverPath: string | null,
  photoPaths: string[],
): Promise<ActionState> {
  const client = await actionClient();
  if (!client) return fail(toTurkishError({ message: 'not_authenticated' }));

  const prefix = `${venueId}/`;
  if (!photoPaths.every((p) => p.startsWith(prefix)) || (coverPath !== null && !photoPaths.includes(coverPath))) {
    return fail('Geçersiz fotoğraf listesi.');
  }
  const { data, error } = await client.supabase
    .from('venues')
    .update({ photo_paths: photoPaths, cover_photo_path: coverPath })
    .eq('id', venueId)
    .select('id');
  if (error) return fail(toTurkishError(error));
  if (!data || data.length === 0) return fail(toTurkishError({ message: 'forbidden' }));
  revalidatePath(`/venues/${venueId}`);
  return ok('Fotoğraflar güncellendi.');
}
