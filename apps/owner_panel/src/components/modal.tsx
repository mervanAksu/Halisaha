'use client';

import { useEffect, useRef, type ReactNode } from 'react';

type Props = {
  title: string;
  onClose: () => void;
  children: ReactNode;
  side?: boolean;
};

/** Accessible modal / right-hand drawer: Escape and backdrop click close it. */
export function Modal({ title, onClose, children, side = false }: Props) {
  const ref = useRef<HTMLDivElement>(null);

  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  useEffect(() => {
    ref.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeRef.current();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  return (
    <div className={`fixed inset-0 z-50 flex ${side ? 'justify-end' : 'items-center justify-center'} bg-primary/40 p-4`}>
      <button type="button" aria-label="Kapat" className="absolute inset-0 cursor-default" onClick={onClose} tabIndex={-1} />
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className={`relative z-10 overflow-y-auto bg-card p-6 shadow-xl focus:outline-none ${
          side ? 'h-full w-full max-w-md rounded-2xl' : 'w-full max-w-md rounded-2xl'
        }`}
      >
        <div className="mb-4 flex items-start justify-between gap-4">
          <h2 className="text-[17px] font-semibold text-primary">{title}</h2>
          <button type="button" onClick={onClose} className="btn-secondary btn-sm">
            Kapat
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
