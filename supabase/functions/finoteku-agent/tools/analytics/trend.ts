/**
 * Trend Tool
 * Analisis tren pengeluaran
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import * as transactionData from '../../data/transactions.ts';
import type { UserContext } from '../../data/users.ts';

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

interface SpendingTrend {
  thisMonth: number;
  lastMonth: number;
  change: number;
  trend: 'up' | 'down' | 'stable';
}

export class TrendTool extends BaseTool {
  name = 'trend';
  description = 'Analyze spending trends';
  intents = ['query_trend'];

  constructor(private supabase: SupabaseClient) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;

    if (!userContext) {
      return this.error('User context required');
    }

    const [thisYear, thisMonth] = userContext.today.split('-').map(Number);
    const lastMonth = thisMonth === 1 ? 12 : thisMonth - 1;
    const lastYear = thisMonth === 1 ? thisYear - 1 : thisYear;

    // Get monthly expenses using Data Layer
    const thisMonthExpense = await transactionData.getMonthlyExpense(
      this.supabase,
      userContext.userId,
      thisYear,
      thisMonth,
    );
    const lastMonthExpense = await transactionData.getMonthlyExpense(
      this.supabase,
      userContext.userId,
      lastYear,
      lastMonth,
    );

    // Calculate change
    let change = 0;
    if (lastMonthExpense > 0) {
      change = Math.round(((thisMonthExpense - lastMonthExpense) / lastMonthExpense) * 100);
    }

    let trend: 'up' | 'down' | 'stable' = 'stable';
    if (change > 10) trend = 'up';
    else if (change < -10) trend = 'down';

    const result: SpendingTrend = {
      thisMonth: thisMonthExpense,
      lastMonth: lastMonthExpense,
      change,
      trend,
    };

    return this.success(result, this.formatMessage(result));
  }

  private formatMessage(trend: SpendingTrend): string {
    let message = `📈 <b>Tren Pengeluaran</b>\n\n`;
    message += `Bulan ini: ${formatCurrency(trend.thisMonth)}\n`;
    message += `Bulan lalu: ${formatCurrency(trend.lastMonth)}\n\n`;

    if (trend.trend === 'up') {
      message += `⚠️ Naik ${Math.abs(trend.change)}% dari bulan lalu`;
    } else if (trend.trend === 'down') {
      message += `✅ Turun ${Math.abs(trend.change)}% dari bulan lalu`;
    } else {
      message += `➡️ Relatif stabil`;
    }

    return message;
  }
}
