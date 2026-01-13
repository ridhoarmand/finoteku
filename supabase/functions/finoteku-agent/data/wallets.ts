/**
 * Wallets Data Access Layer
 * Query Supabase untuk wallet/dompet
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface WalletRecord {
  id: string;
  name: string;
  balance: number;
}

/**
 * Ambil semua wallet dengan saldo
 */
export async function getBalances(
  supabase: SupabaseClient,
  userId: string,
): Promise<{ data: WalletRecord[] | null; error: Error | null }> {
  const { data, error } = await supabase.from('wallets').select('id, name, balance').eq(
    'user_id',
    userId,
  );

  if (error) return { data: null, error };

  // deno-lint-ignore no-explicit-any
  const mapped = (data || []).map((w: any) => ({
    id: w.id,
    name: w.name,
    balance: Number(w.balance) || 0,
  }));

  return { data: mapped, error: null };
}

/**
 * Ambil wallet berdasarkan ID
 */
export async function getById(
  supabase: SupabaseClient,
  walletId: string,
): Promise<{ data: WalletRecord | null; error: Error | null }> {
  const { data, error } = await supabase.from('wallets').select('id, name, balance').eq(
    'id',
    walletId,
  ).single();

  return { data, error };
}

/**
 * Cari wallet berdasarkan nama (fuzzy match)
 */
export async function findByName(
  supabase: SupabaseClient,
  userId: string,
  name: string,
): Promise<WalletRecord | null> {
  const { data } = await getBalances(supabase, userId);
  if (!data) return null;

  const lowerName = name.toLowerCase();

  // Exact match
  const exact = data.find((w) => w.name.toLowerCase() === lowerName);
  if (exact) return exact;

  // Contains match
  const contains = data.find((w) =>
    w.name.toLowerCase().includes(lowerName) || lowerName.includes(w.name.toLowerCase())
  );

  return contains || null;
}
