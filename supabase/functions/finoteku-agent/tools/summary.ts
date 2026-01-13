/**
 * Summary Tool
 * Hitung dan tampilkan ringkasan bulanan
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from './base.ts';
import type { ToolResult } from '../types.ts';
import * as transactionData from '../data/transactions.ts';
import type { UserContext } from '../data/users.ts';

const MONTH_NAMES = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

interface CategorySummary {
  name: string;
  total: number;
  count: number;
}

interface MonthlySummary {
  month: string;
  year: number;
  totalIncome: number;
  totalExpense: number;
  netBalance: number;
  topExpenseCategories: CategorySummary[];
}

export class SummaryTool extends BaseTool {
  name = 'summary';
  description = 'Calculate monthly financial summary';
  intents = ['query_summary'];

  constructor(private supabase: SupabaseClient) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;
    const text = (params.text as string) || '';

    if (!userContext) {
      return this.error('User context required');
    }

    // Parse target month from text
    const { year, month } = this.parseMonth(text);
    const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
    const endDate = `${year}-${String(month).padStart(2, '0')}-31`;

    const { data: transactions } = await transactionData.getByDateRange(
      this.supabase,
      userContext.userId,
      startDate,
      endDate,
    );

    // Calculate summary
    let totalIncome = 0;
    let totalExpense = 0;
    const categoryTotals: Record<string, CategorySummary> = {};

    for (const t of transactions || []) {
      const amount = Math.abs(t.amount);
      const type = t.category_type;
      const catName = t.category_name || 'Lainnya';

      if (type === 'income') totalIncome += amount;
      else totalExpense += amount;

      if (type === 'expense') {
        if (!categoryTotals[catName]) {
          categoryTotals[catName] = { name: catName, total: 0, count: 0 };
        }
        categoryTotals[catName].total += amount;
        categoryTotals[catName].count += 1;
      }
    }

    const summary: MonthlySummary = {
      month: MONTH_NAMES[month - 1],
      year,
      totalIncome,
      totalExpense,
      netBalance: totalIncome - totalExpense,
      topExpenseCategories: Object.values(categoryTotals)
        .sort((a, b) => b.total - a.total)
        .slice(0, 5),
    };

    return this.success(summary, this.formatMessage(summary));
  }

  private parseMonth(text: string): { year: number; month: number } {
    const now = new Date();
    let targetMonth = now.getMonth() + 1;
    let targetYear = now.getFullYear();

    const textLower = text.toLowerCase();

    // Check for "bulan lalu"
    if (textLower.includes('bulan lalu') || textLower.includes('last month')) {
      targetMonth = now.getMonth();
      if (targetMonth === 0) {
        targetMonth = 12;
        targetYear--;
      }
    } else {
      // Check for specific month names
      for (let i = 0; i < MONTH_NAMES.length; i++) {
        if (textLower.includes(MONTH_NAMES[i].toLowerCase())) {
          targetMonth = i + 1;
          if (targetMonth > now.getMonth() + 1) targetYear--;
          break;
        }
      }
    }

    return { year: targetYear, month: targetMonth };
  }

  private formatMessage(summary: MonthlySummary): string {
    let message = `📊 <b>Ringkasan ${summary.month} ${summary.year}</b>\n\n`;
    message += `💰 Pemasukan: ${formatCurrency(summary.totalIncome)}\n`;
    message += `💸 Pengeluaran: ${formatCurrency(summary.totalExpense)}\n`;
    message += `📈 Selisih: ${formatCurrency(summary.netBalance)}\n`;

    if (summary.topExpenseCategories.length > 0) {
      message += `\n<b>Top Pengeluaran:</b>\n`;
      for (let i = 0; i < Math.min(3, summary.topExpenseCategories.length); i++) {
        const cat = summary.topExpenseCategories[i];
        const percent = summary.totalExpense > 0
          ? Math.round((cat.total / summary.totalExpense) * 100)
          : 0;
        message += `${i + 1}. ${cat.name}: ${formatCurrency(cat.total)} (${percent}%)\n`;
      }
    }

    return message;
  }
}
