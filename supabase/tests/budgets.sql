-- Checks get_budget_progress and budgets RLS.
-- Run against a dev/local DB as postgres: psql -v ON_ERROR_STOP=1 -f budgets.sql
-- Everything is rolled back.
BEGIN;

INSERT INTO auth.users (id, email) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'budget-a@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'budget-b@example.com')
  ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, email) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'budget-a@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'budget-b@example.com')
  ON CONFLICT DO NOTHING;

INSERT INTO public.wallets (id, user_id, name, balance, currency) VALUES
  ('b1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'A', 0, 'IDR'),
  ('b1000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'B', 0, 'IDR');
INSERT INTO public.categories (id, user_id, name, type, parent_id) VALUES
  ('bc000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'Makan', 'expense', NULL),
  ('bc000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 'Kopi', 'expense', 'bc000000-0000-0000-0000-000000000001'),
  ('bc000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 'Belanja', 'expense', NULL),
  ('bc000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000001', 'Gaji', 'income', NULL),
  ('bc000000-0000-0000-0000-000000000005', 'bbbbbbbb-0000-0000-0000-000000000002', 'Makan B', 'expense', NULL);

INSERT INTO public.transactions (user_id, wallet_id, category_id, amount, date) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000001', 100, '2026-11-01'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000002', 30, '2026-11-30'),  -- subcategory
  ('bbbbbbbb-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000001', 999, '2026-10-31'), -- other month
  ('bbbbbbbb-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000001', 999, '2026-12-01'), -- other month
  ('bbbbbbbb-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000003', 50, '2026-11-15'),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000004', 5000, '2026-11-15'), -- income
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'bc000000-0000-0000-0000-000000000005', 777, '2026-11-15'); -- user B

-- act as user A through RLS
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000001';

INSERT INTO public.budgets (user_id, category_id, amount) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'bc000000-0000-0000-0000-000000000001', 120),
  ('bbbbbbbb-0000-0000-0000-000000000001', NULL, 1000);

DO $$
DECLARE r record;
BEGIN
  SELECT spent INTO r FROM public.get_budget_progress('2026-11-10') WHERE category_id = 'bc000000-0000-0000-0000-000000000001';
  IF r.spent <> 130 THEN RAISE EXCEPTION 'Makan spent % expected 130 (own + subcategory, this month only)', r.spent; END IF;
  SELECT spent INTO r FROM public.get_budget_progress('2026-11-10') WHERE category_id IS NULL;
  IF r.spent <> 180 THEN RAISE EXCEPTION 'overall spent % expected 180 (expenses only, own user only)', r.spent; END IF;
  IF (SELECT count(*) FROM public.get_budget_progress('2026-11-10') WHERE budget_id IS NOT NULL) <> 2 THEN RAISE EXCEPTION 'expected 2 budgets'; END IF;
  -- Belanja has spending but no budget: listed with NULL budget and amount
  SELECT * INTO r FROM public.get_budget_progress('2026-11-10') WHERE budget_id IS NULL;
  IF r.category_id <> 'bc000000-0000-0000-0000-000000000003' OR r.spent <> 50 OR r.amount IS NOT NULL THEN
    RAISE EXCEPTION 'unbudgeted row wrong: %', r;
  END IF;
  IF (SELECT count(*) FROM public.get_budget_progress('2026-11-10')) <> 3 THEN RAISE EXCEPTION 'expected 3 rows'; END IF;
  RAISE NOTICE 'ok: progress';

  -- a second overall budget violates the NULLS NOT DISTINCT key
  BEGIN
    INSERT INTO public.budgets (user_id, category_id, amount) VALUES ('bbbbbbbb-0000-0000-0000-000000000001', NULL, 5);
    RAISE EXCEPTION 'duplicate overall budget was accepted';
  EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: one overall budget';
  END;

  -- RLS: cannot create a budget for another user
  BEGIN
    INSERT INTO public.budgets (user_id, category_id, amount) VALUES ('bbbbbbbb-0000-0000-0000-000000000002', NULL, 5);
    RAISE EXCEPTION 'budget for another user was accepted';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok: rls insert';
  END;
END $$;

-- user B sees none of A's budgets
SET LOCAL request.jwt.claim.sub = 'bbbbbbbb-0000-0000-0000-000000000002';
DO $$
BEGIN
  IF (SELECT count(*) FROM public.get_budget_progress('2026-11-10') WHERE budget_id IS NOT NULL) <> 0 THEN RAISE EXCEPTION 'user B sees A''s budgets'; END IF;
  -- B only sees its own spending (777), none of A's
  IF (SELECT string_agg(spent::text, ',') FROM public.get_budget_progress('2026-11-10')) <> '777.00' THEN RAISE EXCEPTION 'user B sees other spending'; END IF;
  IF (SELECT count(*) FROM public.budgets) <> 0 THEN RAISE EXCEPTION 'user B reads A''s budgets'; END IF;
  RAISE NOTICE 'ok: rls read';
END $$;

ROLLBACK;
