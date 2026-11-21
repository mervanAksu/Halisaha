import { cache } from 'react';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import type { AppRole } from '@/lib/database.types';

export type SearchParams = Promise<Record<string, string | string[] | undefined>>;

export type VenueLite = {
  id: string;
  name: string;
  status: 'pending' | 'active' | 'suspended';
};

export type StaffProfile = { id: string; full_name: string; role: AppRole };

/** First value of a search param. */
export function first(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}

/**
 * Per-request context for the panel: authenticated owner/admin + the venues they can pick from.
 * Redirects to /login when there is no session, and to the sign-out route when the role is wrong
 * (cookies can only be cleared in a route handler).
 */
export const getStaffContext = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, full_name, role')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile || (profile.role !== 'owner' && profile.role !== 'admin')) {
    redirect('/auth/signout?reason=forbidden');
  }

  // MFA (S-04): admins must be aal2 (is_admin() requires it in the DB); owners must be aal2 once they
  // have a verified TOTP factor. Redirect BEFORE any admin query runs.
  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  const currentLevel = aal?.currentLevel ?? 'aal1';
  const hasFactor = aal?.nextLevel === 'aal2' || currentLevel === 'aal2';
  if (profile.role === 'admin' && currentLevel !== 'aal2') redirect('/login/mfa');
  if (profile.role === 'owner' && hasFactor && currentLevel !== 'aal2') redirect('/login/mfa');

  // Owners see their own venues; admins can switch between all venues (RLS allows it).
  let query = supabase.from('venues').select('id, name, status').order('name');
  if (profile.role === 'owner') query = query.eq('owner_id', user.id);
  const { data: venues, error } = await query;
  if (error) throw new Error(error.message);

  return {
    supabase,
    user,
    profile: profile as StaffProfile,
    mfaEnabled: hasFactor,
    venues: (venues ?? []) as VenueLite[],
  };
});

export async function requireAdmin() {
  const ctx = await getStaffContext();
  if (ctx.profile.role !== 'admin') redirect('/calendar');
  return ctx;
}

/** Picks the venue from the `venue` search param, falling back to the first one. */
export function pickVenue(venues: VenueLite[], requested: string | undefined): VenueLite | null {
  if (venues.length === 0) return null;
  return venues.find((v) => v.id === requested) ?? venues[0] ?? null;
}

/** Authenticated Supabase client for server actions, or null when the session is gone. */
export async function actionClient() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user ? { supabase, user } : null;
}
