'use client';

export default function PanelError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div role="alert" className="panel-card flex flex-col items-start gap-3">
      <h2 className="text-[17px] font-semibold text-danger">Bir şeyler ters gitti</h2>
      <p className="text-sm text-textSecondary">Sayfa yüklenemedi. Tekrar dene; sorun sürerse yöneticiye haber ver.</p>
      <button type="button" onClick={reset} className="btn-primary">Tekrar dene</button>
    </div>
  );
}
