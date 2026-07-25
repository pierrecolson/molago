import { NextRequest, NextResponse } from 'next/server';

export async function POST(req: NextRequest) {
  // Validate env vars
  const webhookUrl = process.env.N8N_DELETE_WEBHOOK_URL;
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

  const wordId = (body as Record<string, unknown>)?.word_id;

  if (typeof wordId !== 'string' || !wordId.trim()) {
    return NextResponse.json(
      { error: 'bad_request', message: 'Missing or invalid word_id.' },
      { status: 400 }
    );
  }

  // Forward to n8n — only send the word_id field
  try {
    const n8nRes = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: JSON.stringify({ word_id: wordId.trim() }),
      signal: AbortSignal.timeout(15_000), // 15s timeout
    });

    // n8n may return empty body on success
    let data: unknown = {};
    try {
      data = await n8nRes.json();
    } catch {
      // empty response is fine for delete
    }

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
