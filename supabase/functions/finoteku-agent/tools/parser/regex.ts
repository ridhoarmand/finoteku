/**
 * Regex Parser
 * Parsing transaksi berbasis regex (fallback jika AI tidak tersedia)
 */

import type { UserContext } from '../../data/users.ts';

// Keywords for income detection
const INCOME_KEYWORDS = [
  'gaji',
  'gajian',
  'salary',
  'bonus',
  'thr',
  'insentif',
  'hadiah',
  'reward',
  'dapat',
  'terima',
  'received',
  'transfer masuk',
  'tf masuk',
  'uang masuk',
  'masuk',
  'penjualan',
  'jual',
  'cashback',
  'refund',
  'dividen',
  'bunga',
];

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
    { regex: /(\d+(?:[.,]\d+)?)\s*(jt|juta)/gi, multiplier: 1000000, priority: 1 },
    { regex: /(\d+(?:[.,]\d+)?)\s*(k|rb|ribu)/gi, multiplier: 1000, priority: 1 },
    { regex: /(\d+(?:[.,]\d+)?)/gi, multiplier: 1, priority: 0 },
  ];

  type MatchCandidate = { amount: number; start: number; end: number; priority: number };
  const candidates: MatchCandidate[] = [];

  const montRegex = /^\s+(jan|feb|mar|apr|mei|jun|jul|agu|sep|okt|nov|des)/i;

  for (const { regex, multiplier, priority } of patterns) {
    regex.lastIndex = 0;
    let match;
    while ((match = regex.exec(text.toLowerCase())) !== null) {
      const valStr = match[1].replace(',', '.');
      const value = parseFloat(valStr);

      // Skip invalid numbers
      if (isNaN(value)) continue;

      const fullMatch = match[0];
      const start = match.index;
      const end = start + fullMatch.length;

      // Check if it looks like a date (e.g. "10 " followed by "Januari")
      // Only for priority 0 (raw numbers) and small values (<=31)
      if (priority === 0 && value <= 31) {
        const remainingText = text.slice(end);
        if (montRegex.test(remainingText)) {
          continue; // It's a date!
        }
      }

      candidates.push({
        amount: Math.round(value * multiplier),
        start,
        end,
        priority,
      });
    }
  }

  if (candidates.length === 0) return null;

  // Sort by priority desc, then amount desc
  candidates.sort((a, b) => {
    if (a.priority !== b.priority) return b.priority - a.priority;
    return b.amount - a.amount;
  });

  const best = candidates[0];
  return { amount: best.amount, position: best.start, length: best.end - best.start };
}

/**
 * Parse date offset from text
 */
export function parseDateOffset(text: string): number {
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
  const commonWallets = [
    'bca',
    'mandiri',
    'bni',
    'bri',
    'dana',
    'ovo',
    'gopay',
    'shopeepay',
    'cash',
    'tunai',
  ];
  for (const wallet of commonWallets) {
    if (matchWord(lowerText, wallet) !== -1) return wallet.toUpperCase();
  }
  return null;
}

/**
 * Parse absolute date (e.g. "10 Januari") and return offset + matched text
 */
export function parseAbsoluteDate(text: string): { offset: number; match: string } | null {
  // Regex for "10 jan", "10 januari", "tgl 10", etc.
  // Matches: 1=day, 2=month(optional)
  const regex = /\b(\d{1,2})\s+(jan|feb|mar|apr|mei|jun|jul|agu|sep|okt|nov|des)[a-z]*\b/gi;
  const match = regex.exec(text.toLowerCase());

  if (!match) return null;

  const day = parseInt(match[1]);
  const monthStr = match[2];

  if (day > 31 || day < 1) return null;

  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'mei',
    'jun',
    'jul',
    'agu',
    'sep',
    'okt',
    'nov',
    'des',
  ];
  const monthIndex = months.indexOf(monthStr);

  if (monthIndex === -1) return null;

  const today = new Date();
  // Adjust year: if current month is Jan and input is Dec, assume previous year
  let year = today.getFullYear();
  if (today.getMonth() === 0 && monthIndex === 11) {
    year -= 1;
  }

  const targetDate = new Date(year, monthIndex, day);

  // Calculate difference in days
  const diffTime = targetDate.getTime() - today.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

  return { offset: diffDays, match: match[0] };
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

  const categoryHint = findCategory(text, categories) ||
    (type === 'income' ? 'Pemasukan Lainnya' : 'Pengeluaran Lainnya');
  const walletHint = findWallet(text, wallets);

  // Date parsing
  let dateOffset = parseDateOffset(text);
  const absDate = parseAbsoluteDate(text);
  let dateTextToRemove = '';

  if (absDate) {
    dateOffset = absDate.offset;
    dateTextToRemove = absDate.match;
  }

  // Extract notes (text without amount/wallet/date keywords)
  let notes = text
    .replace(/[\d.,]+\s*(k|rb|jt|juta|m|ribu)?/gi, '') // Remove amounts
    .replace(new RegExp(Object.keys(DATE_KEYWORDS).join('|'), 'gi'), '') // Remove date keywords
    .trim();

  // Remove absolute date string
  if (dateTextToRemove) {
    // Escape special regex chars if any (though date match is simple)
    const escapedDate = dateTextToRemove.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    notes = notes.replace(new RegExp(escapedDate, 'gi'), '').trim();
  }

  if (walletHint) {
    notes = notes.replace(new RegExp(walletHint, 'gi'), '').trim();
  }

  // Clean up category from notes if it matches the detected hint
  if (categoryHint) {
    const catRegex = new RegExp(`\\b${categoryHint}\\b`, 'gi');
    notes = notes.replace(catRegex, '').trim();
  }

  // Clean up type keywords (e.g. remove "masuk" from notes if it was used to detect income)
  if (type === 'income') {
    const incomeKeywordsPattern = new RegExp(INCOME_KEYWORDS.join('|'), 'gi');
    notes = notes.replace(incomeKeywordsPattern, '').trim();
  }

  // Clean remaining punctuation and excessive spaces
  notes = notes.replace(/^[,.\s-]+|[,.\s-]+$/g, '').replace(/\s+/g, ' ');

  return {
    type,
    amount: nominalResult.amount,
    categoryHint,
    walletHint,
    notes: notes || text,
    confidence: 0.7,
    dateOffset,
  };
}
