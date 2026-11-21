import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { first, type SearchParams } from '@/lib/context';
import { LoginForm } from './login-form';

export default async function LoginPage({ searchParams }: { searchParams: SearchParams }) {
  const sp = await searchParams;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (profile && (profile.role === 'owner' || profile.role === 'admin')) redirect('/calendar');
  }

  const notice =
    first(sp.error) === 'forbidden'
      ? 'Bu panele yalnızca işletme sahipleri ve yöneticiler girebilir. Oturumun kapatıldı.'
      : null;

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <div className="panel-card w-full max-w-sm">
        <h1 className="text-[22px] font-extrabold italic tracking-wide text-primary">RÖVANŞ Panel</h1>
        <p className="mb-6 mt-1 text-sm text-textSecondary">İşletme hesabınla giriş yap.</p>
        <LoginForm notice={notice} />
      </div>
    </main>
  );
}
