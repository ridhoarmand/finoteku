// RegEx-based transaction parser (no AI needed)// Fallback parser when user doesn't have AI API key
export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
  dateOffset: number; // 0 = today, -1 = yesterday, +1 = tomorrow, +2 = lusa
}

interface UserContext {
  incomeCategories: string[];
  expenseCategories: string[];
  walletNames: string[];
}

// Keywords for determining income vs expense
const INCOME_KEYWORDS = [
  'gaji',
  'gajian',
  'salary',
  'bonus',
  'thr',
  'dapat',
  'terima',
  'received',
  'transfer masuk',
  'tf masuk',
  'penjualan',
  'jual',
  'cashback',
  'refund',
  'dividen',
  'bunga',
];

const EXPENSE_KEYWORDS = [
  'beli',
  'bayar',
  'pay',
  'jajan',
  'makan',
  'minum',
  'bensin',
  'parkir',
  'tol',
  'tagihan',
  'listrik',
  'air',
  'pln',
  'pdam',
  'langganan',
  'subscribe',
  'cicilan',
  'kredit',
  'transfer keluar',
  'tf keluar',
  'kirim',
  'send',
];

// Default category hints
const DEFAULT_CATEGORY_HINTS: Record<string, string[]> = {
  Gaji: ['gaji', 'gajian', 'salary'],
  Bonus: ['bonus', 'thr', 'insentif'],
  Makanan: ['makan', 'kopi', 'sarapan', 'minum', 'cafe', 'resto', 'gofood', 'grabfood'],
  Jajan: ['jajan', 'snack', 'camilan', 'cimol', 'cilok', 'baso', 'bakso', 'gorengan', 'es'],
  Transportasi: ['bensin', 'parkir', 'tol', 'grab', 'gojek', 'ojek', 'taxi', 'kereta', 'bus'],
  Belanja: ['beli', 'belanja', 'shopping', 'tokped', 'shopee', 'alfamart', 'indomaret'],
  Tagihan: ['listrik', 'air', 'pln', 'pdam', 'internet', 'wifi', 'pulsa', 'token'],
  Hiburan: ['nonton', 'bioskop', 'game', 'spotify', 'netflix', 'youtube'],
  Kesehatan: ['obat', 'dokter', 'rumah sakit', 'apotek', 'vitamin'],
  Pendidikan: ['buku', 'kursus', 'sekolah', 'kuliah', 'les'],
};

// Common wallet/bank names
const WALLET_KEYWORDS = [
  'bca',
  'mandiri',
  'bni',
  'bri',
  'cimb',
  'permata',
  'danamon',
  'mega',
  'btpn',
  'jenius',
  'dana',
  'ovo',
  'gopay',
  'shopeepay',
  'linkaja',
  'cash',
  'tunai',
];

// Date keywords for relative date parsing
const DATE_KEYWORDS: Record<string, number> = {
  kemarin: -1,
  kemaren: -1,
  yesterday: -1,
  besok: 1,
  besuk: 1,
  tomorrow: 1,
  lusa: 2,
  'besok lusa': 2,
};

/**
 * Parse date offset from text (kemarin, besok, lusa)
 * Returns: -1 for yesterday, +1 for tomorrow, +2 for lusa, 0 for today (default)
 */
export function parseDateOffset(text: string): number {
  const lowerText = text.toLowerCase();

  // Check for "besok lusa" first (2 words)
  if (lowerText.includes('besok lusa') || lowerText.includes('besuk lusa')) {
    return 2;
  }

  for (const [keyword, offset] of Object.entries(DATE_KEYWORDS)) {
    if (keyword.includes(' ')) continue; // Skip multi-word (handled above)
    const regex = new RegExp(`\\b${keyword}\\b`, 'gi');
    if (regex.test(lowerText)) {
      return offset;
    }
  }

  return 0; // Default: today
}

/**
 * Check if word matches with word boundary (whole word)
 */
function matchWord(text: string, word: string): number {
  const lowerText = text.toLowerCase();
  const lowerWord = word.toLowerCase();

  // Use word boundary regex for exact word matching
  const regex = new RegExp(`\\b${lowerWord}\\b`, 'gi');
  const match = regex.exec(lowerText);

  return match ? match.index : -1;
}

/**
 * Parse nominal from Indonesian format
 */
