import { PageHeader } from '@/components/page-header';
import { VenueForm } from '@/components/venue-form';

export default function NewVenuePage() {
  return (
    <>
      <PageHeader title="Yeni tesis" subtitle="Tesisin oluşturulduktan sonra yönetici onayından geçer; onaylanana kadar uygulamada görünmez." />
      <div className="panel-card max-w-3xl">
        <VenueForm />
      </div>
    </>
  );
}
