/**
 * Transaction Parser Tool
 * AI-first parser: optimized prompts, uses generateJSON
 */

import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import type { AIProvider } from '../../providers/base.ts';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface TransactionData {
  original: string;
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  categoryHint: string;
  walletHint: string;
  toWalletHint?: string;
  notes: string;
  dateOffset: number;
  _aiParsed?: boolean;
}

interface ParsedAIResponse {
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  category: string;
  wallet: string;
  toWallet?: string;
  dateOffset: number;
  notes: string;
}

// System prompt statis — dikirim sebagai systemInstruction (dioptimasi oleh Gemini)
const PARSER_SYSTEM_PROMPT = `You are a transaction parser for an Indonesian finance app. Parse text into structured JSON.

Rules by Step:
1. Priority: If input contains "[Catatan Tambahan User: ...]", treat that text as the ABSOLUTE HIGHEST priority for determining the Category, Wallet, and Notes. It overrides the raw text/OCR.
2. Detect Type: "transfer" (pindah saldo, tarik tunai). "income" (pemasukan, gaji). "expense" (pengeluaran, belanja).
3. Category: Pick EXACTLY one name from the provided category lists matching the detected type. NEVER add brackets or types.
4. Wallet: Pick EXACT name from list. Default "Cash". For transfers: wallet=source, toWallet=destination.
5. DateOffset: 0=today, -1=kemarin, 1=besok.
6. Amount: Extract numbers (25rb=25000, 2jt=2000000).
7. Notes: Extract ONLY the specific context or items (e.g., "Makan Siang"). NEVER include the transaction type or the category name in the notes! Keep it concise in Title Case.

Return JSON: {"type","amount","category","wallet","toWallet"(transfers only),"dateOffset","notes"}`;

export class TransactionParserTool extends BaseTool {
  name = 'transaction_parser';
  description = 'Parse transaction data using AI';
  intents = ['enrich_transaction_data', 'transaction'];

  constructor(private supabase: SupabaseClient, private ai?: AIProvider) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const text = params.text as string;
    const userContext = params.userContext as UserContext;

    console.log('[TransactionParser] Input:', text);