export function parseNominal(
  text: string,
): { amount: number; position: number; length: number } | null {
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
 * Find wallet in text using word boundary matching
 */
function findWallet(
  text: string,
  userWallets: string[] = [],
): { name: string; position: number } | null {
  // Check user's wallets first (exact word match)
  for (const wallet of userWallets) {
    const pos = matchWord(text, wallet);
    if (pos !== -1) {
      return { name: wallet, position: pos };
    }
  }

  // Check common wallets (exact word match)
  for (const wallet of WALLET_KEYWORDS) {
    const pos = matchWord(text, wallet);
    if (pos !== -1) {
      return { name: wallet.toUpperCase(), position: pos };
    }
  }

  return null;
}

/**
 * Find category in text using word boundary matching
 */
function findCategory(
  text: string,
  userCategories: string[] = [],
  _isIncome: boolean = false,
): { name: string; position: number } | null {
  // Check user's categories first (exact word match)
  for (const category of userCategories) {
    const pos = matchWord(text, category);
    if (pos !== -1) {
      return { name: category, position: pos };
    }
  }

  // Check default hints (exact word match)
  for (const [category, keywords] of Object.entries(DEFAULT_CATEGORY_HINTS)) {
    for (const keyword of keywords) {
      const pos = matchWord(text, keyword);
      if (pos !== -1) {
        return { name: category, position: pos };
      }
    }
  }

  return null;
}

/**
 * Determine transaction type
 */
function determineTransactionType(text: string): 'income' | 'expense' {
  const lowerText = text.toLowerCase();

  if (text.trim().startsWith('+')) return 'income';
  if (text.trim().startsWith('-')) return 'expense';

  for (const keyword of INCOME_KEYWORDS) {
    if (matchWord(lowerText, keyword) !== -1) return 'income';
  }

  for (const keyword of EXPENSE_KEYWORDS) {
    if (matchWord(lowerText, keyword) !== -1) return 'expense';
  }

  return 'expense';
}

/**
 * Extract notes from text
 */
function extractNotes(
  text: string,
  nominal: { position: number; length: number } | null,
  wallet: { position: number } | null,
  category: { position: number } | null,
): string {
  // Rule 1: Check for comma separator
  const commaIndex = text.indexOf(',');
  if (commaIndex !== -1) {
    const notes = text.substring(commaIndex + 1).trim();
    if (notes.length > 0) return notes;
  }

  // Rule 2: Find the end position of the last detected element
  const positions: number[] = [];

  if (nominal) {
    positions.push(nominal.position + nominal.length);
  }
  if (wallet) {
    const walletWord = text.substring(wallet.position).split(/\s/)[0];
    positions.push(wallet.position + walletWord.length);
  }
  if (category) {
    const categoryWord = text.substring(category.position).split(/\s/)[0];
    positions.push(category.position + categoryWord.length);
  }

  if (positions.length > 0) {
    const maxPosition = Math.max(...positions);
    const remaining = text.substring(maxPosition).trim();

    const cleaned = remaining
      .replace(/^[,.\s]+/, '')
      .replace(/^(dari|ke|from|to|di)\s+\w+/i, '')
      .trim();

    if (cleaned.length > 2) return cleaned;
  }

  return '';
}

/**
 * Main parsing function (without user context)
 */
export function parseTransaction(text: string): ParsedTransaction | null {
  const nominalResult = parseNominal(text);
  if (!nominalResult || nominalResult.amount <= 0) {
    return null;
  }

  const type = determineTransactionType(text);
  const categoryResult = findCategory(text, [], type === 'income');
  const walletResult = findWallet(text);

  const notes = extractNotes(text, nominalResult, walletResult, categoryResult);
  const categoryHint = categoryResult?.name ||
    (type === 'income' ? 'Pemasukan Lainnya' : 'Pengeluaran Lainnya');

  let confidence = 0.5;
  if (text.startsWith('+') || text.startsWith('-')) confidence += 0.2;
  if (categoryResult) confidence += 0.15;
  if (walletResult) confidence += 0.1;
  confidence = Math.min(confidence, 1);

  return {
    type,
    amount: nominalResult.amount,
    categoryHint,
    walletHint: walletResult?.name || null,
    notes: notes || text.replace(/[\d.,]+\s*(k|rb|jt|juta|m|ribu)?/gi, '').trim(),
    confidence,
    dateOffset: parseDateOffset(text),
  };
}

/**
 * Parse with user context for smarter matching
 */
export function parseTransactionWithContext(
  text: string,
  context: UserContext,
): ParsedTransaction | null {
  const nominalResult = parseNominal(text);
  if (!nominalResult || nominalResult.amount <= 0) {
    return null;
  }

  const type = determineTransactionType(text);
  const categories = type === 'income' ? context.incomeCategories : context.expenseCategories;

  const categoryResult = findCategory(text, categories, type === 'income');
  const walletResult = findWallet(text, context.walletNames);

  const notes = extractNotes(text, nominalResult, walletResult, categoryResult);
  const categoryHint = categoryResult?.name ||
    (type === 'income' ? 'Pemasukan Lainnya' : 'Pengeluaran Lainnya');

  let confidence = 0.6;
  if (text.startsWith('+') || text.startsWith('-')) confidence += 0.15;
  if (categoryResult) confidence += 0.15;
  if (walletResult) confidence += 0.1;
  confidence = Math.min(confidence, 1);

  return {
    type,
    amount: nominalResult.amount,
    categoryHint,
    walletHint: walletResult?.name || null,
    notes: notes || text.replace(/[\d.,]+\s*(k|rb|jt|juta|m|ribu)?/gi, '').trim(),
    confidence,
    dateOffset: parseDateOffset(text),
  };
}
