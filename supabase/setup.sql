-- ==============================================================================
-- FINOTEKU SUPABASE COMPLETE SETUP
-- Version: 2.0 (Consolidated)
-- Description: Complete database setup including Schema, RLS, Storage & Extensions
-- ==============================================================================

-- =============================================
-- [SECTION 0] CONFIGURATION & EXTENSIONS
-- =============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Define Custom Types (ENUMs)
DO $$
BEGIN
IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_type') THEN
  CREATE TYPE category_type AS ENUM ('income', 'expense');
END IF;
END $$;

-- =============================================
-- [SECTION 1] CORE TABLES
-- =============================================

-- 1.1 USERS (Extends Auth)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT,
  currency TEXT DEFAULT 'IDR',
  timezone TEXT DEFAULT 'Asia/Jakarta', -- Default Timezone as requested
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 1.2 WALLETS
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'IDR',
  icon TEXT, 
  is_hidden BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 1.3 CATEGORIES
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  TYPE category_type NOT NULL,
  parent_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
  icon_code_point BIGINT,
  is_hidden BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 1.4 TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  wallet_id UUID REFERENCES public.wallets(id) ON DELETE RESTRICT NOT NULL,
  category_id UUID REFERENCES public.categories(id) ON DELETE RESTRICT NOT NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  notes TEXT,
  date DATE NOT NULL DEFAULT (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 1.5 TRANSACTION IMAGES
CREATE TABLE IF NOT EXISTS public.transaction_images (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT NOT NULL,
  image_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('Asia/Jakarta'::text, NOW()) NOT NULL
);

-- 1.6 TRANSFERS
CREATE TABLE IF NOT EXISTS public.transfers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  from_wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
  to_wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(15, 2) NOT NULL,
  fee DECIMAL(15, 2) DEFAULT 0.00,
  notes TEXT,
  date DATE NOT NULL DEFAULT (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 1.7 BOT LINKS (Integrations)
CREATE TABLE IF NOT EXISTS public.bot_links (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL,              -- 'telegram', 'whatsapp'
  platform_user_id TEXT NOT NULL,      -- ID user di platform
  platform_username TEXT,              
  is_active BOOLEAN DEFAULT TRUE,
  ai_provider TEXT DEFAULT 'none',     -- 'none', 'gemini', 'openai'
  ai_api_key TEXT,                     
  parser_mode TEXT DEFAULT 'regex',    -- 'regex', 'server_key', 'user_key'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  UNIQUE(platform, platform_user_id),
  UNIQUE(user_id, platform)
);

-- 1.9 PENDING BOT TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.pending_bot_transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  telegram_chat_id BIGINT NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  wallet_id UUID NOT NULL,
  category_id UUID NOT NULL,
  amount DECIMAL NOT NULL,
  notes TEXT DEFAULT '',
  date DATE NOT NULL,
  type TEXT DEFAULT 'expense', 
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '5 minutes') NOT NULL
);