    try {
      if (this.ai) {
        return await this.parseWithAI(text, userContext);
      }
      return this.error('❌ AI parsing tidak tersedia. Silakan hubungi admin.', 'AI provider not configured');
    } catch (error) {
      console.error('[TransactionParser] Error:', error);
      return this.error('❌ Gagal memproses transaksi', (error as Error).message);
    }
  }

  /**
   * Parse transaction using AI (generateJSON — no manual JSON extraction needed)
   */
  private async parseWithAI(text: string, userContext: UserContext): Promise<ToolResult> {
    console.log('[TransactionParser] Using AI parser');

    const dateStr = new Date().toISOString().split('T')[0];

    // Pisahkan kategori berdasarkan tipe agar AI lebih mengerti konteks
    const expenseCats = userContext.categories.filter(c => c.type === 'expense');
    const incomeCats = userContext.categories.filter(c => c.type === 'income');

    const lowerText = text.toLowerCase();
    const isLikelyIncome = ['masuk', 'terima', 'dapat', 'pemasukan'].some(k => lowerText.startsWith(k) || lowerText.includes(k));
    const isLikelyTransfer = ['transfer', 'pindah', 'kirim', 'mutasi', 'tarik tunai'].some(k => lowerText.startsWith(k) || lowerText.includes(k));
    const isLikelyExpense = ['keluar', 'bayar', 'pengeluaran', 'beli'].some(k => lowerText.startsWith(k) || lowerText.includes(k));
    
    let typeHint = 'unknown';
    if (isLikelyTransfer) typeHint = 'transfer';
    else if (isLikelyIncome) typeHint = 'income';
    else if (isLikelyExpense) typeHint = 'expense';

    // User prompt — hanya data dinamis
    const prompt = `Date: ${dateStr}
Input: "${text}"
Type Hint: ${typeHint} (prioritize this type if set)

Expense Categories:
${expenseCats.map(c => `- ${c.name}${c.parent_name ? ` [${c.parent_name}]` : ''}`).join('\n')}

Income Categories:
${incomeCats.map(c => `- ${c.name}${c.parent_name ? ` [${c.parent_name}]` : ''}`).join('\n')}

Wallets:
${userContext.wallets.map(w => `- ${w.name}`).join('\n')}`;

    try {
      const parsed = await this.ai!.generateJSON<ParsedAIResponse>(prompt, {
        systemPrompt: PARSER_SYSTEM_PROMPT,
        maxTokens: 200,
        temperature: 0.1,
      });

      console.log('[TransactionParser] AI parsed:', parsed);

      if (!parsed.amount || !parsed.category || !parsed.wallet || parsed.dateOffset === undefined) {
        throw new Error('AI response missing required fields');
      }

      // STRICT validation: category must exist in user's list, prioritizing exact type match
      let category = userContext.categories.find(c => c.name.toLowerCase() === parsed.category.toLowerCase() && c.type === parsed.type);
      if (!category) {
        // Fallback to name-only match if type mismatched
        category = userContext.categories.find(c => c.name.toLowerCase() === parsed.category.toLowerCase());
      }

      if (!category) {
        console.error('[TransactionParser] Category not found:', parsed.category);
        return this.error(`❌ Kategori "${parsed.category}" tidak ditemukan.\n\n` + `Gunakan salah satu:\n${userContext.categories.map(c => `• ${c.name}`).join('\n')}`);
      }

      // Wallet validation with Cash fallback
      const wallet = userContext.wallets.find(w => w.name.toLowerCase() === parsed.wallet.toLowerCase());
      if (!wallet && parsed.wallet.toLowerCase() !== 'cash') {
        console.warn('[TransactionParser] Wallet not found, defaulting to Cash:', parsed.wallet);
      }

      const data: TransactionData = {
        original: text,
        type: parsed.type || (category.type as 'income' | 'expense') || 'expense',
        amount: Number(parsed.amount),
        categoryHint: category.name,
        walletHint: wallet ? wallet.name : 'Cash',
        toWalletHint: parsed.toWallet || undefined,
        notes: parsed.notes || 'Transaksi',
        dateOffset: Number(parsed.dateOffset),
        _aiParsed: true,
      };

      console.log('[TransactionParser] Parsed data:', data);

      const message = this.formatConfirmation(data, userContext);

      return this.success({ ...data, needsConfirmation: true }, message);
    } catch (error) {
      console.error('[TransactionParser] AI parsing error:', error);
      return this.error('❌ AI tidak dapat memproses input.\n\n' + `Error: ${(error as Error).message}\n\n` + 'Coba format berbeda atau hubungi admin.', (error as Error).message);
    }
  }

  /**
   * Format confirmation message
   */
  private formatConfirmation(data: TransactionData, userContext: UserContext): string {
    const isIncome = data.type === 'income';
    const isTransfer = data.type === 'transfer';
    const emoji = isTransfer ? '🔄' : isIncome ? '💰' : '💸';

    const date = new Date();
    date.setDate(date.getDate() + data.dateOffset);
    const dateStr = date.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    const wallet = userContext.wallets.find(w => w.name.toLowerCase() === data.walletHint.toLowerCase());
    const toWallet = data.toWalletHint 
      ? userContext.wallets.find(w => w.name.toLowerCase() === data.toWalletHint!.toLowerCase())
      : null;

    const category = userContext.categories.find(c => c.name.toLowerCase() === data.categoryHint.toLowerCase());
    let categoryDisplay = category?.name || data.categoryHint;
    if (category?.parent_name) {
      categoryDisplay = `${category.parent_name} > ${category.name}`;
    }

    const typeLabel = isTransfer ? 'Transfer' : isIncome ? 'Pemasukan' : 'Pengeluaran';
    let message = `${emoji} <b>${typeLabel}</b>\n\n`;
    message += `📅 ${dateStr}\n`;
    
    if (isTransfer) {
      message += `📤 Dari: ${wallet?.name || data.walletHint}\n`;
      message += `📥 Ke: ${toWallet?.name || data.toWalletHint || '?'}\n`;
    } else {
      message += `💳 ${wallet?.name || data.walletHint}\n`;
    }

    message += `💵 Rp ${data.amount.toLocaleString('id-ID')}\n`;
    
    if (!isTransfer) {
      message += `📁 ${categoryDisplay}\n`;
    }
    
    message += `📝 ${data.notes}\n`;

    if (data._aiParsed) {
      message += `\n🤖 <i>Parsed by AI</i>\n`;
    }

    message += `\nSimpan transaksi ini?`;

    return message;
  }
}
