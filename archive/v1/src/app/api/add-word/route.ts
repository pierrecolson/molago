import { NextRequest, NextResponse } from 'next/server';

// Simple in-memory rate limiter: 10 requests per minute per IP
const rateMap = new Map<string, { count: number; resetAt: number }>();

function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip);

  if (!entry || now > entry.resetAt) {
    rateMap.set(ip, { count: 1, resetAt: now + 60_000 });
    return false;
  }

  entry.count++;
  return entry.count > 10;
}

export async function POST(req: NextRequest) {
  // Rate limit
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
  if (isRateLimited(ip)) {
    return NextResponse.json(
      { error: 'rate_limited', message: 'Too many requests. Please wait a moment.' },
      { status: 429 }
    );
  }

  // Validate env vars
  const webhookUrl = process.env.N8N_WEBHOOK_URL;
  const apiKey = process.env.N8N_API_KEY;

  if (!webhookUrl || !apiKey) {
    return NextResponse.json(
      { error: 'server_error', message: 'Server configuration error.' },
      { status: 500 }
    );
  }

  // Parse and validate body
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: 'bad_request', message: 'Invalid request body.' },
      { status: 400 }
    );
  }

  const word = (body as Record<string, unknown>)?.word;

  if (typeof word !== 'string' || !word.trim()) {
    return NextResponse.json(
      { error: 'bad_request', message: 'Missing or empty word.' },
      { status: 400 }
    );
  }

  if (word.trim().length > 50) {
    return NextResponse.json(
      { error: 'too_long', message: 'Word is too long (max 50 characters).' },
      { status: 400 }
    );
  }

  // Forward to n8n — only send the word field
  try {
    const n8nRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: JSON.stringify({ word: word.trim() }),
      signal: AbortSignal.timeout(60_000), // 60s timeout for LLM processing
    });

    const data = await n8nRes.json();

    return NextResponse.json(data, { status: n8nRes.status });
  } catch (err) {
    if (err instanceof DOMException && err.name === 'TimeoutError') {
      return NextResponse.json(
        { error: 'timeout', message: 'Request timed out. Please try again.' },
        { status: 504 }
      );
    }

    return NextResponse.json(
      { error: 'server_error', message: 'Could not reach the word processing service.' },
      { status: 502 }
    );
  }
}
