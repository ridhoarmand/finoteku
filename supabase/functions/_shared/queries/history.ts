// User transaction history for few-shot learning
// Fetches recent transactions to provide context to AI

import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface TransactionExample {
  notes: string;
  category: string;
  wallet: string;
  amount: number;
  type: 'income' | 'expense';
}

/**
 * Fetch user's recent transactions for AI context (few-shot learning)
 * This helps AI learn user's patterns: keywords, categories, wallets, note style
 */
export async function getUserTransactionHistory(supabase: SupabaseClient, userId: string, limit: number = 15): Promise<TransactionExample[]> {
  const { data, error } = await supabase
    .from('transactions')
    .select(
      `
      notes,
      amount,
      categories!inner(name, type),
      wallets!inner(name)
    `
    )
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(limit);

  if (error || !data) {
    console.error('Error fetching transaction history:', error);
    return [];
  }

  return data.map((t: any) => ({
    notes: t.notes || '',
    category: t.categories?.name || 'Unknown',
    wallet: t.wallets?.name || 'Unknown',
    amount: Math.abs(Number(t.amount)),
    type: t.categories?.type || 'expense',
  }));
}

/**
 * Format transaction examples for AI prompt
 */
export function formatExamplesForPrompt(examples: TransactionExample[]): string {
  if (examples.length === 0) {
    return 'Belum ada contoh transaksi sebelumnya.';
  }

  return examples
    .filter((e) => e.notes && e.notes.trim().length > 0)
    .slice(0, 10) // Limit to 10 to avoid token overflow
    .map((e, i) => {
      const amountStr = formatAmount(e.amount);
      return `${i + 1}. "${e.notes}" → ${e.category}, ${e.wallet}, ${amountStr}`;
    })
    .join('\n');
}

/**
 * Detect user's note style from examples
 */
export function detectNoteStyle(examples: TransactionExample[]): {
  capitalization: 'lowercase' | 'uppercase' | 'titlecase' | 'mixed';
  avgLength: number;
  isDetailed: boolean;
} {
  const notesWithText = examples.filter((e) => e.notes && e.notes.trim().length > 0);

  if (notesWithText.length === 0) {
    return { capitalization: 'mixed', avgLength: 0, isDetailed: false };
  }

  const notes = notesWithText.map((e) => e.notes);
  const avgLength = notes.reduce((sum, n) => sum + n.length, 0) / notes.length;

  // Detect capitalization
  let uppercase = 0;
  let lowercase = 0;
  let titlecase = 0;

  for (const note of notes) {
    if (note === note.toUpperCase()) uppercase++;
    else if (note === note.toLowerCase()) lowercase++;
    else if (note.split(' ').every((w) => w[0] === w[0]?.toUpperCase())) titlecase++;
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

function formatAmount(amount: number): string {
  if (amount >= 1000000) {
    return `Rp${(amount / 1000000).toFixed(1)}jt`;
  } else if (amount >= 1000) {
    return `Rp${(amount / 1000).toFixed(0)}rb`;
  }
  return `Rp${amount}`;
}
