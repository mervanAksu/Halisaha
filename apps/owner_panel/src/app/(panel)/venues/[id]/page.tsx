import { notFound } from 'next/navigation';
import { HoursEditor, type HoursByDay } from '@/components/hours-editor';
import { PageHeader } from '@/components/page-header';
import { PhotoManager } from '@/components/photo-manager';
import { PitchManager } from '@/components/pitch-manager';
import { VenueStatusBadge } from '@/components/status-badge';
import { VenueForm } from '@/components/venue-form';
import { loadLocations } from '@/lib/locations';
import { first, getStaffContext, type SearchParams } from '@/lib/context';
import { toTurkishError } from '@/lib/errors';
import { shortTime } from '@/lib/time';

export default async function VenueDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: SearchParams;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const { supabase } = await getStaffContext();

  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();

  const locations = await loadLocations(supabase);
  const [venueRes, hoursRes, pitchesRes] = await Promise.all([
    supabase
      .from('venues')
      .select(
        'id, owner_id, name, description, city, district, address, lat, lng, phone, cover_photo_path, photo_paths, amenities, status, cancellation_window_hours, created_at, updated_at',
      )
      .eq('id', id)
      .maybeSingle(),
    supabase.from('venue_hours').select('*').eq('venue_id', id),
    supabase.from('pitches').select('*').eq('venue_id', id).order('sort_order').order('name'),
  ]);
  if (venueRes.error) throw new Error(toTurkishError(venueRes.error));
  if (hoursRes.error) throw new Error(toTurkishError(hoursRes.error));
  if (pitchesRes.error) throw new Error(toTurkishError(pitchesRes.error));
  const venue = venueRes.data;
  if (!venue) notFound();

  const hours: HoursByDay = {};
  for (const h of hoursRes.data ?? []) {
    hours[h.iso_weekday] = { open: shortTime(h.open_time), close: shortTime(h.close_time) };
  }

  return (
    <div className="max-w-4xl space-y-6">
      <PageHeader title={venue.name} actions={<VenueStatusBadge status={venue.status} />} />
      {first(sp.created) === '1' ? (
        <p role="status" className="rounded-xl bg-accentSoft px-3 py-2 text-sm text-primary">
          Tesis oluşturuldu. Çalışma saatlerini ve sahalarını ekle; ardından yönetici onayı beklenir.
        </p>
      ) : null}
      {venue.status === 'pending' ? (
        <p className="rounded-xl bg-warning/15 px-3 py-2 text-sm">
          Tesisin onay bekliyor. Onaylanana kadar oyuncular uygulamada göremez.
        </p>
      ) : null}
      {venue.status === 'suspended' ? (
        <p className="rounded-xl bg-danger/10 px-3 py-2 text-sm text-danger">
          Tesisin askıya alındı. Ayrıntı için platform ekibiyle iletişime geç.
        </p>
      ) : null}

      <section className="panel-card" aria-labelledby="sec-info">
        <h2 id="sec-info" className="mb-4 text-[17px] font-semibold text-primary">Tesis bilgileri</h2>
        <VenueForm
          locations={locations}
          venue={{
            id: venue.id,
            name: venue.name,
            description: venue.description,
            city: venue.city,
            district: venue.district,
            address: venue.address,
            lat: venue.lat,
            lng: venue.lng,
            phone: venue.phone,
            amenities: venue.amenities,
            cancellation_window_hours: venue.cancellation_window_hours,
          }}
        />
      </section>

      <section className="panel-card" aria-labelledby="sec-photos">
        <h2 id="sec-photos" className="mb-4 text-[17px] font-semibold text-primary">Fotoğraflar</h2>
        <PhotoManager venueId={venue.id} initialPaths={venue.photo_paths} initialCover={venue.cover_photo_path} />
      </section>

      <section className="panel-card" aria-labelledby="sec-hours">
        <h2 id="sec-hours" className="mb-4 text-[17px] font-semibold text-primary">Çalışma saatleri</h2>
        <HoursEditor venueId={venue.id} initial={hours} />
      </section>

      <section className="panel-card" aria-labelledby="sec-pitches">
        <h2 id="sec-pitches" className="mb-4 text-[17px] font-semibold text-primary">Sahalar</h2>
        <PitchManager venueId={venue.id} pitches={pitchesRes.data ?? []} />
      </section>
    </div>
  );
}
