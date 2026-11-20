-- Separate migration: a new enum value cannot be used in the same transaction that adds it.
alter type public.payment_status add value if not exists 'refund_processing' after 'refund_required';
