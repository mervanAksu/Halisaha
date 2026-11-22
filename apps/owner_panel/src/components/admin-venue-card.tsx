'use client';

import { useActionState } from 'react';
import { adminUpdateVenue } from '@/actions/admin';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import { VenueStatusBadge } from '@/components/status-badge';
import type { ActionState } from '@/lib/action-state';
import type { VenueStatus } from '@/lib/database.types';

export type AdminVenue = {
  id: string;
  name: string;
  city: string;
  district: string;
  ownerName: string;
  status: VenueStatus;
  commissionBps: number;
  paytrKey: string | null;
};

export function AdminVenueCard({ venue }: { venue: AdminVenue }) {
  const [state, action] = useActionState<ActionState, FormData>(adminUpdateVenue, null);
  return (
    <form action={action} className="panel-card space-y-4">
      <input type="hidden" name="venueId" value={venue.id} />
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h2 className="text-[17px] font-semibold text-primary">{venue.name}</h2>
          <p className="text-sm text-textSecondary">{venue.district}, {venue.city} · {venue.ownerName || 'Sahip bilgisi yok'}</p>
        </div>
        <VenueStatusBadge status={venue.status} />
      </div>
      <div className="grid gap-4 md:grid-cols-3">
        <div>
          <label htmlFor={`status-${venue.id}`} className="label">Durum</label>
          <select id={`status-${venue.id}`} name="status" defaultValue={venue.status} className="input">
            <option value="pending">Onay bekliyor</option>
            <option value="active">Yayında</option>
            <option value="suspended">Askıya alındı</option>
          </select>
          {!venue.paytrKey ? (
            <p className="hint">Yayına almak için önce PayTR alt üye işyeri anahtarı girilmeli.</p>
          ) : null}
        </div>
        <div>
          <label htmlFor={`pct-${venue.id}`} className="label">Komisyon (% kaporadan)</label>
          <input id={`pct-${venue.id}`} name="commission_pct" inputMode="decimal" defaultValue={String(venue.commissionBps / 100).replace('.', ',')} className="input" />
          <p className="hint">0–50 arası. Veritabanında baz puan olarak saklanır.</p>
        </div>
        <div>
          <label htmlFor={`key-${venue.id}`} className="label">PayTR alt üye işyeri anahtarı</label>
          <input id={`key-${venue.id}`} name="paytr_submerchant_key" autoComplete="off" defaultValue={venue.paytrKey ?? ''} className="input" />
          <p className="hint">Boş bırakılırsa mevcut anahtar değişmez.</p>
        </div>
      </div>
      {!venue.paytrKey && venue.status !== 'active' ? (
        <p className="text-xs text-warning">PayTR anahtarı girilmeden onaylama önerilmez.</p>
      ) : null}
      <FormMessage state={state} />
      <div className="flex flex-wrap gap-2">
        <SubmitButton name="intent" value="save" className="btn-primary">Kaydet</SubmitButton>
        {venue.status !== 'active' ? (
          <SubmitButton name="intent" value="approve" className="btn-accent" pendingLabel="…">Onayla</SubmitButton>
        ) : null}
        {venue.status !== 'suspended' ? (
          <SubmitButton name="intent" value="suspend" className="btn-secondary text-danger" pendingLabel="…">Askıya al</SubmitButton>
        ) : null}
      </div>
    </form>
  );
}
