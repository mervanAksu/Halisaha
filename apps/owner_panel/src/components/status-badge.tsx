import type { BookingSource, BookingStatus, VenueStatus } from '@/lib/database.types';

const BOOKING: Record<BookingStatus, { label: string; cls: string }> = {
  confirmed: { label: 'Onaylandı', cls: 'bg-accent text-white' },
  pending_payment: { label: 'Ödeme bekleniyor', cls: 'bg-warning text-textPrimary' },
  cancelled: { label: 'İptal', cls: 'bg-danger text-white' },
  completed: { label: 'Tamamlandı', cls: 'bg-gray-200 text-textPrimary' },
  no_show: { label: 'Gelmedi', cls: 'border border-danger bg-white text-danger' },
  expired: { label: 'Süresi doldu', cls: 'bg-gray-200 text-textSecondary' },
};

export function BookingStatusBadge({ status }: { status: BookingStatus }) {
  const s = BOOKING[status];
  return <span className={`badge ${s.cls}`}>{s.label}</span>;
}

const VENUE: Record<VenueStatus, { label: string; cls: string }> = {
  pending: { label: 'Onay bekliyor', cls: 'bg-warning text-textPrimary' },
  active: { label: 'Yayında', cls: 'bg-accent text-white' },
  suspended: { label: 'Askıya alındı', cls: 'bg-danger text-white' },
};

export function VenueStatusBadge({ status }: { status: VenueStatus }) {
  const s = VENUE[status];
  return <span className={`badge ${s.cls}`}>{s.label}</span>;
}

export const SOURCE_LABEL: Record<BookingSource, string> = {
  app: 'Uygulama',
  manual: 'Manuel',
  block: 'Kapalı',
};
