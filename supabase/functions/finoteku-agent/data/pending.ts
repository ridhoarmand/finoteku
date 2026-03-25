/**
 * Pending Transactions Data Access Layer
 * Multi-platform support with view-based data loading
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type Platform = 'telegram' | 'discord' | 'whatsapp' | 'api';

export interface PendingTransaction {
  id: string;
  user_id: string;
  platform: Platform;
  platform_identifier: string;
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  category_id: string;
  category_name: string; // From VIEW join
  category_parent?: string; // From VIEW join
  wallet_id: string;
  wallet_name: string; // From VIEW join
  to_wallet_id?: string;
  to_wallet_name?: string; // From VIEW join
  notes: string;
  date: string;
  original_input?: string;
  expires_at: string;
}

export interface PendingTransactionInput {
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  category_id: string;
  wallet_id: string;
  to_wallet_id?: string;
  notes: string;
  date: string;
  original_input?: string;
}

/**
 * Ambil transaksi pending berdasarkan user + platform
 * Menggunakan VIEW untuk mendapatkan nama kategori dan wallet
 */
export async function get(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
): Promise<PendingTransaction | null> {
  const { data } = await supabase.from('pending_transactions_view').select('*').eq(
    'user_id',
    userId,
  ).eq('platform', platform).gt('expires_at', new Date().toISOString()).single();

  return data;
}

/**
 * Cek apakah ada transaksi pending untuk user + platform (lightweight)
 */
export async function exists(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
): Promise<boolean> {
  const { data } = await supabase
    .from('pending_bot_transactions')
    .select('id')
    .eq('user_id', userId)
    .eq('platform', platform)
    .gt('expires_at', new Date().toISOString())
    .maybeSingle();

  return !!data;
}

/**
 * Simpan/update transaksi pending
 */
export async function save(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
  platformIdentifier: string,
  transaction: PendingTransactionInput,
): Promise<{ id: string | null; error: Error | null }> {
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + 10);

  const { data, error } = await supabase
    .from('pending_bot_transactions')
    .upsert(
      {
        user_id: userId,
        platform,
        platform_identifier: platformIdentifier,
        type: transaction.type,
        amount: transaction.amount,
        category_id: transaction.category_id,
        wallet_id: transaction.wallet_id,
        to_wallet_id: transaction.to_wallet_id,
        notes: transaction.notes,
        date: transaction.date,
        original_input: transaction.original_input,
        expires_at: expiresAt.toISOString(),
      },
      { onConflict: 'user_id,platform' },
    )
    .select('id')
    .single();

  return { id: data?.id || null, error };
}

/**
 * Hapus transaksi pending
 */
export async function remove(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
): Promise<{ success: boolean; error: Error | null }> {
  const { error } = await supabase.from('pending_bot_transactions').delete().eq('user_id', userId)
    .eq('platform', platform);

  return { success: !error, error };
}

/**
 * Update field tertentu di transaksi pending (PARTIAL UPDATE)
 * Hanya field yang ada di updates yang akan diubah
 */
export async function update(
  supabase: SupabaseClient,
  userId: string,
  platform: Platform,
  updates: Partial<PendingTransactionInput>,
): Promise<{ success: boolean; error: Error | null }> {
  // Filter out undefined values to ensure true partial update
  const cleanUpdates: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(updates)) {
    if (value !== undefined) {
      cleanUpdates[key] = value;
    }
  }

  if (Object.keys(cleanUpdates).length === 0) {
    return { success: true, error: null }; // Nothing to update
  }

  const { error } = await supabase.from('pending_bot_transactions').update(cleanUpdates).eq(
    'user_id',
    userId,
  ).eq('platform', platform);

  return { success: !error, error };
}
