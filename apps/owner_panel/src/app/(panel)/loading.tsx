export default function Loading() {
  return (
    <div role="status" aria-live="polite" className="space-y-4">
      <div className="h-8 w-48 animate-pulse rounded-xl bg-border" />
      <div className="h-64 animate-pulse rounded-2xl bg-border" />
      <span className="sr-only">Yükleniyor…</span>
    </div>
  );
}
