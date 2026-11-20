'use client';

import { useActionState, useEffect, useRef } from 'react';
import { deletePitch, savePitch } from '@/actions/pitches';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';
import { PITCH_FORMATS, SLOT_MINUTES } from '@/lib/constants';
import { formatTry, kurusToInput } from '@/lib/money';

export type PitchValues = {
  id: string;
  name: string;
  format: string;
  is_indoor: boolean;
  hourly_price_kurus: number;
  deposit_kurus: number;
  slot_minutes: number;
  is_active: boolean;
};

export function PitchManager({ venueId, pitches }: { venueId: string; pitches: PitchValues[] }) {
  return (
    <div className="space-y-3">
      {pitches.length === 0 ? (
        <p className="text-sm text-textSecondary">Henüz saha eklenmemiş. Aşağıdan ilk sahanı ekle.</p>
      ) : null}
      {pitches.map((p) => (
        <details key={p.id} className="rounded-xl border border-border">
          <summary className="flex cursor-pointer flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm">
            <span className="font-semibold">{p.name} <span className="font-normal text-textSecondary">· {p.format} · {p.is_indoor ? 'Kapalı' : 'Açık'} saha</span></span>
            <span className="text-textSecondary">
              {formatTry(p.hourly_price_kurus)}/saat · kapora {formatTry(p.deposit_kurus)} · {p.slot_minutes} dk
              {p.is_active ? '' : ' · pasif'}
            </span>
          </summary>
          <div className="border-t border-border p-4">
            <PitchForm venueId={venueId} pitch={p} />
          </div>
        </details>
      ))}
      <details className="rounded-xl border border-dashed border-border">
        <summary className="cursor-pointer px-4 py-3 text-sm font-semibold text-primary">+ Saha ekle</summary>
        <div className="border-t border-border p-4">
          <PitchForm venueId={venueId} />
        </div>
      </details>
    </div>
  );
}

function PitchForm({ venueId, pitch }: { venueId: string; pitch?: PitchValues }) {
  const [state, action] = useActionState<ActionState, FormData>(savePitch, null);
  const [delState, delAction] = useActionState<ActionState, FormData>(deletePitch, null);
  const formRef = useRef<HTMLFormElement>(null);
  const uid = pitch?.id ?? 'new';

  useEffect(() => {
    if (state?.ok && !pitch) formRef.current?.reset();
  }, [state, pitch]);

  return (
    <div className="space-y-3">
      <form ref={formRef} action={action} className="space-y-4">
        <input type="hidden" name="venueId" value={venueId} />
        {pitch ? <input type="hidden" name="id" value={pitch.id} /> : null}
        <div className="grid gap-4 md:grid-cols-3">
          <div>
            <label htmlFor={`name-${uid}`} className="label">Saha adı</label>
            <input id={`name-${uid}`} name="name" required maxLength={40} defaultValue={pitch?.name ?? ''} className="input" />
          </div>
          <div>
            <label htmlFor={`format-${uid}`} className="label">Format</label>
            <select id={`format-${uid}`} name="format" defaultValue={pitch?.format ?? '7v7'} className="input">
              {PITCH_FORMATS.map((f) => (
                <option key={f} value={f}>{f}</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor={`slot-${uid}`} className="label">Slot süresi</label>
            <select id={`slot-${uid}`} name="slot_minutes" defaultValue={String(pitch?.slot_minutes ?? 60)} className="input">
              {SLOT_MINUTES.map((m) => (
                <option key={m} value={m}>{m} dakika</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor={`price-${uid}`} className="label">Saatlik ücret (TL)</label>
            <input id={`price-${uid}`} name="price" inputMode="decimal" required defaultValue={pitch ? kurusToInput(pitch.hourly_price_kurus) : ''} className="input" placeholder="3500" />
          </div>
          <div>
            <label htmlFor={`deposit-${uid}`} className="label">Kapora (TL)</label>
            <input id={`deposit-${uid}`} name="deposit" inputMode="decimal" required defaultValue={pitch ? kurusToInput(pitch.deposit_kurus) : ''} className="input" placeholder="500" />
            <p className="hint">Slot ücretini aşamaz. Kapora yoksa 0 yaz.</p>
          </div>
          <div className="flex flex-col justify-end gap-2 text-sm">
            <label className="flex items-center gap-2">
              <input type="checkbox" name="is_indoor" defaultChecked={pitch?.is_indoor ?? true} /> Kapalı saha
            </label>
            <label className="flex items-center gap-2">
              <input type="checkbox" name="is_active" defaultChecked={pitch?.is_active ?? true} /> Aktif (rezervasyona açık)
            </label>
          </div>
        </div>
        <FormMessage state={state} />
        <SubmitButton>{pitch ? 'Sahayı kaydet' : 'Sahayı ekle'}</SubmitButton>
      </form>

      {pitch ? (
        <form
          action={delAction}
          onSubmit={(e) => {
            if (!window.confirm(`“${pitch.name}” sahası silinsin mi?`)) e.preventDefault();
          }}
          className="space-y-2"
        >
          <input type="hidden" name="id" value={pitch.id} />
          <input type="hidden" name="venueId" value={venueId} />
          <FormMessage state={delState} />
          <SubmitButton className="btn-secondary btn-sm text-danger" pendingLabel="Siliniyor…">Sahayı sil</SubmitButton>
        </form>
      ) : null}
    </div>
  );
}
