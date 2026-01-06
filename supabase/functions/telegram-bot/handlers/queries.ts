import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendTelegramMessage, formatCurrency } from '../../_shared/platforms/telegram.ts';
import {
  getWalletBalances,
  getMonthlySummary,
  formatBalanceMessage,
  formatMonthlySummaryMessage,
  getSpendingTrend,
  getSavingTips,
  formatSpendingTrendMessage,
  formatSavingTipsMessage,
  MonthlySummary,
} from '../../_shared/queries/finance.ts';

export async function handleQuery(supabase: SupabaseClient, telegramToken: string, chatId: number, userId: string, intent: string, originalText: string): Promise<Response | null> {
  // Handle balance query
  if (intent === 'query_balance') {
    console.log('Balance query - userId:', userId);
    const balances = await getWalletBalances(supabase, userId);
    console.log('Balance query result:', balances);

    // Check if user asked for specific wallet
    const lowerText = originalText.toLowerCase();
    const specificWallet = balances.find((w) => lowerText.includes(w.name.toLowerCase()));

    let message: string;
    if (specificWallet) {
      message = `💳 <b>Saldo ${specificWallet.name}</b>\n\n${formatCurrency(specificWallet.balance)}`;
    } else {
      message = formatBalanceMessage(balances);
    }

    await sendTelegramMessage(telegramToken, chatId, message);
    return new Response('OK', { status: 200 });
  }

  // Handle monthly summary query
  if (intent === 'query_summary') {
    const now = new Date();
    const monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    const textLower = originalText.toLowerCase();
    const isDetail = textLower.includes('detail');

    let targetMonth = now.getMonth() + 1; // 1-12
    let targetYear = now.getFullYear();

    // Check for "bulan lalu"
    if (textLower.includes('bulan lalu') || textLower.includes('last month') || textLower.includes('kemarin')) {
      targetMonth = now.getMonth(); // 0-11
      if (targetMonth === 0) {
        targetMonth = 12;
        targetYear--;
      }
    } else {
      // Check for specific month names
      for (let i = 0; i < monthNames.length; i++) {
        if (textLower.includes(monthNames[i].toLowerCase())) {
          targetMonth = i + 1;
          // If asked for a month that is ahead of current month, assume last year
          if (targetMonth > now.getMonth() + 1) {
            targetYear--;
          }
          break;
        }
      }
    }

    const monthName = monthNames[targetMonth - 1] + ' ' + targetYear;
    const summary = await getMonthlySummary(supabase, userId, targetYear, targetMonth);

    let message = '';
    if (isDetail) {
      message = formatDetailedSummary(summary, monthName);

      // Add Insight (Call to action to check trends/tips)
      message += `\n\n💡 <b>Insight:</b>\nCek tren pengeluaranmu dengan mengetik "tren pengeluaran" atau minta "saran hemat" untuk tips personal!`;
    } else {
      message = formatMonthlySummaryMessage(summary, monthName);
    }

    await sendTelegramMessage(telegramToken, chatId, message);
    return new Response('OK', { status: 200 });
  }

  // Handle spending trend query
  if (intent === 'query_trend') {
    const trend = await getSpendingTrend(supabase, userId);
    const message = formatSpendingTrendMessage(trend);
    await sendTelegramMessage(telegramToken, chatId, message);
    return new Response('OK', { status: 200 });
  }

  // Handle saving tips query
  if (intent === 'query_tips') {
    const tips = await getSavingTips(supabase, userId);
    const message = formatSavingTipsMessage(tips);
    await sendTelegramMessage(telegramToken, chatId, message);
    return new Response('OK', { status: 200 });
  }

  return null;
}

function formatDetailedSummary(summary: MonthlySummary, monthName: string): string {
  let msg = `📊 <b>Ringkasan Detail ${monthName}</b>\n\n`;
  msg += `<b>Total Pemasukan:</b> ${formatCurrency(summary.totalIncome)}\n`;
  msg += `<b>Total Pengeluaran:</b> ${formatCurrency(summary.totalExpense)}\n`;
  msg += `<b>Sisa Saldo:</b> ${formatCurrency(summary.netBalance)}\n\n`;

  msg += `<b>🔝 Pengeluaran Terbesar:</b>\n`;
  if (summary.topExpenseCategories.length === 0) msg += `- Belum ada data\n`;

  for (const cat of summary.topExpenseCategories) {
    msg += `• <b>${cat.name}</b>: ${formatCurrency(cat.total)}\n`;
    if (cat.children && cat.children.length > 0) {
      // Sort children desc
      const sorted = [...cat.children].sort((a, b) => b.total - a.total);
      for (const child of sorted) {
        msg += `   └ ${child.name}: ${formatCurrency(child.total)}\n`;
      }
    }
  }
  return msg;
}
