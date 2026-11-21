import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { VerifyPayoutButton } from '@/components/verify-payout-button';
import { requireAdmin } from '@/lib/context';
import { toTurkishError } from '@/lib/errors';
import { formatDateTime } from '@/lib/time';
import { formatIban } from '@/lib/validation';

export default async function AdminPayoutsPage() {
  const { supabase } = await requireAdmin();

  const { data, error } = await supabase
    .from('venue_payout_accounts')
    .select('venue_id, legal_name, tax_number, iban, verified_at, updated_at')
    .is('verified_at', null)
    .order('updated_at', { ascending: true })
    .limit(200);
  if (error) throw new Error(toTurkishError(error));
  const rows = data ?? [];

  const names = new Map<string, string>();
  if (rows.length > 0) {
    const { data: venues, error: vErr } = await supabase
      .from('venues')
      .select('id, name')
      .in('id', rows.map((r) => r.venue_id));
    if (vErr) throw new Error(toTurkishError(vErr));
    for (const v of venues ?? []) names.set(v.id, v.name);
  }

  return (
    <>
      <PageHeader title="IBAN Doğrulama" subtitle="Onay bekleyen ödeme hesapları" />
      {rows.length === 0 ? (
        <EmptyState title="Doğrulama bekleyen IBAN yok." />
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-border bg-card">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-border bg-surface text-xs uppercase text-textSecondary">
              <tr>
                <th scope="col" className="px-4 py-3">Tesis</th>
                <th scope="col" className="px-4 py-3">Ünvan</th>
                <th scope="col" className="px-4 py-3">Vergi/TC no</th>
                <th scope="col" className="px-4 py-3">IBAN</th>
                <th scope="col" className="px-4 py-3">Son değişiklik</th>
                <th scope="col" className="px-4 py-3"><span className="sr-only">İşlem</span></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.venue_id} className="border-b border-border last:border-0">
                  <td className="px-4 py-3">{names.get(r.venue_id) ?? '—'}</td>
                  <td className="px-4 py-3">{r.legal_name}</td>
                  <td className="px-4 py-3 font-mono text-xs">{r.tax_number}</td>
                  <td className="px-4 py-3 font-mono text-xs">{formatIban(r.iban)}</td>
                  <td className="px-4 py-3 whitespace-nowrap">{formatDateTime(r.updated_at)}</td>
                  <td className="px-4 py-3"><VerifyPayoutButton venueId={r.venue_id} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
