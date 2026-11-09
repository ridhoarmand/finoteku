/**
 * Users Data Access Layer
 * Mengambil data user dan konteks untuk agent
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as categoryData from './categories.ts';
import * as walletData from './wallets.ts';
import * as trainingData from './training.ts';
import { todayIn } from '../nlu/date.ts';

export interface UserContext {
  userId: string;
  categories: categoryData.CategoryRecord[];
  wallets: walletData.WalletRecord[];
  /** 'regex' = "Tanpa AI": never call an LLM. Anything else uses the server LLM. */
  parserMode: 'regex' | 'server_key' | 'user_key';
  /** The user's own instructions and examples (app: Chat Bot → Pelatihan). */
  agentTraining: trainingData.AgentTrainingContext;
  /** IANA zone from users.timezone; the server itself runs in UTC. */
  timezone: string;
  /** Today in the user's zone, YYYY-MM-DD. */
  today: string;
}

/**
 * Ambil konteks lengkap user untuk pemrosesan agent
 * Termasuk: kategori, wallet, dan preferensi parsing
 */
export async function getContext(
  supabase: SupabaseClient,
  userId: string,
): Promise<UserContext | null> {
  const [categoriesResult, walletsResult, userResult, agentTraining] = await Promise.all([
    categoryData.getAll(supabase, userId),
    walletData.getBalances(supabase, userId),
    supabase.from('users').select('parser_mode, timezone').eq('id', userId).single(),
    trainingData.getAgentTraining(supabase, userId),
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
    parserMode: (userResult.data?.parser_mode as UserContext['parserMode']) || 'server_key',
    agentTraining,
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
