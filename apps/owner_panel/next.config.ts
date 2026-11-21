import type { NextConfig } from 'next';

function buildCsp(): string {
  const isDev = process.env.NODE_ENV === 'development';
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  const turnstile = Boolean(process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY);

  let wss = '';
  try {
    if (supabaseUrl) wss = `wss://${new URL(supabaseUrl).host}`;
  } catch {
    // invalid URL: env.ts reports it at runtime
  }

  const scriptSrc = ["'self'", "'unsafe-inline'"];
  if (isDev) scriptSrc.push("'unsafe-eval'");
  if (turnstile) scriptSrc.push('https://challenges.cloudflare.com');

  const directives: Record<string, string[]> = {
    'default-src': ["'self'"],
    'connect-src': ["'self'", supabaseUrl, wss].filter(Boolean),
    'img-src': ["'self'", 'data:', 'blob:', supabaseUrl].filter(Boolean),
    'script-src': scriptSrc,
    'style-src': ["'self'", "'unsafe-inline'"],
    'frame-ancestors': ["'none'"],
    'base-uri': ["'self'"],
    'form-action': ["'self'"],
    'object-src': ["'none'"],
  };
  if (turnstile) directives['frame-src'] = ['https://challenges.cloudflare.com'];

  return Object.entries(directives)
    .map(([k, v]) => `${k} ${v.join(' ')}`)
    .join('; ');
}

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'Content-Security-Policy', value: buildCsp() },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
    ];
  },
};

export default nextConfig;
