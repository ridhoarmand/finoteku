/**
 * Reasoning Engine
 * Mendeteksi intent dan merencanakan aksi agent
 * Menggunakan keyword matching untuk kecepatan, AI untuk kasus ambigu
 */

import type { AIProvider } from './providers/base.ts';
import type { AgentEvaluation, AgentInput, AgentPlan, Intent, ToolResult } from './types.ts';

// Keywords untuk deteksi intent
const BALANCE_KEYWORDS = ['saldo', 'balance', 'uang', 'berapa', 'dompet', 'wallet', 'rekening'];
const SUMMARY_KEYWORDS = [
  'ringkasan',
  'summary',
  'laporan',
  'bulan',
  'bulanan',
  'total',
  'statistik',
];
const TRANSACTIONS_KEYWORDS = ['transaksi', 'riwayat', 'history', 'terakhir', 'terbaru', 'list'];
const TREND_KEYWORDS = ['tren', 'trend', 'naik', 'turun', 'perbandingan', 'bandingkan'];
const TIPS_KEYWORDS = ['hemat', 'saran', 'tips', 'rekomendasi', 'boros', 'kurangi', 'saving'];
const CONFIRM_KEYWORDS = ['ya', 'y', 'yes', 'ok', 'oke', 'simpan', 'save'];
const CANCEL_KEYWORDS = ['tidak', 'no', 'n', 'batal', 'cancel', 'batalkan'];
const TRANSFER_KEYWORDS = [
  'transfer',
  'pindah',
  'kirim',
  'mutasi',
  'tarik',
  'tarik tunai',
  'cabut dana',
];
const INCOME_PREFIX = ['masuk', 'terima', 'dapat'];
const EXPENSE_PREFIX = ['keluar', 'bayar', 'beli'];

// Pola transaksi (angka dengan suffix)
const TRANSACTION_PATTERNS = [/\d+\s*(k|rb|ribu|jt|juta|m)/i, /\d{2,}/];

export class ReasoningEngine {
  constructor(private ai: AIProvider) {}

  /**
   * Deteksi intent secara cepat menggunakan keyword matching
   * @param text - Input text dari user
   * @returns Intent dan confidence score
   */
  detectIntent(text: string): { intent: Intent; confidence: number } {
    const lowerText = text.toLowerCase().trim();

    // Handle commands
    if (lowerText === '/help' || lowerText === '/start') {
      return { intent: 'help', confidence: 1.0 };
    }
    if (lowerText === '/balance') {
      return { intent: 'query_balance', confidence: 1.0 };
    }
    if (lowerText === '/history') {
      return { intent: 'query_transactions', confidence: 1.0 };
    }

    // Konfirmasi atau pembatalan
    if (CONFIRM_KEYWORDS.includes(lowerText)) {
      return { intent: 'confirm', confidence: 1.0 };
    }
    if (CANCEL_KEYWORDS.includes(lowerText)) {
      return { intent: 'cancel', confidence: 1.0 };
    }

    // Cek awalan khusus (Prefix Detection)
    if (TRANSFER_KEYWORDS.some((k) => lowerText.startsWith(k) || lowerText.includes(k))) {
      return { intent: 'transaction', confidence: 0.95 };
    }
    if (INCOME_PREFIX.some((k) => lowerText.startsWith(k))) {
      return { intent: 'transaction', confidence: 0.95 };
    }
    if (EXPENSE_PREFIX.some((k) => lowerText.startsWith(k))) {
      return { intent: 'transaction', confidence: 0.95 };
    }

    // Cek indikator transaksi (angka dengan k/rb/jt)
    const hasTransaction = TRANSACTION_PATTERNS.some((p) => p.test(lowerText));
    const isQuestion = this.isQuestion(lowerText);

    // Query tips keuangan
    if (TIPS_KEYWORDS.some((k) => lowerText.includes(k)) && !hasTransaction) {
      return { intent: 'query_tips', confidence: 0.85 };
    }

    // Query tren pengeluaran
    if (TREND_KEYWORDS.some((k) => lowerText.includes(k)) && !hasTransaction) {
      return { intent: 'query_trend', confidence: 0.85 };
    }

    // Query saldo
    if (BALANCE_KEYWORDS.some((k) => lowerText.includes(k)) && (isQuestion || !hasTransaction)) {
      return { intent: 'query_balance', confidence: 0.8 };
    }

    // Query ringkasan
    if (SUMMARY_KEYWORDS.some((k) => lowerText.includes(k)) && !hasTransaction) {
      return { intent: 'query_summary', confidence: 0.85 };
    }

    // Query riwayat transaksi
    if (TRANSACTIONS_KEYWORDS.some((k) => lowerText.includes(k)) && isQuestion) {
      return { intent: 'query_transactions', confidence: 0.8 };
    }

    // Pertanyaan tanpa transaksi → classify as data or web
    if (isQuestion && !hasTransaction) {
      return this.classifyQuestion(lowerText);
    }

    // Input transaksi (ada nominal)
    if (hasTransaction) {
      return { intent: 'transaction', confidence: 0.9 };
    }

    return { intent: 'unknown', confidence: 0.3 };
  }

