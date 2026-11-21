import { Suspense, type ReactNode } from 'react';
import Link from 'next/link';
import { getStaffContext } from '@/lib/context';
import { Sidebar } from '@/components/sidebar';
import { VenueSwitcher } from '@/components/venue-switcher';

export default async function PanelLayout({ children }: { children: ReactNode }) {
  const { profile, venues, mfaEnabled } = await getStaffContext();

  return (
    <div className="flex min-h-screen">
      <Suspense fallback={<div className="w-56 shrink-0 bg-primary" />}>
        <Sidebar isAdmin={profile.role === 'admin'} />
      </Suspense>
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between gap-4 border-b border-border bg-card px-6 py-3">
          <Suspense fallback={null}>
            <VenueSwitcher venues={venues} />
          </Suspense>
          <div className="flex items-center gap-3 text-sm">
            <span className="text-textSecondary">
              {profile.full_name || 'Kullanıcı'} · {profile.role === 'admin' ? 'Yönetici' : 'İşletme'}
            </span>
            <form action="/auth/signout" method="post">
              <button type="submit" className="btn-secondary btn-sm">Çıkış</button>
            </form>
          </div>
        </header>
        <main className="min-w-0 flex-1 p-6">
          {profile.role === 'owner' && !mfaEnabled ? (
            <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-2xl bg-warning/15 p-4 text-sm">
              <span>Hesabını korumak için iki adımlı doğrulamayı açmanı öneririz.</span>
              <Link href="/security" className="btn-secondary btn-sm">İki adımlı doğrulamayı aç</Link>
            </div>
          ) : null}
          {children}
        </main>
      </div>
    </div>
  );
}
