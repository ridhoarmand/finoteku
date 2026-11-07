-- Security fix: SECURITY DEFINER functions trusted p_user_id from the caller and were
-- executable by anon. Run once on the project (SQL editor or `supabase db push`).

BEGIN;

-- 1. Nobody calls functions without being granted explicitly.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon, public;

-- 2. Bot-only functions: service_role only (edge functions use the service key).
REVOKE EXECUTE ON FUNCTION public.get_user_parser_settings(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.link_by_user_id(uuid, text, text, jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_user_by_platform_id(text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cleanup_user_storage_files(uuid) FROM authenticated;

-- 3. Transfer RPCs are used by the app (authenticated) and the agent (service_role):
--    the app may only act as itself.
CREATE OR REPLACE FUNCTION public.assert_acting_user(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' AND p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.assert_acting_user(uuid) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.assert_acting_user(uuid) TO authenticated, service_role;

DO $$
DECLARE
  fn text;
BEGIN
  -- Prepend the check to each transfer RPC without retyping its body.
  FOREACH fn IN ARRAY ARRAY[
    'public.create_wallet_transfer(uuid, uuid, uuid, numeric, uuid, uuid, text, date)',
    'public.update_wallet_transfer(uuid, uuid, uuid, uuid, numeric, text, date)',
    'public.delete_wallet_transfer(uuid, uuid)'
  ] LOOP
    IF pg_get_functiondef(fn::regprocedure) NOT LIKE '%assert_acting_user%' THEN
      EXECUTE regexp_replace(
        pg_get_functiondef(fn::regprocedure),
        '\nBEGIN\s*\n',
        E'\nBEGIN\n  PERFORM public.assert_acting_user(p_user_id);\n'
      );
    END IF;
    IF pg_get_functiondef(fn::regprocedure) NOT LIKE '%assert_acting_user%' THEN
      RAISE EXCEPTION 'Failed to patch %', fn;
    END IF;
  END LOOP;
END;
$$;

-- recalculate_wallet_balance is SECURITY INVOKER (RLS applies) but takes p_user_id; same check.
CREATE OR REPLACE FUNCTION public.recalculate_wallet_balance(p_wallet_id uuid, p_user_id uuid) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE calculated_balance DECIMAL(15, 2);
DECLARE tx_balance DECIMAL(15, 2);
DECLARE transfer_in DECIMAL(15, 2);
DECLARE transfer_out DECIMAL(15, 2);
BEGIN
  PERFORM public.assert_acting_user(p_user_id);
  SELECT COALESCE(SUM(t.amount * CASE c.type WHEN 'expense' THEN -1 ELSE 1 END), 0)
    INTO tx_balance
  FROM public.transactions t
  JOIN public.categories c ON c.id = t.category_id
  WHERE t.wallet_id = p_wallet_id AND t.user_id = p_user_id;
  SELECT COALESCE(SUM(amount), 0) INTO transfer_in FROM public.transfers WHERE to_wallet_id = p_wallet_id AND user_id = p_user_id;
  SELECT COALESCE(SUM(amount), 0) INTO transfer_out FROM public.transfers WHERE from_wallet_id = p_wallet_id AND user_id = p_user_id;
  calculated_balance := tx_balance + transfer_in - transfer_out;
  UPDATE public.wallets SET balance = calculated_balance, updated_at = NOW()
  WHERE id = p_wallet_id AND user_id = p_user_id;
  RETURN calculated_balance;
END;
$$;

-- 4. Functions the logged-in app calls (they use auth.uid() internally).
GRANT EXECUTE ON FUNCTION
  public.create_wallet_transfer(uuid, uuid, uuid, numeric, uuid, uuid, text, date),
  public.update_wallet_transfer(uuid, uuid, uuid, uuid, numeric, text, date),
  public.delete_wallet_transfer(uuid, uuid),
  public.recalculate_wallet_balance(uuid, uuid),
  public.get_bot_link(text),
  public.unlink_platform(text),
  public.update_bot_link_metadata(text, jsonb),
  public.update_parser_settings(text, text, text),
  public.get_user_data_summary(),
  public.delete_user_account_complete()
TO authenticated;

-- 5. Bot linking with a one-time token instead of the user's UUID.
CREATE TABLE IF NOT EXISTS public.bot_link_tokens (
  token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform text NOT NULL,
  expires_at timestamptz NOT NULL DEFAULT now() + interval '15 minutes'
);
ALTER TABLE public.bot_link_tokens ENABLE ROW LEVEL SECURITY; -- no policies: only definer functions touch it

CREATE OR REPLACE FUNCTION public.create_bot_link_token(p_platform text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_token text := encode(extensions.gen_random_bytes(16), 'hex');
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  DELETE FROM public.bot_link_tokens WHERE user_id = v_user_id OR expires_at < now();
  INSERT INTO public.bot_link_tokens (token, user_id, platform) VALUES (v_token, v_user_id, p_platform);
  RETURN v_token;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.create_bot_link_token(text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.create_bot_link_token(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.link_with_token(
  p_token text, p_platform text, p_platform_user_id text, p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  DELETE FROM public.bot_link_tokens
  WHERE token = p_token AND platform = p_platform AND expires_at >= now()
  RETURNING user_id INTO v_user_id;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Link token invalid or expired';
  END IF;
  PERFORM public.link_by_user_id(v_user_id, p_platform, p_platform_user_id, p_metadata);
  RETURN v_user_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.link_with_token(text, text, text, jsonb) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.link_with_token(text, text, text, jsonb) TO service_role;

-- 6. Never expose the raw AI key to the client: the app only needs to know one is saved.
CREATE OR REPLACE FUNCTION public.has_ai_api_key() RETURNS boolean
    LANGUAGE sql SECURITY DEFINER STABLE
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(length(ai_api_key) > 0, false) FROM public.users WHERE id = auth.uid();
$$;
REVOKE EXECUTE ON FUNCTION public.has_ai_api_key() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.has_ai_api_key() TO authenticated;
-- Column privileges only bite once the table-wide SELECT is gone.
REVOKE SELECT ON public.users FROM anon, authenticated;
GRANT SELECT (id, email, full_name, currency, timezone, parser_mode, ai_provider, created_at, updated_at)
  ON public.users TO authenticated;

-- 7. Future functions are not callable by anon by default.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon, public;

-- 8. Old balance trigger function, superseded by handle_transfer_amount_only; no trigger uses it.
DROP FUNCTION IF EXISTS public.handle_transfer();

COMMIT;
