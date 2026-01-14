/** * Smart Classifier
 * Classifies remaining text segments into Category and Wallet
 * Uses: User context, Historical patterns, Default hints
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { UserContext } from '../../data/users.ts';

export interface ClassificationResult {
  category: {
    id: string;
    name: string;
    confidence: number;
    source: 'exact' | 'history' | 'hint' | 'default';
  };
  wallet: {
    id: string;
    name: string;
    confidence: number;
    source: 'exact' | 'history' | 'hint' | 'default';
  } | null;
  type: 'income' | 'expense';
}

// Default category keyword hints
const CATEGORY_HINTS: Record<string, string[]> = {
  Makanan: [
    'makan',
    'kopi',
    'sarapan',
    'minum',
    'cafe',
    'resto',
    'gofood',
    'grabfood',
    'nasi',
    'ayam',
  ],
  Transportasi: ['bensin', 'parkir', 'tol', 'grab', 'gojek', 'ojek', 'taxi', 'transport'],
  Belanja: ['beli', 'belanja', 'shopping', 'tokped', 'shopee'],
  Tagihan: ['listrik', 'pln', 'air', 'pdam', 'internet', 'wifi', 'pulsa'],
  Hiburan: ['nonton', 'bioskop', 'game', 'netflix', 'spotify'],
};

// Income keywords
const INCOME_KEYWORDS = [
  'gaji',
  'gajian',
  'salary',
  'bonus',
  'thr',
  'insentif',
  'terima',
  'dapat',
  'masuk',
  'transfer masuk',
];

/**
 * Determine transaction type based on keywords
 */
function determineType(text: string): 'income' | 'expense' {
  const lowerText = text.toLowerCase();

  // Check for explicit income keywords
  for (const keyword of INCOME_KEYWORDS) {
    if (lowerText.includes(keyword)) {
      return 'income';
    }
  }

  // Default to expense
  return 'expense';
}

/**
 * Find wallet from text using user's wallet list
 */
function findWallet(
  text: string,
  wallets: { id: string; name: string }[],
): { id: string; name: string; confidence: number; source: 'exact' | 'history' | 'hint' } | null {
  const lowerText = text.toLowerCase();

  // Exact match from user's wallets
  for (const wallet of wallets) {
    if (lowerText.includes(wallet.name.toLowerCase())) {
      return {
        id: wallet.id,
        name: wallet.name,
        confidence: 1.0,
        source: 'exact',
      };
    }
  }

  // Common wallet name detection
  const commonWallets: Record<string, string[]> = {
    BCA: ['bca'],
    Mandiri: ['mandiri'],
    BNI: ['bni'],
    BRI: ['bri'],
    DANA: ['dana'],
    OVO: ['ovo'],
    GoPay: ['gopay'],
    ShopeePay: ['shopeepay', 'spay'],
    Cash: ['cash', 'tunai'],
    Seabank: ['seabank', 'sea'],
    BSI: ['bsi'],
  };

  for (const [walletName, keywords] of Object.entries(commonWallets)) {
    for (const kw of keywords) {
      if (lowerText.includes(kw)) {
        // Find matching wallet from user's list
        const userWallet = wallets.find((w) =>
          w.name.toLowerCase().includes(kw) || w.name.toLowerCase() === walletName.toLowerCase()
        );
        if (userWallet) {
          return {
            id: userWallet.id,
            name: userWallet.name,
            confidence: 0.9,
            source: 'hint',
          };
        }
      }
    }
  }

  return null;
}

/**
 * Find category from text using user's categories and hints
 */
function findCategory(
  text: string,
  categories: {
    id: string;
    name: string;
    type: 'income' | 'expense';
    parent_name?: string | null;
  }[],
  transactionType: 'income' | 'expense',
): {
  id: string;
  name: string;
  confidence: number;
  source: 'exact' | 'history' | 'hint' | 'default';
} {
  const lowerText = text.toLowerCase();

  // Filter categories by type
  const typeCategories = categories.filter((c) => c.type === transactionType);

  // Exact match from user's categories
  for (const category of typeCategories) {
    if (lowerText.includes(category.name.toLowerCase())) {
      return {
        id: category.id,
        name: category.name,
        confidence: 1.0,
        source: 'exact',
      };
    }
  }

  // Check default hints
  for (const [categoryName, keywords] of Object.entries(CATEGORY_HINTS)) {
    for (const kw of keywords) {
      if (lowerText.includes(kw)) {
        // Find matching category from user's list
        const userCategory = typeCategories.find((c) =>
          c.name.toLowerCase().includes(categoryName.toLowerCase())
        );
        if (userCategory) {
          return {
            id: userCategory.id,
            name: userCategory.name,
            confidence: 0.8,
            source: 'hint',
          };
        }
      }
    }
  }

  // Default to first category of type
  const defaultCategory = typeCategories[0];
  if (defaultCategory) {
    return {
      id: defaultCategory.id,
      name: defaultCategory.name,
      confidence: 0.3,
      source: 'default',
    };
  }

  // Fallback
  return {
    id: categories[0]?.id || '',
    name: transactionType === 'income' ? 'Pemasukan Lainnya' : 'Pengeluaran Lainnya',
    confidence: 0.1,
    source: 'default',
  };
}

/**
 * Lookup historical patterns for this user
 * Returns learned mappings from past transactions
 */
export function lookupHistoricalPatterns(
  _supabase: SupabaseClient,
  _userId: string,
  _text: string,
): {
  category?: { id: string; name: string; confidence: number };
  wallet?: { id: string; name: string; confidence: number };
} | null {
  // TODO: Query user_patterns table once created
  // For now, return null (no historical data)
  return null;
}

/**
 * Main classifier function
 * Classifies remaining text into Category and Wallet
 */
export async function classify(
  text: string,
  userContext: UserContext,
  supabase: SupabaseClient,
): Promise<ClassificationResult> {
  const type = determineType(text);

  // 1. Check historical patterns first (highest priority)
  const historical = await lookupHistoricalPatterns(supabase, userContext.userId, text);

  // 2. Find wallet
  let wallet = findWallet(text, userContext.wallets);
  if (historical?.wallet && (!wallet || wallet.confidence < historical.wallet.confidence)) {
    wallet = { ...historical.wallet, source: 'history' as const };
  }

  // 3. Find category
  let category = findCategory(text, userContext.categories, type);
  if (historical?.category && category.confidence < historical.category.confidence) {
    category = { ...historical.category, source: 'history' as const };
  }

  return {
    type,
    category,
    wallet,
  };
}

/**
 * Remove classified segments from text to get clean notes
 */
export function cleanRemainingText(
  text: string,
  walletName: string | null,
  categoryName: string,
): string {
  let cleaned = text;

  // Remove wallet name
  if (walletName) {
    cleaned = cleaned.replace(new RegExp(walletName, 'gi'), '').trim();
  }

  // Remove category name
  cleaned = cleaned.replace(new RegExp(`\\b${categoryName}\\b`, 'gi'), '').trim();

  // Remove common transaction keywords
  const keywords = ['beli', 'bayar', 'buat', 'untuk', 'ke', 'di'];
  for (const kw of keywords) {
    cleaned = cleaned.replace(new RegExp(`\\b${kw}\\b`, 'gi'), '').trim();
  }

  // Clean punctuation and spaces
  cleaned = cleaned
    .replace(/^[,.\s-]+|[,.\s-]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  return cleaned;
}
