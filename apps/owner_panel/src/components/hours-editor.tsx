'use client';

import { useActionState, useState } from 'react';
import { saveVenueHours } from '@/actions/hours';
import { FormMessage } from '@/components/form-message';
import { SubmitButton } from '@/components/submit-button';
import type { ActionState } from '@/lib/action-state';
import { WEEKDAYS } from '@/lib/constants';

export type HoursByDay = Record<number, { open: string; close: string } | undefined>; // 'HH:MM'

type Row = { closed: boolean; open: string; close: string };

export function HoursEditor({ venueId, initial }: { venueId: string; initial: HoursByDay }) {
  const [state, action] = useActionState<ActionState, FormData>(saveVenueHours, null);
  const [rows, setRows] = useState<Record<number, Row>>(() => {
    const init: Record<number, Row> = {};
    for (const { iso } of WEEKDAYS) {
      const h = initial[iso];
      init[iso] = { closed: !h, open: h?.open ?? '09:00', close: h?.close ?? '23:00' };
    }
    return init;
  });

  const update = (iso: number, patch: Partial<Row>) =>
    setRows((prev) => ({ ...prev, [iso]: { ...(prev[iso] as Row), ...patch } }));

  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="venueId" value={venueId} />
      <p className="text-sm text-textSecondary">
        Kapanış saati açılıştan önce veya aynıysa tesis gece yarısından sonra kapanır (ör. 12:00 → 06:00).
      </p>
      <ul className="divide-y divide-border">
        {WEEKDAYS.map(({ iso, label }) => {
          const r = rows[iso] as Row;
          const overnight = !r.closed && r.close <= r.open;
          return (
            <li key={iso} className="flex flex-wrap items-center gap-4 py-3">
              <span className="w-28 text-sm font-medium">{label}</span>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" name={`closed_${iso}`} checked={r.closed} onChange={(e) => update(iso, { closed: e.target.checked })} />
                Kapalı
              </label>
              <div>
                <label htmlFor={`open_${iso}`} className="sr-only">{label} açılış</label>
                <input id={`open_${iso}`} name={`open_${iso}`} type="time" required={!r.closed} disabled={r.closed} value={r.open} onChange={(e) => update(iso, { open: e.target.value })} className="input w-32" />
              </div>
              <span aria-hidden="true">–</span>
              <div>
                <label htmlFor={`close_${iso}`} className="sr-only">{label} kapanış</label>
                <input id={`close_${iso}`} name={`close_${iso}`} type="time" required={!r.closed} disabled={r.closed} value={r.close} onChange={(e) => update(iso, { close: e.target.value })} className="input w-32" />
              </div>
              {overnight ? <span className="text-xs text-textSecondary">ertesi gün kapanır</span> : null}
            </li>
          );
        })}
      </ul>
      <FormMessage state={state} />
      <SubmitButton>Saatleri kaydet</SubmitButton>
    </form>
  );
}
