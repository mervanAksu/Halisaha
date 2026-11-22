import { toTurkishError } from '@/lib/errors';
import type { ServerSupabase } from '@/lib/supabase/server';

export type Locations = {
  /** Province names, alphabetical (tr). */
  provinces: string[];
  /** Province name -> district names, alphabetical (tr). */
  districts: Record<string, string[]>;
};

export async function loadLocations(supabase: ServerSupabase): Promise<Locations> {
  const [pRes, dRes] = await Promise.all([
    supabase.from('tr_provinces').select('plate, name'),
    supabase.from('tr_districts').select('province, name').limit(2000),
  ]);
  if (pRes.error) throw new Error(toTurkishError(pRes.error));
  if (dRes.error) throw new Error(toTurkishError(dRes.error));
  const provinces = (pRes.data ?? []).map((p) => p.name).sort((a, b) => a.localeCompare(b, 'tr'));
  const districts: Record<string, string[]> = {};
  for (const d of dRes.data ?? []) (districts[d.province] ??= []).push(d.name);
  for (const k of Object.keys(districts)) districts[k].sort((a, b) => a.localeCompare(b, 'tr'));
  return { provinces, districts };
}
