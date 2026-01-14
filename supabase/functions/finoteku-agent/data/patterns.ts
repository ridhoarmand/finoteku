/** * Pattern Learning Module * Analyze user transaction history dan build intelligent patterns */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface PatternData {
  category: string;
  wallet?: string;
  confidence: number;
  frequency: number;
}

export interface UserPatterns {
  keywords: Record<string, PatternData>;
  mostUsedWallet: string;
  mostUsedCategory: string;
  recentTransactions: RecentTransaction[];
}

interface RecentTransaction {
  amount: number;
  category: string;
  wallet: string;
  notes: string;
  date: string;
}

/**
 * Build user patterns dari transaction history
 */
export async function buildUserPatterns(
  supabase: SupabaseClient,
  userId: string,
): Promise<UserPatterns> {
  console.log('[Patterns] Building patterns for user:', userId);

  // Ambil 100 transaksi terakhir
  const { data: transactions, error } = await supabase
    .from('transactions')
    .select(
      `
      amount,
      notes,
      date,
      categories!inner(name, type),
      wallets!inner(name)
    `,
    )
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(100);

  if (error || !transactions || transactions.length === 0) {
    console.log('[Patterns] No transaction history found');
    return {
      keywords: {},
      mostUsedWallet: 'Cash',
      mostUsedCategory: '',
      recentTransactions: [],
    };
  }

  const keywords: Record<string, PatternData> = {};
  const categoryFreq: Record<string, number> = {};
  const walletFreq: Record<string, number> = {};

  // Analyze patterns
  for (const tx of transactions) {
    // deno-lint-ignore no-explicit-any
    const category = (tx.categories as any).name;
    // deno-lint-ignore no-explicit-any
    const wallet = (tx.wallets as any).name;
    const notes = tx.notes.toLowerCase();

    // Count frequency
    categoryFreq[category] = (categoryFreq[category] || 0) + 1;
    walletFreq[wallet] = (walletFreq[wallet] || 0) + 1;

    // Extract keywords dari notes
    const words = notes.split(/\s+/).filter((w: string) => w.length >= 3);

    for (const word of words) {
      if (!keywords[word]) {
        keywords[word] = {
          category,
          wallet,
          confidence: 0,
          frequency: 1,
        };
      } else {
        keywords[word].frequency++;

        // Jika word konsisten map ke category yang sama, confidence naik
        if (keywords[word].category === category) {
          keywords[word].confidence = Math.min(0.95, keywords[word].frequency / 10);
        }
      }
    }
  }

  // Find most used
  const mostUsedCategory =
    Object.entries(categoryFreq).sort(([, a], [, b]) => (b as number) - (a as number))[0]?.[0] ||
    '';

  const mostUsedWallet =
    Object.entries(walletFreq).sort(([, a], [, b]) => (b as number) - (a as number))[0]?.[0] ||
    'Cash';

  // Get recent 10 transactions
  const recentTransactions: RecentTransaction[] = transactions.slice(0, 10).map((tx) => ({
    amount: tx.amount,
    // deno-lint-ignore no-explicit-any
    category: (tx.categories as any).name,
    // deno-lint-ignore no-explicit-any
    wallet: (tx.wallets as any).name,
    notes: tx.notes,
    date: tx.date,
  }));

  console.log('[Patterns] Built patterns:', {
    keywordCount: Object.keys(keywords).length,
    mostUsedCategory,
    mostUsedWallet,
  });

  return {
    keywords,
    mostUsedCategory,
    mostUsedWallet,
    recentTransactions,
  };
}
