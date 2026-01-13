/**
 * Text Parser Tool
 * Mem-parse pesan teks menjadi data transaksi
 * Menggunakan AI dengan fallback regex + preference learning + notes style learning
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import { parseWithRegex } from './regex.ts';
import { PreferenceLearner } from '../../memory/learning.ts';
import * as transactionData from '../../data/transactions.ts';

export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
  dateOffset: number;
  originalInput?: string;
}

export class TextParserTool extends BaseTool {
  name = 'text_parser';
  description = 'Mem-parse teks menjadi data transaksi';
  intents = ['transaction'];

  private learner: PreferenceLearner;

  constructor(private supabase: SupabaseClient, private ai?: AIProvider) {
    super();
    this.learner = new PreferenceLearner(supabase);
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const text = params.text as string;
    const userContext = params.userContext as UserContext;

    if (!text) {
      return this.error('Input teks diperlukan');
    }

    if (!userContext) {
      return this.error('User context diperlukan');
    }

    // Ambil learned preferences + contoh notes dari history
    const [preferences, notesExamples] = await Promise.all([
      this.learner.getPreferences(userContext.userId, text),
      transactionData.getNotesExamples(this.supabase, userContext.userId, 8),
    ]);

    let parsed: ParsedTransaction | null = null;

    // Coba AI dulu jika tersedia dan bukan mode regex
    if (this.ai && userContext.parserMode !== 'regex') {
      parsed = await this.parseWithAI(text, userContext, preferences, notesExamples);
    }

    // Fallback ke regex jika AI gagal
    if (!parsed) {
      parsed = parseWithRegex(text, userContext);
    }

    if (!parsed) {
      return this.error(
        'Tidak dapat memahami transaksi. Gunakan format: [kategori] [nominal] [wallet]',
      );
    }

    // Terapkan learned preferences jika confidence tinggi
    if (preferences.category && preferences.category.confidence >= 0.7) {
      const exists = userContext.categories.some((c) =>
        c.name.toLowerCase() === preferences.category!.name.toLowerCase()
      );
      if (exists) {
        parsed.categoryHint = preferences.category.name;
      }
    }

    if (preferences.wallet && preferences.wallet.confidence >= 0.7) {
      const exists = userContext.wallets.some((w) =>
        w.name.toLowerCase() === preferences.wallet!.name.toLowerCase()
      );
      if (exists) {
        parsed.walletHint = preferences.wallet.name;
      }
    }

    // Simpan original input untuk learning saat dikonfirmasi
    parsed.originalInput = text;

    return this.success(
      { ...parsed, needsConfirmation: true },
      this.formatConfirmation(parsed, preferences),
    );
  }

  /**
   * Parse menggunakan AI (Gemini)
   */
  private async parseWithAI(
    text: string,
    userContext: UserContext,
    preferences: { category?: { name: string }; wallet?: { name: string } },
    notesExamples: { notes: string; categoryName: string }[],
  ): Promise<ParsedTransaction | null> {
    if (!this.ai) return null;

    const prompt = this.buildAIPrompt(userContext, text, preferences, notesExamples);

    try {
      const result = await this.ai.generateJSON<{
        type: 'income' | 'expense';
        amount: number;
        categoryHint: string;
        walletHint: string | null;
        notes: string;
        dateOffset: number;
      }>(prompt);

      return { ...result, confidence: 1.0 };
    } catch (error) {
      console.error('AI parsing gagal:', error);
      return null;
    }
  }

  /**
   * Membangun prompt untuk AI
   * Menyertakan kategori user, contoh notes, dan preferensi yang dipelajari
   */
  private buildAIPrompt(
    userContext: UserContext,
    text: string,
    preferences: { category?: { name: string }; wallet?: { name: string } },
    notesExamples: { notes: string; categoryName: string }[],
  ): string {
    const incomeCategories = userContext.categories.filter((c) => c.type === 'income').map((c) =>
      c.name
    );
    const expenseCategories = userContext.categories.filter((c) => c.type === 'expense').map((c) =>
      c.name
    );
    const wallets = userContext.wallets.map((w) => w.name);

    let prompt = `Kamu adalah parser transaksi keuangan untuk user Indonesia.

TUGAS: Parse pesan menjadi JSON:
{
  "type": "income" atau "expense",
  "amount": number,
  "categoryHint": "nama kategori",
  "walletHint": "nama wallet" atau null,
  "notes": "deskripsi singkat",
  "dateOffset": 0 (hari ini), -1 (kemarin), 1 (besok)
}

ATURAN:
- k/rb = ×1000, jt = ×1000000
- kemarin = -1, besok = 1
- Notes: BERSIH dari nominal, wallet, tanggal. Hanya isi/item saja.

KATEGORI PEMASUKAN: ${incomeCategories.join(', ') || 'Gaji, Bonus'}
KATEGORI PENGELUARAN: ${expenseCategories.join(', ') || 'Makanan, Transport'}
WALLET: ${wallets.join(', ') || 'Cash, BCA'}`;

    // Sertakan contoh notes dari history user (few-shot learning)
    if (notesExamples.length > 0) {
      prompt += `\n\n📝 GAYA PENULISAN NOTES USER (ikuti gaya ini):`;
      for (const ex of notesExamples.slice(0, 6)) {
        prompt += `\n• ${ex.categoryName}: "${ex.notes}"`;
      }
    }

    // Sertakan preferensi yang sudah dipelajari
    if (preferences.category) {
      prompt += `\n\n💡 User biasanya memilih: "${preferences.category.name}"`;
    }
    if (preferences.wallet) {
      prompt += `\n💡 Wallet favorit: "${preferences.wallet.name}"`;
    }

    prompt += `\n\nINPUT: "${text}"\n\nHANYA RETURN JSON.`;

    return prompt;
  }

  /**
   * Format pesan konfirmasi untuk ditampilkan ke user
   * Menampilkan emoji 🧠 jika menggunakan learned preference
   */
  private formatConfirmation(
    parsed: ParsedTransaction,
    preferences: {
      category?: { name: string; confidence: number };
      wallet?: { name: string; confidence: number };
    },
  ): string {
    const emoji = parsed.type === 'income' ? '💰' : '💸';
    const amount = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
    }).format(parsed.amount);

    let msg = `${emoji} <b>Konfirmasi Transaksi</b>\n\n`;
    msg += `📝 ${parsed.notes}\n`;
    msg += `💵 ${amount}\n`;
    msg += `📁 ${parsed.categoryHint}`;
    if (preferences.category?.name === parsed.categoryHint) msg += ` 🧠`;
    msg += `\n`;

    if (parsed.walletHint) {
      msg += `💳 ${parsed.walletHint}`;
      if (preferences.wallet?.name === parsed.walletHint) msg += ` 🧠`;
      msg += `\n`;
    }

    if (parsed.dateOffset !== 0) {
      const label = parsed.dateOffset === -1
        ? 'Kemarin'
        : parsed.dateOffset === 1
        ? 'Besok'
        : `${parsed.dateOffset} hari`;
      msg += `📅 ${label}\n`;
    }

    msg += `\n<b>Simpan transaksi ini?</b>`;
    return msg;
  }
}
