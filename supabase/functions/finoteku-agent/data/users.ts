/**
 * Users Data Access Layer
 * Mengambil data user dan konteks untuk agent
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as categoryData from './categories.ts';
import * as walletData from './wallets.ts';

export interface UserContext {
  userId: string;
  categories: categoryData.CategoryRecord[];
  wallets: walletData.WalletRecord[];
  parserMode: 'server_key' | 'user_key';
  aiApiKey: string | null;
}

export interface BotLink {
  user_id: string;
  parser_mode: string;
  ai_api_key: string | null;
}

/**
 * Ambil konteks lengkap user untuk pemrosesan agent
 * Termasuk: kategori, wallet, dan preferensi parsing
 */
export async function getContext(
  supabase: SupabaseClient,
  userId: string,
): Promise<UserContext | null> {
  const [categoriesResult, walletsResult, botLinkResult] = await Promise.all([
    categoryData.getAll(supabase, userId),
    walletData.getBalances(supabase, userId),
    supabase.from('bot_links').select('parser_mode, ai_api_key').eq('user_id', userId).single(),
  ]);

  if (!categoriesResult.data && !walletsResult.data) {
    return null;
  }

  return {
    userId,
    categories: categoriesResult.data || [],
    wallets: walletsResult.data || [],
    parserMode: (botLinkResult.data?.parser_mode as UserContext['parserMode']) || 'regex',
    aiApiKey: botLinkResult.data?.ai_api_key || null,
  };
}

/**
 * Cari user berdasarkan platform ID (telegram, discord, dll)
 */
export async function getByPlatformId(
  supabase: SupabaseClient,
  platform: string,
  platformUserId: string,
): Promise<string | null> {
  const { data } = await supabase.rpc('get_user_by_platform_id', {
    p_platform: platform,
    p_platform_user_id: platformUserId,
  });

  if (!data || data.length === 0) return null;
  return data[0].user_id;
}

/**
 * Hubungkan akun platform ke user
 */
export async function linkPlatformAccount(
  supabase: SupabaseClient,
  linkToken: string,
  _platform: string,
  platformUserId: string,
  platformUsername: string | null,
): Promise<{ success: boolean; error: Error | null }> {
  const { error } = await supabase.rpc('link_telegram_account', {
    p_link_token: linkToken,
    p_telegram_id: platformUserId,
    p_telegram_username: platformUsername,
  });

  return { success: !error, error };
}
