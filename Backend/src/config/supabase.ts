import { createClient } from '@supabase/supabase-js';
import { env } from './env.js';

/**
 * Supabase Admin client — uses the service_role key to bypass RLS.
 * Use this ONLY on the backend for admin operations like:
 * - Generating signed upload URLs
 * - Reading soft-deleted profiles (admin queries)
 * - Password reset proxying
 *
 * NEVER expose this client or its key to the frontend.
 */
export const supabaseAdmin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});
