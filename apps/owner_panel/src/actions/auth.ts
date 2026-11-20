'use server';

import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { fail, type ActionState } from '@/lib/action-state';
import { str } from '@/lib/form';

export async function login(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const email = str(formData, 'email');
  const password = typeof formData.get('password') === 'string' ? (formData.get('password') as string) : '';
  if (!email || !password) return fail('E-posta ve şifre gerekli.');

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) return fail('E-posta veya şifre hatalı.');

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', data.user.id)
    .maybeSingle();

  if (!profile || (profile.role !== 'owner' && profile.role !== 'admin')) {
    await supabase.auth.signOut();
    return fail('Bu panele yalnızca işletme sahipleri ve yöneticiler girebilir.');
  }

  redirect('/calendar');
}
