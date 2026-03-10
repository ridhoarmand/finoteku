/**
 * Transaction Parser Tool
 * AI-first parser: simple, accurate, maintainable
 */

import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import type { AIProvider } from '../../providers/base.ts';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface TransactionData {
  original: string;
  amount: number;
  categoryHint: string;
  walletHint: string;
  notes: string;
  dateOffset: number;
  _aiParsed?: boolean;
}

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
      // AI-first approach
      if (this.ai) {
        return await this.parseWithAI(text, userContext);
      }

      // Fallback if no AI
      return this.error('❌ AI parsing tidak tersedia. Silakan hubungi admin.', 'AI provider not configured');
    } catch (error) {
      console.error('[TransactionParser] Error:', error);
      return this.error('❌ Gagal memproses transaksi', (error as Error).message);
    }
  }

  /**
   * Parse transaction using AI
   */
  private async parseWithAI(text: string, userContext: UserContext): Promise<ToolResult> {
    console.log('[TransactionParser] Using AI parser');

    const currentDate = new Date();
    const dateStr = currentDate.toISOString().split('T')[0]; // YYYY-MM-DD

    const prompt = `
You are a transaction parser. Parse the following transaction text and extract structured data.

Current date: ${dateStr}

Input text: "${text}"

Available categories (with type and parent):
${userContext.categories
  .map((c) => {
    const parentInfo = c.parent_name ? ` [child of ${c.parent_name}]` : ' [parent]';
    return `- ${c.name} (${c.type})${parentInfo}`;
  })
  .join('\n')}

Available wallets:
${userContext.wallets.map((w) => `- ${w.name}`).join('\n')}

Parse and return JSON with this exact structure:
{
  "amount": number,
  "category": "exact category name from list above",
  "wallet": "exact wallet name from list above or default to 'Cash'",
  "dateOffset": number,
  "notes": "string"
}

Rules:
1. **Amount**: Extract the transaction amount
   - Handle formats: "Rp32.500", "25rb", "100k", "50 ribu", "2jt"
   - Indonesian format uses dots for thousands: "1.000" = 1000
   - Remove "Rp" prefix and convert to number
   - "k/rb/ribu" = ×1000, "jt/juta" = ×1000000

2. **Category**: Choose ONE category from the available list
   - **IMPORTANT**: Use the EXACT category name from the list, not a combination
   - **PRIORITIZE child categories over parent categories**
   - Examples of correct matching:
     * Input "Kencan Jajan" → Choose "Jajan" (the child of Kencan, not "Kencan")
     * Input "Makan Diluar" → Choose "Makan Diluar" (exact match)
     * Input "Bayar listrik" → Choose "Listrik" (keyword match)
   - Match by context/keywords in the text
   - Categories shown as "Parent > Child" mean the category name is "Child" with parent "Parent"
   - If unclear, use most common category type

3. **Wallet**: Choose ONE wallet from the available list
   - If wallet explicitly mentioned (e.g., "pakai BCA", "dari Gopay"), use that exact wallet name
   - **Payment method inference:**
     - "QRIS" → Likely e-wallet: BCA, Seabank, Gopay, ... (in order of preference)
     - "Transfer" / "M-Banking" → Likely bank: BCA, Mandiri, BCA, BSI (in order of preference)
     - "Debit" / "Kartu" → Likely bank: BCA, Mandiri, etc
     - "Tunai" / "Cash" → Use "Cash"
   - If payment method mentioned but wallet unclear, use most common wallet from available list
   - Default to "Cash" only if truly no information

4. **Date Offset**: Calculate days from current date (${dateStr})
   - Format "DD MMM YYYY" or "DD/MM/YYYY": calculate exact offset
   - "kemarin" = -1
   - "besok" = 1
   - "lusa" = 2
   - "hari ini" or not mentioned = 0
   - "minggu lalu" = -7
   - "bulan lalu" = -30

5. **Notes**: Create meaningful description with proper formatting
   - **Formatting**: Use Title Case (capitalize first letter of each word)
   - **Preserve acronyms**: Keep 2-3 letter abbreviations in CAPS (e.g., "BJ Store", "ATM", "KFC")
   - **Avoid**: Full CAPS text (e.g., "MARTA FROZEN FOOD" → "Marta Frozen Food")
   - Include merchant name, items, or purpose
   - Don't repeat category or amount
   - Keep it concise but informative
   - Examples: 
     * "Marta Frozen Food - Sosis Kanzler, Bakso"
     * "Grab ke Kantor"
     * "BJ Store - Beli Sayuran"
     * "ATM Mandiri - Tarik Tunai"

Return ONLY valid JSON, no additional text.
`.trim();

    try {
      const response = await this.ai!.generateText(prompt);
      console.log('[TransactionParser] AI response:', response);

      // Extract JSON from markdown code blocks if present
      let jsonStr = response.trim();

      // Remove markdown code blocks: ```json ... ``` or ``` ... ```
      const codeBlockMatch = jsonStr.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
      if (codeBlockMatch) {
        jsonStr = codeBlockMatch[1];
      }

      // Also try to find JSON object directly if no code block
      if (!codeBlockMatch) {
        const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          jsonStr = jsonMatch[0];
        }
      }

      console.log('[TransactionParser] Extracted JSON:', jsonStr);

      // Parse AI response
      const parsed = JSON.parse(jsonStr);
      console.log('[TransactionParser] Parsed JSON:', parsed);

      // Validate required fields
      if (!parsed.amount || !parsed.category || !parsed.wallet || parsed.dateOffset === undefined) {
        console.error('[TransactionParser] Missing fields:', {
          hasAmount: !!parsed.amount,
          hasCategory: !!parsed.category,
          hasWallet: !!parsed.wallet,
          hasDateOffset: parsed.dateOffset !== undefined,
        });
        throw new Error('AI response missing required fields');
      }

      // STRICT validation: category must exist in user's list
      const category = userContext.categories.find((c) => c.name.toLowerCase() === parsed.category.toLowerCase());

      if (!category) {
        console.error('[TransactionParser] Category not found:', parsed.category);
        console.error(
          '[TransactionParser] Available categories:',
          userContext.categories.map((c) => c.name)
        );

        return this.error(`❌ Kategori "${parsed.category}" tidak ditemukan.\n\n` + `Gunakan salah satu:\n${userContext.categories.map((c) => `• ${c.name}`).join('\n')}`);
      }

      // Relaxed validation: wallet should exist, but allow Cash as fallback
      const wallet = userContext.wallets.find((w) => w.name.toLowerCase() === parsed.wallet.toLowerCase());

      // If wallet not found, default to Cash (common for payment methods like QRIS)
      if (!wallet && parsed.wallet.toLowerCase() !== 'cash') {
        console.warn('[TransactionParser] Wallet not found, defaulting to Cash:', parsed.wallet);
        console.warn(
          '[TransactionParser] Available wallets:',
          userContext.wallets.map((w) => w.name)
        );
      }

      const data: TransactionData = {
        original: text,
        amount: Number(parsed.amount),
        categoryHint: category.name,
        walletHint: wallet ? wallet.name : 'Cash',
        notes: parsed.notes || 'Transaksi',
        dateOffset: Number(parsed.dateOffset),
        _aiParsed: true,
      };

      console.log('[TransactionParser] Parsed data:', data);

      // Format confirmation message
      const message = this.formatConfirmation(data, userContext);

      return this.success(
        {
          ...data,
          needsConfirmation: true,
        },
        message
      );
    } catch (error) {
      console.error('[TransactionParser] AI parsing error:', error);
      console.error('[TransactionParser] Error details:', {
        message: (error as Error).message,
        stack: (error as Error).stack,
      });

      return this.error('❌ AI tidak dapat memproses input.\n\n' + `Error: ${(error as Error).message}\n\n` + 'Coba format berbeda atau hubungi admin.', (error as Error).message);
    }
  }

  /**
   * Format confirmation message
   */
  private formatConfirmation(data: TransactionData, userContext: UserContext): string {
    // Determine type from category
    const category = userContext.categories.find((c) => c.name.toLowerCase() === data.categoryHint.toLowerCase());

    const type = category?.type || 'expense';
    const emoji = type === 'income' ? '💰' : '💸';

    // Format date
    const date = new Date();
    date.setDate(date.getDate() + data.dateOffset);
    const dateStr = date.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    // Find wallet
    const wallet = userContext.wallets.find((w) => w.name.toLowerCase() === data.walletHint.toLowerCase());

    // Format category with parent if available
    let categoryDisplay = category?.name || data.categoryHint;
    if (category?.parent_name) {
      categoryDisplay = `${category.parent_name} > ${category.name}`;
    }

    let message = `${emoji} <b>${type === 'income' ? 'Pemasukan' : 'Pengeluaran'}</b>\n\n`;
    message += `📅 ${dateStr}\n`;
    message += `💳 ${wallet?.name || data.walletHint}\n`;
    message += `💵 Rp ${data.amount.toLocaleString('id-ID')}\n`;
    message += `📁 ${categoryDisplay}\n`;
    message += `📝 ${data.notes}\n`;

    if (data._aiParsed) {
      message += `\n🤖 <i>Parsed by AI</i>\n`;
    }

    message += `\nSimpan transaksi ini?`;

    return message;
  }
}
