import { EmptyState } from '@/components/empty-state';
import { PageHeader } from '@/components/page-header';
import { requireAdmin } from '@/lib/context';
import { toTurkishError } from '@/lib/errors';
import { formatDateTime } from '@/lib/time';

export default async function AdminAuditPage() {
  const { supabase } = await requireAdmin();

  const { data, error } = await supabase
    .from('audit_log')
    .select('id, at, actor, table_name, row_id, action, diff')
    .order('at', { ascending: false })
    .limit(200);
  if (error) throw new Error(toTurkishError(error));
  const rows = data ?? [];

  return (
    <>
      <PageHeader title="Denetim Kaydı" subtitle="Son 200 kayıt" />
      {rows.length === 0 ? (
        <EmptyState title="Denetim kaydı yok." />
      ) : (
        <div className="overflow-x-auto rounded-2xl border border-border bg-card">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-border bg-surface text-xs uppercase text-textSecondary">
              <tr>
                <th scope="col" className="px-4 py-3">Zaman</th>
                <th scope="col" className="px-4 py-3">Kullanıcı</th>
                <th scope="col" className="px-4 py-3">Tablo</th>
                <th scope="col" className="px-4 py-3">Kayıt</th>
                <th scope="col" className="px-4 py-3">İşlem</th>
                <th scope="col" className="px-4 py-3">Fark</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-b border-border align-top last:border-0">
                  <td className="px-4 py-3 whitespace-nowrap">{formatDateTime(r.at)}</td>
                  <td className="px-4 py-3 font-mono text-xs">{r.actor ?? '—'}</td>
                  <td className="px-4 py-3">{r.table_name}</td>
                  <td className="px-4 py-3 font-mono text-xs">{r.row_id}</td>
                  <td className="px-4 py-3">{r.action}</td>
                  <td className="px-4 py-3">
                    <pre className="max-w-md whitespace-pre-wrap break-all text-xs">{JSON.stringify(r.diff, null, 1)}</pre>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
