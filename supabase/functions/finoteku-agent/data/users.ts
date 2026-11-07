/**
 * Users Data Access Layer
 * Mengambil data user dan konteks untuk agent
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as categoryData from './categories.ts';
import * as walletData from './wallets.ts';
import { todayIn } from '../nlu/date.ts';

export interface UserContext {
  userId: string;
  categories: categoryData.CategoryRecord[];
  wallets: walletData.WalletRecord[];
  parserMode: 'regex' | 'server_key' | 'user_key';
  aiProvider: string;
  aiApiKey: string | null;
  /** IANA zone from users.timezone; the server itself runs in UTC. */
  timezone: string;
  /** Today in the user's zone, YYYY-MM-DD. */
  today: string;
}

export interface BotLink {
  user_id: string;
  parser_mode: string;
  ai_provider: string;
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
  const [categoriesResult, walletsResult, userResult] = await Promise.all([
    categoryData.getAll(supabase, userId),
    walletData.getBalances(supabase, userId),
    supabase.from('users').select('parser_mode, ai_provider, ai_api_key, timezone').eq('id', userId).single(),
  ]);

  if (!categoriesResult.data && !walletsResult.data) {
    return null;
  }

  let timezone = userResult.data?.timezone || 'Asia/Jakarta';
  try {
    todayIn(timezone);
  } catch {
    timezone = 'Asia/Jakarta'; // unknown zone name in the profile
  }

  return {
    userId,
    categories: categoriesResult.data || [],
    wallets: walletsResult.data || [],
    parserMode: (userResult.data?.parser_mode as UserContext['parserMode']) || 'regex',
    aiProvider: userResult.data?.ai_provider || 'none',
    aiApiKey: userResult.data?.ai_api_key || null,
    timezone,
    today: todayIn(timezone),
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
