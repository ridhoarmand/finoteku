/**
 * Tips Tool
 * Generate tips hemat berdasarkan pola pengeluaran
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from './base.ts';
import type { ToolResult } from '../types.ts';
import * as transactionData from '../data/transactions.ts';
import type { UserContext } from '../data/users.ts';

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

interface SavingTip {
  category: string;
  suggestion: string;
  potentialSaving: number;
}

export class TipsTool extends BaseTool {
  name = 'tips';
  description = 'Generate saving tips';
  intents = ['query_tips'];

  constructor(private supabase: SupabaseClient) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;

    if (!userContext) {
      return this.error('User context required');
    }

    const now = new Date();
    const thisMonthExpense = await transactionData.getMonthlyExpense(this.supabase, userContext.userId, now.getFullYear(), now.getMonth() + 1);

    const tips: SavingTip[] = [];

    if (thisMonthExpense > 0) {
      const dailyBudget = Math.round(thisMonthExpense / now.getDate());
      const remainingDays = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate() - now.getDate();
      const projectedTotal = thisMonthExpense + dailyBudget * remainingDays;

      tips.push({
        category: 'Budget Harian',
        suggestion: `Rata-rata pengeluaran harian: ${formatCurrency(dailyBudget)}. Sisa ${remainingDays} hari.`,
        potentialSaving: Math.round(dailyBudget * 0.2 * remainingDays),
      });

      if (projectedTotal > thisMonthExpense * 1.5) {
        tips.push({
          category: 'Proyeksi',
          suggestion: `Proyeksi akhir bulan: ${formatCurrency(projectedTotal)}. Pertimbangkan untuk mengurangi pengeluaran.`,
          potentialSaving: Math.round(projectedTotal * 0.1),
        });
      }
    }

    if (tips.length === 0) {
      return this.success([], '💡 <b>Tips Hemat</b>\n\nBelum cukup data untuk memberikan rekomendasi.');
    }

    return this.success(tips, this.formatMessage(tips));
  }

  private formatMessage(tips: SavingTip[]): string {
    let message = `💡 <b>Tips Hemat</b>\n\n`;
    for (let i = 0; i < tips.length; i++) {
      const tip = tips[i];
      message += `${i + 1}. <b>${tip.category}</b>\n`;
      message += `   ${tip.suggestion}\n`;
      message += `   💰 Potensi hemat: ${formatCurrency(tip.potentialSaving)}/bulan\n\n`;
    }
    return message;
  }
}