  /**
   * Cek apakah input adalah pertanyaan
   */
  private isQuestion(text: string): boolean {
    const questionIndicators = [
      '?',
      'berapa',
      'apa',
      'gimana',
      'bagaimana',
      'kenapa',
      'mengapa',
      'siapa',
      'kapan',
      'dimana',
      'jelaskan',
      'ceritakan',
      'tolong',
      'bisa',
      'apakah',
    ];
    return questionIndicators.some((q) => text.includes(q));
  }

  /**
   * Klasifikasi pertanyaan: tentang data user atau butuh web search
   */
  private classifyQuestion(text: string): { intent: Intent; confidence: number } {
    const dataKeywords = [
      'pengeluaran',
      'pemasukan',
      'saldo',
      'transaksi',
      'bulan',
      'minggu',
      'hari',
      'kategori',
      'wallet',
      'dompet',
      'total',
      'rata-rata',
      'tertinggi',
      'terendah',
      'uang',
      'keuangan',
      'tabungan',
    ];
    const isDataQuestion = dataKeywords.some((k) => text.includes(k));

    if (isDataQuestion) {
      return { intent: 'query_data', confidence: 0.85 };
    }
    // Pertanyaan umum → web search
    return { intent: 'query_web', confidence: 0.7 };
  }

  /**
   * Plan: Menganalisis input dan memilih tool yang tepat
   * @param input - Input dari user
   * @param hasPending - Apakah ada transaksi pending
   * @returns Rencana aksi (intent, tool, params)
   */
  plan(input: AgentInput, hasPending?: boolean): AgentPlan {
    const text = input.content;

    // Untuk image/voice, gunakan tool khusus
    if (input.type === 'image') {
      return {
        intent: 'transaction',
        tool: 'transaction_parser',
        params: { type: 'image', content: input.content, mimeType: input.mimeType },
        confidence: 0.9,
      };
    }

    if (input.type === 'voice') {
      return {
        intent: 'transaction',
        tool: 'stt',
        params: { content: input.content, mimeType: input.mimeType },
        confidence: 0.9,
      };
    }

    // Untuk text, deteksi intent
    const { intent, confidence } = this.detectIntent(text);

    // Mapping intent ke tool
    const toolMap: Record<Intent, string> = {
      transaction: 'transaction_parser',
      query_balance: 'query',
      query_summary: 'query',
      query_transactions: 'query',
      query_trend: 'query',
      query_tips: 'query',
      query_data: 'data_query',
      query_web: 'web_search',
      update_pending: 'pending_handler',
      confirm: 'pending_handler',
      cancel: 'pending_handler',
      help: 'help',
      unknown: 'fallback',
    };

    // Jika ada pending, cek apakah input adalah transaksi baru yang lengkap atau partial update
    if (hasPending && !intent.startsWith('query_') && intent !== 'help') {
      // Cek apakah input punya nominal (indikasi transaksi baru yang lengkap)
      const hasAmount = /\d+\s*(k|rb|ribu|jt|juta)?/i.test(text);

      if (intent === 'confirm' || intent === 'cancel') {
        // Eksplisit konfirmasi/batal
        return {
          intent,
          tool: 'pending_handler',
          params: { action: intent, text },
          confidence,
        };
      }

      if (hasAmount && intent === 'transaction') {
        // Input lengkap dengan nominal → RE-PARSE sebagai transaksi baru (replace pending)
        console.log('[Reasoning] Full transaction input detected, routing to parser');
        return {
          intent: 'transaction',
          tool: toolMap['transaction'] || 'text_parser',
          params: { text, intent: 'transaction' },
          confidence,
        };
      }

      // Partial update (tanpa nominal): kategorinya X, walletnya Y, catatan Z
      return {
        intent: 'update_pending',
        tool: 'pending_handler',
        params: { action: 'update_pending', text },
        confidence,
      };
    }

    return {
      intent,
      tool: toolMap[intent] || 'fallback',
      params: {
        text,
        intent,
      },
      confidence,
    };
  }

  /**
   * Evaluate: Mengevaluasi hasil eksekusi tool
   * @param result - Hasil dari tool
   * @returns Evaluasi (success, needsFollowUp)
   */
  evaluate(result: ToolResult): AgentEvaluation {
    return {
      success: result.success,
      needsFollowUp: false,
      message: result.message,
    };
  }
}
