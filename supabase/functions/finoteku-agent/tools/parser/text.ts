/**
 * Text Parser Tool - Redesigned with Smart Segmentation
 *
 * Flow:
 * 1. Tokenize input → Extract Amount, Date, Notes (after comma)
 * 2. Classify remaining text → Category, Wallet
 * 3. AI fallback for low confidence
 * 4. Learn from confirmed transactions
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import { tokenize } from './tokenizer.ts';
import { classify, cleanRemainingText } from './classifier.ts';
import { PreferenceLearner } from '../../memory/learning.ts';

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
  description = 'Mem-parse teks menjadi data transaksi dengan smart segmentation';
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

    console.log('[TextParser] Parsing:', text);

    // PHASE 1: TOKENIZE - Extract Amount, Date, Notes
    const tokens = tokenize(text);
    console.log('[TextParser] Tokenized:', {
      amount: tokens.amount,
      date: tokens.date,
      notes: tokens.notes,
      remaining: tokens.remainingText,
    });

    // Validate: Must have amount
    if (!tokens.amount) {
      return this.error('Tidak ditemukan nominal transaksi');
    }

    // PHASE 2: CLASSIFY - Match Category & Wallet from remaining text
    const classification = await classify(tokens.remainingText, userContext, this.supabase);
    console.log('[TextParser] Classified:', classification);

    // PHASE 3: BUILD RESULT
    let notes = tokens.notes || '';

    // If no comma-separated notes, clean remaining text
    if (!notes && tokens.remainingText) {
      notes = cleanRemainingText(
        tokens.remainingText,
        classification.wallet?.name || null,
        classification.category.name,
      );
    }

    // PHASE 4: SMART AMBIGUITY DETECTION
    const ambiguityScore = this.detectAmbiguity(text, tokens, classification, userContext);
    console.log('[TextParser] Ambiguity score:', ambiguityScore);

    // Calculate overall confidence
    const confidence = this.calculateConfidence(tokens, classification);

    // PHASE 5: AI FALLBACK - For ambiguous or low confidence cases
    const shouldUseAI = ambiguityScore > 0.3 || confidence < 0.6;

    if (shouldUseAI && this.ai) {
      console.log('[TextParser] Ambiguity/low confidence detected, calling AI...', {
        ambiguityScore,
        confidence,
      });
      const aiResult = await this.parseWithAI(text, userContext);
      if (aiResult) {
        return this.success(
          { ...aiResult, needsConfirmation: true },
          this.formatConfirmation(aiResult, userContext),
        );
      }
    }

    // Build final result
    const result: ParsedTransaction = {
      type: classification.type,
      amount: tokens.amount.value,
      categoryHint: classification.category.name,
      walletHint: classification.wallet?.name || null,
      notes: notes || 'Transaksi',
      confidence,
      dateOffset: tokens.date?.offset || 0,
      originalInput: text,
    };

    console.log('[TextParser] Result:', result);

    return this.success(
      { ...result, needsConfirmation: true },
      this.formatConfirmation(result, userContext),
    );
  }

  /**
   * Detect ambiguity in input
   * Returns score 0-1 (higher = more ambiguous)
   */
  private detectAmbiguity(
    text: string,
    tokens: ReturnType<typeof tokenize>,
    classification: Awaited<ReturnType<typeof classify>>,
    userContext: UserContext,
  ): number {
    let ambiguity = 0;
    const lowerText = text.toLowerCase();

    // 1. DATE AMBIGUITY - Both absolute and relative dates
    const hasAbsoluteDate = /\d{1,2}\s*(jan|feb|mar|apr|mei|jun|jul|agu|sep|okt|nov|des)/i.test(
      lowerText,
    );
    const hasRelativeDate = /(kemarin|kemaren|besok|lusa|\d+\s*hari\s*lalu)/i.test(lowerText);
    if (hasAbsoluteDate && hasRelativeDate) {
      ambiguity += 0.5; // Major ambiguity
      console.log('[Ambiguity] Date conflict: absolute + relative');
    }

    // 2. CONFUSING KEYWORDS - "tanggal", "waktu" without clear context
    if (/\btanggal\b/i.test(lowerText) && !hasAbsoluteDate) {
      ambiguity += 0.2;
      console.log('[Ambiguity] Confusing keyword: "tanggal"');
    }

    // 3. CATEGORY NOT IN DATABASE - High priority for AI
    const categoryExists = userContext.categories.some((c) =>
      c.name.toLowerCase() === classification.category.name.toLowerCase()
    );
    if (!categoryExists || classification.category.confidence < 0.5) {
      ambiguity += 0.4; // Use AI to find right category
      console.log('[Ambiguity] Category unclear or not in database');
    }

    // 4. MULTIPLE UNKNOWN WORDS - Might need AI to understand
    const words = tokens.remainingText.split(/\s+/);
    const unknownWords = words.filter((w) => {
      const wordLower = w.toLowerCase();
      // Check if word matches any category or wallet
      const matchesCategory = userContext.categories.some((c) =>
        c.name.toLowerCase().includes(wordLower) || wordLower.includes(c.name.toLowerCase())
      );
      const matchesWallet = userContext.wallets.some((w) =>
        w.name.toLowerCase().includes(wordLower) || wordLower.includes(w.name.toLowerCase())
      );
      return !matchesCategory && !matchesWallet && w.length > 3;
    });

    if (unknownWords.length >= 3) {
      ambiguity += 0.2;
      console.log('[Ambiguity] Multiple unknown words:', unknownWords);
    }

    // 5. COMPLEX SENTENCE STRUCTURE - "dan", "atau", "dengan", etc
    const complexPatterns = [/\bdan\b.*\bdan\b/i, /\batau\b/i, /\bdengan\b.*\bdan\b/i];
    if (complexPatterns.some((p) => p.test(lowerText))) {
      ambiguity += 0.1;
      console.log('[Ambiguity] Complex sentence structure');
    }

    return Math.min(ambiguity, 1.0);
  }

  /**
   * Calculate overall confidence
   */
  private calculateConfidence(
    tokens: ReturnType<typeof tokenize>,
    classification: Awaited<ReturnType<typeof classify>>,
  ): number {
    let confidence = 0.5; // Base

    // Amount with suffix = high confidence
    if (tokens.amount && /\d+\s*(k|rb|jt)/i.test(tokens.amount.raw)) {
      confidence += 0.2;
    }

    // Category confidence
    confidence += classification.category.confidence * 0.2;

    // Wallet matched = bonus
    if (classification.wallet) {
      confidence += classification.wallet.confidence * 0.1;
    }

    // Notes from comma = clean separation
    if (tokens.notes) {
      confidence += 0.1;
    }

    return Math.min(confidence, 1.0);
  }

  /**
   * AI Parsing fallback for complex cases
   */
  private async parseWithAI(
    text: string,
    userContext: UserContext,
  ): Promise<ParsedTransaction | null> {
    if (!this.ai) return null;

    try {
      const incomeCategories = userContext.categories.filter((c) => c.type === 'income').map((c) =>
        c.name
      );
      const expenseCategories = userContext.categories.filter((c) => c.type === 'expense').map((
        c,
      ) => c.name);
      const wallets = userContext.wallets.map((w) => w.name);

      const today = new Date().toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      });

      const prompt = `Parse transaksi keuangan ke JSON.
HARI INI: ${today}

INPUT: "${text}"

OUTPUT JSON:
{
  "type": "income" atau "expense",
  "amount": number,
  "categoryHint": "nama kategori dari list",
  "walletHint": "nama wallet dari list" atau null,
  "notes": "deskripsi BERSIH (hapus tanggal, nominal, wallet, kategori)",
  "dateOffset": number (0=hari ini, -1=kemarin, -4=4 hari lalu)
}

KATEGORI INCOME: ${incomeCategories.join(', ') || 'Gaji'}
KATEGORI EXPENSE: ${expenseCategories.join(', ') || 'Makanan'}
WALLETS: ${wallets.join(', ') || 'Cash'}

PENTING:
- Notes harus BERSIH! Hanya deskripsi item/aktivitas.
- Jika ada "X hari lalu", dateOffset = -X
- Output HANYA JSON, tanpa penjelasan.`;

      const response = await this.ai.generateText(prompt);
      const jsonMatch = response.match(/\{[\s\S]*\}/);

      if (!jsonMatch) return null;

      const parsed = JSON.parse(jsonMatch[0]);
      return {
        type: parsed.type || 'expense',
        amount: Number(parsed.amount) || 0,
        categoryHint: parsed.categoryHint || 'Pengeluaran Lainnya',
        walletHint: parsed.walletHint || null,
        notes: parsed.notes || '',
        confidence: 0.85,
        dateOffset: Number(parsed.dateOffset) || 0,
        originalInput: text,
      };
    } catch (error) {
      console.error('[TextParser] AI parsing error:', error);
      return null;
    }
  }

  /**
   * Format confirmation message
   */
  private formatConfirmation(parsed: ParsedTransaction, userContext: UserContext): string {
    const isIncome = parsed.type === 'income';
    const emoji = isIncome ? '💰' : '💸';
    const typeLabel = isIncome ? 'Pemasukan' : 'Pengeluaran';

    const amount = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
    }).format(parsed.amount);

    // Calculate actual date
    const date = new Date();
    date.setDate(date.getDate() + (parsed.dateOffset || 0));
    const dateStr = date.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    // Find parent category
    const category = userContext.categories.find((c) =>
      c.name.toLowerCase() === parsed.categoryHint.toLowerCase()
    );
    let categoryDisplay = parsed.categoryHint;
    if (category?.parent_name) {
      categoryDisplay = `${category.parent_name}, ${parsed.categoryHint}`;
    }

    let msg = `${emoji} <b>Konfirmasi ${typeLabel}</b>\n\n`;
    msg += `📅 ${dateStr}\n`;
    msg += `💳 ${parsed.walletHint || '-'}\n`;
    msg += `💵 ${amount}\n`;
    msg += `📁 ${categoryDisplay}\n`;
    msg += `📝 ${parsed.notes}\n`;
    msg += `\n<b>Simpan transaksi ini?</b>`;

    return msg;
  }
}
