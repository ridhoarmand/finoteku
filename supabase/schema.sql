

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."category_type" AS ENUM (
    'income',
    'expense'
);


ALTER TYPE "public"."category_type" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cleanup_user_storage_files"("p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Delete avatar files from storage.objects if they exist
  -- The storage bucket is typically 'avatars'
  DELETE FROM storage.objects
  WHERE bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = p_user_id::text;
  
  RAISE NOTICE 'Cleaned up storage files for user: %', p_user_id;
EXCEPTION
  WHEN OTHERS THEN
    -- Log but don't fail if storage cleanup fails
    RAISE WARNING 'Failed to cleanup storage for user %: %', p_user_id, SQLERRM;
END;
$$;


ALTER FUNCTION "public"."cleanup_user_storage_files"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_wallet_transfer"("p_user_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_expense_category_id" "uuid" DEFAULT NULL::"uuid", "p_income_category_id" "uuid" DEFAULT NULL::"uuid", "p_notes" "text" DEFAULT NULL::"text", "p_date" "date" DEFAULT CURRENT_DATE) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_transfer_id UUID;
  v_from_owner UUID;
  v_to_owner UUID;
  v_expense_type category_type;
  v_income_type category_type;
  v_from_balance DECIMAL(15, 2);
BEGIN
  -- Validasi dasar
  IF p_from_wallet_id = p_to_wallet_id THEN
    RAISE EXCEPTION 'Source and destination wallet must be different';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  -- Cek kepemilikan wallet
  SELECT user_id INTO v_from_owner FROM public.wallets WHERE id = p_from_wallet_id;
  SELECT user_id INTO v_to_owner FROM public.wallets WHERE id = p_to_wallet_id;
  IF v_from_owner IS NULL OR v_to_owner IS NULL THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;
  IF v_from_owner != p_user_id OR v_to_owner != p_user_id THEN
    RAISE EXCEPTION 'Permission denied: wallets do not belong to user';
  END IF;

  -- Validasi tipe kategori (opsional untuk kompatibilitas caller)
  IF p_expense_category_id IS NOT NULL THEN
    SELECT type INTO v_expense_type FROM public.categories WHERE id = p_expense_category_id AND user_id = p_user_id;
    IF v_expense_type IS DISTINCT FROM 'expense' THEN
      RAISE EXCEPTION 'Expense category invalid for transfer';
    END IF;
  END IF;
  IF p_income_category_id IS NOT NULL THEN
    SELECT type INTO v_income_type FROM public.categories WHERE id = p_income_category_id AND user_id = p_user_id;
    IF v_income_type IS DISTINCT FROM 'income' THEN
      RAISE EXCEPTION 'Income category invalid for transfer';
    END IF;
  END IF;
  -- Cek saldo cukup: sumber harus >= amount
  SELECT balance INTO v_from_balance FROM public.wallets WHERE id = p_from_wallet_id AND user_id = p_user_id;
  IF v_from_balance IS NULL THEN
    RAISE EXCEPTION 'Source wallet not found';
  END IF;
  IF v_from_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient funds in source wallet';
  END IF;

  -- Buat record transfer
  INSERT INTO public.transfers (
    user_id, from_wallet_id, to_wallet_id, amount, notes, date
  ) VALUES (
    p_user_id, p_from_wallet_id, p_to_wallet_id, p_amount, p_notes, p_date
  ) RETURNING id INTO v_transfer_id;

  -- Transaksi expense di wallet sumber (opsional, untuk alur agent)
  IF p_expense_category_id IS NOT NULL THEN
    INSERT INTO public.transactions (
      user_id, wallet_id, category_id, amount, notes, date
    ) VALUES (
      p_user_id, p_from_wallet_id, p_expense_category_id, p_amount, COALESCE(p_notes, 'Transfer Out') || ' [transfer:' || v_transfer_id || ']', p_date
    );
  END IF;

  -- Transaksi income di wallet tujuan (opsional, untuk alur agent)
  IF p_income_category_id IS NOT NULL THEN
    INSERT INTO public.transactions (
      user_id, wallet_id, category_id, amount, notes, date
    ) VALUES (
      p_user_id, p_to_wallet_id, p_income_category_id, p_amount, COALESCE(p_notes, 'Transfer In') || ' [transfer:' || v_transfer_id || ']', p_date
    );
  END IF;

  RETURN v_transfer_id;
END;
$$;


