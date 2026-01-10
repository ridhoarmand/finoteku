import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
export interface UserCategory {
  id: string;
  name: string;
  type: 'income' | 'expense';
  parentName: string | null;
}

export interface UserWallet {
  id: string;
  name: string;
}

export interface UserContext {
  categories: UserCategory[];
  wallets: UserWallet[];
}

export interface PendingTransaction {
  id: string;
  user_id: string;
  wallet_id: string;
  category_id: string;
  amount: number;
  notes: string;
  date: string;
  telegram_chat_id: number;
  type: 'income' | 'expense';
}

export interface TransactionExample {
  notes: string;
  category: string;
  wallet: string;
  amount: number;
  type: 'income' | 'expense';
}

export interface NoteStyle {
  capitalization: 'lowercase' | 'uppercase' | 'titlecase' | 'mixed';
  avgLength: number;
  isDetailed: boolean;
}

/**
 * Fetch user's categories and wallets for context
 */
export async function getUserContext(
  supabase: SupabaseClient,
  userId: string,
): Promise<UserContext> {
  const [categoriesResult, walletsResult] = await Promise.all([
    supabase
      .from('categories')
      .select(
        `
      id, 
      name, 
      type,
      parent:parent_id(name)
    `,
      )
      .eq('user_id', userId)
      .eq('is_hidden', false),
    supabase.from('wallets').select('id, name').eq('user_id', userId),
  ]);

  // Transform to include parentName
  // deno-lint-ignore no-explicit-any
  const categories = (categoriesResult.data || []).map((c: any) => ({
    id: c.id,
    name: c.name,
    type: c.type,
    parentName: c.parent?.name || null,
  })) as UserCategory[];

  return {
    categories,
    wallets: (walletsResult.data || []) as UserWallet[],
  };
}

/**
 * Link Telegram account to Finoteku user
 */
export async function linkTelegramAccount(
  supabase: SupabaseClient,
  userId: string,
  telegramId: number,
  telegramUsername: string | undefined,
): Promise<boolean> {
  try {
    const { data: userExists } = await supabase.from('users').select('id').eq('id', userId)
      .single();

    if (!userExists) {
      console.error('User not found:', userId);
      return false;
    }

    const { data: existingLink } = await supabase.from('bot_links').select('user_id').eq(
      'platform',
      'telegram',
    ).eq('platform_user_id', telegramId.toString()).single();

    if (existingLink) {
      if (existingLink.user_id === userId) {
        return true;
      }
      return false;
    }

    const { error } = await supabase.from('bot_links').insert({
      user_id: userId,
      platform: 'telegram',
      platform_user_id: telegramId.toString(),
      platform_username: telegramUsername || null,
      is_active: true,
      ai_provider: 'none',
      parser_mode: 'regex',
    });

    return !error;
  } catch (e) {
    console.error('Error linking account:', e);
    return false;
  }
}

/**
 * Get user info by Telegram ID
 */
export async function getUserByTelegramId(
  supabase: SupabaseClient,
  telegramId: number,
): Promise<
  {
    userId: string;
    aiProvider: string;
    aiApiKey: string | null;
    parserMode: string;
  } | null
> {
  const { data, error } = await supabase.rpc('get_user_by_platform_id', {
    p_platform: 'telegram',
    p_platform_user_id: telegramId.toString(),
  });

  if (error || !data || data.length === 0) {
    return null;
  }

  return {
    userId: data[0].user_id,
    aiProvider: data[0].ai_provider || 'none',
    aiApiKey: data[0].ai_api_key,
    parserMode: data[0].parser_mode || 'regex',
  };
}

/**
 * Create transaction in database
 */
export async function createTransaction(
  supabase: SupabaseClient,
  userId: string,
  walletId: string,
  categoryId: string,
  amount: number,
  notes: string,
  date: string,
): Promise<boolean> {
  const { error } = await supabase.from('transactions').insert({
    user_id: userId,
    wallet_id: walletId,
    category_id: categoryId,
    amount,
    notes,
    date,
  });

  return !error;
}

/**
 * Save pending transaction for confirmation
 */
