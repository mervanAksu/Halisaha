import { redirect } from 'next/navigation';
import { MfaForm } from '@/components/mfa-form';
import { createClient } from '@/lib/supabase/server';

export default async function MfaPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
  if (!profile || (profile.role !== 'owner' && profile.role !== 'admin')) {
    redirect('/auth/signout?reason=forbidden');
  }

  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel === 'aal2') redirect('/calendar');

  const { data: factors } = await supabase.auth.mfa.listFactors();
  const verified = factors?.totp?.find((f) => f.status === 'verified') ?? null;

  // Owners without a factor are not forced to enroll (they use /security); admins must.
  if (!verified && profile.role !== 'admin') redirect('/calendar');

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <div className="panel-card w-full max-w-sm">
        <h1 className="text-[22px] font-bold text-primary">İki adımlı doğrulama</h1>
        <p className="mb-6 mt-1 text-sm text-textSecondary">
          {verified
            ? 'Authenticator uygulamandaki kodu gir.'
            : 'Yönetici hesapları için iki adımlı doğrulama zorunludur. Kurulumu tamamla.'}
        </p>
        <MfaForm factorId={verified?.id ?? null} next="/calendar" />
        <form action="/auth/signout" method="post" className="mt-4 text-center">
          <button type="submit" className="text-sm text-textSecondary underline">Çıkış yap</button>
        </form>
      </div>
    </main>
  );
}
