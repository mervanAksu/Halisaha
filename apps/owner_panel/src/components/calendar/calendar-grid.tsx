'use client';

import { Fragment, useCallback, useState } from 'react';
import { ROW_MS } from '@/lib/calendar';
import { formatTry } from '@/lib/money';
import { formatTime } from '@/lib/time';
import { BookingDrawer } from './booking-drawer';
import { SlotDialog, type SelectedSlot } from './slot-dialog';
import type { CalBooking, CalPitch } from './types';

const ROW_PX = 32;
const HEADER_PX = 48;

type Props = {
  openMs: number;
  closeMs: number;
  nowMs: number;
  pitches: CalPitch[];
  bookings: CalBooking[];
};

function bookingStyle(b: CalBooking): { cls: string; label: string } {
  if (b.source === 'block') return { cls: 'bg-stripes text-textPrimary', label: 'Kapalı' };
  if (b.status === 'pending_payment') return { cls: 'bg-warning text-textPrimary', label: 'Ödeme bekleniyor' };
  const base = b.source === 'app' ? 'bg-accent text-white' : 'bg-primary text-white';
  if (b.status === 'completed') return { cls: `${base} opacity-60`, label: 'Tamamlandı' };
  if (b.status === 'no_show') return { cls: `${base} opacity-60 ring-2 ring-inset ring-danger`, label: 'Gelmedi' };
  return { cls: base, label: b.source === 'app' ? 'Uygulama' : 'Manuel' };
}

export function CalendarGrid({ openMs, closeMs, nowMs, pitches, bookings }: Props) {
  const [slot, setSlot] = useState<SelectedSlot | null>(null);
  const [selected, setSelected] = useState<CalBooking | null>(null);
  const [flash, setFlash] = useState<string | null>(null);

  const closeSlot = useCallback(() => setSlot(null), []);
  const closeBooking = useCallback(() => setSelected(null), []);
  const done = useCallback((message: string) => {
    setSlot(null);
    setSelected(null);
    setFlash(message);
  }, []);

  const rows = Math.ceil((closeMs - openMs) / ROW_MS);
  const rowOf = (ms: number, round: 'floor' | 'ceil') =>
    (round === 'floor' ? Math.floor : Math.ceil)((ms - openMs) / ROW_MS) + 2; // +1 for 1-based, +1 for header row

  if (pitches.length === 0) {
    return <p className="panel-card text-sm text-textSecondary">Bu tesiste aktif saha yok.</p>;
  }

  return (
    <div className="space-y-3">
      <Legend />
      {flash ? (
        <p role="status" className="rounded-xl bg-accentSoft px-3 py-2 text-sm text-primary">
          {flash}
        </p>
      ) : null}

      <div className="max-h-[75vh] overflow-auto rounded-2xl border border-border bg-card">
        <div
          className="grid"
          style={{
            gridTemplateColumns: `64px repeat(${pitches.length}, minmax(170px, 1fr))`,
            gridTemplateRows: `${HEADER_PX}px repeat(${rows}, ${ROW_PX}px)`,
          }}
        >
          <div className="sticky left-0 top-0 z-20 border-b border-border bg-card" style={{ gridRow: 1, gridColumn: 1 }} />
          {pitches.map((p, i) => (
            <div
              key={p.id}
              className="sticky top-0 z-10 flex flex-col justify-center border-b border-l border-border bg-card px-3"
              style={{ gridRow: 1, gridColumn: i + 2 }}
            >
              <span className="truncate text-sm font-semibold text-primary">{p.name}</span>
              <span className="text-xs text-textSecondary">{p.format}</span>
            </div>
          ))}

          {Array.from({ length: Math.ceil(rows / 2) }, (_, k) => (
            <div
              key={`t${k}`}
              className="sticky left-0 z-10 border-t border-border bg-card px-2 pt-1 text-xs text-textSecondary"
              style={{ gridRow: `${k * 2 + 2} / span 2`, gridColumn: 1 }}
            >
              {formatTime(openMs + k * 2 * ROW_MS)}
            </div>
          ))}

          {pitches.map((p, i) => {
            const own = bookings.filter((b) => b.pitchId === p.id);
            return (
              <Fragment key={p.id}>
              {[
              ...p.slots
                .filter((s) => !own.some((b) => b.startsAtMs < s.endMs && b.endsAtMs > s.startMs))
                .map((s) => {
                  const past = s.endMs <= nowMs;
                  return (
                    <button
                      key={`${p.id}-${s.startMs}`}
                      type="button"
                      onClick={() => setSlot({ pitchId: p.id, pitchName: p.name, startMs: s.startMs, endMs: s.endMs })}
                      aria-label={`${p.name} ${formatTime(s.startMs)} boş saat`}
                      className={`m-px flex flex-col items-start justify-center rounded-lg border border-l border-accent/40 px-2 text-left text-xs hover:bg-accentSoft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent ${
                        past ? 'bg-surface text-textSecondary' : 'bg-white text-textPrimary'
                      }`}
                      style={{
                        gridColumn: i + 2,
                        gridRow: `${rowOf(s.startMs, 'floor')} / ${Math.max(rowOf(s.endMs, 'ceil'), rowOf(s.startMs, 'floor') + 1)}`,
                      }}
                    >
                      <span>{formatTime(s.startMs)}–{formatTime(s.endMs)}</span>
                      <span className="text-textSecondary">{formatTry(p.priceKurus)}</span>
                    </button>
                  );
                }),
              ...own.map((b) => {
                const start = rowOf(Math.max(b.startsAtMs, openMs), 'floor');
                const end = Math.max(rowOf(Math.min(b.endsAtMs, closeMs), 'ceil'), start + 1);
                const st = bookingStyle(b);
                return (
                  <button
                    key={b.id}
                    type="button"
                    onClick={() => setSelected(b)}
                    aria-label={`${p.name} ${formatTime(b.startsAtMs)} ${st.label}`}
                    className={`m-px flex flex-col items-start justify-center overflow-hidden rounded-lg px-2 text-left text-xs font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary ${st.cls}`}
                    style={{ gridColumn: i + 2, gridRow: `${start} / ${end}` }}
                  >
                    <span>{formatTime(b.startsAtMs)}–{formatTime(b.endsAtMs)}</span>
                    <span className="max-w-full truncate">
                      {b.source === 'block' ? 'Kapalı' : b.customerName || st.label}
                    </span>
                  </button>
                );
              }),
              ]}
              </Fragment>
            );
          })}
        </div>
      </div>

      {slot ? <SlotDialog slot={slot} onClose={closeSlot} onDone={done} /> : null}
      {selected ? (
        <BookingDrawer
          booking={selected}
          pitchName={pitches.find((p) => p.id === selected.pitchId)?.name ?? ''}
          nowMs={nowMs}
          onClose={closeBooking}
          onDone={done}
        />
      ) : null}
    </div>
  );
}

function Legend() {
  const items = [
    { cls: 'bg-accent', label: 'Uygulama' },
    { cls: 'bg-primary', label: 'Manuel' },
    { cls: 'bg-stripes', label: 'Kapalı' },
    { cls: 'bg-warning', label: 'Ödeme bekleniyor' },
    { cls: 'border border-accent/40 bg-white', label: 'Boş' },
  ];
  return (
    <ul className="flex flex-wrap gap-4 text-xs text-textSecondary" aria-label="Renk açıklaması">
      {items.map((i) => (
        <li key={i.label} className="flex items-center gap-1.5">
          <span className={`inline-block h-3 w-3 rounded ${i.cls}`} />
          {i.label}
        </li>
      ))}
    </ul>
  );
}
