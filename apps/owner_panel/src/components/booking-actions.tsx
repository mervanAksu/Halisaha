'use client';

import { useActionState, useEffect, useState } from 'react';
import { cancelBooking, markAttendance } from '@/actions/bookings';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';
import type { BookingSource, BookingStatus } from '@/lib/database.types';

export type ActionableBooking = {
  id: string;
  source: BookingSource;
  status: BookingStatus;
  startsAtMs: number;
};

type Props = {
  booking: ActionableBooking;
  nowMs: number;
  onDone?: (message: string) => void;
};

export function BookingActions({ booking, nowMs, onDone }: Props) {
  const [cancelState, cancelAction] = useActionState<ActionState, FormData>(cancelBooking, null);
  const [attendState, attendAction] = useActionState<ActionState, FormData>(markAttendance, null);
  const [confirming, setConfirming] = useState(false);

  useEffect(() => {
    if (cancelState?.ok) onDone?.(cancelState.message);
  }, [cancelState, onDone]);
  useEffect(() => {
    if (attendState?.ok) onDone?.(attendState.message);
  }, [attendState, onDone]);

  const cancellable = booking.status === 'confirmed' || booking.status === 'pending_payment';
  const canMark =
    booking.source !== 'block' &&
    (booking.status === 'confirmed' || booking.status === 'completed' || booking.status === 'no_show') &&
    booking.startsAtMs <= nowMs;
  const appConfirmed = booking.source === 'app' && booking.status === 'confirmed';

  if (!cancellable && !canMark) return null;

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {canMark ? (
          <form action={attendAction} className="flex gap-2">
            <input type="hidden" name="bookingId" value={booking.id} />
            <SubmitButton className="btn-accent btn-sm" name="status" value="completed" pendingLabel="…" disabled={booking.status === 'completed'}>
              Geldi
            </SubmitButton>
            <SubmitButton className="btn-secondary btn-sm" name="status" value="no_show" pendingLabel="…" disabled={booking.status === 'no_show'}>
              Gelmedi
            </SubmitButton>
          </form>
        ) : null}
        {cancellable && !confirming ? (
          <button type="button" className="btn-secondary btn-sm text-danger" onClick={() => setConfirming(true)}>
            {booking.source === 'block' ? 'Kapatmayı kaldır' : 'İptal et'}
          </button>
        ) : null}
      </div>

      {confirming && cancellable ? (
        <form action={cancelAction} className="space-y-2 rounded-xl border border-danger/30 bg-danger/5 p-3">
          <input type="hidden" name="bookingId" value={booking.id} />
          {appConfirmed ? (
            <p className="text-sm text-danger">
              Bu bir uygulama rezervasyonu. İptal edersen müşterinin kaporası tam olarak iade edilir.
            </p>
          ) : (
            <p className="text-sm">Bu işlem geri alınamaz. Emin misin?</p>
          )}
          <label htmlFor={`reason-${booking.id}`} className="label">İptal nedeni (isteğe bağlı)</label>
          <input id={`reason-${booking.id}`} name="reason" maxLength={300} className="input" />
          <div className="flex gap-2">
            <SubmitButton className="btn-danger btn-sm" pendingLabel="İptal ediliyor…">Evet, iptal et</SubmitButton>
            <button type="button" className="btn-secondary btn-sm" onClick={() => setConfirming(false)}>Vazgeç</button>
          </div>
        </form>
      ) : null}

      <FormMessage state={cancelState} />
      <FormMessage state={attendState} />
    </div>
  );
}
