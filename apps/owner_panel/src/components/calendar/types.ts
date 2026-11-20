import type { BookingSource, BookingStatus } from '@/lib/database.types';

export type CalPitch = {
  id: string;
  name: string;
  format: string;
  priceKurus: number; // per slot
  depositKurus: number;
  slots: { startMs: number; endMs: number }[];
};

export type CalBooking = {
  id: string;
  pitchId: string;
  source: BookingSource;
  status: BookingStatus;
  startsAtMs: number;
  endsAtMs: number;
  priceKurus: number;
  depositKurus: number;
  customerName: string | null;
  customerPhone: string | null;
  note: string | null;
};
