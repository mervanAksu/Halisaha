'use client';

import type { ReactNode } from 'react';
import { useFormStatus } from 'react-dom';

type Props = {
  children: ReactNode;
  pendingLabel?: string;
  className?: string;
  name?: string;
  value?: string;
  disabled?: boolean;
};

export function SubmitButton({
  children,
  pendingLabel = 'Kaydediliyor…',
  className = 'btn-primary',
  name,
  value,
  disabled,
}: Props) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" name={name} value={value} className={className} disabled={pending || disabled}>
      {pending ? pendingLabel : children}
    </button>
  );
}
