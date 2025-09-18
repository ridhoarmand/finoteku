-- =============================================
-- Skema Database Finoteku (Supabase)
-- Aplikasi Pencatatan Keuangan Pribadi Sederhana
-- =============================================
-- Aktifkan ekstensi UUID (untuk generate id unik)
-- 0) EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- 1) CUSTOM TYPES (ENUM)
-- =============================================
DO $$
BEGIN
IF NOT EXISTS (
  SELECT
    1
  FROM
    pg_type
  WHERE
    typname = 'category_type'
) THEN
  CREATE TYPE category_type AS ENUM ('income', 'expense');
END IF;
END
$$;

-- =============================================
-- 2) CORE TABLES
-- =============================================
-- Tabel users (perpanjangan dari auth.users milik Supabase)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT,
  currency TEXT DEFAULT 'IDR',
  timezone TEXT DEFAULT 'Asia/Jakarta',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL
);

-- Tabel wallets (disederhanakan)
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'IDR',
  icon TEXT,
  -- Lokasi ikon (assets banks/*.svg atau ewallets/*.svg)
  is_hidden BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL
);

-- Tabel categories (sederhana + flag hide, tipe tidak boleh diubah setelah dipakai)
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  TYPE category_type NOT NULL,
  parent_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
  icon_code_point BIGINT,
  -- Menyimpan codePoint Material Icon (untuk ikon kustom)
  is_hidden BOOLEAN DEFAULT false,
  -- Disembunyikan dari picker tetapi tetap dihitung dalam analitik
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL
);

-- Tabel transactions (amount selalu positif; tanda + / - diturunkan dari category.type)
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  wallet_id UUID REFERENCES public.wallets(id) ON DELETE RESTRICT NOT NULL,
  category_id UUID REFERENCES public.categories(id) ON DELETE RESTRICT NOT NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  notes TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL
);

-- Tabel transaction_images (menyimpan banyak bukti gambar)
CREATE TABLE IF NOT EXISTS public.transaction_images (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE CASCADE NOT NULL,
  image_url TEXT NOT NULL,
  image_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL
);

-- Tabel transfers (pemindahan antar wallet – versi sederhana)
CREATE TABLE IF NOT EXISTS public.transfers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  from_wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
  to_wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(15, 2) NOT NULL,
  fee DECIMAL(15, 2) DEFAULT 0.00,
  notes TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc' :: text, NOW()) NOT NULL
);

-- =============================================
-- 3) INDEXES (performa query)
-- =============================================
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);

CREATE INDEX IF NOT EXISTS idx_wallets_hidden ON public.wallets(user_id, is_hidden);

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);

CREATE INDEX IF NOT EXISTS idx_categories_type ON public.categories(user_id, TYPE);

CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);

CREATE INDEX IF NOT EXISTS idx_categories_hidden ON public.categories(user_id, is_hidden);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_wallet_id ON public.transactions(wallet_id);

CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions(category_id);

CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(user_id, date);

CREATE INDEX IF NOT EXISTS idx_transaction_images_user_id ON public.transaction_images(user_id);

CREATE INDEX IF NOT EXISTS idx_transaction_images_transaction_id ON public.transaction_images(transaction_id);

CREATE INDEX IF NOT EXISTS idx_transfers_user_id ON public.transfers(user_id);

CREATE INDEX IF NOT EXISTS idx_transfers_date ON public.transfers(user_id, date);

CREATE INDEX IF NOT EXISTS idx_transfers_wallets ON public.transfers(from_wallet_id, to_wallet_id);

-- (Opsional) Index waktu untuk sort/filter recent data
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_transfers_created_at ON public.transfers(user_id, created_at);

-- =============================================
-- 4) GENERIC TRIGGERS
-- =============================================
-- Fungsi trigger untuk mengisi kolom updated_at otomatis
CREATE OR REPLACE FUNCTION public.handle_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc' :: text, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tambahkan trigger updated_at ke semua tabel
DROP TRIGGER IF EXISTS set_updated_at ON public.users;
CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.users FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON public.wallets;
CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.wallets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON public.categories;
CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.categories FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON public.transactions;
CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON public.transfers;
CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.transfers FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- 5) WALLET BALANCE TRIGGERS (berbasis tabel transactions)
-- =============================================
CREATE OR REPLACE FUNCTION public.update_wallet_balance() RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

-- Pasang trigger agar saldo otomatis ter-update pada INSERT/UPDATE/DELETE transaksi
DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_insert ON public.transactions;
CREATE TRIGGER update_wallet_balance_on_transaction_insert
AFTER
INSERT
  ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_update ON public.transactions;
CREATE TRIGGER update_wallet_balance_on_transaction_update
AFTER
UPDATE
  ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_delete ON public.transactions;
CREATE TRIGGER update_wallet_balance_on_transaction_delete
AFTER
  DELETE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

-- =============================================
-- =============================================
-- Fungsi untuk menghitung ulang saldo 1 wallet dari seluruh transaksinya
CREATE OR REPLACE FUNCTION public.recalculate_wallet_balance(p_wallet_id UUID, p_user_id UUID) RETURNS DECIMAL(15, 2) AS $$
DECLARE calculated_balance DECIMAL(15, 2);
DECLARE tx_balance DECIMAL(15, 2);
DECLARE transfer_in DECIMAL(15, 2);
DECLARE transfer_out DECIMAL(15, 2);
DECLARE transfer_fee DECIMAL(15, 2);
BEGIN
  -- Hitung saldo dari semua transaksi normal (income/expense)
  SELECT COALESCE(SUM(t.amount * CASE c.type WHEN 'expense' THEN -1 ELSE 1 END), 0)
    INTO tx_balance
  FROM public.transactions t
  JOIN public.categories c ON c.id = t.category_id
  WHERE t.wallet_id = p_wallet_id AND t.user_id = p_user_id;

  -- Hitung transfer masuk ke wallet ini
  SELECT COALESCE(SUM(amount), 0) INTO transfer_in
  FROM public.transfers tr
  WHERE tr.to_wallet_id = p_wallet_id AND tr.user_id = p_user_id;

  -- Hitung transfer keluar dari wallet ini (termasuk fee yang sudah dipotong via trigger transaksi)
  SELECT COALESCE(SUM(amount), 0) INTO transfer_out
  FROM public.transfers tr
  WHERE tr.from_wallet_id = p_wallet_id AND tr.user_id = p_user_id;

  -- Saldo final = transaksi normal + transfer masuk - transfer keluar
  -- (fee sudah dihitung sebagai expense transaction terpisah)
  calculated_balance := tx_balance + transfer_in - transfer_out;
  
  UPDATE public.wallets
    SET balance = calculated_balance,
        updated_at = TIMEZONE('utc' :: text, NOW())
  WHERE id = p_wallet_id AND user_id = p_user_id;
  
  RETURN calculated_balance;
END;
$$ LANGUAGE plpgsql;

-- Fungsi untuk menghitung ulang semua saldo wallet milik 1 user
CREATE OR REPLACE FUNCTION public.recalculate_all_wallet_balances(p_user_id UUID) RETURNS VOID AS $$
DECLARE wallet_record RECORD;
BEGIN
  FOR wallet_record IN SELECT id FROM public.wallets WHERE user_id = p_user_id LOOP
    PERFORM public.recalculate_wallet_balance(wallet_record.id, p_user_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 7) CATEGORY TYPE PROTECTIONS
-- =============================================
-- Immutability & Proteksi Kategori
-- Cegah penggantian type kategori jika sudah dipakai oleh transaksi
CREATE OR REPLACE FUNCTION public.prevent_category_type_change() RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prevent_category_type_change_trigger ON public.categories;
CREATE TRIGGER prevent_category_type_change_trigger
  BEFORE UPDATE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.prevent_category_type_change();

-- Cegah penghapusan kategori bila sudah dipakai (sarankan hide)
CREATE OR REPLACE FUNCTION public.prevent_category_delete() RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prevent_category_delete_trigger ON public.categories;
CREATE TRIGGER prevent_category_delete_trigger BEFORE DELETE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.prevent_category_delete();

-- =============================================
-- 8) BULK TRANSFER UTILITIES (migrasi data)
-- =============================================
-- Pindahkan semua transaksi dari satu wallet ke wallet lain
CREATE OR REPLACE FUNCTION public.transfer_transactions_to_wallet(
  p_from_wallet_id UUID,
  p_to_wallet_id UUID,
  p_user_id UUID
) RETURNS INTEGER AS $$
DECLARE transaction_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO transaction_count
  FROM public.transactions
  WHERE wallet_id = p_from_wallet_id AND user_id = p_user_id;

  UPDATE public.transactions
    SET wallet_id = p_to_wallet_id,
        updated_at = TIMEZONE('utc' :: text, NOW())
  WHERE wallet_id = p_from_wallet_id AND user_id = p_user_id;

  PERFORM public.recalculate_wallet_balance(p_from_wallet_id, p_user_id);
  PERFORM public.recalculate_wallet_balance(p_to_wallet_id, p_user_id);
  RETURN transaction_count;
END;
$$ LANGUAGE plpgsql;

-- Pindahkan transaksi dari satu kategori ke kategori lain (tanpa membalik amount)
CREATE OR REPLACE FUNCTION public.transfer_transactions_to_category(
  p_from_category_id UUID,
  p_to_category_id UUID,
  p_user_id UUID
) RETURNS INTEGER AS $$
DECLARE
  transaction_count INTEGER;
  from_category_type category_type;
  to_category_type category_type;
BEGIN
  SELECT TYPE INTO from_category_type FROM public.categories WHERE id = p_from_category_id;
  SELECT TYPE INTO to_category_type FROM public.categories WHERE id = p_to_category_id;

  SELECT COUNT(*) INTO transaction_count
  FROM public.transactions
  WHERE category_id = p_from_category_id AND user_id = p_user_id;

  UPDATE public.transactions
    SET category_id = p_to_category_id,
        updated_at = TIMEZONE('utc' :: text, NOW())
  WHERE category_id = p_from_category_id AND user_id = p_user_id;

  -- No amount flipping because amounts are always positive & sign derived from category.type
  IF from_category_type != to_category_type THEN
    PERFORM public.recalculate_all_wallet_balances(p_user_id);
  END IF;
  RETURN transaction_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- =============================================
-- Membuat record di tabel transfers dan dua transaksi (expense di wallet sumber,
-- income di wallet tujuan). Opsi biaya admin akan dibuat sebagai transaksi expense
-- terpisah di wallet sumber. Semua operasi berjalan atomik di dalam 1 transaksi.
-- Catatan: amount & fee selalu positif; tanda +/- ditentukan oleh trigger transaksi
-- berdasarkan category.type.
-- Catatan Postgres: parameter tanpa default harus dideklarasikan sebelum parameter yang memiliki default
CREATE OR REPLACE FUNCTION public.create_wallet_transfer(
  p_user_id UUID,
  p_from_wallet_id UUID,
  p_to_wallet_id UUID,
  p_amount DECIMAL(15, 2),
  p_fee DECIMAL(15, 2) DEFAULT 0.00,
  p_notes TEXT DEFAULT NULL,
  p_date DATE DEFAULT CURRENT_DATE,
  p_fee_category_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_transfer_id UUID;
  v_from_owner UUID;
  v_to_owner UUID;
  v_fee_type category_type;
  v_from_balance DECIMAL(15, 2);
BEGIN
  -- Validasi dasar
  IF p_from_wallet_id = p_to_wallet_id THEN
    RAISE EXCEPTION 'Source and destination wallet must be different';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;
  IF p_fee IS NULL THEN
    p_fee := 0.00;
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

  -- Validasi kategori biaya (jika ada)
  IF p_fee > 0 AND p_fee_category_id IS NOT NULL THEN
    SELECT type INTO v_fee_type FROM public.categories WHERE id = p_fee_category_id AND user_id = p_user_id;
    IF v_fee_type IS DISTINCT FROM 'expense' THEN
      RAISE EXCEPTION 'Fee category must be expense';
    END IF;
  END IF;

  -- Cek saldo cukup (opsional hard-stop): sumber harus >= amount + fee
  SELECT balance INTO v_from_balance FROM public.wallets WHERE id = p_from_wallet_id AND user_id = p_user_id;
  IF v_from_balance IS NULL THEN
    RAISE EXCEPTION 'Source wallet not found';
  END IF;
  IF v_from_balance < (p_amount + COALESCE(p_fee, 0)) THEN
    RAISE EXCEPTION 'Insufficient funds in source wallet';
  END IF;

  -- Buat record transfer
  INSERT INTO public.transfers (
    user_id, from_wallet_id, to_wallet_id, amount, fee, notes, date
  ) VALUES (
    p_user_id, p_from_wallet_id, p_to_wallet_id, p_amount, p_fee, p_notes, p_date
  ) RETURNING id INTO v_transfer_id;

  -- Biaya admin (opsional) di wallet sumber sebagai transaksi Expense
  IF p_fee > 0 THEN
    IF p_fee_category_id IS NULL THEN
      RAISE EXCEPTION 'Fee category is required when fee > 0';
    END IF;
    INSERT INTO public.transactions (
      user_id, wallet_id, category_id, amount, notes, date
    ) VALUES (
      p_user_id, p_from_wallet_id, p_fee_category_id, p_fee, 'Transfer Fee' || CASE WHEN p_notes IS NOT NULL THEN ' - ' || p_notes ELSE '' END || ' [transfer:' || v_transfer_id || ']', p_date
    );
  END IF;

  RETURN v_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update existing wallet transfer atomically and sync fee expense transaction
CREATE OR REPLACE FUNCTION public.update_wallet_transfer(
  p_user_id UUID,
  p_transfer_id UUID,
  p_from_wallet_id UUID DEFAULT NULL,
  p_to_wallet_id UUID DEFAULT NULL,
  p_amount DECIMAL(15, 2) DEFAULT NULL,
  p_fee DECIMAL(15, 2) DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_date DATE DEFAULT NULL,
  p_fee_category_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_old RECORD;
  v_new_from UUID;
  v_new_to UUID;
  v_new_amount DECIMAL(15, 2);
  v_new_fee DECIMAL(15, 2);
  v_new_notes TEXT;
  v_new_date DATE;
  v_fee_tx RECORD;
  v_fee_type category_type;
BEGIN
  SELECT * INTO v_old FROM public.transfers WHERE id = p_transfer_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transfer not found';
  END IF;

  v_new_from := COALESCE(p_from_wallet_id, v_old.from_wallet_id);
  v_new_to := COALESCE(p_to_wallet_id, v_old.to_wallet_id);
  v_new_amount := COALESCE(p_amount, v_old.amount);
  v_new_fee := COALESCE(p_fee, v_old.fee);
  v_new_notes := COALESCE(p_notes, v_old.notes);
  v_new_date := COALESCE(p_date, v_old.date);

  IF v_new_from = v_new_to THEN
    RAISE EXCEPTION 'Source and destination wallet must be different';
  END IF;
  IF v_new_amount IS NULL OR v_new_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;
  IF v_new_fee IS NULL THEN v_new_fee := 0.00; END IF;

  -- Update transfer row (triggers will handle balance movements for amount/from/to changes)
  UPDATE public.transfers
    SET from_wallet_id = v_new_from,
        to_wallet_id = v_new_to,
        amount = v_new_amount,
        fee = v_new_fee,
        notes = v_new_notes,
        date = v_new_date,
        updated_at = TIMEZONE('utc' :: text, NOW())
  WHERE id = p_transfer_id AND user_id = p_user_id;

  -- Fee transaction handling remains the same as before
  -- Handle fee expense transaction linked by marker [transfer:<id>] in notes
  SELECT t.* INTO v_fee_tx
  FROM public.transactions t
  WHERE t.user_id = p_user_id
    AND t.notes LIKE ('%' || '[transfer:' || p_transfer_id || ']')
  ORDER BY t.created_at DESC
  LIMIT 1;

  IF v_old.fee > 0 AND v_new_fee > 0 THEN
    -- Update existing fee transaction (amount/date/wallet/notes)
    UPDATE public.transactions
      SET amount = v_new_fee,
          wallet_id = v_new_from,
          notes = ('Transfer Fee' || CASE WHEN v_new_notes IS NOT NULL THEN ' - ' || v_new_notes ELSE '' END || ' [transfer:' || p_transfer_id || ']'),
          date = v_new_date,
          updated_at = TIMEZONE('utc' :: text, NOW())
    WHERE id = v_fee_tx.id AND user_id = p_user_id;
  ELSIF v_old.fee > 0 AND v_new_fee = 0 THEN
    -- Remove fee transaction
    DELETE FROM public.transactions WHERE id = v_fee_tx.id AND user_id = p_user_id;
  ELSIF v_old.fee = 0 AND v_new_fee > 0 THEN
    -- Need fee category to create new expense
    IF p_fee_category_id IS NULL THEN
      RAISE EXCEPTION 'Fee category is required when adding a new fee';
    END IF;
    SELECT type INTO v_fee_type FROM public.categories WHERE id = p_fee_category_id AND user_id = p_user_id;
    IF v_fee_type IS DISTINCT FROM 'expense' THEN
      RAISE EXCEPTION 'Fee category must be expense';
    END IF;
    INSERT INTO public.transactions (user_id, wallet_id, category_id, amount, notes, date)
    VALUES (p_user_id, v_new_from, p_fee_category_id, v_new_fee,
            'Transfer Fee' || CASE WHEN v_new_notes IS NOT NULL THEN ' - ' || v_new_notes ELSE '' END || ' [transfer:' || p_transfer_id || ']',
            v_new_date);
  END IF;

  -- The improved trigger handles balance updates correctly, no manual recalculation needed
  RETURN p_transfer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete wallet transfer atomically: remove linked fee transaction(s) and let triggers handle balance
CREATE OR REPLACE FUNCTION public.delete_wallet_transfer(
  p_user_id UUID,
  p_transfer_id UUID
) RETURNS VOID AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 10) AUTH: BOOTSTRAP PROFIL USER PADA SIGNUP
-- =============================================
-- Membuat profil di public.users ketika user baru dibuat di auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- 11) ACCOUNT CLEANUP (DATA & FILES)
-- =============================================
-- Fungsi hapus file storage terkait user
CREATE OR REPLACE FUNCTION public.cleanup_user_storage_files(user_id_param UUID) RETURNS void AS $$
BEGIN
  DELETE FROM storage.objects
  WHERE bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = user_id_param::text;

  DELETE FROM storage.objects
  WHERE bucket_id = 'transaction-images'
    AND (storage.foldername(name))[1] = user_id_param::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fungsi hapus semua data user + akun
CREATE OR REPLACE FUNCTION public.delete_user_account() RETURNS void AS $$
DECLARE current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  DELETE FROM public.transaction_images WHERE user_id = current_user_id;
  DELETE FROM public.transactions WHERE user_id = current_user_id;
  DELETE FROM public.transfers WHERE user_id = current_user_id;
  DELETE FROM public.categories WHERE user_id = current_user_id;
  DELETE FROM public.wallets WHERE user_id = current_user_id;
  DELETE FROM public.users WHERE id = current_user_id;
  DELETE FROM auth.users WHERE id = current_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fungsi komprehensif: hapus file lalu data (wrapper)
CREATE OR REPLACE FUNCTION public.delete_user_account_complete() RETURNS void AS $$
DECLARE current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;
  PERFORM public.cleanup_user_storage_files(current_user_id);
  PERFORM public.delete_user_account();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 9.1) TRANSFER BALANCE TRIGGER (amount-only)
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_transfer_amount_only()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS handle_transfer_trigger ON public.transfers;
CREATE TRIGGER handle_transfer_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.transfers
FOR EACH ROW EXECUTE FUNCTION public.handle_transfer_amount_only();

-- =============================================
-- 9.2) VIEW: Unified ledger entries (transactions + transfers)
-- Read-only convenience view for client: shows signed amounts per wallet
-- kind: 'transaction' | 'transfer_out' | 'transfer_in'
-- Note: entry_id + kind can be used as a composite unique key on the client
CREATE OR REPLACE VIEW public.ledger_entries AS
  SELECT
    t.id AS entry_id,
    t.user_id,
    t.wallet_id,
    t.category_id,
    (t.amount * CASE c.type WHEN 'expense' THEN -1 ELSE 1 END) AS signed_amount,
    t.amount AS amount,
    t.date,
    t.notes,
    'transaction'::text AS kind,
    NULL::uuid AS transfer_id
  FROM public.transactions t
  JOIN public.categories c ON c.id = t.category_id

  UNION ALL

  SELECT
    tr.id AS entry_id,
    tr.user_id,
    tr.from_wallet_id AS wallet_id,
    NULL::uuid AS category_id,
    (-tr.amount) AS signed_amount,
    tr.amount AS amount,
    tr.date,
    tr.notes,
    'transfer_out'::text AS kind,
    tr.id AS transfer_id
  FROM public.transfers tr

  UNION ALL

  SELECT
    tr.id AS entry_id,
    tr.user_id,
    tr.to_wallet_id AS wallet_id,
    NULL::uuid AS category_id,
    tr.amount AS signed_amount,
    tr.amount AS amount,
    tr.date,
    tr.notes,
    'transfer_in'::text AS kind,
    tr.id AS transfer_id
  FROM public.transfers tr;