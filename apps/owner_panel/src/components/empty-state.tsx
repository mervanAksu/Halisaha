import Link from 'next/link';

export function EmptyState({
  title,
  actionHref,
  actionLabel,
}: {
  title: string;
  actionHref?: string;
  actionLabel?: string;
}) {
  return (
    <div className="panel-card flex flex-col items-center gap-4 py-12 text-center">
      <svg aria-hidden="true" viewBox="0 0 24 24" className="h-10 w-10 text-textSecondary" fill="none" stroke="currentColor" strokeWidth="1.5">
        <rect x="3" y="4" width="18" height="16" rx="3" />
        <path d="M12 4v16M3 12h18" />
      </svg>
      <p className="text-textSecondary">{title}</p>
      {actionHref && actionLabel ? (
        <Link href={actionHref} className="btn-primary">
          {actionLabel}
        </Link>
      ) : null}
    </div>
  );
}