ALTER FUNCTION "public"."create_wallet_transfer"("p_user_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_expense_category_id" "uuid", "p_income_category_id" "uuid", "p_notes" "text", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_account"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_delete_count INT;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Log the deletion attempt
  RAISE NOTICE 'Starting account deletion for user: %', v_user_id;

  -- 1. Delete all transactions
  DELETE FROM public.transactions WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_delete_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % transactions', v_delete_count;

  -- 2. Delete all transfers
  DELETE FROM public.transfers WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_delete_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % transfers', v_delete_count;

  -- 3. Delete all categories
  DELETE FROM public.categories WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_delete_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % categories', v_delete_count;

  -- 4. Delete all wallets
  DELETE FROM public.wallets WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_delete_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % wallets', v_delete_count;

  -- 5. Delete bot_links if table exists
  DELETE FROM public.bot_links WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_delete_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % bot links', v_delete_count;

  -- 6. Delete from public.users table
  DELETE FROM public.users WHERE id = v_user_id;
  GET DIAGNOSTICS v_delete_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % user record', v_delete_count;

  -- 7. Delete user from auth.users table (requires SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = v_user_id;
  
  RAISE NOTICE 'Successfully deleted user account: %', v_user_id;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error deleting user account: %', SQLERRM;
END;
$$;


ALTER FUNCTION "public"."delete_user_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_user_account_complete"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;
  PERFORM public.cleanup_user_storage_files(current_user_id);
  PERFORM public.delete_user_account();
END;
$$;


ALTER FUNCTION "public"."delete_user_account_complete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_old RECORD;
BEGIN
  SELECT * INTO v_old FROM public.transfers WHERE id = p_transfer_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transfer not found';
  END IF;

  -- Remove fee transactions linked to this transfer via marker in notes
  DELETE FROM public.transactions
  WHERE user_id = p_user_id
    AND notes LIKE ('%' || '[transfer:' || p_transfer_id || ']');

  -- Delete the transfer row (trigger will handle balance adjustments)
  DELETE FROM public.transfers WHERE id = p_transfer_id AND user_id = p_user_id;

  -- No manual recalculation needed - the trigger handles balance updates correctly
END;
$$;


ALTER FUNCTION "public"."delete_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bot_link"("p_platform" "text") RETURNS TABLE("id" "uuid", "link_token" "text", "user_id" "uuid", "platform" "text", "platform_user_id" "text", "metadata" "jsonb", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT bl.id, bl.link_token, bl.user_id, bl.platform, bl.platform_user_id,
           bl.metadata, bl.is_active, bl.created_at, bl.updated_at
    FROM public.bot_links bl
    WHERE bl.user_id = auth.uid() AND bl.platform = p_platform
    LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_bot_link"("p_platform" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_by_platform_id"("p_platform" "text", "p_platform_user_id" "text") RETURNS TABLE("user_id" "uuid", "metadata" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT bl.user_id, bl.metadata
  FROM public.bot_links bl
  WHERE bl.platform = p_platform
    AND bl.platform_user_id = p_platform_user_id
    AND bl.is_active = TRUE
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_user_by_platform_id"("p_platform" "text", "p_platform_user_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_data_summary"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE 
  current_user_id UUID;
  wallets_count INTEGER;
  categories_count INTEGER;
  transactions_count INTEGER;
  transfers_count INTEGER;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Count wallets (tidak termasuk yang hidden)
  SELECT COUNT(*) INTO wallets_count
  FROM public.wallets 
  WHERE user_id = current_user_id AND is_hidden = false;

  -- Count categories (tidak termasuk yang hidden)
  SELECT COUNT(*) INTO categories_count
  FROM public.categories 
  WHERE user_id = current_user_id AND is_hidden = false;

  -- Count transactions
  SELECT COUNT(*) INTO transactions_count
  FROM public.transactions 
  WHERE user_id = current_user_id;

  -- Count transfers
  SELECT COUNT(*) INTO transfers_count
  FROM public.transfers 
  WHERE user_id = current_user_id;

  -- Return as JSON
  RETURN json_build_object(
    'walletsCount', wallets_count,
    'categoriesCount', categories_count,
    'transactionsCount', transactions_count,
    'transfersCount', transfers_count
  );
END;
$$;


ALTER FUNCTION "public"."get_user_data_summary"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_parser_settings"("p_user_id" "uuid") RETURNS TABLE("parser_mode" "text", "ai_provider" "text", "ai_api_key" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT u.parser_mode, u.ai_provider, u.ai_api_key
    FROM public.users u
    WHERE u.id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_user_parser_settings"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_transfer"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.wallets
        SET balance = balance - NEW.amount
        WHERE id = NEW.from_wallet_id;

        UPDATE public.wallets
        SET balance = balance + NEW.amount
        WHERE id = NEW.to_wallet_id;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        UPDATE public.wallets
        SET balance = balance + OLD.amount
        WHERE id = OLD.from_wallet_id;

        UPDATE public.wallets
        SET balance = balance - OLD.amount
        WHERE id = OLD.to_wallet_id;

        UPDATE public.wallets
        SET balance = balance - NEW.amount
        WHERE id = NEW.from_wallet_id;

        UPDATE public.wallets
        SET balance = balance + NEW.amount
        WHERE id = NEW.to_wallet_id;

        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE public.wallets
        SET balance = balance + OLD.amount
        WHERE id = OLD.from_wallet_id;

        UPDATE public.wallets
        SET balance = balance - OLD.amount
        WHERE id = OLD.to_wallet_id;

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."handle_transfer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_transfer_amount_only"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.wallets SET balance = balance - NEW.amount WHERE id = NEW.from_wallet_id AND user_id = NEW.user_id;
    UPDATE public.wallets SET balance = balance + NEW.amount WHERE id = NEW.to_wallet_id AND user_id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Handle wallet changes properly
    -- Only revert from wallets that are actually changing
    IF OLD.from_wallet_id != NEW.from_wallet_id THEN
      UPDATE public.wallets SET balance = balance + OLD.amount WHERE id = OLD.from_wallet_id AND user_id = OLD.user_id;
      UPDATE public.wallets SET balance = balance - NEW.amount WHERE id = NEW.from_wallet_id AND user_id = NEW.user_id;
    ELSIF OLD.amount != NEW.amount THEN
      -- Same from wallet, but amount changed
      UPDATE public.wallets SET balance = balance + (OLD.amount - NEW.amount) WHERE id = OLD.from_wallet_id AND user_id = OLD.user_id;
    END IF;
    
    IF OLD.to_wallet_id != NEW.to_wallet_id THEN
      UPDATE public.wallets SET balance = balance - OLD.amount WHERE id = OLD.to_wallet_id AND user_id = OLD.user_id;
      UPDATE public.wallets SET balance = balance + NEW.amount WHERE id = NEW.to_wallet_id AND user_id = NEW.user_id;
    ELSIF OLD.amount != NEW.amount THEN
      -- Same to wallet, but amount changed
      UPDATE public.wallets SET balance = balance + (NEW.amount - OLD.amount) WHERE id = OLD.to_wallet_id AND user_id = OLD.user_id;
    END IF;
    
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.wallets SET balance = balance + OLD.amount WHERE id = OLD.from_wallet_id AND user_id = OLD.user_id;
    UPDATE public.wallets SET balance = balance - OLD.amount WHERE id = OLD.to_wallet_id AND user_id = OLD.user_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."handle_transfer_amount_only"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW(); -- Store strict UTC
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."link_by_user_id"("p_user_id" "uuid", "p_platform" "text", "p_platform_user_id" "text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    INSERT INTO public.bot_links (link_token, user_id, platform, platform_user_id, metadata, is_active, id)
    VALUES (
        encode(extensions.gen_random_bytes(16), 'hex'),
        p_user_id, 
        p_platform, 
        p_platform_user_id,
        p_metadata,
        TRUE,
        extensions.uuid_generate_v4()
    )
    ON CONFLICT (user_id, platform)
    DO UPDATE SET
        platform_user_id = p_platform_user_id,
        metadata = bot_links.metadata || p_metadata,
        is_active = TRUE,
        updated_at = NOW();
END;
$$;


ALTER FUNCTION "public"."link_by_user_id"("p_user_id" "uuid", "p_platform" "text", "p_platform_user_id" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_category_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE usage_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.transactions t
    WHERE t.category_id = OLD.id LIMIT 1
  ) INTO usage_exists;
  IF usage_exists THEN
    RAISE EXCEPTION 'Cannot delete category with existing transactions. Use hide instead.';
  END IF;
  RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."prevent_category_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_category_type_change"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE usage_exists BOOLEAN;
BEGIN
  IF OLD.type != NEW.type THEN
    SELECT EXISTS(
      SELECT 1 FROM public.transactions t WHERE t.category_id = OLD.id LIMIT 1
    ) INTO usage_exists;
    IF usage_exists THEN
      RAISE EXCEPTION 'Cannot change category type after it is used by transactions';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_category_type_change"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_wallet_balance"("p_wallet_id" "uuid", "p_user_id" "uuid") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE calculated_balance DECIMAL(15, 2);
DECLARE tx_balance DECIMAL(15, 2);
DECLARE transfer_in DECIMAL(15, 2);
DECLARE transfer_out DECIMAL(15, 2);
BEGIN
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


ALTER FUNCTION "public"."recalculate_wallet_balance"("p_wallet_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unlink_platform"("p_platform" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN 
        RAISE EXCEPTION 'Not authenticated'; 
    END IF;
    
    UPDATE public.bot_links
    SET 
        platform_user_id = NULL,
        is_active = FALSE,
        -- Keep metadata for potential reconnect, just mark inactive
        updated_at = NOW()
    WHERE user_id = v_user_id
      AND platform = p_platform;
      
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bot link not found for platform: %', p_platform;
    END IF;
END;
$$;


ALTER FUNCTION "public"."unlink_platform"("p_platform" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_bot_link_metadata"("p_platform" "text", "p_metadata" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    UPDATE public.bot_links
    SET 
        metadata = metadata || p_metadata,
        updated_at = NOW()
    WHERE user_id = v_user_id 
      AND platform = p_platform;
      
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bot link not found for platform: %', p_platform;
    END IF;
END;
$$;


ALTER FUNCTION "public"."update_bot_link_metadata"("p_platform" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_parser_settings"("p_parser_mode" "text", "p_ai_provider" "text", "p_ai_api_key" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    UPDATE public.users
    SET 
        parser_mode = p_parser_mode,
        ai_provider = p_ai_provider,
        ai_api_key = CASE 
            WHEN p_ai_api_key IS NOT NULL THEN p_ai_api_key 
            ELSE ai_api_key  -- Keep existing if not provided
        END,
        updated_at = NOW()
    WHERE id = v_user_id;
END;
$$;


ALTER FUNCTION "public"."update_parser_settings"("p_parser_mode" "text", "p_ai_provider" "text", "p_ai_api_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_wallet_balance"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  old_sign NUMERIC := 0;
  new_sign NUMERIC := 0;
  old_effect NUMERIC := 0;
  new_effect NUMERIC := 0;
  old_type category_type;
  new_type category_type;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT TYPE INTO new_type FROM public.categories WHERE id = NEW.category_id;
    new_sign := CASE WHEN new_type = 'expense' THEN -1 ELSE 1 END;
    UPDATE public.wallets SET balance = balance + (NEW.amount * new_sign)
      WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    SELECT TYPE INTO old_type FROM public.categories WHERE id = OLD.category_id;
    SELECT TYPE INTO new_type FROM public.categories WHERE id = NEW.category_id;
    old_sign := CASE WHEN old_type = 'expense' THEN -1 ELSE 1 END;
    new_sign := CASE WHEN new_type = 'expense' THEN -1 ELSE 1 END;
    old_effect := OLD.amount * old_sign;
    new_effect := NEW.amount * new_sign;
    IF OLD.wallet_id != NEW.wallet_id THEN
      UPDATE public.wallets SET balance = balance - old_effect WHERE id = OLD.wallet_id AND user_id = OLD.user_id;
      UPDATE public.wallets SET balance = balance + new_effect WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
    ELSE
      UPDATE public.wallets SET balance = balance - old_effect + new_effect WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT TYPE INTO old_type FROM public.categories WHERE id = OLD.category_id;
    old_sign := CASE WHEN old_type = 'expense' THEN -1 ELSE 1 END;
    UPDATE public.wallets SET balance = balance - (OLD.amount * old_sign)
      WHERE id = OLD.wallet_id AND user_id = OLD.user_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_wallet_balance"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid", "p_from_wallet_id" "uuid" DEFAULT NULL::"uuid", "p_to_wallet_id" "uuid" DEFAULT NULL::"uuid", "p_amount" numeric DEFAULT NULL::numeric, "p_notes" "text" DEFAULT NULL::"text", "p_date" "date" DEFAULT NULL::"date") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_old RECORD;
  v_new_from UUID;
  v_new_to UUID;
  v_new_amount DECIMAL(15, 2);
  v_new_notes TEXT;
  v_new_date DATE;
BEGIN
  SELECT * INTO v_old FROM public.transfers WHERE id = p_transfer_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transfer not found';
  END IF;

  v_new_from := COALESCE(p_from_wallet_id, v_old.from_wallet_id);
  v_new_to := COALESCE(p_to_wallet_id, v_old.to_wallet_id);
  v_new_amount := COALESCE(p_amount, v_old.amount);
  v_new_notes := COALESCE(p_notes, v_old.notes);
  v_new_date := COALESCE(p_date, v_old.date);

  IF v_new_from = v_new_to THEN
    RAISE EXCEPTION 'Source and destination wallet must be different';
  END IF;
  IF v_new_amount IS NULL OR v_new_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  -- Update transfer row (triggers will handle balance movements for amount/from/to changes)
  UPDATE public.transfers
    SET from_wallet_id = v_new_from,
        to_wallet_id = v_new_to,
        amount = v_new_amount,
        notes = v_new_notes,
        date = v_new_date,
        updated_at = TIMEZONE('utc' :: text, NOW())
  WHERE id = p_transfer_id AND user_id = p_user_id;

  -- The improved trigger handles balance updates correctly, no manual recalculation needed
  RETURN p_transfer_id;
END;
$$;


ALTER FUNCTION "public"."update_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_notes" "text", "p_date" "date") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."bot_links" (
    "link_token" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "platform" "text" NOT NULL,
    "platform_user_id" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "is_active" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"()
);


ALTER TABLE "public"."bot_links" OWNER TO "postgres";


COMMENT ON TABLE "public"."bot_links" IS 'Stores platform (Telegram, WhatsApp, etc) linking information for users.';



COMMENT ON COLUMN "public"."bot_links"."link_token" IS 'Legacy column, kept for primary key';



COMMENT ON COLUMN "public"."bot_links"."metadata" IS 'Platform-specific metadata: username, chat_id, ai_provider, ai_api_key, parser_mode, etc.';



COMMENT ON COLUMN "public"."bot_links"."id" IS 'UUID identifier for Flutter model compatibility';



CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "type" "public"."category_type" NOT NULL,
    "parent_id" "uuid",
    "icon_code_point" bigint,
    "is_hidden" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "wallet_id" "uuid" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "notes" "text",
    "date" "date" DEFAULT (("now"() AT TIME ZONE 'Asia/Jakarta'::"text"))::"date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "transactions_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transfers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "from_wallet_id" "uuid" NOT NULL,
    "to_wallet_id" "uuid" NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "notes" "text",
    "date" "date" DEFAULT (("now"() AT TIME ZONE 'Asia/Jakarta'::"text"))::"date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."transfers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallets" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "balance" numeric(15,2) DEFAULT 0.00 NOT NULL,
    "currency" "text" DEFAULT 'IDR'::"text" NOT NULL,
    "icon" "text",
    "is_hidden" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."wallets" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ledger_entries" WITH ("security_invoker"='on') AS
 SELECT "t"."id" AS "entry_id",
    "t"."user_id",
    "t"."wallet_id",
    "w"."name" AS "wallet_name",
    "t"."category_id",
    "c"."name" AS "category_name",
    "c"."type" AS "category_type",
    ( SELECT "pc"."name"
           FROM "public"."categories" "pc"
          WHERE ("pc"."id" = "c"."parent_id")) AS "category_parent",
    ("t"."amount" * (
        CASE "c"."type"
            WHEN 'expense'::"public"."category_type" THEN '-1'::integer
            ELSE 1
        END)::numeric) AS "signed_amount",
    "t"."amount",
    "t"."date",
    "t"."notes",
    'transaction'::"text" AS "kind",
    NULL::"uuid" AS "transfer_id"
   FROM (("public"."transactions" "t"
     JOIN "public"."categories" "c" ON (("c"."id" = "t"."category_id")))
     LEFT JOIN "public"."wallets" "w" ON (("w"."id" = "t"."wallet_id")))
UNION ALL
 SELECT "tr"."id" AS "entry_id",
    "tr"."user_id",
    "tr"."from_wallet_id" AS "wallet_id",
    "fw"."name" AS "wallet_name",
    NULL::"uuid" AS "category_id",
    'Transfer Keluar'::"text" AS "category_name",
    NULL::"public"."category_type" AS "category_type",
    NULL::"text" AS "category_parent",
    (- "tr"."amount") AS "signed_amount",
    "tr"."amount",
    "tr"."date",
    "tr"."notes",
    'transfer_out'::"text" AS "kind",
    "tr"."id" AS "transfer_id"
   FROM ("public"."transfers" "tr"
     LEFT JOIN "public"."wallets" "fw" ON (("fw"."id" = "tr"."from_wallet_id")))
UNION ALL
 SELECT "tr"."id" AS "entry_id",
    "tr"."user_id",
    "tr"."to_wallet_id" AS "wallet_id",
    "tw"."name" AS "wallet_name",
    NULL::"uuid" AS "category_id",
    'Transfer Masuk'::"text" AS "category_name",
    NULL::"public"."category_type" AS "category_type",
    NULL::"text" AS "category_parent",
    "tr"."amount" AS "signed_amount",
    "tr"."amount",
    "tr"."date",
    "tr"."notes",
    'transfer_in'::"text" AS "kind",
    "tr"."id" AS "transfer_id"
   FROM ("public"."transfers" "tr"
     LEFT JOIN "public"."wallets" "tw" ON (("tw"."id" = "tr"."to_wallet_id")));


ALTER VIEW "public"."ledger_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_reminders" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "hour" integer NOT NULL,
    "minute" integer NOT NULL,
    "is_enabled" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "notification_reminders_hour_check" CHECK ((("hour" >= 0) AND ("hour" <= 23))),
    CONSTRAINT "notification_reminders_minute_check" CHECK ((("minute" >= 0) AND ("minute" <= 59)))
);


ALTER TABLE "public"."notification_reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pending_bot_transactions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid",
    "wallet_id" "uuid" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "amount" numeric NOT NULL,
    "notes" "text",
    "date" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:05:00'::interval),
    "type" "text" DEFAULT 'expense'::"text",
    "platform" "text" DEFAULT 'telegram'::"text" NOT NULL,
    "platform_identifier" "text",
    "original_input" "text"
);


ALTER TABLE "public"."pending_bot_transactions" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."pending_transactions_view" WITH ("security_invoker"='on') AS
 SELECT "p"."id",
    "p"."user_id",
    "p"."wallet_id",
    "p"."category_id",
    "p"."amount",
    "p"."notes",
    "p"."date",
    "p"."created_at",
    "p"."expires_at",
    "p"."type",
    "p"."platform",
    "p"."platform_identifier",
    "p"."original_input",
    "w"."name" AS "wallet_name",
    "c"."name" AS "category_name"
   FROM (("public"."pending_bot_transactions" "p"
     LEFT JOIN "public"."wallets" "w" ON (("p"."wallet_id" = "w"."id")))
     LEFT JOIN "public"."categories" "c" ON (("p"."category_id" = "c"."id")));


ALTER VIEW "public"."pending_transactions_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transaction_images" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "transaction_id" "uuid" NOT NULL,
    "image_url" "text" NOT NULL,
    "image_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."transaction_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_preferences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "keyword" "text" NOT NULL,
    "preference_type" "text" NOT NULL,
    "value_id" "uuid" NOT NULL,
    "value_name" "text" NOT NULL,
    "confidence" double precision DEFAULT 0.5,
    "usage_count" integer DEFAULT 1,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_preferences_confidence_check" CHECK ((("confidence" >= (0)::double precision) AND ("confidence" <= (1)::double precision)))
);


ALTER TABLE "public"."user_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "currency" "text" DEFAULT 'IDR'::"text",
    "timezone" "text" DEFAULT 'Asia/Jakarta'::"text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parser_mode" "text" DEFAULT 'regex'::"text",
    "ai_provider" "text" DEFAULT 'none'::"text",
    "ai_api_key" "text"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."parser_mode" IS 'Transaction parsing mode: regex or ai';



COMMENT ON COLUMN "public"."users"."ai_provider" IS 'AI provider for parsing: none, openai, gemini, anthropic, groq';



COMMENT ON COLUMN "public"."users"."ai_api_key" IS 'Encrypted API key for AI provider (user_key mode)';



ALTER TABLE ONLY "public"."bot_links"
    ADD CONSTRAINT "bot_links_pkey" PRIMARY KEY ("link_token");



ALTER TABLE ONLY "public"."bot_links"
    ADD CONSTRAINT "bot_links_platform_platform_user_id_key" UNIQUE ("platform", "platform_user_id");



ALTER TABLE ONLY "public"."bot_links"
    ADD CONSTRAINT "bot_links_user_id_platform_key" UNIQUE ("user_id", "platform");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_reminders"
    ADD CONSTRAINT "notification_reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pending_bot_transactions"
    ADD CONSTRAINT "pending_bot_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pending_bot_transactions"
    ADD CONSTRAINT "pending_bot_transactions_user_id_platform_key" UNIQUE ("user_id", "platform");



ALTER TABLE ONLY "public"."pending_bot_transactions"
    ADD CONSTRAINT "pending_unique_user_platform" UNIQUE ("user_id", "platform");



ALTER TABLE ONLY "public"."transaction_images"
    ADD CONSTRAINT "transaction_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transfers"
    ADD CONSTRAINT "transfers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_preferences"
    ADD CONSTRAINT "user_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_preferences"
    ADD CONSTRAINT "user_preferences_user_id_keyword_preference_type_key" UNIQUE ("user_id", "keyword", "preference_type");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_bot_links_link_token" ON "public"."bot_links" USING "btree" ("link_token") WHERE ("link_token" IS NOT NULL);



CREATE INDEX "idx_bot_links_platform_lookup" ON "public"."bot_links" USING "btree" ("platform", "platform_user_id");



CREATE INDEX "idx_bot_links_user_id" ON "public"."bot_links" USING "btree" ("user_id");



CREATE INDEX "idx_categories_hidden" ON "public"."categories" USING "btree" ("user_id", "is_hidden");



CREATE INDEX "idx_categories_parent_id" ON "public"."categories" USING "btree" ("parent_id");



CREATE INDEX "idx_categories_type" ON "public"."categories" USING "btree" ("user_id", "type");



CREATE INDEX "idx_categories_user_id" ON "public"."categories" USING "btree" ("user_id");



CREATE INDEX "idx_notification_reminders_user_id" ON "public"."notification_reminders" USING "btree" ("user_id");



CREATE INDEX "idx_transaction_images_transaction_id" ON "public"."transaction_images" USING "btree" ("transaction_id");



CREATE INDEX "idx_transaction_images_user_id" ON "public"."transaction_images" USING "btree" ("user_id");



CREATE INDEX "idx_transactions_category_id" ON "public"."transactions" USING "btree" ("category_id");



CREATE INDEX "idx_transactions_created_at" ON "public"."transactions" USING "btree" ("user_id", "created_at");



CREATE INDEX "idx_transactions_date" ON "public"."transactions" USING "btree" ("user_id", "date");



CREATE INDEX "idx_transactions_user_id" ON "public"."transactions" USING "btree" ("user_id");



CREATE INDEX "idx_transactions_wallet_id" ON "public"."transactions" USING "btree" ("wallet_id");



CREATE INDEX "idx_transfers_created_at" ON "public"."transfers" USING "btree" ("user_id", "created_at");



CREATE INDEX "idx_transfers_date" ON "public"."transfers" USING "btree" ("user_id", "date");



CREATE INDEX "idx_transfers_user_id" ON "public"."transfers" USING "btree" ("user_id");



CREATE INDEX "idx_transfers_wallets" ON "public"."transfers" USING "btree" ("from_wallet_id", "to_wallet_id");



CREATE INDEX "idx_user_preferences_lookup" ON "public"."user_preferences" USING "btree" ("user_id", "keyword");



CREATE INDEX "idx_wallets_active" ON "public"."wallets" USING "btree" ("user_id", "is_hidden");



CREATE INDEX "idx_wallets_hidden" ON "public"."wallets" USING "btree" ("user_id", "is_hidden");



CREATE INDEX "idx_wallets_user_id" ON "public"."wallets" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "handle_transfer_trigger" AFTER INSERT OR DELETE OR UPDATE ON "public"."transfers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_transfer_amount_only"();



CREATE OR REPLACE TRIGGER "prevent_category_delete_trigger" BEFORE DELETE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_category_delete"();



CREATE OR REPLACE TRIGGER "prevent_category_type_change_trigger" BEFORE UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_category_type_change"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."bot_links" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."categories" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."notification_reminders" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."transfers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."wallets" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "update_user_preferences_updated_at" BEFORE UPDATE ON "public"."user_preferences" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_wallet_balance_on_transaction_delete" AFTER DELETE ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallet_balance"();



CREATE OR REPLACE TRIGGER "update_wallet_balance_on_transaction_insert" AFTER INSERT ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallet_balance"();



CREATE OR REPLACE TRIGGER "update_wallet_balance_on_transaction_update" AFTER UPDATE ON "public"."transactions" FOR EACH ROW EXECUTE FUNCTION "public"."update_wallet_balance"();



ALTER TABLE ONLY "public"."bot_links"
    ADD CONSTRAINT "bot_links_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_reminders"
    ADD CONSTRAINT "notification_reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pending_bot_transactions"
    ADD CONSTRAINT "pending_bot_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transaction_images"
    ADD CONSTRAINT "transaction_images_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transaction_images"
    ADD CONSTRAINT "transaction_images_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "public"."wallets"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."transfers"
    ADD CONSTRAINT "transfers_from_wallet_id_fkey" FOREIGN KEY ("from_wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transfers"
    ADD CONSTRAINT "transfers_to_wallet_id_fkey" FOREIGN KEY ("to_wallet_id") REFERENCES "public"."wallets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transfers"
    ADD CONSTRAINT "transfers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_preferences"
    ADD CONSTRAINT "user_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wallets"
    ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Service role full access on pending_bot_transactions" ON "public"."pending_bot_transactions" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Service role full access on user_preferences" ON "public"."user_preferences" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Users can create own bot links" ON "public"."bot_links" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create own reminders" ON "public"."notification_reminders" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own bot links" ON "public"."bot_links" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own categories" ON "public"."categories" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own pending transactions" ON "public"."pending_bot_transactions" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own reminders" ON "public"."notification_reminders" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own transaction images" ON "public"."transaction_images" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own transactions" ON "public"."transactions" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own transfers" ON "public"."transfers" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own wallets" ON "public"."wallets" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own categories" ON "public"."categories" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own pending transactions" ON "public"."pending_bot_transactions" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."users" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can insert own transaction images" ON "public"."transaction_images" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own transactions" ON "public"."transactions" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own transfers" ON "public"."transfers" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own wallets" ON "public"."wallets" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own bot links" ON "public"."bot_links" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own categories" ON "public"."categories" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own pending transactions" ON "public"."pending_bot_transactions" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."users" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can update own reminders" ON "public"."notification_reminders" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own transaction images" ON "public"."transaction_images" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own transactions" ON "public"."transactions" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own transfers" ON "public"."transfers" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own wallets" ON "public"."wallets" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own bot links" ON "public"."bot_links" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own categories" ON "public"."categories" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own pending transactions" ON "public"."pending_bot_transactions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own preferences" ON "public"."user_preferences" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own profile" ON "public"."users" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view own reminders" ON "public"."notification_reminders" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own transaction images" ON "public"."transaction_images" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own transactions" ON "public"."transactions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own transfers" ON "public"."transfers" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own wallets" ON "public"."wallets" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."bot_links" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pending_bot_transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transaction_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transfers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."wallets" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."cleanup_user_storage_files"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cleanup_user_storage_files"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cleanup_user_storage_files"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_wallet_transfer"("p_user_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_expense_category_id" "uuid", "p_income_category_id" "uuid", "p_notes" "text", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."create_wallet_transfer"("p_user_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_expense_category_id" "uuid", "p_income_category_id" "uuid", "p_notes" "text", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_wallet_transfer"("p_user_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_expense_category_id" "uuid", "p_income_category_id" "uuid", "p_notes" "text", "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_user_account_complete"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_user_account_complete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_user_account_complete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bot_link"("p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_bot_link"("p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bot_link"("p_platform" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_by_platform_id"("p_platform" "text", "p_platform_user_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_by_platform_id"("p_platform" "text", "p_platform_user_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_by_platform_id"("p_platform" "text", "p_platform_user_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_data_summary"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_data_summary"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_data_summary"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_parser_settings"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_parser_settings"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_parser_settings"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_transfer"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_transfer"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_transfer"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_transfer_amount_only"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_transfer_amount_only"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_transfer_amount_only"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."link_by_user_id"("p_user_id" "uuid", "p_platform" "text", "p_platform_user_id" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."link_by_user_id"("p_user_id" "uuid", "p_platform" "text", "p_platform_user_id" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_by_user_id"("p_user_id" "uuid", "p_platform" "text", "p_platform_user_id" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_category_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_category_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_category_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_category_type_change"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_category_type_change"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_category_type_change"() TO "service_role";



GRANT ALL ON FUNCTION "public"."recalculate_wallet_balance"("p_wallet_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."recalculate_wallet_balance"("p_wallet_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_wallet_balance"("p_wallet_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."unlink_platform"("p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."unlink_platform"("p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."unlink_platform"("p_platform" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_bot_link_metadata"("p_platform" "text", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_bot_link_metadata"("p_platform" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_bot_link_metadata"("p_platform" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_parser_settings"("p_parser_mode" "text", "p_ai_provider" "text", "p_ai_api_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_parser_settings"("p_parser_mode" "text", "p_ai_provider" "text", "p_ai_api_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_parser_settings"("p_parser_mode" "text", "p_ai_provider" "text", "p_ai_api_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_wallet_balance"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_wallet_balance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_wallet_balance"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_notes" "text", "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."update_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_notes" "text", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_wallet_transfer"("p_user_id" "uuid", "p_transfer_id" "uuid", "p_from_wallet_id" "uuid", "p_to_wallet_id" "uuid", "p_amount" numeric, "p_notes" "text", "p_date" "date") TO "service_role";


















GRANT ALL ON TABLE "public"."bot_links" TO "anon";
GRANT ALL ON TABLE "public"."bot_links" TO "authenticated";
GRANT ALL ON TABLE "public"."bot_links" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."transfers" TO "anon";
GRANT ALL ON TABLE "public"."transfers" TO "authenticated";
GRANT ALL ON TABLE "public"."transfers" TO "service_role";



GRANT ALL ON TABLE "public"."wallets" TO "anon";
GRANT ALL ON TABLE "public"."wallets" TO "authenticated";
GRANT ALL ON TABLE "public"."wallets" TO "service_role";



GRANT ALL ON TABLE "public"."ledger_entries" TO "anon";
GRANT ALL ON TABLE "public"."ledger_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."ledger_entries" TO "service_role";



GRANT ALL ON TABLE "public"."notification_reminders" TO "anon";
GRANT ALL ON TABLE "public"."notification_reminders" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_reminders" TO "service_role";



GRANT ALL ON TABLE "public"."pending_bot_transactions" TO "anon";
GRANT ALL ON TABLE "public"."pending_bot_transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."pending_bot_transactions" TO "service_role";



GRANT ALL ON TABLE "public"."pending_transactions_view" TO "anon";
GRANT ALL ON TABLE "public"."pending_transactions_view" TO "authenticated";
GRANT ALL ON TABLE "public"."pending_transactions_view" TO "service_role";



GRANT ALL ON TABLE "public"."transaction_images" TO "anon";
GRANT ALL ON TABLE "public"."transaction_images" TO "authenticated";
GRANT ALL ON TABLE "public"."transaction_images" TO "service_role";



GRANT ALL ON TABLE "public"."user_preferences" TO "anon";
GRANT ALL ON TABLE "public"."user_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."user_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
-- ==========================================
-- Agent Training & Few-Shot Examples Schema
-- ==========================================

CREATE TABLE IF NOT EXISTS "public"."agent_training" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "user_id" uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    "training_type" text NOT NULL CHECK (training_type IN ('system_instruction', 'few_shot_example')),
    "sample_input" text,
    "expected_output" jsonb,
    "instruction_text" text,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS "idx_agent_training_user" ON "public"."agent_training" ("user_id", "training_type");

CREATE OR REPLACE TRIGGER "update_agent_training_updated_at"
BEFORE UPDATE ON "public"."agent_training"
FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();

ALTER TABLE "public"."agent_training" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own agent training" ON "public"."agent_training"
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on agent_training" ON "public"."agent_training"
    FOR ALL USING (auth.role() = 'service_role');

GRANT ALL ON TABLE "public"."agent_training" TO "anon";
GRANT ALL ON TABLE "public"."agent_training" TO "authenticated";
GRANT ALL ON TABLE "public"."agent_training" TO "service_role";































