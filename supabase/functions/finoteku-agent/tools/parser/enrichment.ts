/** * Data Enrichment Tool * Smart all-in-one parser: extract → patterns → defaults → clean → validate
 */

import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import type { UserPatterns } from '../../data/patterns.ts';
import type { AIProvider } from '../../providers/base.ts';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface PartialTransactionData {
  original: string;
  amount: number | null;
  categoryHint: string | null;
  walletHint: string | null;
  notes: string | null;
  dateOffset: number | null;
  _patternMatch?: { word: string; confidence: number };
  _defaultApplied?: string[];
  _aiAssisted?: boolean;
}

interface EnrichedTransactionData
  extends
    Required<Omit<PartialTransactionData, '_patternMatch' | '_defaultApplied' | '_aiAssisted'>> {
  _patternMatch?: { word: string; confidence: number };
  _defaultApplied?: string[];
  _aiAssisted?: boolean;
}

export class DataEnrichmentTool extends BaseTool {
  name = 'data_enrichment';
  description = 'Lengkapi data transaksi dengan pattern learning & smart defaults';
  intents = ['enrich_transaction_data', 'transaction'];

  constructor(private supabase: SupabaseClient, private ai?: AIProvider) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const text = params.text as string;
    const userContext = params.userContext as UserContext;
    const patterns = params.patterns as UserPatterns;

    console.log('[DataEnrichment] Start:', text);

