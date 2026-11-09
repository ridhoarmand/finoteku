-- Checks that the wallet balance triggers agree with recalculate_wallet_balance.
-- Run against a dev/local DB as postgres: psql -v ON_ERROR_STOP=1 -f balance_triggers.sql
-- Everything is rolled back.
BEGIN;
SET LOCAL request.jwt.claim.role = 'service_role';

INSERT INTO auth.users (id, email) VALUES ('dddddddd-0000-0000-0000-000000000000', 'balance-test@example.com')
  ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, email) VALUES ('dddddddd-0000-0000-0000-000000000000', 'balance-test@example.com')
  ON CONFLICT DO NOTHING;
DELETE FROM public.wallets WHERE user_id = 'dddddddd-0000-0000-0000-000000000000';

INSERT INTO public.wallets (id, user_id, name, balance, currency) VALUES
  ('d1000000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000', 'W1', 0, 'IDR'),
  ('d2000000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000', 'W2', 0, 'IDR');
INSERT INTO public.categories (id, user_id, name, type) VALUES
  ('dc100000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000', 'Gaji', 'income'),
  ('dc200000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000', 'Makan', 'expense');

CREATE TEMP TABLE expect (step text, wallet uuid, balance numeric) ON COMMIT DROP;

CREATE FUNCTION pg_temp.check(p_step text, w1 numeric, w2 numeric) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  b1 numeric; b2 numeric;
BEGIN
  SELECT balance INTO b1 FROM public.wallets WHERE id = 'd1000000-0000-0000-0000-000000000000';
  SELECT balance INTO b2 FROM public.wallets WHERE id = 'd2000000-0000-0000-0000-000000000000';
  IF b1 <> w1 OR b2 <> w2 THEN
    RAISE EXCEPTION '% : trigger balances (%, %) expected (%, %)', p_step, b1, b2, w1, w2;
  END IF;
  -- recalculation from scratch must agree with what the triggers maintained
  IF public.recalculate_wallet_balance('d1000000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000') <> w1
     OR public.recalculate_wallet_balance('d2000000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000') <> w2 THEN
    RAISE EXCEPTION '% : recalculated balance differs from trigger balance', p_step;
  END IF;
  RAISE NOTICE 'ok: %', p_step;
END;
$$;

INSERT INTO public.transactions (id, user_id, wallet_id, category_id, amount, date) VALUES
  ('d7100000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'dc100000-0000-0000-0000-000000000000', 1000, CURRENT_DATE);
SELECT pg_temp.check('insert income', 1000, 0);

INSERT INTO public.transactions (id, user_id, wallet_id, category_id, amount, date) VALUES
  ('d7200000-0000-0000-0000-000000000000', 'dddddddd-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'dc200000-0000-0000-0000-000000000000', 300, CURRENT_DATE);
SELECT pg_temp.check('insert expense', 700, 0);

UPDATE public.transactions SET amount = 400 WHERE id = 'd7200000-0000-0000-0000-000000000000';
SELECT pg_temp.check('update expense amount', 600, 0);

UPDATE public.transactions SET wallet_id = 'd2000000-0000-0000-0000-000000000000' WHERE id = 'd7200000-0000-0000-0000-000000000000';
SELECT pg_temp.check('move expense to other wallet', 1000, -400);

UPDATE public.transactions SET category_id = 'dc100000-0000-0000-0000-000000000000' WHERE id = 'd7200000-0000-0000-0000-000000000000';
SELECT pg_temp.check('expense becomes income', 1000, 400);

DELETE FROM public.transactions WHERE id = 'd7200000-0000-0000-0000-000000000000';
SELECT pg_temp.check('delete transaction', 1000, 0);

SELECT public.create_wallet_transfer('dddddddd-0000-0000-0000-000000000000', 'd1000000-0000-0000-0000-000000000000', 'd2000000-0000-0000-0000-000000000000', 250) AS tr \gset
SELECT pg_temp.check('create transfer', 750, 250);

SELECT public.update_wallet_transfer('dddddddd-0000-0000-0000-000000000000', :'tr', p_amount => 100);
SELECT pg_temp.check('update transfer amount', 900, 100);

SELECT public.update_wallet_transfer('dddddddd-0000-0000-0000-000000000000', :'tr', p_from_wallet_id => 'd2000000-0000-0000-0000-000000000000', p_to_wallet_id => 'd1000000-0000-0000-0000-000000000000');
SELECT pg_temp.check('swap transfer direction', 1100, -100);

SELECT public.delete_wallet_transfer('dddddddd-0000-0000-0000-000000000000', :'tr');
SELECT pg_temp.check('delete transfer', 1000, 0);

ROLLBACK;
