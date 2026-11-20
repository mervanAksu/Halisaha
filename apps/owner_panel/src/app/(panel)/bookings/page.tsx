import { BookingActions } from '@/components/booking-actions';
import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { BookingStatusBadge, SOURCE_LABEL } from '@/components/status-badge';
import { first, getStaffContext, pickVenue, type SearchParams } from '@/lib/context';
import { loadCustomers } from '@/lib/customers';
import type { BookingStatus } from '@/lib/database.types';
import { toTurkishError } from '@/lib/errors';
import { formatTry } from '@/lib/money';
import { addDays, formatDateTime, formatTime, isDateString, todayIstanbul, toTimestamptz } from '@/lib/time';

const STATUSES: { value: BookingStatus; label: string }[] = [
  { value: 'confirmed', label: 'Onaylandı' },
  { value: 'pending_payment', label: 'Ödeme bekleniyor' },
  { value: 'completed', label: 'Tamamlandı' },
  { value: 'no_show', label: 'Gelmedi' },
  { value: 'cancelled', label: 'İptal' },
  { value: 'expired', label: 'Süresi doldu' },
];

export default async function BookingsPage({ searchParams }: { searchParams: SearchParams }) {
  const sp = await searchParams;
  const { supabase, venues } = await getStaffContext();
  const venue = pickVenue(venues, first(sp.venue));
  if (!venue) {
    return <EmptyState title="Henüz bir tesisin yok. Önce tesisini ekle." actionHref="/venues/new" actionLabel="Tesis ekle" />;
  }

  const today = todayIstanbul();
  const fromParam = first(sp.from);
  const toParam = first(sp.to);
  const from = isDateString(fromParam) ? fromParam : today;
  const to = isDateString(toParam) ? toParam : addDays(today, 7);
  const statusParam = first(sp.status);
  const status = STATUSES.find((s) => s.value === statusParam)?.value;

  let query = supabase
    .from('bookings')
    .select('*')
    .eq('venue_id', venue.id)
    .gte('starts_at', toTimestamptz(from, '00:00'))
    .lt('starts_at', toTimestamptz(addDays(to, 1), '00:00'))
    .order('starts_at', { ascending: true })
    .limit(300);
  if (status) query = query.eq('status', status);

  const [bookingsRes, pitchesRes] = await Promise.all([
    query,
    supabase.from('pitches').select('id, name').eq('venue_id', venue.id),
  ]);
  if (bookingsRes.error) throw new Error(toTurkishError(bookingsRes.error));
  if (pitchesRes.error) throw new Error(toTurkishError(pitchesRes.error));

  const rows = bookingsRes.data ?? [];
  const pitchNames = new Map((pitchesRes.data ?? []).map((p) => [p.id, p.name]));
  const customers = await loadCustomers(supabase, rows.map((b) => b.user_id));
  const nowMs = Date.now();

  return (
    <>
      <PageHeader title="Rezervasyonlar" subtitle={venue.name} />

      <form method="get" action="/bookings" className="panel-card mb-4 flex flex-wrap items-end gap-4">
        <input type="hidden" name="venue" value={venue.id} />
        <div>
          <label htmlFor="from" className="label">Başlangıç</label>
          <input id="from" name="from" type="date" defaultValue={from} className="input" />
        </div>
        <div>
          <label htmlFor="to" className="label">Bitiş</label>
          <input id="to" name="to" type="date" defaultValue={to} className="input" />
        </div>
        <div>
          <label htmlFor="status" className="label">Durum</label>
          <select id="status" name="status" defaultValue={status ?? ''} className="input">
            <option value="">Tümü</option>
            {STATUSES.map((s) => (
              <option key={s.value} value={s.value}>{s.label}</option>
            ))}
          </select>
        </div>
        <button type="submit" className="btn-primary">Filtrele</button>
      </form>

      {rows.length === 0 ? (
        <EmptyState title="Bu filtreyle eşleşen rezervasyon yok." />
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-border bg-card">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-border bg-surface text-xs uppercase text-textSecondary">
              <tr>
                <th scope="col" className="px-4 py-3">Tarih / saat</th>
                <th scope="col" className="px-4 py-3">Saha</th>
                <th scope="col" className="px-4 py-3">Müşteri</th>
                <th scope="col" className="px-4 py-3">Tür</th>
                <th scope="col" className="px-4 py-3">Ücret / kapora</th>
                <th scope="col" className="px-4 py-3">Durum</th>
                <th scope="col" className="px-4 py-3">İşlemler</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((b) => {
                const c = b.user_id ? customers.get(b.user_id) : undefined;
                const name = c?.name || b.customer_name;
                const phone = c?.phone ?? b.customer_phone;
                return (
                  <tr key={b.id} className="border-b border-border last:border-0 align-top">
                    <td className="px-4 py-3 whitespace-nowrap">
                      {formatDateTime(b.starts_at)}–{formatTime(b.ends_at)}
                    </td>
                    <td className="px-4 py-3">{pitchNames.get(b.pitch_id) ?? '—'}</td>
                    <td className="px-4 py-3">
                      {b.source === 'block' ? '—' : name || '—'}
                      {phone && b.source !== 'block' ? <div className="text-xs text-textSecondary">{phone}</div> : null}
                    </td>
                    <td className="px-4 py-3">{SOURCE_LABEL[b.source]}</td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      {b.source === 'block' ? '—' : `${formatTry(b.price_kurus)} / ${formatTry(b.deposit_kurus)}`}
                    </td>
                    <td className="px-4 py-3"><BookingStatusBadge status={b.status} /></td>
                    <td className="px-4 py-3 min-w-[14rem]">
                      <BookingActions
                        booking={{ id: b.id, source: b.source, status: b.status, startsAtMs: Date.parse(b.starts_at) }}
                        nowMs={nowMs}
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {rows.length === 300 ? (
        <p className="mt-3 text-xs text-textSecondary">İlk 300 kayıt gösteriliyor. Tarih aralığını daralt.</p>
      ) : null}
    </>
  );
}
