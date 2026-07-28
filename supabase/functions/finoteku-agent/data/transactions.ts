/**
 * Transactions Data Access Layer
 * Query Supabase untuk transaksi
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface TransactionRecord {
  id: string;
  user_id: string;
  amount: number;
  date: string;
  notes: string | null;
  category_id: string;
  wallet_id: string;
  category_name?: string;
  category_type?: 'income' | 'expense';
  wallet_name?: string;
}

export interface TransactionInput {
  amount: number;
  date: string;
  notes: string;
  category_id: string;
  wallet_id: string;
}

export interface TransferInput {
  amount: number;
  date: string;
  notes: string;
  from_wallet_id: string;
  to_wallet_id: string;
  expense_category_id: string | null;
  income_category_id: string | null;
}

/**
 * Ambil transaksi berdasarkan rentang tanggal
 */
export async function getByDateRange(
  supabase: SupabaseClient,
  userId: string,
  startDate: string,
  endDate: string,
): Promise<{ data: TransactionRecord[] | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('transactions')
    .select(
      `
      id, amount, date, notes, category_id, wallet_id,
      categories!inner(name, type),
      wallets!inner(name)
    `,
    )
    .eq('user_id', userId)
    .gte('date', startDate)
    .lte('date', endDate)
    .order('date', { ascending: false });

  if (error) return { data: null, error };

  // deno-lint-ignore no-explicit-any
  const mapped = (data || []).map((t: any) => ({
    id: t.id,
    user_id: userId,
    amount: t.amount,
    date: t.date,
    notes: t.notes,
    category_id: t.category_id,
    wallet_id: t.wallet_id,
    category_name: t.categories?.name,
    category_type: t.categories?.type,
    wallet_name: t.wallets?.name,
  }));

  return { data: mapped, error: null };
}

/**
 * Ambil transaksi terbaru dari ledger_entries view
 */
export async function getRecent(
  supabase: SupabaseClient,
  userId: string,
  limit: number = 5,
): Promise<{ data: TransactionRecord[] | null; error: Error | null }> {
  const { data, error } = await supabase.from('ledger_entries').select('*').eq('user_id', userId)
    .order('date', { ascending: false }).limit(limit);

  return { data, error };
}

export interface RecentLearningExample {
  notes: string | null;
  amount: number;
  category_name: string | null;
  parent_category_name?: string | null;
  wallet_name: string | null;
  type: string | null;
}

/**
 * Ambil riwayat transaksi nyata terbaru user untuk dijadikan konteks self-learning AI
 */
export async function getRecentLearningContext(
  supabase: SupabaseClient,
  userId: string,
  limit: number = 5,
): Promise<RecentLearningExample[]> {
  try {
    const { data, error } = await supabase
      .from('ledger_entries')
      .select('notes, amount, category_name, parent_category_name, wallet_name, type')
      .eq('user_id', userId)
      .order('date', { ascending: false })
      .limit(limit);

    if (error || !data) return [];
    return data as RecentLearningExample[];
  } catch (_e) {
    return [];
  }
}

/**
 * Buat transaksi baru
 */
export async function create(
  supabase: SupabaseClient,
  userId: string,
  transaction: TransactionInput,
): Promise<{ data: TransactionRecord | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('transactions')
    .insert({
      user_id: userId,
      ...transaction,
    })
    .select()
    .single();

  return { data, error };
}

/**
 * Hitung total pengeluaran bulan tertentu
 */
export async function getMonthlyExpense(
  supabase: SupabaseClient,
  userId: string,
  year: number,
  month: number,
): Promise<number> {
  const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
  const endDate = `${year}-${String(month).padStart(2, '0')}-31`;

  const { data } = await supabase.from('transactions').select('amount, categories!inner(type)').eq(
    'user_id',
    userId,
  ).gte('date', startDate).lte('date', endDate);

  // deno-lint-ignore no-explicit-any
  return (data || []).filter((t: any) => (t.categories as any)?.type === 'expense').reduce(
    // deno-lint-ignore no-explicit-any
    (sum: number, t: any) => sum + Math.abs(Number(t.amount)),
    0,
  );
}

/**
 * Ambil contoh notes untuk AI learning (few-shot)
 * Mengembalikan notes unik dengan kategorinya
 */
export async function getNotesExamples(
  supabase: SupabaseClient,
  userId: string,
  limit: number = 10,
): Promise<{ notes: string; categoryName: string }[]> {
  const { data } = await supabase.from('transactions').select('notes, categories!inner(name)').eq(
    'user_id',
    userId,
  ).not('notes', 'is', null).order('created_at', { ascending: false }).limit(50);

  if (!data) return [];

  // Deduplikasi notes
  const seen = new Set<string>();
  const examples: { notes: string; categoryName: string }[] = [];

  for (const t of data) {
    // deno-lint-ignore no-explicit-any
    const notes = (t as any).notes?.trim();
    // deno-lint-ignore no-explicit-any
    const categoryName = (t as any).categories?.name;

    if (notes && categoryName && !seen.has(notes.toLowerCase())) {
      seen.add(notes.toLowerCase());
      examples.push({ notes, categoryName });
      if (examples.length >= limit) break;
    }
  }

  return examples;
}

/**
 * Buat transfer antar wallet menggunakan RPC
 */
export async function createTransfer(
  supabase: SupabaseClient,
  userId: string,
  transfer: TransferInput,
): Promise<{ data: string | null; error: Error | null }> {
  const { data, error } = await supabase.rpc('create_wallet_transfer', {
    p_user_id: userId,
    p_from_wallet_id: transfer.from_wallet_id,
    p_to_wallet_id: transfer.to_wallet_id,
    p_amount: transfer.amount,
    p_expense_category_id: transfer.expense_category_id,
    p_income_category_id: transfer.income_category_id,
    p_notes: transfer.notes,
    p_date: transfer.date,
  });

  return { data: data as string | null, error };
}
