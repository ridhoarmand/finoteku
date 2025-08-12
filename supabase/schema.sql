-- =============================================
-- Skema Database Finoteku (Supabase)
-- Aplikasi Pencatatan Keuangan Pribadi Sederhana
-- =============================================
-- Aktifkan ekstensi UUID (untuk generate id unik)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- TIPE KUSTOM (ENUM)
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
-- TABEL-TABEL INTI
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
  is_active BOOLEAN DEFAULT TRUE,
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
  color BIGINT,
  -- Menyimpan warna dalam integer ARGB
  is_active BOOLEAN DEFAULT TRUE,
  -- Menandai kategori masih aktif dipakai (soft disable)
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
-- INDEX (untuk performa query)
-- =============================================
CREATE INDEX idx_wallets_user_id ON public.wallets(user_id);

CREATE INDEX idx_wallets_active ON public.wallets(user_id, is_active);

CREATE INDEX idx_categories_user_id ON public.categories(user_id);

CREATE INDEX idx_categories_type ON public.categories(user_id, TYPE);

CREATE INDEX idx_categories_parent_id ON public.categories(parent_id);

CREATE INDEX idx_categories_hidden ON public.categories(user_id, is_hidden);

CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);

CREATE INDEX idx_transactions_wallet_id ON public.transactions(wallet_id);

CREATE INDEX idx_transactions_category_id ON public.transactions(category_id);

CREATE INDEX idx_transactions_date ON public.transactions(user_id, date);

CREATE INDEX idx_transaction_images_user_id ON public.transaction_images(user_id);

CREATE INDEX idx_transaction_images_transaction_id ON public.transaction_images(transaction_id);

CREATE INDEX idx_transfers_user_id ON public.transfers(user_id);

CREATE INDEX idx_transfers_date ON public.transfers(user_id, date);

CREATE INDEX idx_transfers_wallets ON public.transfers(from_wallet_id, to_wallet_id);

-- Fungsi trigger untuk mengisi kolom updated_at otomatis
CREATE OR REPLACE FUNCTION public.handle_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc' :: text, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tambahkan trigger updated_at ke semua tabel
CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.users FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.wallets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.categories FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE
UPDATE
  ON public.transfers FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- TRIGGER UNTUK PERBARUI SALDO WALLET
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
CREATE TRIGGER update_wallet_balance_on_transaction_insert
AFTER
INSERT
  ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

CREATE TRIGGER update_wallet_balance_on_transaction_update
AFTER
UPDATE
  ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

CREATE TRIGGER update_wallet_balance_on_transaction_delete
AFTER
  DELETE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

-- =============================================
-- FUNGSI REKALKULASI SALDO WALLET
-- =============================================
-- Fungsi untuk menghitung ulang saldo 1 wallet dari seluruh transaksinya
CREATE OR REPLACE FUNCTION public.recalculate_wallet_balance(p_wallet_id UUID, p_user_id UUID) RETURNS DECIMAL(15, 2) AS $$
DECLARE calculated_balance DECIMAL(15, 2);
BEGIN
  SELECT COALESCE(SUM(t.amount * CASE c.type WHEN 'expense' THEN -1 ELSE 1 END), 0)
    INTO calculated_balance
  FROM public.transactions t
  JOIN public.categories c ON c.id = t.category_id
  WHERE t.wallet_id = p_wallet_id AND t.user_id = p_user_id;
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
-- PENANGANAN PERUBAHAN TIPE KATEGORI
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

CREATE TRIGGER prevent_category_delete_trigger BEFORE DELETE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.prevent_category_delete();

-- =============================================
-- FUNGSI TRANSFER TRANSAKSI
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
-- FUNGSI PENGHAPUSAN AKUN USER (TERMASUK DATA & FILE)
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