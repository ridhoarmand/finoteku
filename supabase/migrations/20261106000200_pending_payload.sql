-- Agent v2: a pending confirmation can hold several transactions (and the
-- choices offered as numbered buttons). `payload` is the source of truth; the
-- old single-transaction columns stay for compatibility and become optional.
ALTER TABLE public.pending_bot_transactions
  ADD COLUMN IF NOT EXISTS payload jsonb;

ALTER TABLE public.pending_bot_transactions
  ALTER COLUMN wallet_id DROP NOT NULL,
  ALTER COLUMN amount DROP NOT NULL,
  ALTER COLUMN date DROP NOT NULL;
