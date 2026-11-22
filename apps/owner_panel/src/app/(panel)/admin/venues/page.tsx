import { AdminVenueCard, type AdminVenue } from '@/components/admin-venue-card';
import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { requireAdmin } from '@/lib/context';
import { toTurkishError } from '@/lib/errors';

export default async function AdminVenuesPage() {
  const { supabase } = await requireAdmin();
  // commission_bps / paytr_submerchant_key are not column-granted to clients; admins read them via RPC.
  const { data, error } = await supabase.rpc('admin_list_venues');
  if (error) throw new Error(toTurkishError(error));
  const rows = data ?? [];

  const ownerIds = Array.from(new Set(rows.map((v) => v.owner_id)));
  const owners = new Map<string, string>();
  if (ownerIds.length > 0) {
    const { data: profiles, error: pErr } = await supabase.from('profiles').select('id, full_name, email').in('id', ownerIds);
    if (pErr) throw new Error(toTurkishError(pErr));
    for (const p of profiles ?? []) owners.set(p.id, [p.full_name, p.email].filter(Boolean).join(' · '));
  }

  // Pending venues first.
  const order = { pending: 0, active: 1, suspended: 2 } as const;
  const venues: AdminVenue[] = rows
    .map((v) => ({
      id: v.id,
      name: v.name,
      city: v.city,
      district: v.district,
      ownerName: owners.get(v.owner_id) ?? '',
      status: v.status,
      commissionBps: v.commission_bps,
      paytrKey: v.paytr_submerchant_key,
    }))
    .sort((a, b) => order[a.status] - order[b.status]);

  return (
    <>
      <PageHeader title="Saha Onayları" subtitle="Tesisleri onayla veya askıya al, komisyon oranını ve PayTR anahtarını belirle." />
      {venues.length === 0 ? (
        <EmptyState title="Henüz kayıtlı tesis yok." />
      ) : (
        <div className="max-w-4xl space-y-4">
          {venues.map((v) => (
            <AdminVenueCard key={v.id} venue={v} />
          ))}
        </div>
      )}
    </>
  );
}
