import type { ServerSupabase } from '@/lib/supabase/server';

export type CustomerInfo = { name: string; phone: string | null };

/** Looks up full_name/phone of app customers (RLS lets owners read customers who booked at their venues). */
export async function loadCustomers(
  supabase: ServerSupabase,
  userIds: (string | null)[],
): Promise<Map<string, CustomerInfo>> {
  const ids = Array.from(new Set(userIds.filter((id): id is string => !!id)));
  const map = new Map<string, CustomerInfo>();
  if (ids.length === 0) return map;
  const { data, error } = await supabase.from('profiles').select('id, full_name, phone').in('id', ids);
  if (error) throw new Error(error.message);
  for (const p of data ?? []) map.set(p.id, { name: p.full_name, phone: p.phone });
  return map;
}
