-- Kebijakan Row Level Security (RLS) untuk Finoteku
-- Jalankan file ini SETELAH schema.sql

-- Aktifkan RLS pada semua tabel
-- 1) ENABLE RLS ON ALL TABLES
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;

-- Kebijakan akses untuk tabel users
-- 2) POLICIES: users
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Kebijakan akses untuk tabel wallets
-- 3) POLICIES: wallets
DROP POLICY IF EXISTS "Users can view own wallets" ON public.wallets;
CREATE POLICY "Users can view own wallets" ON public.wallets
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own wallets" ON public.wallets;
CREATE POLICY "Users can insert own wallets" ON public.wallets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own wallets" ON public.wallets;
CREATE POLICY "Users can update own wallets" ON public.wallets
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own wallets" ON public.wallets;
CREATE POLICY "Users can delete own wallets" ON public.wallets
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel categories
-- 4) POLICIES: categories
DROP POLICY IF EXISTS "Users can view own categories" ON public.categories;
CREATE POLICY "Users can view own categories" ON public.categories
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own categories" ON public.categories;
CREATE POLICY "Users can insert own categories" ON public.categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own categories" ON public.categories;
CREATE POLICY "Users can update own categories" ON public.categories
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own categories" ON public.categories;
CREATE POLICY "Users can delete own categories" ON public.categories
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel transactions
-- 5) POLICIES: transactions
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
CREATE POLICY "Users can update own transactions" ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;
CREATE POLICY "Users can delete own transactions" ON public.transactions
    FOR DELETE USING (auth.uid() = user_id);

-- Kebijakan akses untuk tabel transfers
-- 6) POLICIES: transfers
DROP POLICY IF EXISTS "Users can view own transfers" ON public.transfers;
CREATE POLICY "Users can view own transfers" ON public.transfers
    FOR SELECT USING (auth.uid() = user_id);

-- Optional: enforce RPC-only writes by disabling INSERT/UPDATE/DELETE policies below
-- (commented out intentionally to prevent direct writes that bypass balance logic)
-- DROP POLICY IF EXISTS "Users can insert own transfers" ON public.transfers;
-- DROP POLICY IF EXISTS "Users can update own transfers" ON public.transfers;
-- DROP POLICY IF EXISTS "Users can delete own transfers" ON public.transfers;
-- -- No CREATE POLICY for write operations to encourage using the RPC

-- Kebijakan akses untuk tabel transaction_images
-- 7) POLICIES: transaction_images
DROP POLICY IF EXISTS "Users can view own transaction images" ON public.transaction_images;
CREATE POLICY "Users can view own transaction images" ON public.transaction_images
        FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transaction images" ON public.transaction_images;
CREATE POLICY "Users can insert own transaction images" ON public.transaction_images
        FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transaction images" ON public.transaction_images;
CREATE POLICY "Users can update own transaction images" ON public.transaction_images
        FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own transaction images" ON public.transaction_images;
CREATE POLICY "Users can delete own transaction images" ON public.transaction_images
        FOR DELETE USING (auth.uid() = user_id);

-- 8) GRANTS: allow authenticated to call safe functions/RPCs
-- Note: Adjust roles if you use different ones
DO $$ BEGIN
    PERFORM 1 FROM pg_roles WHERE rolname = 'authenticated';
    IF FOUND THEN
                GRANT EXECUTE ON FUNCTION public.create_wallet_transfer(
                    UUID, UUID, UUID, DECIMAL, DECIMAL, TEXT, DATE, UUID
                ) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.recalculate_wallet_balance(UUID, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.recalculate_all_wallet_balances(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.update_wallet_transfer(UUID, UUID, UUID, UUID, DECIMAL, DECIMAL, TEXT, DATE, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.delete_wallet_transfer(UUID, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.transfer_transactions_to_wallet(UUID, UUID, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.transfer_transactions_to_category(UUID, UUID, UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.cleanup_user_storage_files(UUID) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
        GRANT EXECUTE ON FUNCTION public.delete_user_account_complete() TO authenticated;
    -- Read-only view for unified ledger
    GRANT SELECT ON TABLE public.ledger_entries TO authenticated;
    END IF;
END $$;
