-- Kebijakan Row Level Security (RLS) untuk Finoteku
-- Jalankan file ini SETELAH schema.sql

-- Aktifkan RLS pada semua tabel
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;

-- Kebijakan akses untuk tabel users
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Kebijakan akses untuk tabel wallets
CREATE POLICY "Users can view own wallets" ON public.wallets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallets" ON public.wallets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wallets" ON public.wallets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own wallets" ON public.wallets
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel categories
CREATE POLICY "Users can view own categories" ON public.categories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories" ON public.categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories" ON public.categories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories" ON public.categories
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel transactions
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions" ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions" ON public.transactions
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel transfers
CREATE POLICY "Users can view own transfers" ON public.transfers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transfers" ON public.transfers
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transfers" ON public.transfers
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transfers" ON public.transfers
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel transaction_images
CREATE POLICY "Users can view own transaction images" ON public.transaction_images
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transaction images" ON public.transaction_images
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transaction images" ON public.transaction_images
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transaction images" ON public.transaction_images
    FOR DELETE USING (auth.uid() = user_id);

-- Fungsi otomatis membuat profil user saat signup di auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger eksekusi fungsi pembuatan profil user
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- CATATAN: Fungsi & trigger update saldo tidak didefinisikan di sini (ada di schema.sql)

-- Fungsi menyesuaikan saldo 2 wallet saat transfer INSERT/UPDATE/DELETE
CREATE OR REPLACE FUNCTION public.handle_transfer()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Kurangi saldo wallet sumber
        UPDATE public.wallets 
        SET balance = balance - (NEW.amount + NEW.fee)
        WHERE id = NEW.from_wallet_id;
        
        -- Tambah saldo wallet tujuan
        UPDATE public.wallets 
        SET balance = balance + NEW.amount
        WHERE id = NEW.to_wallet_id;
        
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Revert nilai lama
        UPDATE public.wallets 
        SET balance = balance + (OLD.amount + OLD.fee)
        WHERE id = OLD.from_wallet_id;
        
        UPDATE public.wallets 
        SET balance = balance - OLD.amount
        WHERE id = OLD.to_wallet_id;
        
        -- Terapkan nilai baru
        UPDATE public.wallets 
        SET balance = balance - (NEW.amount + NEW.fee)
        WHERE id = NEW.from_wallet_id;
        
        UPDATE public.wallets 
        SET balance = balance + NEW.amount
        WHERE id = NEW.to_wallet_id;
        
        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        -- Revert transfer
        UPDATE public.wallets 
        SET balance = balance + (OLD.amount + OLD.fee)
        WHERE id = OLD.from_wallet_id;
        
        UPDATE public.wallets 
        SET balance = balance - OLD.amount
        WHERE id = OLD.to_wallet_id;
        
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger jalankan fungsi transfer
CREATE TRIGGER handle_transfer_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.transfers
    FOR EACH ROW EXECUTE FUNCTION public.handle_transfer();
