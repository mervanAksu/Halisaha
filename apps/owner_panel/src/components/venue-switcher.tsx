'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import type { VenueLite } from '@/lib/context';

export function VenueSwitcher({ venues }: { venues: VenueLite[] }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

  if (venues.length === 0) return null;
  const current = params.get('venue') ?? venues[0]?.id ?? '';

  function onChange(id: string) {
    if (/^\/venues\/(?!new)[^/]+$/.test(pathname)) {
      router.push(`/venues/${id}?venue=${id}`);
      return;
    }
    const next = new URLSearchParams(params.toString());
    next.set('venue', id);
    router.push(`${pathname}?${next.toString()}`);
  }

  return (
    <div className="flex items-center gap-2">
      <label htmlFor="venue-switcher" className="text-sm text-textSecondary">
        Tesis
      </label>
      <select
        id="venue-switcher"
        className="input w-56"
        value={venues.some((v) => v.id === current) ? current : venues[0]?.id}
        onChange={(e) => onChange(e.target.value)}
      >
        {venues.map((v) => (
          <option key={v.id} value={v.id}>
            {v.name}
          </option>
        ))}
      </select>
    </div>
  );
}
