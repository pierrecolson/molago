import { NextResponse } from 'next/server';

/**
 * Relance du pipeline « en un tap » depuis l'état dégradé : déclenche le
 * workflow_dispatch GitHub Actions. Nécessite GITHUB_DISPATCH_TOKEN
 * (fine-grained, scope Actions read/write sur le repo).
 */
export async function POST() {
  const token = process.env.GITHUB_DISPATCH_TOKEN;
  const repo = process.env.GITHUB_REPO ?? 'pierrecolson/molago';
  if (!token) {
    return NextResponse.json(
      { error: 'GITHUB_DISPATCH_TOKEN non configuré — lancer npm run pipeline à la main.' },
      { status: 501 },
    );
  }

  const res = await fetch(
    `https://api.github.com/repos/${repo}/actions/workflows/nightly-brief.yml/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ref: 'main', inputs: { force: 'true' } }),
    },
  );

  if (res.status !== 204) {
    const text = await res.text();
    return NextResponse.json({ error: `GitHub: ${res.status} ${text.slice(0, 200)}` }, { status: 502 });
  }
  return NextResponse.json({ dispatched: true });
}
