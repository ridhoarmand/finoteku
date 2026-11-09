-- Monthly budgets per expense category (category_id NULL = overall monthly limit).
-- A budget applies to every month until changed. Idempotent.
CREATE TABLE IF NOT EXISTS public.budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  category_id uuid REFERENCES public.categories (id) ON DELETE CASCADE,
  amount numeric(15,2) NOT NULL CHECK (amount > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- one budget per category, and one overall budget (NULL counts as a value here)
CREATE UNIQUE INDEX IF NOT EXISTS budgets_user_category_key
  ON public.budgets (user_id, category_id) NULLS NOT DISTINCT;

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'budgets' AND policyname = 'Users can read own budgets') THEN
    CREATE POLICY "Users can read own budgets" ON public.budgets FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'budgets' AND policyname = 'Users can create own budgets') THEN
    CREATE POLICY "Users can create own budgets" ON public.budgets FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'budgets' AND policyname = 'Users can update own budgets') THEN
    CREATE POLICY "Users can update own budgets" ON public.budgets FOR UPDATE
      USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'budgets' AND policyname = 'Users can delete own budgets') THEN
    CREATE POLICY "Users can delete own budgets" ON public.budgets FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.budgets TO authenticated;

-- Spending of p_month per budget, plus root expense categories that have spending
-- but no budget (budget_id and amount NULL), so the app can offer to set one.
-- SECURITY INVOKER: RLS on budgets, transactions and categories limits it to the
-- caller, so no user id parameter. A category budget counts its subcategories too;
-- the overall budget (category_id NULL) counts all expenses.
CREATE OR REPLACE FUNCTION public.get_budget_progress(p_month date)
RETURNS TABLE (budget_id uuid, category_id uuid, amount numeric, spent numeric)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$
  WITH month_tx AS (
    SELECT t.amount, COALESCE(c.parent_id, c.id) AS root_id
    FROM transactions t
    JOIN categories c ON c.id = t.category_id
    WHERE t.user_id = auth.uid()
      AND c.type = 'expense'
      AND t.date >= date_trunc('month', p_month)::date
      AND t.date < (date_trunc('month', p_month) + interval '1 month')::date
  ),
  by_root AS (SELECT root_id, sum(amount) AS spent FROM month_tx GROUP BY root_id),
  own AS (SELECT * FROM budgets WHERE user_id = auth.uid())
  SELECT b.id, b.category_id, b.amount,
         CASE WHEN b.category_id IS NULL THEN (SELECT COALESCE(sum(amount), 0) FROM month_tx)
              ELSE COALESCE(r.spent, 0) END
  FROM own b LEFT JOIN by_root r ON r.root_id = b.category_id
  UNION ALL
  SELECT NULL, r.root_id, NULL, r.spent
  FROM by_root r
  WHERE NOT EXISTS (SELECT 1 FROM own b WHERE b.category_id = r.root_id)
  ORDER BY 4 DESC;
$$;
REVOKE ALL ON FUNCTION public.get_budget_progress(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_budget_progress(date) TO authenticated;
