/**
 * Regex Parser
 * Parsing transaksi berbasis regex (fallback jika AI tidak tersedia)
 */

import type { UserContext } from '../../data/users.ts';

// Keywords for income detection
const INCOME_KEYWORDS = ['gaji', 'gajian', 'salary', 'bonus', 'thr', 'dapat', 'terima', 'received', 'transfer masuk', 'tf masuk', 'penjualan', 'jual', 'cashback', 'refund', 'dividen', 'bunga'];

// Default category hints based on keywords
const DEFAULT_CATEGORY_HINTS: Record<string, string[]> = {
  Gaji: ['gaji', 'gajian', 'salary'],
  Bonus: ['bonus', 'thr', 'insentif'],
  Makanan: ['makan', 'kopi', 'sarapan', 'minum', 'cafe', 'resto', 'gofood', 'grabfood'],
  Jajan: ['jajan', 'snack', 'camilan'],
  Transportasi: ['bensin', 'parkir', 'tol', 'grab', 'gojek', 'ojek', 'taxi'],
  Belanja: ['beli', 'belanja', 'shopping', 'tokped', 'shopee', 'alfamart', 'indomaret'],
  Tagihan: ['listrik', 'air', 'pln', 'pdam', 'internet', 'wifi', 'pulsa'],
};

// Date keywords
const DATE_KEYWORDS: Record<string, number> = {
  kemarin: -1,
  kemaren: -1,
  yesterday: -1,
  besok: 1,
  besuk: 1,
  tomorrow: 1,
  lusa: 2,
};

export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
  dateOffset: number;
}

/**
 * Parse nominal from text
 */
function parseNominal(text: string): { amount: number; position: number; length: number } | null {
  const patterns = [
    { regex: /(\d+(?:[.,]\d+)?)\s*(jt|juta)/gi, multiplier: 1000000 },
    { regex: /(\d+(?:[.,]\d+)?)\s*(k|rb|ribu)/gi, multiplier: 1000 },
    { regex: /(\d+)/gi, multiplier: 1 },
  ];

  for (const { regex, multiplier } of patterns) {
    regex.lastIndex = 0;
    const match = regex.exec(text.toLowerCase());
    if (match) {
      const value = parseFloat(match[1].replace(',', '.'));
      return {
        amount: Math.round(value * multiplier),
        position: match.index,
        length: match[0].length,
      };
    }
  }
  return null;
}

/**
 * Parse date offset from text
 */
function parseDateOffset(text: string): number {
  const lowerText = text.toLowerCase();
  for (const [keyword, offset] of Object.entries(DATE_KEYWORDS)) {
    if (lowerText.includes(keyword)) return offset;
  }
  return 0;
}

/**
 * Match word in text
 */
function matchWord(text: string, word: string): number {
  const regex = new RegExp(`\\b${word.toLowerCase()}\\b`, 'gi');
  const match = regex.exec(text.toLowerCase());
  return match ? match.index : -1;
}

/**
 * Determine transaction type (income/expense)
 */
function determineType(text: string): 'income' | 'expense' {
  if (text.trim().startsWith('+')) return 'income';
  if (text.trim().startsWith('-')) return 'expense';

  const lowerText = text.toLowerCase();
  for (const keyword of INCOME_KEYWORDS) {
    if (matchWord(lowerText, keyword) !== -1) return 'income';
  }
  return 'expense';
}

/**
 * Find category from text
 */
function findCategory(text: string, userCategories: string[]): string | null {
  const lowerText = text.toLowerCase();

  // Check user categories first
  for (const category of userCategories) {
    if (matchWord(lowerText, category) !== -1) return category;
  }

  // Check default hints
  for (const [category, keywords] of Object.entries(DEFAULT_CATEGORY_HINTS)) {
    for (const keyword of keywords) {
      if (matchWord(lowerText, keyword) !== -1) return category;
    }
  }
  return null;
}

/**
 * Find wallet from text
 */
function findWallet(text: string, userWallets: string[]): string | null {
  const lowerText = text.toLowerCase();

  // Check user wallets
  for (const wallet of userWallets) {
    if (matchWord(lowerText, wallet) !== -1) return wallet;
  }

  // Common wallet names
  const commonWallets = ['bca', 'mandiri', 'bni', 'bri', 'dana', 'ovo', 'gopay', 'shopeepay', 'cash', 'tunai'];
  for (const wallet of commonWallets) {
    if (matchWord(lowerText, wallet) !== -1) return wallet.toUpperCase();
  }
  return null;
}

/**
 * Parse transaction with regex
 */
export function parseWithRegex(text: string, userContext: UserContext): ParsedTransaction | null {
  const nominalResult = parseNominal(text);
  if (!nominalResult || nominalResult.amount <= 0) return null;

  const type = determineType(text);
  const categories = userContext.categories.filter((c) => c.type === type).map((c) => c.name);
  const wallets = userContext.wallets.map((w) => w.name);

  const categoryHint = findCategory(text, categories) || (type === 'income' ? 'Pemasukan Lainnya' : 'Pengeluaran Lainnya');
  const walletHint = findWallet(text, wallets);

  // Extract notes (text without amount/wallet/date keywords)
  let notes = text
    .replace(/[\d.,]+\s*(k|rb|jt|juta|m|ribu)?/gi, '')
    .replace(new RegExp(Object.keys(DATE_KEYWORDS).join('|'), 'gi'), '')
    .trim();
  if (walletHint) {
    notes = notes.replace(new RegExp(walletHint, 'gi'), '').trim();
  }

  return {
    type,
    amount: nominalResult.amount,
    categoryHint,
    walletHint,
    notes: notes || text,
    confidence: 0.7,
    dateOffset: parseDateOffset(text),
  };
}
