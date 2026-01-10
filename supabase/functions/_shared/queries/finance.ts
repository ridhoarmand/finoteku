// Query functions for bot - get balance, summary, etc.
// These are used by the smart assistant when AI mode is enabled

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface WalletBalance {
  name: string;
  balance: number;
}

export interface CategorySummary {
  name: string;
  total: number;
  count: number;
  type: 'income' | 'expense';
  children?: { name: string; total: number; count: number }[];
}

export interface MonthlySummary {
  totalIncome: number;
  totalExpense: number;
  netBalance: number;
  topExpenseCategories: CategorySummary[];
  topIncomeCategories: CategorySummary[];
}

/**
 * Get all wallet balances for a user
 */
export async function getWalletBalances(
  supabase: SupabaseClient,
  userId: string,
): Promise<WalletBalance[]> {
  console.log('getWalletBalances called with userId:', userId);

  // Get wallets with balance directly
  const { data: wallets, error } = await supabase.from('wallets').select('name, balance').eq(
    'user_id',
    userId,
  );

  if (error) {
    console.error('Error fetching wallets:', error);
    return [];
  }

  if (!wallets || wallets.length === 0) {
    console.log('No wallets found for user');
    return [];
  }

  const result = wallets.map((w: any) => ({
    name: w.name,
    balance: Number(w.balance) || 0,
  }));

  console.log('Final wallet balances:', result);
  return result;
}

/**
 * Get monthly summary (income, expense, by category)
 */
export async function getMonthlySummary(
  supabase: SupabaseClient,
  userId: string,
  year?: number,
  month?: number,
): Promise<MonthlySummary> {
  const now = new Date();
  const targetYear = year || now.getFullYear();
  const targetMonth = month || now.getMonth() + 1;

  const startDate = `${targetYear}-${String(targetMonth).padStart(2, '0')}-01`;
  const endDate = `${targetYear}-${String(targetMonth).padStart(2, '0')}-31`;

  // 1. Fetch all categories to map parent IDs to names
  const { data: allCats } = await supabase.from('categories').select('id, name').eq(
    'user_id',
    userId,
  );
  const catMap = new Map((allCats || []).map((c) => [c.id, c.name]));

  // 2. Fetch transactions with parent_id info
  // Assuming 'parent_id' column exists in 'categories' and we can fetch it via join
  // If parent_id is in categories table:
  const { data: transactions, error } = await supabase.from('transactions').select(
    'amount, categories!inner(name, type, parent_id)',
  ).eq('user_id', userId).gte('date', startDate).lte('date', endDate);

  if (error || !transactions) {
    console.error('Error fetching monthly transactions:', error);
    return {
      totalIncome: 0,
      totalExpense: 0,
      netBalance: 0,
      topExpenseCategories: [],
      topIncomeCategories: [],
    };
  }

  let totalIncome = 0;
  let totalExpense = 0;
  const categoryTotals: Record<string, CategorySummary> = {};

  for (const t of transactions) {
    const amount = Math.abs(Number(t.amount));
    const cat = (t as any).categories;
    const type = cat.type;
    const parentId = cat.parent_id;

    // Use Parent Name if available
    let summaryName = cat.name;
    if (parentId && catMap.has(parentId)) {
      summaryName = catMap.get(parentId)!;
    }

    if (type === 'income') {
      totalIncome += amount;
    } else {
      totalExpense += amount;
    }

    const key = `${summaryName}-${type}`;
    if (!categoryTotals[key]) {
      categoryTotals[key] = { name: summaryName, total: 0, count: 0, type, children: [] };
    }
    categoryTotals[key].total += amount;
    categoryTotals[key].count += 1;

    // Add to children breakdown
    const children = categoryTotals[key].children!;
    const childName = cat.name;
    const existingChild = children.find((c) => c.name === childName);

    if (existingChild) {
      existingChild.total += amount;
      existingChild.count += 1;
    } else {
      children.push({ name: childName, total: amount, count: 1 });
    }
  }

  const categories = Object.values(categoryTotals);
  const expenseCategories = categories.filter((c) => c.type === 'expense').sort((a, b) =>
    b.total - a.total
  );
  const incomeCategories = categories.filter((c) => c.type === 'income').sort((a, b) =>
    b.total - a.total
  );

  return {
    totalIncome,
    totalExpense,
    netBalance: totalIncome - totalExpense,
    topExpenseCategories: expenseCategories.slice(0, 5),
    topIncomeCategories: incomeCategories.slice(0, 3),
  };
}

