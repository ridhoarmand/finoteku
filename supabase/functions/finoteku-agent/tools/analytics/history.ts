/**
 * History Tool
 * Query riwayat transaksi terbaru
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

export class HistoryTool extends BaseTool {
  name = 'history';
  description = 'Query recent transaction history';
  intents = ['query_transactions'];

  constructor(private supabase: SupabaseClient) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;

    if (!userContext) {
      return this.error('User context required');
    }

    const { data: entries, error } = await transactionData.getRecent(
      this.supabase,
      userContext.userId,
      5,
    );

    if (error || !entries || entries.length === 0) {
      return this.success([], '📋 <b>Riwayat Transaksi</b>\n\nBelum ada transaksi yang tercatat.');
    }

    let message = '📋 <b>Riwayat Transaksi (5 Terakhir)</b>\n\n';
    // deno-lint-ignore no-explicit-any
    for (const entry of entries as any[]) {
      // Use signed_amount from ledger_entries view for correct income/expense detection
      const signedAmount = Number(entry.signed_amount ?? entry.amount);
      const isExpense = signedAmount < 0;
      const amount = Math.abs(signedAmount);
      const emoji = isExpense ? '💸' : '💰';
      const sign = isExpense ? '-' : '+';

      const dateStr = new Date(entry.date).toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'short',
      });

      // Get category name from view or fallback
      const category = entry.category_name || entry.description || 'Transfer';

      message += `${emoji} ${dateStr} • ${category}\n`;
      message += `   ${sign}${formatCurrency(amount)}`;
      if (entry.notes) message += ` • ${entry.notes}`;
      message += '\n\n';
    }

    return this.success(entries, message);
  }
}
