/**
 * Balance Tool
 * Query saldo wallet
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from './base.ts';
import type { ToolResult } from '../types.ts';
import * as walletData from '../data/wallets.ts';
import type { UserContext } from '../data/users.ts';

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

export class BalanceTool extends BaseTool {
  name = 'balance';
  description = 'Query wallet balances';
  intents = ['query_balance'];

  constructor(private supabase: SupabaseClient) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;
    const text = (params.text as string) || '';

    if (!userContext) {
      return this.error('User context required');
    }

    const { data: wallets, error } = await walletData.getBalances(this.supabase, userContext.userId);

    if (error || !wallets || wallets.length === 0) {
      return this.success([], '💳 <b>Saldo Wallet</b>\n\nBelum ada wallet yang tersimpan.');
    }

    // Check if user asked for specific wallet
    const lowerText = text.toLowerCase();
    const specificWallet = wallets.find((w) => lowerText.includes(w.name.toLowerCase()));

    if (specificWallet) {
      return this.success(specificWallet, `💳 <b>Saldo ${specificWallet.name}</b>\n\n${formatCurrency(specificWallet.balance)}`);
    }

    // All wallets
    const total = wallets.reduce((sum, w) => sum + w.balance, 0);
    const sorted = [...wallets].sort((a, b) => b.balance - a.balance);

    let message = `💰 <b>Saldo Wallet</b>\n\n`;
    for (const wallet of sorted) {
      const emoji = wallet.balance >= 0 ? '💳' : '⚠️';
      message += `${emoji} ${wallet.name}: ${formatCurrency(wallet.balance)}\n`;
    }
    message += `\n<b>Total: ${formatCurrency(total)}</b>`;

    return this.success({ wallets: sorted, total }, message);
  }
}