export async function savePendingTransaction(
  supabase: SupabaseClient,
  telegramChatId: number,
  userId: string,
  walletId: string,
  categoryId: string,
  amount: number,
  notes: string,
  date: string,
  type: 'income' | 'expense',
): Promise<string | null> {
  // Delete existing pending for this chat
  await supabase.from('pending_bot_transactions').delete().eq('telegram_chat_id', telegramChatId);

  const { data, error } = await supabase
    .from('pending_bot_transactions')
    .insert({
      telegram_chat_id: telegramChatId,
      user_id: userId,
      wallet_id: walletId,
      category_id: categoryId,
      amount,
      notes,
      date,
      type,
    })
    .select('id')
    .single();

  if (error) {
    console.error('Error saving pending transaction:', error);
    return null;
  }

  return data?.id || null;
}

/**
 * Get pending transaction for a chat
 */
export async function getPendingTransaction(
  supabase: SupabaseClient,
  telegramChatId: number,
): Promise<PendingTransaction | null> {
  const { data, error } = await supabase.from('pending_bot_transactions').select('*').eq(
    'telegram_chat_id',
    telegramChatId,
  ).gt('expires_at', new Date().toISOString()).single();

  if (error || !data) return null;
  return data as PendingTransaction;
}

/**
 * Update pending transaction
 */
export async function updatePendingTransaction(
  supabase: SupabaseClient,
  id: string,
  updates: {
    wallet_id?: string;
    category_id?: string;
    date?: string;
    amount?: number;
    notes?: string;
  },
): Promise<boolean> {
  const { error } = await supabase.from('pending_bot_transactions').update(updates).eq('id', id);
  return !error;
}

/**
 * Delete pending transaction
 */
export async function deletePendingTransaction(
  supabase: SupabaseClient,
  id: string,
): Promise<void> {
  await supabase.from('pending_bot_transactions').delete().eq('id', id);
}

/**
 * Fetch user's recent transactions for AI context (few-shot learning)
 */
export async function getUserTransactionHistory(
  supabase: SupabaseClient,
  userId: string,
  limit: number = 30,
): Promise<TransactionExample[]> {
  const { data, error } = await supabase
    .from('transactions')
    .select(
      `
      notes,
      amount,
      categories!inner(name, type),
      wallets!inner(name)
    `,
    )
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(limit);

  if (error || !data) {
    console.error('Error fetching transaction history:', error);
    return [];
  }

  // deno-lint-ignore no-explicit-any
  return data.map((t: any) => ({
    notes: t.notes || '',
    category: t.categories?.name || 'Unknown',
    wallet: t.wallets?.name || 'Unknown',
    amount: Math.abs(Number(t.amount)),
    type: t.categories?.type || 'expense',
  }));
}

/**
 * Detect user's note style from examples
 */
export function detectNoteStyle(examples: TransactionExample[]): NoteStyle {
  const notesWithText = examples.filter((e) => e.notes && e.notes.trim().length > 0);

  if (notesWithText.length === 0) {
    return { capitalization: 'mixed', avgLength: 0, isDetailed: false };
  }

  const notes = notesWithText.map((e) => e.notes);
  const avgLength = notes.reduce((sum, n) => sum + n.length, 0) / notes.length;

  let uppercase = 0;
  let lowercase = 0;
  let titlecase = 0;

  for (const note of notes) {
    if (note === note.toUpperCase()) uppercase++;
    else if (note === note.toLowerCase()) lowercase++;
    else if (note.split(' ').every((w: string) => w[0] === w[0]?.toUpperCase())) titlecase++;
  }

  let capitalization: 'lowercase' | 'uppercase' | 'titlecase' | 'mixed' = 'mixed';
  const total = notes.length;
  if (uppercase / total > 0.7) capitalization = 'uppercase';
  else if (lowercase / total > 0.7) capitalization = 'lowercase';
  else if (titlecase / total > 0.5) capitalization = 'titlecase';

  return {
    capitalization,
    avgLength: Math.round(avgLength),
    isDetailed: avgLength > 15,
  };
}