/**
 * Get recent transactions
 */
export async function getRecentTransactions(
  supabase: SupabaseClient,
  userId: string,
  limit: number = 10,
): Promise<
  { date: string; notes: string; amount: number; category: string; wallet: string; type: string }[]
> {
  const { data, error } = await supabase
    .from('transactions')
    .select('date, notes, amount, categories!inner(name, type), wallets!inner(name)')
    .eq('user_id', userId)
    .order('date', { ascending: false })
    .limit(limit);

  if (error || !data) {
    return [];
  }

  return data.map((t: any) => ({
    date: t.date,
    notes: t.notes || '',
    amount: Math.abs(Number(t.amount)),
    category: t.categories?.name || 'Unknown',
    wallet: t.wallets?.name || 'Unknown',
    type: t.categories?.type || 'expense',
  }));
}

// Format helpers
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

export function formatBalanceMessage(balances: WalletBalance[]): string {
  if (balances.length === 0) {
    return `💳 <b>Saldo Wallet</b>

Belum ada wallet yang tersimpan.

Silakan buat wallet di aplikasi Finoteku terlebih dahulu.`;
  }

  const total = balances.reduce((sum, w) => sum + w.balance, 0);

  // Sort by balance descending (terbesar ke terkecil)
  const sortedBalances = [...balances].sort((a, b) => b.balance - a.balance);

  let message = `💰 <b>Saldo Wallet</b>\n\n`;
  for (const wallet of sortedBalances) {
    const emoji = wallet.balance >= 0 ? '💳' : '⚠️';
    message += `${emoji} ${wallet.name}: ${formatCurrency(wallet.balance)}\n`;
  }
  message += `\n<b>Total: ${formatCurrency(total)}</b>`;

  return message;
}

