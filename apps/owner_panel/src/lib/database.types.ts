// HAND-WRITTEN (not generated) — regenerate with `supabase gen types typescript --local`
// Source of truth: supabase/migrations/*.sql (core_schema, rls_policies, booking_rpcs).

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type AppRole = 'customer' | 'owner' | 'admin';
export type VenueStatus = 'pending' | 'active' | 'suspended';
export type BookingSource = 'app' | 'manual' | 'block';
export type BookingStatus =
  | 'pending_payment'
  | 'confirmed'
  | 'cancelled'
  | 'expired'
  | 'completed'
  | 'no_show';
export type PaymentStatus =
  | 'initiated'
  | 'succeeded'
  | 'failed'
  | 'refund_required'
  | 'refund_processing'
  | 'refunded';

type ProfileRow = {
  id: string;
  full_name: string;
  phone: string | null;
  email: string | null;
  role: AppRole;
  marketing_consent: boolean;
  kvkk_ack_at: string | null;
  created_at: string;
  updated_at: string;
};

type VenueRow = {
  id: string;
  owner_id: string;
  name: string;
  description: string;
  city: string;
  district: string;
  address: string;
  lat: number | null;
  lng: number | null;
  phone: string | null;
  cover_photo_path: string | null;
  photo_paths: string[];
  amenities: string[];
  status: VenueStatus;
  commission_bps: number;
  cancellation_window_hours: number;
  paytr_submerchant_key: string | null;
  created_at: string;
  updated_at: string;
};

type VenuePayoutAccountRow = {
  venue_id: string;
  legal_name: string;
  tax_number: string;
  iban: string;
  verified_at: string | null;
  updated_at: string;
};

type VenueHoursRow = {
  venue_id: string;
  iso_weekday: number;
  open_time: string; // 'HH:MM:SS'
  close_time: string; // 'HH:MM:SS'
};

type PitchRow = {
  id: string;
  venue_id: string;
  name: string;
  format: string;
  is_indoor: boolean;
  hourly_price_kurus: number;
  deposit_kurus: number;
  slot_minutes: number;
  is_active: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
};

type BookingRow = {
  id: string;
  pitch_id: string;
  venue_id: string;
  user_id: string | null;
  source: BookingSource;
  status: BookingStatus;
  starts_at: string;
  ends_at: string;
  price_kurus: number;
  deposit_kurus: number;
  // commission_kurus: column SELECT revoked from `authenticated` (F-06); never select it from the panel.
  commission_kurus?: number;
  hold_expires_at: string | null;
  customer_name: string | null;
  customer_phone: string | null;
  note: string | null;
  cancelled_at: string | null;
  cancelled_by: string | null;
  cancel_reason: string | null;
  created_at: string;
  updated_at: string;
  cancellation_window_hours: number | null;
  confirmed_at: string | null;
};

type PaymentRow = {
  id: string;
  booking_id: string;
  user_id: string | null;
  provider: string;
  merchant_oid: string;
  amount_kurus: number;
  status: PaymentStatus;
  provider_payload: Json | null;
  failed_reason: string | null;
  created_at: string;
  updated_at: string;
};

type FavoriteRow = {
  user_id: string;
  venue_id: string;
  created_at: string;
};

type AuditLogRow = {
  id: number;
  at: string;
  actor: string | null;
  table_name: string;
  row_id: string;
  action: string;
  diff: Json;
};

type DeviceTokenRow = {
  token: string;
  user_id: string;
  platform: 'ios' | 'android';
  updated_at: string;
};

