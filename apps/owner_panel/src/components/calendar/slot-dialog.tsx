'use client';

import { useActionState, useEffect, useState } from 'react';
import { createManualBooking } from '@/actions/bookings';
import { FormMessage } from '@/components/form-message';
import { Modal } from '@/components/modal';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';
import { formatTime } from '@/lib/time';

export type SelectedSlot = { pitchId: string; pitchName: string; startMs: number; endMs: number };

export function SlotDialog({
  slot,
  onClose,
  onDone,
}: {
  slot: SelectedSlot;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const [state, action] = useActionState<ActionState, FormData>(createManualBooking, null);
  const [mode, setMode] = useState<'manual' | 'block'>('manual');

  useEffect(() => {
    if (state?.ok) onDone(state.message);
  }, [state, onDone]);

  return (
    <Modal title="Boş saat" onClose={onClose}>
      <p className="mb-4 text-sm text-textSecondary">
        {slot.pitchName} · {formatTime(slot.startMs)}–{formatTime(slot.endMs)}
      </p>
      <form action={action} className="space-y-4">
        <input type="hidden" name="pitchId" value={slot.pitchId} />
        <input type="hidden" name="startsAt" value={new Date(slot.startMs).toISOString()} />
        <input type="hidden" name="endsAt" value={new Date(slot.endMs).toISOString()} />

        <fieldset>
          <legend className="label">İşlem</legend>
          <div className="flex gap-4 text-sm">
            <label className="flex items-center gap-2">
              <input type="radio" name="mode" value="manual" checked={mode === 'manual'} onChange={() => setMode('manual')} />
              Manuel rezervasyon
            </label>
            <label className="flex items-center gap-2">
              <input type="radio" name="mode" value="block" checked={mode === 'block'} onChange={() => setMode('block')} />
              Saati kapat
            </label>
          </div>
        </fieldset>

        {mode === 'manual' ? (
          <>
            <div>
              <label htmlFor="customerName" className="label">Müşteri adı</label>
              <input id="customerName" name="customerName" required maxLength={80} className="input" />
            </div>
            <div>
              <label htmlFor="customerPhone" className="label">Telefon</label>
              <input id="customerPhone" name="customerPhone" type="tel" maxLength={20} className="input" />
            </div>
          </>
        ) : null}
        <div>
          <label htmlFor="note" className="label">Not (isteğe bağlı)</label>
          <textarea id="note" name="note" maxLength={500} rows={2} className="input" />
        </div>

        <FormMessage state={state} />
        <SubmitButton className="btn-primary w-full">{mode === 'block' ? 'Saati kapat' : 'Rezervasyonu kaydet'}</SubmitButton>
      </form>
    </Modal>
  );
}
