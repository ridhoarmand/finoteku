/**
 * Categories Data Access Layer
 * Query Supabase untuk kategori
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface CategoryRecord {
  id: string;
  name: string;
  type: 'income' | 'expense';
  parent_name: string | null;
}

/**
 * Ambil semua kategori user
 */
export async function getAll(
  supabase: SupabaseClient,
  userId: string,
): Promise<{ data: CategoryRecord[] | null; error: Error | null }> {
  const { data, error } = await supabase
    .from('categories')
    .select(
      `
      id, name, type,
      parent:parent_id(name)
    `,
    )
    .eq('user_id', userId)
    .eq('is_hidden', false);

  if (error) return { data: null, error };

  // deno-lint-ignore no-explicit-any
  const mapped = (data || []).map((c: any) => ({
    id: c.id,
    name: c.name,
    type: c.type,
    parent_name: c.parent?.name || null,
  }));

  return { data: mapped, error: null };
}

/**
 * Ambil kategori berdasarkan tipe (income/expense)
 */
export async function getByType(
  supabase: SupabaseClient,
  userId: string,
  type: 'income' | 'expense',
): Promise<CategoryRecord[]> {
  const { data } = await getAll(supabase, userId);
  return (data || []).filter((c) => c.type === type);
}

/**
 * Cari kategori berdasarkan nama (fuzzy match)
 */
export async function findByName(
  supabase: SupabaseClient,
  userId: string,
  name: string,
  type: 'income' | 'expense',
): Promise<CategoryRecord | null> {
  const categories = await getByType(supabase, userId, type);
  const lowerName = name.toLowerCase();

  // Exact match
  const exact = categories.find((c) => c.name.toLowerCase() === lowerName);
  if (exact) return exact;

  // Contains match
  const contains = categories.find((c) =>
    c.name.toLowerCase().includes(lowerName) || lowerName.includes(c.name.toLowerCase())
  );

  return contains || null;
}