/** Insert shape: the listed keys are required, everything else is optional (has a default). */
type Insertable<Row, Required extends keyof Row> = Pick<Row, Required> & Partial<Omit<Row, Required>>;

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: ProfileRow;
        Insert: Insertable<ProfileRow, 'id'>;
        Update: Partial<ProfileRow>;
        Relationships: [];
      };
      venues: {
        Row: VenueRow;
        Insert: Insertable<VenueRow, 'name' | 'district'>;
        Update: Partial<VenueRow>;
        Relationships: [
          {
            foreignKeyName: 'venues_owner_id_fkey';
            columns: ['owner_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      venue_payout_accounts: {
        Row: VenuePayoutAccountRow;
        Insert: Insertable<VenuePayoutAccountRow, 'venue_id' | 'legal_name' | 'tax_number' | 'iban'>;
        Update: Partial<VenuePayoutAccountRow>;
        Relationships: [
          {
            foreignKeyName: 'venue_payout_accounts_venue_id_fkey';
            columns: ['venue_id'];
            isOneToOne: true;
            referencedRelation: 'venues';
            referencedColumns: ['id'];
          },
        ];
      };
      venue_hours: {
        Row: VenueHoursRow;
        Insert: VenueHoursRow;
        Update: Partial<VenueHoursRow>;
        Relationships: [
          {
            foreignKeyName: 'venue_hours_venue_id_fkey';
            columns: ['venue_id'];
            isOneToOne: false;
            referencedRelation: 'venues';
            referencedColumns: ['id'];
          },
        ];
      };
      pitches: {
        Row: PitchRow;
        Insert: Insertable<PitchRow, 'venue_id' | 'name' | 'hourly_price_kurus' | 'deposit_kurus'>;
        Update: Partial<PitchRow>;
        Relationships: [
          {
            foreignKeyName: 'pitches_venue_id_fkey';
            columns: ['venue_id'];
            isOneToOne: false;
            referencedRelation: 'venues';
            referencedColumns: ['id'];
          },
        ];
      };
      bookings: {
        Row: BookingRow;
        Insert: Insertable<BookingRow, 'pitch_id' | 'venue_id' | 'status' | 'starts_at' | 'ends_at'>;
        Update: Partial<BookingRow>;
        Relationships: [
          {
            foreignKeyName: 'bookings_pitch_id_fkey';
            columns: ['pitch_id'];
            isOneToOne: false;
            referencedRelation: 'pitches';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'bookings_venue_id_fkey';
            columns: ['venue_id'];
            isOneToOne: false;
            referencedRelation: 'venues';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'bookings_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      payments: {
        Row: PaymentRow;
        Insert: Insertable<PaymentRow, 'booking_id' | 'merchant_oid' | 'amount_kurus'>;
        Update: Partial<PaymentRow>;
        Relationships: [
          {
            foreignKeyName: 'payments_booking_id_fkey';
            columns: ['booking_id'];
            isOneToOne: false;
            referencedRelation: 'bookings';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'payments_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      favorites: {
        Row: FavoriteRow;
        Insert: Insertable<FavoriteRow, 'venue_id'>;
        Update: Partial<FavoriteRow>;
        Relationships: [
          {
            foreignKeyName: 'favorites_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'favorites_venue_id_fkey';
            columns: ['venue_id'];
            isOneToOne: false;
            referencedRelation: 'venues';
            referencedColumns: ['id'];
          },
        ];
      };
      device_tokens: {
        Row: DeviceTokenRow;
        Insert: Insertable<DeviceTokenRow, 'token' | 'platform'>;
        Update: Partial<DeviceTokenRow>;
        Relationships: [
          {
            foreignKeyName: 'device_tokens_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      audit_log: {
        Row: AuditLogRow;
        Insert: Insertable<AuditLogRow, 'table_name' | 'row_id' | 'action'>;
        Update: Partial<AuditLogRow>;
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      admin_list_venues: {
        Args: Record<string, never>;
        Returns: VenueRow[];
      };
      admin_update_venue: {
        Args: {
          p_venue_id: string;
          p_status?: VenueStatus;
          p_commission_bps?: number;
          p_paytr_submerchant_key?: string;
        };
        Returns: VenueRow;
      };
      admin_verify_payout: {
        Args: { p_venue_id: string };
        Returns: undefined;
      };
      register_device_token: {
        Args: { p_token: string; p_platform: 'ios' | 'android' };
        Returns: undefined;
      };
      owner_customer_contacts: {
        Args: { p_user_ids: string[] };
        Returns: { user_id: string; full_name: string; phone: string | null }[];
      };
      cancel_booking: {
        Args: { p_booking_id: string; p_reason?: string };
        Returns: { status: BookingStatus; refund_eligible: boolean }[];
      };
      create_booking_hold: {
        Args: { p_pitch_id: string; p_starts_at: string };
        Returns: BookingRow;
      };
      get_availability: {
        Args: { p_pitch_id: string; p_date: string };
        Returns: {
          starts_at: string;
          ends_at: string;
          state: string;
          price_kurus: number;
          deposit_kurus: number;
        }[];
      };
      is_admin: { Args: Record<PropertyKey, never>; Returns: boolean };
      is_venue_owner: { Args: { p_venue_id: string }; Returns: boolean };
      venue_is_visible: { Args: { p_venue_id: string }; Returns: boolean };
      list_venues: {
        Args: {
          p_search?: string;
          p_district?: string;
          p_lat?: number;
          p_lng?: number;
        };
        Returns: {
          id: string;
          name: string;
          district: string;
          address: string;
          cover_photo_path: string | null;
          min_hourly_price_kurus: number | null;
          open_time: string | null;
          close_time: string | null;
          distance_km: number | null;
          is_favorite: boolean;
        }[];
      };
      my_completed_match_count: { Args: Record<PropertyKey, never>; Returns: number };
      owner_cancel_booking: {
        Args: { p_booking_id: string; p_reason?: string };
        Returns: BookingRow;
      };
      owner_create_manual_booking: {
        Args: {
          p_pitch_id: string;
          p_starts_at: string;
          p_ends_at: string;
          p_source?: BookingSource;
          p_customer_name?: string;
          p_customer_phone?: string;
          p_note?: string;
        };
        Returns: BookingRow;
      };
      owner_mark_attendance: {
        Args: { p_booking_id: string; p_status: BookingStatus };
        Returns: BookingRow;
      };
    };
    Enums: {
      app_role: AppRole;
      venue_status: VenueStatus;
      booking_source: BookingSource;
      booking_status: BookingStatus;
      payment_status: PaymentStatus;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type PublicSchema = Database['public'];

export type Tables<T extends keyof PublicSchema['Tables']> = PublicSchema['Tables'][T]['Row'];
export type TablesInsert<T extends keyof PublicSchema['Tables']> = PublicSchema['Tables'][T]['Insert'];
export type TablesUpdate<T extends keyof PublicSchema['Tables']> = PublicSchema['Tables'][T]['Update'];
export type Enums<T extends keyof PublicSchema['Enums']> = PublicSchema['Enums'][T];
