/** Public URL of an object in the public 'venue-photos' bucket. */
export function photoUrl(path: string): string {
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  return `${base}/storage/v1/object/public/venue-photos/${path}`;
}
