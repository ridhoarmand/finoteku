// Intent detection for smart bot// Classifies user message as: transaction input, query (balance/summary), or chat

export type BotIntent = 'transaction' | 'query_balance' | 'query_summary' | 'query_transactions' | 'query_trend' | 'query_tips' | 'help' | 'unknown';

interface IntentResult {
  intent: BotIntent;
  confidence: number;
  params?: Record<string, any>;
}

// Keywords for different intents
const BALANCE_KEYWORDS = ['saldo', 'balance', 'uang', 'berapa', 'dompet', 'wallet', 'rekening'];
const SUMMARY_KEYWORDS = ['ringkasan', 'summary', 'laporan', 'bulan', 'bulanan', 'total', 'statistik'];
const TRANSACTIONS_KEYWORDS = ['transaksi', 'riwayat', 'history', 'terakhir', 'terbaru', 'list'];
const TREND_KEYWORDS = ['tren', 'trend', 'naik', 'turun', 'perbandingan', 'bandingkan', 'banding'];
const TIPS_KEYWORDS = ['hemat', 'saran', 'tips', 'rekomendasi', 'boros', 'kurangi', 'saving'];

// Transaction indicator keywords
const TRANSACTION_INDICATORS = [
  // Numbers with k/rb/jt
  /\d+\s*(k|rb|ribu|jt|juta|m)/i,
  // Amount numbers
  /\d{2,}/,
];

// Question indicators
const QUESTION_INDICATORS = ['?', 'berapa', 'gimana', 'bagaimana', 'apa', 'mana', 'kapan', 'kenapa', 'mengapa'];

/**
 * Detect intent from user message (simple keyword-based)
 * Used for RegEx mode or as fallback
 */
export function detectIntentSimple(text: string): IntentResult {
  const lowerText = text.toLowerCase().trim();

  // Help commands
  if (lowerText === '/help' || lowerText === '/start') {
    return { intent: 'help', confidence: 1.0 };
  }

  // Check for tips/recommendation query
  const hasTipsKeyword = TIPS_KEYWORDS.some((k) => lowerText.includes(k));
  if (hasTipsKeyword && !hasTransactionIndicator(lowerText)) {
    return { intent: 'query_tips', confidence: 0.85 };
  }

  // Check for trend query
  const hasTrendKeyword = TREND_KEYWORDS.some((k) => lowerText.includes(k));
  if (hasTrendKeyword && !hasTransactionIndicator(lowerText)) {
    return { intent: 'query_trend', confidence: 0.85 };
  }

  // Check for balance query
  const hasBalanceKeyword = BALANCE_KEYWORDS.some((k) => lowerText.includes(k));
  const isQuestion = QUESTION_INDICATORS.some((q) => lowerText.includes(q));

  if (hasBalanceKeyword && (isQuestion || !hasTransactionIndicator(lowerText))) {
    return { intent: 'query_balance', confidence: 0.8 };
  }

  // Check for summary query
  const hasSummaryKeyword = SUMMARY_KEYWORDS.some((k) => lowerText.includes(k));
  if (hasSummaryKeyword) {
    return { intent: 'query_summary', confidence: 0.85 };
  }

  // Check for transactions query
  const hasTransactionsKeyword = TRANSACTIONS_KEYWORDS.some((k) => lowerText.includes(k));
  if (hasTransactionsKeyword && isQuestion) {
    return { intent: 'query_transactions', confidence: 0.8 };
  }

  // Check for transaction input (has amount indicator)
  if (hasTransactionIndicator(lowerText)) {
    return { intent: 'transaction', confidence: 0.9 };
  }

  // Default to unknown for other queries
  return { intent: 'unknown', confidence: 0.3 };
}

function hasTransactionIndicator(text: string): boolean {
  return TRANSACTION_INDICATORS.some((pattern) => pattern.test(text));
}

/**
 * Build prompt for AI intent detection
 */
export function buildIntentDetectionPrompt(): string {
  return `Klasifikasikan intent pesan user ke salah satu kategori:
- "transaction": Input transaksi keuangan (ada nominal/jumlah uang)
- "query_balance": Tanya saldo wallet
- "query_summary": Tanya ringkasan/laporan/statistik
- "query_transactions": Tanya riwayat/list transaksi
- "recommendation": Minta saran/tips hemat
- "chat": Obrolan umum

Jawab dengan JSON saja:
{"intent": "...", "confidence": 0.0-1.0}`;
}

/**
 * Parse AI intent response
 */
export function parseAIIntentResponse(response: string): IntentResult {
  try {
    let jsonStr = response.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr
        .replace(/```json?\n?/g, '')
        .replace(/```/g, '')
        .trim();
    }
    const parsed = JSON.parse(jsonStr);
    return {
      intent: parsed.intent || 'unknown',
      confidence: parsed.confidence || 0.5,
      params: parsed.params,
    };
  } catch {
    return { intent: 'unknown', confidence: 0.3 };
  }
}
