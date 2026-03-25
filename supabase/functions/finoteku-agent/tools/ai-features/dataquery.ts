/** * Data Query Tool * Menjawab pertanyaan tentang data keuangan user dengan bantuan AI
 * Mengintegrasikan multiple data sources dan LLM untuk natural language answers
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import * as walletData from '../../data/wallets.ts';
import * as transactionData from '../../data/transactions.ts';

export class DataQueryTool extends BaseTool {
  name = 'data_query';
  description = 'Menjawab pertanyaan tentang data keuangan user';
  intents = ['query_data'];

  constructor(private supabase: SupabaseClient, private ai?: AIProvider) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;
    const text = (params.text as string) || '';

    if (!userContext) {
      return this.error('User context required');
    }

    if (!text) {
      return this.error('Pertanyaan diperlukan');
    }

    try {
      // 1. Gather relevant data based on question keywords
      const dataContext = await this.gatherData(userContext.userId, text);

      // 2. If no AI, return raw data summary
      if (!this.ai) {
        return this.success(dataContext, this.formatRawData(dataContext));
      }

      // 3. Use AI to generate natural language answer
      const answer = await this.generateAnswer(text, dataContext);
      return this.success(dataContext, answer);
    } catch (error) {
      console.error('[DataQueryTool] Error:', error);
      return this.error('Gagal mengambil data. Coba lagi nanti.');
    }
  }

  /**
   * Gather relevant financial data based on question
   */
  private async gatherData(userId: string, question: string): Promise<Record<string, unknown>> {
    const data: Record<string, unknown> = {};
    const lowerQ = question.toLowerCase();

    // Fetch wallet/balance data if relevant
    if (
      lowerQ.includes('saldo') || lowerQ.includes('wallet') || lowerQ.includes('dompet') ||
      lowerQ.includes('uang')
    ) {
      const { data: wallets } = await walletData.getBalances(this.supabase, userId);
      data.wallets = wallets;
      data.totalBalance = wallets?.reduce((sum, w) => sum + w.balance, 0) || 0;
    }

    // Fetch monthly expense summary if relevant
    if (lowerQ.includes('pengeluaran') || lowerQ.includes('bulan') || lowerQ.includes('total')) {
      const now = new Date();
      const monthlyExpense = await transactionData.getMonthlyExpense(
        this.supabase,
        userId,
        now.getFullYear(),
        now.getMonth() + 1,
      );
      data.monthlyExpense = monthlyExpense;
    }

    // Fetch recent transactions if relevant
    if (
      lowerQ.includes('terakhir') || lowerQ.includes('terbaru') || lowerQ.includes('riwayat') ||
      lowerQ.includes('histori') || lowerQ.includes('transaksi')
    ) {
      const { data: recent } = await transactionData.getRecent(this.supabase, userId, 5);
      data.recentTransactions = recent;
    }

    // Fetch this month's transactions for analysis
    if (
      lowerQ.includes('kategori') || lowerQ.includes('tertinggi') || lowerQ.includes('terendah') ||
      lowerQ.includes('terbanyak') || lowerQ.includes('minggu')
    ) {
      const now = new Date();
      const startOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
      const endOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-31`;
      const { data: monthTransactions } = await transactionData.getByDateRange(
        this.supabase,
        userId,
        startOfMonth,
        endOfMonth,
      );
      data.monthTransactions = monthTransactions;
    }

    return data;
  }

  /**
   * Generate natural language answer using AI
   */
  private async generateAnswer(question: string, data: Record<string, unknown>): Promise<string> {
    if (!this.ai) return this.formatRawData(data);

    const response = await this.ai.generateText(
      `Pertanyaan: "${question}"\nData: ${JSON.stringify(data)}`,
      {
        systemPrompt: 'Kamu Finoteku, asisten keuangan. Jawab dalam Bahasa Indonesia santai, pakai emoji, format Rupiah. Maks 4 kalimat. Jika data kosong, sarankan user menambah data.',
        maxTokens: 300,
        temperature: 0.3,
      }
    );
    return response;
  }

  /**
   * Format raw data as fallback when AI is not available
   */
  private formatRawData(data: Record<string, unknown>): string {
    const parts: string[] = ['📊 <b>Data Keuangan</b>\n'];

    if (data.totalBalance !== undefined) {
      const formatted = new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        minimumFractionDigits: 0,
      }).format(data.totalBalance as number);
      parts.push(`💰 Total Saldo: ${formatted}`);
    }

    if (data.monthlySummary) {
      const summary = data.monthlySummary as { income?: number; expense?: number };
      if (summary.income) {
        parts.push(`📈 Pemasukan Bulan Ini: Rp ${summary.income.toLocaleString('id-ID')}`);
      }
      if (summary.expense) {
        parts.push(`📉 Pengeluaran Bulan Ini: Rp ${summary.expense.toLocaleString('id-ID')}`);
      }
    }

    if (parts.length === 1) {
      parts.push('Belum ada data yang tersedia.');
    }

    return parts.join('\n');
  }
}
