import type { ReactNode } from 'react';
import Link from 'next/link';
import { CalendarGrid } from '@/components/calendar/calendar-grid';
import type { CalBooking, CalPitch } from '@/components/calendar/types';
import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { dayWindow, generateSlots } from '@/lib/calendar';
import { first, getStaffContext, pickVenue, type SearchParams } from '@/lib/context';
import { loadCustomers } from '@/lib/customers';
import { toTurkishError } from '@/lib/errors';
import { addDays, formatDateLong, isDateString, isoWeekday, todayIstanbul, TZ } from '@/lib/time';

export default async function CalendarPage({ searchParams }: { searchParams: SearchParams }) {
  const sp = await searchParams;
  const { supabase, venues } = await getStaffContext();
  const venue = pickVenue(venues, first(sp.venue));
  if (!venue) {
    return <EmptyState title="Henüz bir tesisin yok. Önce tesisini ekle." actionHref="/venues/new" actionLabel="Tesis ekle" />;
  }

  // Before 06:00 we are still inside yesterday's (possibly overnight) business day.
  const istanbulHour = Number(
    new Intl.DateTimeFormat('en-GB', { timeZone: TZ, hour: '2-digit', hourCycle: 'h23' }).format(new Date()),
  );
  const today = istanbulHour < 6 ? addDays(todayIstanbul(), -1) : todayIstanbul();
  const requested = first(sp.date);
  const date = isDateString(requested) ? requested : today;
  const href = (d: string) => `/calendar?venue=${venue.id}&date=${d}`;

  const [hoursRes, pitchesRes] = await Promise.all([
    supabase.from('venue_hours').select('open_time, close_time').eq('venue_id', venue.id).eq('iso_weekday', isoWeekday(date)).maybeSingle(),
    supabase.from('pitches').select('*').eq('venue_id', venue.id).eq('is_active', true).order('sort_order').order('name'),
  ]);
  if (hoursRes.error) throw new Error(toTurkishError(hoursRes.error));
  if (pitchesRes.error) throw new Error(toTurkishError(pitchesRes.error));

  const hours = hoursRes.data;
  let body: ReactNode;

  if (!hours) {
    body = <p className="panel-card text-sm text-textSecondary">Tesis bu gün kapalı. Çalışma saatlerini Tesislerim sayfasından düzenleyebilirsin.</p>;
  } else {
    const win = dayWindow(date, hours.open_time, hours.close_time);
    const { data: rows, error } = await supabase
      .from('bookings')
      .select('*')
      .eq('venue_id', venue.id)
      .lt('starts_at', new Date(win.closeMs).toISOString())
      .gt('ends_at', new Date(win.openMs).toISOString())
      .in('status', ['confirmed', 'pending_payment', 'completed', 'no_show']);
    if (error) throw new Error(toTurkishError(error));

    const nowMs = Date.now();
    // Expired holds are not occupying the slot (same rule as get_availability()).
    const live = (rows ?? []).filter(
      (b) => b.status !== 'pending_payment' || (b.hold_expires_at !== null && Date.parse(b.hold_expires_at) > nowMs),
    );
    const customers = await loadCustomers(supabase, live.map((b) => b.user_id));

    const pitches: CalPitch[] = (pitchesRes.data ?? []).map((p) => ({
      id: p.id,
      name: p.name,
      format: p.format,
      priceKurus: Math.floor((p.hourly_price_kurus * p.slot_minutes) / 60),
      depositKurus: p.deposit_kurus,
      slots: generateSlots(win, p.slot_minutes),
    }));

    const bookings: CalBooking[] = live.map((b) => {
      const c = b.user_id ? customers.get(b.user_id) : undefined;
      return {
        id: b.id,
        pitchId: b.pitch_id,
        source: b.source,
        status: b.status,
        startsAtMs: Date.parse(b.starts_at),
        endsAtMs: Date.parse(b.ends_at),
        priceKurus: b.price_kurus,
        depositKurus: b.deposit_kurus,
        customerName: c?.name || b.customer_name,
        customerPhone: c?.phone ?? b.customer_phone,
        note: b.note,
      };
    });

    body = <CalendarGrid openMs={win.openMs} closeMs={win.closeMs} nowMs={nowMs} pitches={pitches} bookings={bookings} />;
  }

  return (
    <>
      <PageHeader title="Takvim" subtitle={`${venue.name} · ${formatDateLong(date)}`} />
      <div className="mb-4 flex flex-wrap items-center gap-2">
        <Link href={href(addDays(date, -1))} className="btn-secondary btn-sm">← Önceki gün</Link>
        <Link href={href(today)} className="btn-secondary btn-sm">Bugün</Link>
        <Link href={href(addDays(date, 1))} className="btn-secondary btn-sm">Sonraki gün →</Link>
        <form method="get" action="/calendar" className="ml-2 flex items-center gap-2">
          <input type="hidden" name="venue" value={venue.id} />
          <label htmlFor="date" className="sr-only">Tarih</label>
          <input id="date" name="date" type="date" defaultValue={date} className="input w-44" />
          <button type="submit" className="btn-secondary btn-sm">Git</button>
        </form>
      </div>
      {body}
    </>
  );
}
