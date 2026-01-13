/**
 * Pending Transactions Data Access Layer
 * Query Supabase untuk transaksi pending (menunggu konfirmasi)
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface PendingTransaction {
  id: string;
  user_id: string;
  conversation_id: string;
  type: 'income' | 'expense';
  amount: number;
  category_id: string;
  category_name?: string;
  wallet_id: string;
  wallet_name?: string;
  notes: string;
  date: string;
  expires_at: string;
  original_input?: string; // Untuk learning
}

export interface PendingTransactionInput {
  type: 'income' | 'expense';
  amount: number;
  category_id: string;
  category_name?: string;
  wallet_id: string;
  wallet_name?: string;
  notes: string;
  date: string;
  original_input?: string;
}

/**
 * Ambil transaksi pending berdasarkan conversation ID
 */
export async function get(
  supabase: SupabaseClient,
  conversationId: string,
): Promise<PendingTransaction | null> {
  const { data } = await supabase.from('pending_bot_transactions').select('*').eq(
    'telegram_chat_id',
    conversationId,
  ).gt('expires_at', new Date().toISOString()).single();

  return data;
}

/**
 * Cek apakah ada transaksi pending
 */
export async function exists(supabase: SupabaseClient, conversationId: string): Promise<boolean> {
  const pending = await get(supabase, conversationId);
  return !!pending;
}

/**
 * Simpan/update transaksi pending
 */
export async function save(
  supabase: SupabaseClient,
  userId: string,
  conversationId: string,
  transaction: PendingTransactionInput,
): Promise<{ id: string | null; error: Error | null }> {
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + 10);

  const { data, error } = await supabase
    .from('pending_bot_transactions')
    .upsert({
      user_id: userId,
      telegram_chat_id: conversationId,
      type: transaction.type,
      amount: transaction.amount,
      category_id: transaction.category_id,
      wallet_id: transaction.wallet_id,
      notes: transaction.notes,
      date: transaction.date,
      expires_at: expiresAt.toISOString(),
      // category_name, wallet_name, original_input excluded matching schema
    })
    .select('id')
    .single();

  return { id: data?.id || null, error };
}

/**
 * Hapus transaksi pending
 */
export async function remove(
  supabase: SupabaseClient,
  conversationId: string,
): Promise<{ success: boolean; error: Error | null }> {
  const { error } = await supabase.from('pending_bot_transactions').delete().eq(
    'telegram_chat_id',
    conversationId,
  );
  return { success: !error, error };
}

/**
 * Update field tertentu di transaksi pending
 */
export async function update(
  supabase: SupabaseClient,
  conversationId: string,
  updates: Partial<PendingTransactionInput>,
): Promise<{ success: boolean; error: Error | null }> {
  const { error } = await supabase.from('pending_bot_transactions').update(updates).eq(
    'telegram_chat_id',
    conversationId,
  );
  return { success: !error, error };
}
