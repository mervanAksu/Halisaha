'use client';

import type { ReactNode } from 'react';
import { BookingActions } from '@/components/booking-actions';
import { Modal } from '@/components/modal';
import { BookingStatusBadge, SOURCE_LABEL } from '@/components/status-badge';
import { formatTime, formatDateTime } from '@/lib/time';
import { formatTry } from '@/lib/money';
import type { CalBooking } from './types';

export function BookingDrawer({
  booking,
  pitchName,
  nowMs,
  onClose,
  onDone,
}: {
  booking: CalBooking;
  pitchName: string;
  nowMs: number;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const isBlock = booking.source === 'block';
  return (
    <Modal title={isBlock ? 'Kapalı saat' : 'Rezervasyon detayı'} onClose={onClose} side>
      <dl className="space-y-3 text-sm">
        <Row label="Durum"><BookingStatusBadge status={booking.status} /></Row>
        <Row label="Tür">{SOURCE_LABEL[booking.source]}</Row>
        <Row label="Saha">{pitchName}</Row>
        <Row label="Saat">
          {formatDateTime(booking.startsAtMs)} – {formatTime(booking.endsAtMs)}
        </Row>
        {!isBlock ? (
          <>
            <Row label="Müşteri">{booking.customerName || '—'}</Row>
            <Row label="Telefon">
              {booking.customerPhone ? (
                <a className="text-primary underline" href={`tel:${booking.customerPhone}`}>{booking.customerPhone}</a>
              ) : (
                '—'
              )}
            </Row>
            <Row label="Ücret">{formatTry(booking.priceKurus)}</Row>
            <Row label="Kapora">
              {booking.source === 'app' ? `${formatTry(booking.depositKurus)} (online)` : 'Yok (manuel giriş)'}
            </Row>
          </>
        ) : null}
        {booking.note ? <Row label="Not">{booking.note}</Row> : null}
      </dl>
      <div className="mt-6">
        <BookingActions booking={booking} nowMs={nowMs} onDone={onDone} />
      </div>
    </Modal>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-textSecondary">{label}</dt>
      <dd className="text-right font-medium">{children}</dd>
    </div>
  );
}
