'use client';

import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';

const LINKS = [
  { href: '/calendar', label: 'Takvim' },
  { href: '/bookings', label: 'Rezervasyonlar' },
  { href: '/venues', label: 'Tesislerim' },
  { href: '/payout', label: 'Ödeme Bilgileri' },
];

const ADMIN_LINKS = [
  { href: '/admin/venues', label: 'Saha Onayları' },
  { href: '/admin/refunds', label: 'İadeler' },
];

export function Sidebar({ isAdmin }: { isAdmin: boolean }) {
  const pathname = usePathname();
  const venue = useSearchParams().get('venue');

  const render = (items: { href: string; label: string }[]) =>
    items.map((l) => {
      const active = pathname === l.href || pathname.startsWith(`${l.href}/`);
      const href = venue ? `${l.href}?venue=${encodeURIComponent(venue)}` : l.href;
      return (
        <li key={l.href}>
          <Link
            href={href}
            aria-current={active ? 'page' : undefined}
            className={`block rounded-xl px-3 py-2 text-sm font-medium ${
              active ? 'bg-white/15 text-white' : 'text-white/75 hover:bg-white/10 hover:text-white'
            }`}
          >
            {l.label}
          </Link>
        </li>
      );
    });

  return (
    <nav aria-label="Ana menü" className="flex w-56 shrink-0 flex-col gap-6 bg-primary p-4 text-white">
      <div className="px-3 py-2 text-lg font-bold">Halısaha</div>
      <ul className="space-y-1">{render(LINKS)}</ul>
      {isAdmin ? (
        <div>
          <p className="mb-2 px-3 text-xs font-semibold uppercase tracking-wide text-white/50">Yönetici</p>
          <ul className="space-y-1">{render(ADMIN_LINKS)}</ul>
        </div>
      ) : null}
    </nav>
  );
}
