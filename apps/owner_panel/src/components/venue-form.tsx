'use client';

import { useActionState } from 'react';
import { saveVenue } from '@/actions/venues';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';
import { AMENITIES } from '@/lib/constants';

export type VenueFormValues = {
  id?: string;
  name: string;
  description: string;
  district: string;
  address: string;
  lat: number | null;
  lng: number | null;
  phone: string | null;
  amenities: string[];
  cancellation_window_hours: number;
};

const EMPTY: VenueFormValues = {
  name: '',
  description: '',
  district: '',
  address: '',
  lat: null,
  lng: null,
  phone: null,
  amenities: [],
  cancellation_window_hours: 24,
};

export function VenueForm({ venue = EMPTY }: { venue?: VenueFormValues }) {
  const [state, action] = useActionState<ActionState, FormData>(saveVenue, null);
  return (
    <form action={action} className="space-y-4">
      {venue.id ? <input type="hidden" name="id" value={venue.id} /> : null}
      <div className="grid gap-4 md:grid-cols-2">
        <div>
          <label htmlFor="name" className="label">Tesis adı</label>
          <input id="name" name="name" required minLength={2} maxLength={80} defaultValue={venue.name} className="input" />
        </div>
        <div>
          <label htmlFor="district" className="label">İlçe</label>
          <input id="district" name="district" required defaultValue={venue.district} className="input" />
        </div>
        <div className="md:col-span-2">
          <label htmlFor="address" className="label">Adres</label>
          <input id="address" name="address" defaultValue={venue.address} className="input" />
        </div>
        <div className="md:col-span-2">
          <label htmlFor="description" className="label">Açıklama</label>
          <textarea id="description" name="description" rows={3} maxLength={2000} defaultValue={venue.description} className="input" />
        </div>
        <div>
          <label htmlFor="lat" className="label">Enlem</label>
          <input id="lat" name="lat" inputMode="decimal" defaultValue={venue.lat ?? ''} className="input" placeholder="41.0082" />
        </div>
        <div>
          <label htmlFor="lng" className="label">Boylam</label>
          <input id="lng" name="lng" inputMode="decimal" defaultValue={venue.lng ?? ''} className="input" placeholder="28.9784" />
        </div>
        <div>
          <label htmlFor="phone" className="label">Telefon</label>
          <input id="phone" name="phone" type="tel" defaultValue={venue.phone ?? ''} className="input" />
        </div>
        <div>
          <label htmlFor="cancellation_window_hours" className="label">İptal penceresi (saat)</label>
          <input
            id="cancellation_window_hours"
            name="cancellation_window_hours"
            type="number"
            min={0}
            max={168}
            step={1}
            required
            defaultValue={venue.cancellation_window_hours}
            className="input"
          />
          <p className="hint">Maça bu kadar saatten fazla varsa müşteri iptal ederse kapora iade edilir.</p>
          <p className="hint">İptal süresindeki değişiklik yalnızca yeni rezervasyonlara uygulanır.</p>
        </div>
      </div>

      <fieldset>
        <legend className="label">Olanaklar</legend>
        <div className="flex flex-wrap gap-x-6 gap-y-2 text-sm">
          {AMENITIES.map((a) => (
            <label key={a.value} className="flex items-center gap-2">
              <input type="checkbox" name="amenities" value={a.value} defaultChecked={venue.amenities.includes(a.value)} />
              {a.label}
            </label>
          ))}
        </div>
      </fieldset>

      <FormMessage state={state} />
      <SubmitButton>{venue.id ? 'Kaydet' : 'Tesisi oluştur'}</SubmitButton>
    </form>
  );
}
