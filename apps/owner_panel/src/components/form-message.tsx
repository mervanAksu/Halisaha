import type { ActionState } from '@/lib/action-state';

export function FormMessage({ state }: { state: ActionState }) {
  if (!state || !state.message) return null;
  return (
    <p
      role={state.ok ? 'status' : 'alert'}
      className={`rounded-xl px-3 py-2 text-sm ${
        state.ok ? 'bg-accentSoft text-primary' : 'bg-danger/10 text-danger'
      }`}
    >
      {state.message}
    </p>
  );
}
