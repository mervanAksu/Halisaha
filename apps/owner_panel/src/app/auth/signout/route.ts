import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';

async function signOut(request: NextRequest, forbidden: boolean) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  const url = request.nextUrl.clone();
  url.pathname = '/login';
  url.search = forbidden ? '?error=forbidden' : '';
  return NextResponse.redirect(url, { status: 303 });
}

/** Same-origin check: Origin (or Referer) host must equal the request Host. */
function isSameOrigin(request: NextRequest): boolean {
  const host = request.headers.get('x-forwarded-host') ?? request.headers.get('host');
  const source = request.headers.get('origin') ?? request.headers.get('referer');
  if (!host || !source) return false;
  try {
    return new URL(source).host === host;
  } catch {
    return false;
  }
}

// GET is only used by the panel layout when the signed-in role is not owner/admin.
export async function GET(request: NextRequest) {
  if (request.nextUrl.searchParams.get('reason') !== 'forbidden') {
    return new NextResponse('Method Not Allowed', { status: 405, headers: { Allow: 'POST' } });
  }
  return signOut(request, true);
}

export async function POST(request: NextRequest) {
  if (!isSameOrigin(request)) return new NextResponse('Forbidden', { status: 403 });
  return signOut(request, false);
}
