import { PageHeader } from '@/components/page-header';
import { VenueForm } from '@/components/venue-form';
import { getStaffContext } from '@/lib/context';
import { loadLocations } from '@/lib/locations';

export default async function NewVenuePage() {
  const { supabase } = await getStaffContext();
  const locations = await loadLocations(supabase);
  return (
    <>
      <PageHeader title="Yeni tesis" subtitle="Tesisin oluşturulduktan sonra yönetici onayından geçer; onaylanana kadar uygulamada görünmez." />
      <div className="panel-card max-w-3xl">
        <VenueForm locations={locations} />
      </div>
    </>
  );
}
