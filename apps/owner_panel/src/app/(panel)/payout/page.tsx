import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { PayoutForm } from '@/components/payout-form';
import { first, getStaffContext, pickVenue, type SearchParams } from '@/lib/context';
import { toTurkishError } from '@/lib/errors';

export default async function PayoutPage({ searchParams }: { searchParams: SearchParams }) {
  const sp = await searchParams;
  const { supabase, venues } = await getStaffContext();
  const venue = pickVenue(venues, first(sp.venue));
  if (!venue) {
    return <EmptyState title="Ödeme bilgisi girmek için önce bir tesis ekle." actionHref="/venues/new" actionLabel="Tesis ekle" />;
  }

  const { data, error } = await supabase
    .from('venue_payout_accounts')
    .select('legal_name, tax_number, iban, verified_at')
    .eq('venue_id', venue.id)
    .maybeSingle();
  if (error) throw new Error(toTurkishError(error));

  return (
    <>
      <PageHeader title="Ödeme Bilgileri" subtitle={venue.name} />
      <div className="max-w-2xl space-y-4">
        <div className="rounded-2xl bg-accentSoft p-4 text-sm text-primary">
          Kaporalar PayTR üzerinden tahsil edilir ve komisyon düşüldükten sonra bu bilgilerdeki hesaba aktarılır.
          PayTR alt üye işyeri kaydı bu bilgilerle platform ekibi tarafından tamamlanır; senin ayrıca bir işlem yapmana gerek yoktur.
        </div>
        <div className="panel-card">
          <PayoutForm key={venue.id} venueId={venue.id} initial={
              data
                ? {
                    legal_name: data.legal_name,
                    tax_number: data.tax_number,
                    ibanLast4: data.iban.slice(-4),
                    verified: data.verified_at !== null,
                  }
                : null
            } />
        </div>
      </div>
    </>
  );
}
