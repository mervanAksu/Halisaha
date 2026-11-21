/** Explicit bookings columns: commission_kurus is not readable by clients (F-06), so never select('*'). */
export const BOOKING_COLUMNS =
  'id, pitch_id, venue_id, user_id, source, status, starts_at, ends_at, price_kurus, deposit_kurus, hold_expires_at, customer_name, customer_phone, note, cancelled_at, cancelled_by, cancel_reason, created_at, updated_at, cancellation_window_hours, confirmed_at';