export function formatMonthlySummaryMessage(summary: MonthlySummary, monthName: string): string {
  let message = `📊 <b>Ringkasan ${monthName}</b>\n\n`;

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

// ============ PHASE 3: ANALYTICS & RECOMMENDATIONS ============

export interface SpendingTrend {
  thisMonth: number;
  lastMonth: number;
  change: number; // percentage change
  trend: 'up' | 'down' | 'stable';
}

export interface CategoryTrend {
  name: string;
  thisMonth: number;
  lastMonth: number;
  change: number;
  isIncreasing: boolean;
}

export interface SavingTip {
  category: string;
  suggestion: string;
  potentialSaving: number;
}

/**
 * Get spending trend (this month vs last month)
 */
export async function getSpendingTrend(
  supabase: SupabaseClient,
  userId: string,
): Promise<SpendingTrend> {
  const now = new Date();
  const thisMonth = now.getMonth() + 1;
  const thisYear = now.getFullYear();
  const lastMonth = thisMonth === 1 ? 12 : thisMonth - 1;
  const lastYear = thisMonth === 1 ? thisYear - 1 : thisYear;

  const thisMonthSummary = await getMonthlySummary(supabase, userId, thisYear, thisMonth);
  const lastMonthSummary = await getMonthlySummary(supabase, userId, lastYear, lastMonth);

  const thisMonthExpense = thisMonthSummary.totalExpense;
  const lastMonthExpense = lastMonthSummary.totalExpense;

  let change = 0;
  if (lastMonthExpense > 0) {
    change = Math.round(((thisMonthExpense - lastMonthExpense) / lastMonthExpense) * 100);
  }

  let trend: 'up' | 'down' | 'stable' = 'stable';
  if (change > 10) trend = 'up';
  else if (change < -10) trend = 'down';

  return {
    thisMonth: thisMonthExpense,
    lastMonth: lastMonthExpense,
    change,
    trend,
  };
}

/**
 * Get top expense categories with trend
 */
export async function getTopCategoriesWithTrend(
  supabase: SupabaseClient,
  userId: string,
): Promise<CategoryTrend[]> {
  const now = new Date();
  const thisMonth = now.getMonth() + 1;
  const thisYear = now.getFullYear();
  const lastMonth = thisMonth === 1 ? 12 : thisMonth - 1;
  const lastYear = thisMonth === 1 ? thisYear - 1 : thisYear;

  const thisMonthSummary = await getMonthlySummary(supabase, userId, thisYear, thisMonth);
  const lastMonthSummary = await getMonthlySummary(supabase, userId, lastYear, lastMonth);

  const lastMonthMap = new Map<string, number>();
  for (const cat of lastMonthSummary.topExpenseCategories) {
    lastMonthMap.set(cat.name, cat.total);
  }

  return thisMonthSummary.topExpenseCategories.map((cat) => {
    const lastMonthTotal = lastMonthMap.get(cat.name) || 0;
    const change = lastMonthTotal > 0
      ? Math.round(((cat.total - lastMonthTotal) / lastMonthTotal) * 100)
      : 0;

    return {
      name: cat.name,
      thisMonth: cat.total,
      lastMonth: lastMonthTotal,
      change,
      isIncreasing: change > 10,
    };
  });
}

/**
 * Generate saving tips based on spending patterns
 */
export async function getSavingTips(
  supabase: SupabaseClient,
  userId: string,
): Promise<SavingTip[]> {
  const trends = await getTopCategoriesWithTrend(supabase, userId);
  const tips: SavingTip[] = [];

  for (const trend of trends) {
    if (trend.isIncreasing && trend.thisMonth > 100000) {
      const potentialSaving = Math.round(trend.thisMonth * 0.2); // 20% reduction target
      tips.push({
        category: trend.name,
        suggestion: `${trend.name} naik ${trend.change}% dari bulan lalu. Coba kurangi 20%.`,
        potentialSaving,
      });
    }
  }

  // Add general tip if no specific trends
  if (tips.length === 0 && trends.length > 0) {
    const topCategory = trends[0];
    tips.push({
      category: topCategory.name,
      suggestion:
        `${topCategory.name} adalah pengeluaran terbesar. Pertimbangkan untuk membuat budget.`,
      potentialSaving: Math.round(topCategory.thisMonth * 0.1),
    });
  }

  return tips.slice(0, 3);
}

/**
 * Format spending trend message
 */
export function formatSpendingTrendMessage(trend: SpendingTrend): string {
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

/**
 * Format saving tips message
 */
export function formatSavingTipsMessage(tips: SavingTip[]): string {
  if (tips.length === 0) {
    return `💡 <b>Tips Hemat</b>\n\nBelum cukup data untuk memberikan rekomendasi. Terus catat transaksimu!`;
  }

  let message = `💡 <b>Tips Hemat</b>\n\n`;

  for (let i = 0; i < tips.length; i++) {
    const tip = tips[i];
    message += `${i + 1}. <b>${tip.category}</b>\n`;
    message += `   ${tip.suggestion}\n`;
    message += `   💰 Potensi hemat: ${formatCurrency(tip.potentialSaving)}/bulan\n\n`;
  }

  return message;
}

/**
 * Format top categories message
 */
export function formatTopCategoriesMessage(categories: CategoryTrend[]): string {
  if (categories.length === 0) {
    return `📊 <b>Top Kategori</b>\n\nBelum ada data pengeluaran bulan ini.`;
  }

  let message = `📊 <b>Top Pengeluaran Bulan Ini</b>\n\n`;

  for (let i = 0; i < Math.min(5, categories.length); i++) {
    const cat = categories[i];
    const trendIcon = cat.isIncreasing ? '📈' : cat.change < -10 ? '📉' : '➡️';
    const changeText = cat.change !== 0 ? ` (${cat.change > 0 ? '+' : ''}${cat.change}%)` : '';

    message += `${i + 1}. ${cat.name}: ${
      formatCurrency(cat.thisMonth)
    }${changeText} ${trendIcon}\n`;
  }

  return message;
}
