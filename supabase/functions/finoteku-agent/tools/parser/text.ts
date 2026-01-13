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
import { parseAbsoluteDate, parseWithRegex } from './regex.ts';
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

      // Post-process AI result: clean absolute dates from notes if found
      if (parsed) {
        const absDate = parseAbsoluteDate(text);
        if (absDate) {
          // If AI didn't calculate offset correctly or we want to trust regex date more?
          // For now, just clean the notes. AI usually gets dateOffset right if prompt is good.
          const dateTextToRemove = absDate.match;
          if (dateTextToRemove) {
            const escapedDate = dateTextToRemove.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            parsed.notes = parsed.notes.replace(new RegExp(escapedDate, 'gi'), '').trim();
            // Clean punctuation again
            parsed.notes = parsed.notes.replace(/^[,.\s-]+|[,.\s-]+$/g, '').replace(/\s+/g, ' ');
          }
        }
      }
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

    // Cari parent category
    const categoryName = parsed.categoryHint;
    const category = userContext.categories.find((c) =>
      c.name.toLowerCase() === categoryName.toLowerCase()
    );
    const parentCategory = category?.parent_name || null;

    return this.success(
      { ...parsed, needsConfirmation: true },
      this.formatConfirmation(parsed, preferences, parentCategory),
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

    const today = new Date().toLocaleDateString('id-ID', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    let prompt = `Kamu adalah parser transaksi keuangan untuk user Indonesia.
HARI INI: ${today}

TUGAS: Parse pesan menjadi JSON:
{
  "type": "income" atau "expense",
  "amount": number,
  "categoryHint": "nama kategori",
  "walletHint": "nama wallet" atau null,
  "notes": "deskripsi singkat",
  "dateOffset": number (selisih hari dari HARI INI. 0=hari ini, -1=kemarin, -3=tiga hari lalu)
}

ATURAN:
- k/rb = ×1000, jt/juta = ×1000000.
- Prioritaskan angka > 1000 sebagai amount. Angka 1-31 di awal biasanya TANGGAL, bukan amount.
- Jika ada tanggal spesifik (misal "10 Januari"), hitung selisihnya dengan HARI INI.
- Notes: Wajib BERSIH dari nominal, wallet, tanggal, dan kategori. Contoh: "10 Jan Beli Makan 20k" -> Notes: "Makan" (Hapus "10 Jan" dan "20k").

KATEGORI PEMASUKAN: ${incomeCategories.join(', ') || 'Gaji, Bonus'}
KATEGORI PENGELUARAN: ${expenseCategories.join(', ') || 'Makanan, Transport'}
WALLET: ${wallets.join(', ') || 'Cash, BCA'}

LOGIKA DETEKSI (PENTING):
1. INCOME Strong Keywords: "Insentif", "Bonus", "THR", "Gajian".
2. EXPENSE Strong Keywords: "Beli", "Bayar", "Jajan".
3. PATTERN "Masuk + Wallet" = INCOME.
4. PATTERN "Isi + Wallet" = EXPENSE.
5. Jika ambigu, prioritaskan Kata Kerja.`;

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
   * Format:
   * Tanggal
   * Dompet
   * Nominal
   * Jenis Transaksi, Kategory Parent (jika ada), Child
   * Note
   */
  private formatConfirmation(
    parsed: ParsedTransaction,
    preferences: {
      category?: { name: string; confidence: number };
      wallet?: { name: string; confidence: number };
    },
    parentCategory: string | null,
  ): string {
    const amount = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
    }).format(parsed.amount);

    let msg = `<b>Konfirmasi Transaksi</b>\n\n`;

    // 1. Tanggal
    const date = new Date();
    date.setDate(date.getDate() + (parsed.dateOffset || 0));
    const dateStr = date.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
    msg += `📅 ${dateStr}\n`;

    // 2. Dompet
    if (parsed.walletHint) {
      msg += `💳 ${parsed.walletHint}`;
      if (preferences.wallet?.name === parsed.walletHint) msg += ` 🧠`;
      msg += `\n`;
    } else {
      msg += `💳 -\n`;
    }

    // 3. Nominal
    msg += `💵 ${amount}\n`;

    // 4. Jenis & Kategori (Chain)
    const typeLabel = parsed.type === 'income' ? 'Pemasukan' : 'Pengeluaran';
    let categoryChain = `📁 ${typeLabel}`;
    if (parentCategory) {
      categoryChain += `, ${parentCategory}`;
    }
    categoryChain += `, ${parsed.categoryHint}`;

    if (preferences.category?.name === parsed.categoryHint) categoryChain += ` 🧠`;
    msg += `${categoryChain}\n`;

    // 5. Note
    msg += `📝 ${parsed.notes}\n`;

    msg += `\n<b>Simpan transaksi ini?</b>`;
    return msg;
  }
}