    try {
      // Step 1: Extract dari input
      const extracted = this.extractFromInput(text, userContext, patterns);
      console.log('[DataEnrichment] Extracted:', extracted);

      // Step 2: Apply patterns
      const withPatterns = this.applyPatterns(extracted, patterns);
      console.log('[DataEnrichment] With patterns:', withPatterns);

      // Step 3: Apply defaults
      const withDefaults = this.applyDefaults(withPatterns, userContext, patterns);
      console.log('[DataEnrichment] With defaults:', withDefaults);

      // Step 4: Clean notes
      const cleaned = this.cleanNotes(withDefaults);
      console.log('[DataEnrichment] Cleaned notes:', cleaned.notes);

      // Step 5: Validate
      const validation = this.validate(cleaned);

      if (!validation.isComplete) {
        console.warn('[DataEnrichment] Incomplete:', validation.missing);

        // AI fallback jika ada & user allow AI
        if (this.ai && userContext.parserMode !== 'regex' && validation.missing.length > 0) {
          return await this.askAIToComplete(text, cleaned, userContext, validation.missing);
        }

        return this.error(
          `❌ Data tidak lengkap: ${validation.missing.join(', ')}`,
          JSON.stringify(cleaned),
        );
      }

      // Success! Data 100% complete
      const enriched = cleaned as EnrichedTransactionData;

      // Format confirmation message
      const message = this.formatConfirmation(enriched, userContext);

      return this.success(
        {
          ...enriched,
          needsConfirmation: true,
        },
        message,
      );
    } catch (error) {
      console.error('[DataEnrichment] Error:', error);
      return this.error('❌ Gagal memproses transaksi', (error as Error).message);
    }
  }

  /**
   * Extract data dari raw input
   */
  private extractFromInput(
    text: string,
    userContext: UserContext,
    patterns: UserPatterns,
  ): PartialTransactionData {
    const data: PartialTransactionData = {
      original: text,
      amount: null,
      categoryHint: null,
      walletHint: null,
      notes: text,
      dateOffset: null,
    };

    // Extract amount
    const amountRegex = /(\d+)(?:\.?\d+)?\s*(?:k|rb|ribu)?(?:\s|$)/i;
    const amountMatch = text.match(amountRegex);

    if (amountMatch) {
      let amount = parseFloat(amountMatch[1]);
      const suffix = text.slice(amountMatch.index!, amountMatch.index! + amountMatch[0].length)
        .toLowerCase();

      if (suffix.includes('k') || suffix.includes('rb') || suffix.includes('ribu')) {
        amount *= 1000;
      }

      data.amount = amount;
    }

    // Extract date keywords
    const dateKeywords: Record<string, number> = {
      kemarin: -1,
      lusa: 2,
      besok: 1,
      'minggu lalu': -7,
      'bulan lalu': -30,
    };

    for (const [keyword, offset] of Object.entries(dateKeywords)) {
      if (text.toLowerCase().includes(keyword)) {
        data.dateOffset = offset;
        break;
      }
    }

    // Extract wallet hint (explicit mention)
    for (const wallet of userContext.wallets) {
      if (text.toLowerCase().includes(wallet.name.toLowerCase())) {
        data.walletHint = wallet.name;
        break;
      }
    }

    // Extract category hint dari patterns (keyword match)
    const words = text.toLowerCase().split(/\s+/);
    for (const word of words) {
      if (patterns.keywords[word] && patterns.keywords[word].confidence > 0.5) {
        data.categoryHint = patterns.keywords[word].category;
        data._patternMatch = {
          word,
          confidence: patterns.keywords[word].confidence,
        };
        break;
      }
    }

    // Jika tidak ada pattern match, coba predefined hints
    if (!data.categoryHint) {
      const categoryHints: Record<string, string> = {
        jajan: 'Makanan',
        makan: 'Makanan',
        sarapan: 'Makanan',
        lunch: 'Makanan',
        dinner: 'Makanan',
        grab: 'Transport',
        gojek: 'Transport',
        bensin: 'Transport',
        parkir: 'Transport',
        belanja: 'Belanja',
        beli: 'Belanja',
        bayar: 'Tagihan',
        listrik: 'Tagihan',
        wifi: 'Tagihan',
        pulsa: 'Tagihan',
      };

      for (const [keyword, category] of Object.entries(categoryHints)) {
        if (text.toLowerCase().includes(keyword)) {
          // Check if category exists in user's categories
          const found = userContext.categories.find((c) =>
            c.name.toLowerCase() === category.toLowerCase()
          );
          if (found) {
            data.categoryHint = found.name;
            break;
          }
        }
      }
    }

    return data;
  }

  /**
   * Apply user patterns
   */
  private applyPatterns(
    data: PartialTransactionData,
    patterns: UserPatterns,
  ): PartialTransactionData {
    // Jika category sudah ada dari extraction, skip
    if (data.categoryHint) return data;

    // Cari pattern match dari words
    const words = data.original.toLowerCase().split(/\s+/);

    for (const word of words) {
      const pattern = patterns.keywords[word];

      if (pattern && pattern.confidence > 0.6) {
        data.categoryHint = pattern.category;
        data._patternMatch = {
          word,
          confidence: pattern.confidence,
        };

        // Apply wallet from pattern juga
        if (!data.walletHint && pattern.wallet) {
          data.walletHint = pattern.wallet;
        }

        break;
      }
    }

    return data;
  }

  /**
   * Apply smart defaults
   */
  private applyDefaults(
    data: PartialTransactionData,
    userContext: UserContext,
    patterns: UserPatterns,
  ): PartialTransactionData {
    data._defaultApplied = data._defaultApplied || [];

    // Default wallet
    if (!data.walletHint) {
      // 1. Try most used from patterns
      // 2. Try find "Cash" or "Tunai"
      // 3. Use first wallet
      const cashWallet = userContext.wallets.find((w) =>
        ['cash', 'tunai', 'kas'].includes(w.name.toLowerCase())
      );

      data.walletHint = patterns.mostUsedWallet || cashWallet?.name ||
        userContext.wallets[0]?.name || 'Cash';

      data._defaultApplied.push('wallet');
    }

    // Default date = hari ini
    if (data.dateOffset === null) {
      data.dateOffset = 0;
      data._defaultApplied.push('date');
    }

    // Default amount (jika masih null, set 0 - akan di-flag sebagai error)
    if (!data.amount) {
      data.amount = 0;
      data._defaultApplied.push('amount');
    }

    // Default category (use most used)
    if (!data.categoryHint && patterns.mostUsedCategory) {
      data.categoryHint = patterns.mostUsedCategory;
      data._defaultApplied.push('category');
    }

    return data;
  }

  /**
   * Clean notes - remove extracted data
   */
  private cleanNotes(data: PartialTransactionData): PartialTransactionData {
    let notes = data.notes || '';

    // Remove amount
    notes = notes.replace(/\d+(?:\.?\d+)?\s*(?:k|rb|ribu)?/gi, '');

    // Remove date keywords
    notes = notes.replace(/\b(kemarin|lusa|besok|hari ini|minggu lalu|bulan lalu)\b/gi, '');

    // Remove category hint words
    if (data.categoryHint) {
      const categoryWords = data.categoryHint.toLowerCase().split(/\s+/);
      for (const word of categoryWords) {
        notes = notes.replace(new RegExp(`\\b${word}\\b`, 'gi'), '');
      }
    }

    // Remove predefined category keywords
    const keywords = [
      'jajan',
      'makan',
      'sarapan',
      'lunch',
      'dinner',
      'grab',
      'gojek',
      'bensin',
      'parkir',
      'belanja',
      'beli',
      'bayar',
      'listrik',
      'wifi',
      'pulsa',
    ];
    for (const keyword of keywords) {
      notes = notes.replace(new RegExp(`\\b${keyword}\\b`, 'gi'), '');
    }

    // Remove wallet name
    if (data.walletHint) {
      notes = notes.replace(new RegExp(`\\b${data.walletHint}\\b`, 'gi'), '');
    }

    // Clean whitespace
    notes = notes.replace(/\s+/g, ' ').trim();

    // Default if empty
    data.notes = notes || 'Transaksi';

    return data;
  }

  /**
   * Validate completeness
   */
  private validate(data: PartialTransactionData): {
    isComplete: boolean;
    missing: string[];
  } {
    const missing: string[] = [];

    if (!data.amount || data.amount === 0) missing.push('amount');
    if (!data.categoryHint) missing.push('category');
    if (!data.walletHint) missing.push('wallet');
    if (data.dateOffset === null) missing.push('date');

    return {
      isComplete: missing.length === 0,
      missing,
    };
  }

  /**
   * AI fallback untuk complete missing data
   */
  private async askAIToComplete(
    originalText: string,
    currentData: PartialTransactionData,
    userContext: UserContext,
    missing: string[],
  ): Promise<ToolResult> {
    console.log('[DataEnrichment] Asking AI to complete:', missing);

    const prompt = `
Analisa transaksi ini dan lengkapi data yang masih kosong.

Input user: "${originalText}"

Data yang sudah diparse:
- Amount: ${currentData.amount || 'MISSING'}
- Category: ${currentData.categoryHint || 'MISSING'}
- Wallet: ${currentData.walletHint || 'MISSING'}
- Date: ${
      currentData.dateOffset === null
        ? 'MISSING'
        : currentData.dateOffset === 0
        ? 'hari ini'
        : `${currentData.dateOffset} hari`
    }
- Notes: ${currentData.notes || 'MISSING'}

Kategori user: ${userContext.categories.map((c) => c.name).join(', ')}
Wallet user: ${userContext.wallets.map((w) => w.name).join(', ')}

Yang masih MISSING: ${missing.join(', ')}

Lengkapi yang missing dengan data yang paling masuk akal.
Return JSON format:
{
  "amount": number,
  "category": "nama kategori dari list di atas",
  "wallet": "nama wallet dari list di atas",
  "dateOffset": number (0=hari ini, -1=kemarin, dst),
  "notes": "catatan transaksi (bukan kategori, bukan amount)"
}
    `.trim();

    try {
      const response = await this.ai!.generateText(prompt);
      const aiData = JSON.parse(response);

      const enriched: EnrichedTransactionData = {
        original: currentData.original,
        amount: aiData.amount || currentData.amount || 0,
        categoryHint: aiData.category || currentData.categoryHint || '',
        walletHint: aiData.wallet || currentData.walletHint || '',
        dateOffset: aiData.dateOffset ?? currentData.dateOffset ?? 0,
        notes: aiData.notes || currentData.notes || 'Transaksi',
        _aiAssisted: true,
        _defaultApplied: currentData._defaultApplied,
      };

      const message = this.formatConfirmation(enriched, userContext);

      return this.success(
        {
          ...enriched,
          needsConfirmation: true,
        },
        message,
      );
    } catch (error) {
      console.error('[DataEnrichment] AI error:', error);
      return this.error('❌ AI tidak dapat lengkapi data', (error as Error).message);
    }
  }

  /**
   * Format confirmation message
   */
  private formatConfirmation(data: EnrichedTransactionData, userContext: UserContext): string {
    // Determine type from category
    const category = userContext.categories.find((c) =>
      c.name.toLowerCase() === data.categoryHint!.toLowerCase()
    );

    const type = category?.type || 'expense';
    const emoji = type === 'income' ? '💰' : '💸';

    // Format date
    const date = new Date();
    date.setDate(date.getDate() + data.dateOffset!);
    const dateStr = date.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    // Find wallet
    const wallet = userContext.wallets.find((w) =>
      w.name.toLowerCase() === data.walletHint!.toLowerCase()
    );

    let message = `${emoji} <b>${type === 'income' ? 'Pemasukan' : 'Pengeluaran'}</b>\n\n`;
    message += `📅 ${dateStr}\n`;
    message += `💳 ${wallet?.name || data.walletHint}\n`;
    message += `💵 Rp ${data.amount!.toLocaleString('id-ID')}\n`;
    message += `📁 ${category?.name || data.categoryHint}\n`;
    message += `📝 ${data.notes}\n`;

    // Show auto-completed fields
    if (data._defaultApplied && data._defaultApplied.length > 0) {
      message += `\n✨ <i>Auto-completed:</i>\n`;

      for (const field of data._defaultApplied) {
        if (field === 'wallet') {
          message += `• Wallet: ${data.walletHint}\n`;
        } else if (field === 'date') {
          message += `• Tanggal: Hari ini\n`;
        } else if (field === 'category') {
          message += `• Kategori: ${data.categoryHint}\n`;
        }
      }
    }

    // Show pattern match
    if (data._patternMatch) {
      message += `\n🎯 <i>Pattern match: "${data._patternMatch.word}" (${
        (data._patternMatch.confidence * 100).toFixed(0)
      }%)</i>\n`;
    }

    // Show AI assistance
    if (data._aiAssisted) {
      message += `\n🤖 <i>AI-assisted completion</i>\n`;
    }

    message += `\nSimpan transaksi ini?`;

    return message;
  }
}
