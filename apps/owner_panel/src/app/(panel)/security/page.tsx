import { MfaForm } from '@/components/mfa-form';
import { PageHeader } from '@/components/page-header';
import { getStaffContext } from '@/lib/context';

export default async function SecurityPage() {
  const { supabase, mfaEnabled } = await getStaffContext();
  const { data: factors } = await supabase.auth.mfa.listFactors();
  const hasVerified = (factors?.totp ?? []).some((f) => f.status === 'verified');

  return (
    <>
      <PageHeader title="Güvenlik" subtitle="İki adımlı doğrulama" />
      <div className="panel-card max-w-md">
        {mfaEnabled || hasVerified ? (
          <p className="text-sm">İki adımlı doğrulama açık. Girişte authenticator kodu istenir.</p>
        ) : (
          <>
            <p className="mb-4 text-sm text-textSecondary">
              Hesabını korumak için iki adımlı doğrulamayı aç. Açtıktan sonra her girişte authenticator
              uygulamandaki kod istenir.
            </p>
            <MfaForm factorId={null} next="/security" />
          </>
        )}
      </div>
    </>
  );
}
