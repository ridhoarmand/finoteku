/**
 * Pending confirmations (one per user + platform). Agent v2 keeps the whole
 * batch in `payload`; rows written by the old agent (no payload) are ignored —
 * they expire within minutes anyway.
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type Platform = 'telegram' | 'discord' | 'whatsapp' | 'api';

export interface PendingItem {
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  date: string; // YYYY-MM-DD
  category_id: string | null;
  category_name: string | null;
  category_parent: string | null;
  wallet_id: string | null;
  wallet_name: string | null;
  to_wallet_id: string | null;
  to_wallet_name: string | null;
  notes: string;
  /** Category options shown as buttons while the category is not settled. */
  candidates?: { id: string; name: string }[];
}

export interface Pending {
  items: PendingItem[];
  /** Action per button, in display order; WhatsApp replies "1", "2"… map to these. */
  choices: string[];
  original_input?: string;
}

const TTL_MINUTES = 15;

export async function get(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
): Promise<Pending | null> {
  const { data } = await supabase
    .from('pending_bot_transactions')
    .select('payload')
    .eq('user_id', userId)
    .eq('platform', platform)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();
  return (data?.payload as Pending | null) ?? null;
}

/** Replaces whatever was pending (a new message always wins over the old one). */
export async function save(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
  platformIdentifier: string,
  pending: Pending,
): Promise<{ error: Error | null }> {
  const first = pending.items[0];
  const { error } = await supabase.from('pending_bot_transactions').upsert(
    {
      user_id: userId,
      platform,
      platform_identifier: platformIdentifier,
      payload: pending,
      // legacy columns, kept readable for old tooling
      type: first?.type,
      amount: first?.amount,
      category_id: first?.category_id,
      wallet_id: first?.wallet_id,
      to_wallet_id: first?.to_wallet_id,
      notes: first?.notes,
      date: first?.date,
      original_input: pending.original_input,
      expires_at: new Date(Date.now() + TTL_MINUTES * 60_000).toISOString(),
    },
    { onConflict: 'user_id,platform' },
  );
  return { error };
}

export async function remove(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
): Promise<void> {
  await supabase.from('pending_bot_transactions').delete().eq('user_id', userId).eq('platform', platform);
}
