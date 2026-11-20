import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { requireAdmin } from '@/lib/context';
import { loadCustomers } from '@/lib/customers';
import { toTurkishError } from '@/lib/errors';
import { formatTry } from '@/lib/money';
import { formatDateTime } from '@/lib/time';

export default async function AdminRefundsPage() {
  const { supabase } = await requireAdmin();

  const { data: payments, error } = await supabase
    .from('payments')
    .select('id, booking_id, user_id, merchant_oid, amount_kurus, created_at, updated_at')
    .in('status', ['refund_required', 'refund_processing']) // processing = claimed by the refund job
    .order('updated_at', { ascending: true })
    .limit(200);
  if (error) throw new Error(toTurkishError(error));
  const rows = payments ?? [];

  const bookingIds = rows.map((p) => p.booking_id);
  const bookings = new Map<string, { starts_at: string; venue_id: string; pitch_id: string; status: string }>();
  const venueNames = new Map<string, string>();
  const pitchNames = new Map<string, string>();

  if (bookingIds.length > 0) {
    const { data: bs, error: bErr } = await supabase
      .from('bookings')
      .select('id, starts_at, venue_id, pitch_id, status')
      .in('id', bookingIds);
    if (bErr) throw new Error(toTurkishError(bErr));
    for (const b of bs ?? []) bookings.set(b.id, b);

    const venueIds = Array.from(new Set((bs ?? []).map((b) => b.venue_id)));
    const pitchIds = Array.from(new Set((bs ?? []).map((b) => b.pitch_id)));
    const [vRes, pRes] = await Promise.all([
      supabase.from('venues').select('id, name').in('id', venueIds),
      supabase.from('pitches').select('id, name').in('id', pitchIds),
    ]);
    for (const v of vRes.data ?? []) venueNames.set(v.id, v.name);
    for (const p of pRes.data ?? []) pitchNames.set(p.id, p.name);
  }
  const customers = await loadCustomers(supabase, rows.map((p) => p.user_id));

  return (
    <>
      <PageHeader title="İadeler" subtitle="İade bekleyen ödemeler" />
      <div className="mb-4 rounded-2xl bg-accentSoft p-4 text-sm text-primary">
        Bu liste salt okunurdur. İadeler <code>paytr-refund</code> fonksiyonu tarafından PayTR iade API’si ile işlenir ve
        durum otomatik olarak “iade edildi” olur. Burada uzun süre bekleyen kayıt varsa platform ekibine bildir.
      </div>
      {rows.length === 0 ? (
        <EmptyState title="İade bekleyen ödeme yok." />
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-border bg-card">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-border bg-surface text-xs uppercase text-textSecondary">
              <tr>
                <th scope="col" className="px-4 py-3">İade talebi</th>
                <th scope="col" className="px-4 py-3">Tesis / saha</th>
                <th scope="col" className="px-4 py-3">Maç zamanı</th>
                <th scope="col" className="px-4 py-3">Müşteri</th>
                <th scope="col" className="px-4 py-3">Tutar</th>
                <th scope="col" className="px-4 py-3">Sipariş no</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((p) => {
                const b = bookings.get(p.booking_id);
                const c = p.user_id ? customers.get(p.user_id) : undefined;
                return (
                  <tr key={p.id} className="border-b border-border last:border-0">
                    <td className="px-4 py-3 whitespace-nowrap">{formatDateTime(p.updated_at)}</td>
                    <td className="px-4 py-3">
                      {b ? `${venueNames.get(b.venue_id) ?? '—'} / ${pitchNames.get(b.pitch_id) ?? '—'}` : '—'}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">{b ? formatDateTime(b.starts_at) : '—'}</td>
                    <td className="px-4 py-3">
                      {c ? c.name : 'Silinmiş hesap'}
                      {c?.phone ? <div className="text-xs text-textSecondary">{c.phone}</div> : null}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap font-medium">{formatTry(p.amount_kurus)}</td>
                    <td className="px-4 py-3 font-mono text-xs">{p.merchant_oid}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
