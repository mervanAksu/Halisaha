import Link from 'next/link';
import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { VenueStatusBadge } from '@/components/status-badge';
import { getStaffContext } from '@/lib/context';
import { toTurkishError } from '@/lib/errors';

export default async function VenuesPage() {
  const { supabase, user } = await getStaffContext();
  const { data, error } = await supabase
    .from('venues')
    .select('id, name, district, address, status')
    .eq('owner_id', user.id)
    .order('name');
  if (error) throw new Error(toTurkishError(error));

  return (
    <>
      <PageHeader
        title="Tesislerim"
        actions={<Link href="/venues/new" className="btn-primary">Yeni tesis</Link>}
      />
      {!data || data.length === 0 ? (
        <EmptyState title="Henüz bir tesisin yok." actionHref="/venues/new" actionLabel="İlk tesisini ekle" />
      ) : (
        <ul className="grid gap-4 md:grid-cols-2">
          {data.map((v) => (
            <li key={v.id} className="panel-card flex items-start justify-between gap-4">
              <div>
                <h2 className="text-[17px] font-semibold text-primary">{v.name}</h2>
                <p className="text-sm text-textSecondary">{v.district}{v.address ? ` · ${v.address}` : ''}</p>
                <Link href={`/venues/${v.id}?venue=${v.id}`} className="mt-3 inline-block text-sm font-semibold text-primary underline">
                  Düzenle
                </Link>
              </div>
              <VenueStatusBadge status={v.status} />
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