-- 1.8 NOTIFICATION REMINDERS
CREATE TABLE IF NOT EXISTS public.notification_reminders (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  hour INT NOT NULL CHECK (hour >= 0 AND hour <= 23),
  minute INT NOT NULL CHECK (minute >= 0 AND minute <= 59),
  is_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- =============================================
-- [SECTION 2] INDEXES
-- =============================================
-- Core Indexes
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_hidden ON public.wallets(user_id, is_hidden);
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON public.categories(user_id, TYPE);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_wallet_id ON public.transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(user_id, date);
CREATE INDEX IF NOT EXISTS idx_transaction_images_user_id ON public.transaction_images(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_images_transaction_id ON public.transaction_images(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transfers_user_id ON public.transfers(user_id);
CREATE INDEX IF NOT EXISTS idx_transfers_date ON public.transfers(user_id, date);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(user_id, created_at);

-- Extended Indexes
CREATE INDEX IF NOT EXISTS idx_bot_links_user_id ON public.bot_links(user_id);
CREATE INDEX IF NOT EXISTS idx_bot_links_platform_lookup ON public.bot_links(platform, platform_user_id);
CREATE INDEX IF NOT EXISTS idx_notification_reminders_user_id ON public.notification_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_bot_transactions_chat ON public.pending_bot_transactions(telegram_chat_id);

-- =============================================
-- [SECTION 3] FUNCTIONS & TRIGGERS
-- =============================================

-- 3.1 Updated At Handler
CREATE OR REPLACE FUNCTION public.handle_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Register Trigger for all tables
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name IN ('users', 'wallets', 'categories', 'transactions', 'transfers', 'bot_links', 'notification_reminders')
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
        EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at()', t);
    END LOOP;
END;
$$;

-- 3.2 Wallet Balance Triggers & Calculations
CREATE OR REPLACE FUNCTION public.recalculate_wallet_balance(p_wallet_id UUID, p_user_id UUID) RETURNS DECIMAL(15, 2) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.recalculate_all_wallet_balances(p_user_id UUID) RETURNS VOID AS $$
DECLARE wallet_record RECORD;
BEGIN
  FOR wallet_record IN SELECT id FROM public.wallets WHERE user_id = p_user_id LOOP
    PERFORM public.recalculate_wallet_balance(wallet_record.id, p_user_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_wallet_balance() RETURNS TRIGGER AS $$
DECLARE
  old_sign NUMERIC := 0; new_sign NUMERIC := 0;
  old_type category_type; new_type category_type;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT TYPE INTO new_type FROM public.categories WHERE id = NEW.category_id;
    new_sign := CASE WHEN new_type = 'expense' THEN -1 ELSE 1 END;
    UPDATE public.wallets SET balance = balance + (NEW.amount * new_sign) WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    SELECT TYPE INTO old_type FROM public.categories WHERE id = OLD.category_id;
    SELECT TYPE INTO new_type FROM public.categories WHERE id = NEW.category_id;
    IF OLD.wallet_id != NEW.wallet_id THEN
       UPDATE public.wallets SET balance = balance - (OLD.amount * CASE WHEN old_type='expense' THEN -1 ELSE 1 END) WHERE id = OLD.wallet_id;
       UPDATE public.wallets SET balance = balance + (NEW.amount * CASE WHEN new_type='expense' THEN -1 ELSE 1 END) WHERE id = NEW.wallet_id;
    ELSE
       UPDATE public.wallets SET balance = balance - (OLD.amount * CASE WHEN old_type='expense' THEN -1 ELSE 1 END) + (NEW.amount * CASE WHEN new_type='expense' THEN -1 ELSE 1 END) WHERE id = NEW.wallet_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT TYPE INTO old_type FROM public.categories WHERE id = OLD.category_id;
    UPDATE public.wallets SET balance = balance - (OLD.amount * CASE WHEN old_type='expense' THEN -1 ELSE 1 END) WHERE id = OLD.wallet_id AND user_id = OLD.user_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_insert ON public.transactions;
CREATE TRIGGER update_wallet_balance_on_transaction_insert AFTER INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();
DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_update ON public.transactions;
CREATE TRIGGER update_wallet_balance_on_transaction_update AFTER UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();
DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_delete ON public.transactions;
CREATE TRIGGER update_wallet_balance_on_transaction_delete AFTER DELETE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

-- 3.3 Transfer Balance Trigger
CREATE OR REPLACE FUNCTION public.handle_transfer_amount_only() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.wallets SET balance = balance - NEW.amount WHERE id = NEW.from_wallet_id;
    UPDATE public.wallets SET balance = balance + NEW.amount WHERE id = NEW.to_wallet_id;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.wallets SET balance = balance + OLD.amount WHERE id = OLD.from_wallet_id;
    UPDATE public.wallets SET balance = balance - NEW.amount WHERE id = NEW.from_wallet_id;
    UPDATE public.wallets SET balance = balance - OLD.amount WHERE id = OLD.to_wallet_id;
    UPDATE public.wallets SET balance = balance + NEW.amount WHERE id = NEW.to_wallet_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.wallets SET balance = balance + OLD.amount WHERE id = OLD.from_wallet_id;
    UPDATE public.wallets SET balance = balance - OLD.amount WHERE id = OLD.to_wallet_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS handle_transfer_trigger ON public.transfers;
CREATE TRIGGER handle_transfer_trigger AFTER INSERT OR UPDATE OR DELETE ON public.transfers FOR EACH ROW EXECUTE FUNCTION public.handle_transfer_amount_only();

-- 3.4 Logic RPCs
CREATE OR REPLACE FUNCTION public.create_wallet_transfer(
  p_user_id UUID, p_from_wallet_id UUID, p_to_wallet_id UUID, p_amount DECIMAL(15, 2), p_fee DECIMAL(15, 2) DEFAULT 0.00, p_notes TEXT DEFAULT NULL, p_date DATE DEFAULT CURRENT_DATE, p_fee_category_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE v_transfer_id UUID;
BEGIN
  INSERT INTO public.transfers (user_id, from_wallet_id, to_wallet_id, amount, fee, notes, date)
  VALUES (p_user_id, p_from_wallet_id, p_to_wallet_id, p_amount, p_fee, p_notes, p_date)
  RETURNING id INTO v_transfer_id;
  
  IF p_fee > 0 THEN
      IF p_fee_category_id IS NULL THEN RAISE EXCEPTION 'Fee category required'; END IF;
      INSERT INTO public.transactions (user_id, wallet_id, category_id, amount, notes, date)
      VALUES (p_user_id, p_from_wallet_id, p_fee_category_id, p_fee, 'Transfer Fee [transfer:' || v_transfer_id || ']', p_date);
  END IF;
  RETURN v_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.5 New User Handler (Auth)
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, timezone)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name', 'Asia/Jakarta'); -- Force default here too
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3.6 Bot Integration Utils
CREATE OR REPLACE FUNCTION public.get_user_by_platform_id(p_platform TEXT, p_platform_user_id TEXT) 
RETURNS TABLE (user_id UUID, ai_provider TEXT, ai_api_key TEXT, parser_mode TEXT) AS $$
BEGIN
  RETURN QUERY SELECT bl.user_id, bl.ai_provider, bl.ai_api_key, bl.parser_mode FROM public.bot_links bl
  WHERE bl.platform = p_platform AND bl.platform_user_id = p_platform_user_id AND bl.is_active = TRUE LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.get_user_by_platform_id(TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.cleanup_expired_pending_transactions() RETURNS void AS $$
BEGIN
  DELETE FROM public.pending_bot_transactions WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_pending_transactions() TO service_role;

-- 3.7 Account Deletion
CREATE OR REPLACE FUNCTION public.delete_user_account_complete() RETURNS void AS $$
DECLARE current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  DELETE FROM public.transaction_images WHERE user_id = current_user_id;
  DELETE FROM public.transactions WHERE user_id = current_user_id;
  DELETE FROM public.transfers WHERE user_id = current_user_id;
  DELETE FROM public.categories WHERE user_id = current_user_id;
  DELETE FROM public.wallets WHERE user_id = current_user_id;
  DELETE FROM public.bot_links WHERE user_id = current_user_id;
  DELETE FROM public.notification_reminders WHERE user_id = current_user_id;
  DELETE FROM public.users WHERE id = current_user_id;
  DELETE FROM auth.users WHERE id = current_user_id;
  -- Add storage cleanup here if needed
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- [SECTION 4] STORAGE SETUP
-- =============================================
-- Buckets: Only Avatars for now
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('avatars', 'avatars', true, 2097152) ON CONFLICT (id) DO NOTHING;

-- Policies for Storage
DROP POLICY IF EXISTS "Avatars Public View" ON storage.objects;
CREATE POLICY "Avatars Public View" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
DROP POLICY IF EXISTS "Avatars Auth Update" ON storage.objects;
CREATE POLICY "Avatars Auth Update" ON storage.objects 
FOR ALL USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]) 
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =============================================
-- [SECTION 5] SECURITY (RLS)
-- =============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_bot_transactions ENABLE ROW LEVEL SECURITY;

-- Standard "Own Data" Policies
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' 
             AND table_name IN ('wallets', 'categories', 'transactions', 'transfers', 'transaction_images', 'bot_links', 'notification_reminders')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Own Data %I" ON public.%I', t, t);
        EXECUTE format('CREATE POLICY "Own Data %I" ON public.%I USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)', t, t);
    END LOOP;
END;
$$;

-- Users table special policies
DROP POLICY IF EXISTS "Users View Self" ON public.users;
CREATE POLICY "Users View Self" ON public.users FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users Update Self" ON public.users;
CREATE POLICY "Users Update Self" ON public.users FOR UPDATE USING (auth.uid() = id);

-- =============================================
-- [SECTION 6] API GRANTS
-- =============================================
GRANT EXECUTE ON FUNCTION public.create_wallet_transfer(UUID, UUID, UUID, DECIMAL, DECIMAL, TEXT, DATE, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recalculate_all_wallet_balances(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_user_account_complete() TO authenticated;
