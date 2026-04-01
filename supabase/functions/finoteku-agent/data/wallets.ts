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

const WALLET_SYNONYMS: Record<string, string> = {
  tunai: 'cash',
  uang_tunai: 'cash',
  kas: 'cash',
  bca: 'bca',
  'bank bca': 'bca',
  'bca mobile': 'bca',
  mandiri: 'mandiri',
  bri: 'bri',
  bni: 'bni',
};

export function normalizeWalletHint(name: string): string {
  const normalized = name.toLowerCase().trim().replace(/\s+/g, ' ');
  return WALLET_SYNONYMS[normalized] || normalized;
}

export function resolveWalletByHint(wallets: WalletRecord[], hint?: string): WalletRecord | null {
  if (!hint) return null;

  const normalizedHint = normalizeWalletHint(hint);

  const exact = wallets.find((w) => normalizeWalletHint(w.name) === normalizedHint);
  if (exact) return exact;

  const partial = wallets.find((w) => {
    const normalizedWallet = normalizeWalletHint(w.name);
    return normalizedWallet.includes(normalizedHint) || normalizedHint.includes(normalizedWallet);
  });

  return partial || null;
}

export function resolveCashWallet(wallets: WalletRecord[]): WalletRecord | null {
  const priorities = ['cash', 'tunai', 'kas'];
  for (const hint of priorities) {
    const found = resolveWalletByHint(wallets, hint);
    if (found) return found;
  }
  return wallets[0] || null;
}

/**
 * Ambil semua wallet dengan saldo
 */
export async function getBalances(supabase: SupabaseClient, userId: string): Promise<{ data: WalletRecord[] | null; error: Error | null }> {
  const { data, error } = await supabase.from('wallets').select('id, name, balance').eq('user_id', userId);

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
export async function getById(supabase: SupabaseClient, walletId: string): Promise<{ data: WalletRecord | null; error: Error | null }> {
  const { data, error } = await supabase.from('wallets').select('id, name, balance').eq('id', walletId).single();

  return { data, error };
}

/**
 * Cari wallet berdasarkan nama (fuzzy match)
 */
export async function findByName(supabase: SupabaseClient, userId: string, name: string): Promise<WalletRecord | null> {
  const { data } = await getBalances(supabase, userId);
  if (!data) return null;

  return resolveWalletByHint(data, name);
}
