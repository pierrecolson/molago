import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Client service role — serveur uniquement (routes API, pipeline).
// RLS est activée sans policy anon : ce client est le seul chemin d'accès.
let client: SupabaseClient | null = null;

export function supabaseAdmin(): SupabaseClient {
  if (!client) {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) {
      throw new Error('NEXT_PUBLIC_SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont requis');
    }
    client = createClient(url, key, { auth: { persistSession: false } });
  }
  return client;
}
