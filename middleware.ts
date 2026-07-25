import { NextRequest, NextResponse } from 'next/server';

// Auth mono-utilisateur : un cookie contenant APP_SECRET.
// /login?key=<APP_SECRET> pose le cookie (1 an) puis redirige vers /.
const COOKIE_NAME = 'molago_key';

export function middleware(request: NextRequest) {
  const secret = process.env.APP_SECRET;
  if (!secret) return NextResponse.next(); // dev sans secret

  const { pathname, searchParams } = request.nextUrl;

  if (pathname === '/login') {
    if (searchParams.get('key') === secret) {
      const response = NextResponse.redirect(new URL('/', request.url));
      response.cookies.set(COOKIE_NAME, secret, {
        httpOnly: true,
        secure: true,
        sameSite: 'lax',
        maxAge: 60 * 60 * 24 * 365,
        path: '/',
      });
      return response;
    }
    return new NextResponse('Molago — clé requise', { status: 401 });
  }

  if (request.cookies.get(COOKIE_NAME)?.value === secret) {
    return NextResponse.next();
  }
  return new NextResponse('Molago — accès via /login?key=…', { status: 401 });
}

export const config = {
  // Tout sauf les assets statiques Next et les icônes.
  matcher: ['/((?!_next/static|_next/image|icons|logo.svg|favicon.ico|manifest.webmanifest).*)'],
};
