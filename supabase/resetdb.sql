-- =============================================
-- Complete Database Reset Script
-- WARNING: This will delete ALL data and structures
-- Run this to completely reset the database
-- =============================================
-- =============================================
-- DROP STORAGE BUCKETS AND POLICIES
-- =============================================
-- Delete all objects from storage buckets first
DELETE FROM
  STORAGE.objects
WHERE
  bucket_id IN ('avatars', 'transaction-images');

-- Drop storage bucket policies
DROP POLICY IF EXISTS "Users can view own avatar" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can upload own avatar" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can update own avatar" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can delete own avatar" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can view own transaction images" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can upload own transaction images" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can update own transaction images" ON STORAGE.objects;

DROP POLICY IF EXISTS "Users can delete own transaction images" ON STORAGE.objects;

-- Delete storage buckets
DELETE FROM
  STORAGE.buckets
WHERE
  id IN ('avatars', 'transaction-images');

-- =============================================
-- DROP ALL TRIGGERS (they depend on functions)
-- =============================================
-- Auth triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Table triggers
DROP TRIGGER IF EXISTS set_updated_at ON public.users;

DROP TRIGGER IF EXISTS set_updated_at ON public.wallets;

DROP TRIGGER IF EXISTS set_updated_at ON public.categories;

DROP TRIGGER IF EXISTS set_updated_at ON public.transactions;

DROP TRIGGER IF EXISTS set_updated_at ON public.transfers;

-- Wallet balance triggers
DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_insert ON public.transactions;

DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_update ON public.transactions;

DROP TRIGGER IF EXISTS update_wallet_balance_on_transaction_delete ON public.transactions;

DROP TRIGGER IF EXISTS update_wallet_balance_trigger ON public.transactions;

-- Category triggers
DROP TRIGGER IF EXISTS handle_category_type_change_trigger ON public.categories;

-- =============================================
-- DROP ALL FUNCTIONS
-- =============================================
-- Delete account functions
DROP FUNCTION IF EXISTS public.delete_user_account() CASCADE;

DROP FUNCTION IF EXISTS public.delete_user_account_complete() CASCADE;

DROP FUNCTION IF EXISTS public.cleanup_user_storage_files(UUID) CASCADE;

-- Auth functions
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Utility functions
DROP FUNCTION IF EXISTS public.handle_updated_at() CASCADE;

DROP FUNCTION IF EXISTS public.update_wallet_balance() CASCADE;

DROP FUNCTION IF EXISTS public.recalculate_wallet_balance(UUID, UUID) CASCADE;

DROP FUNCTION IF EXISTS public.recalculate_all_wallet_balances(UUID) CASCADE;

DROP FUNCTION IF EXISTS public.handle_category_type_change() CASCADE;

DROP FUNCTION IF EXISTS public.transfer_transactions_to_wallet(UUID, UUID, UUID) CASCADE;

DROP FUNCTION IF EXISTS public.transfer_transactions_to_category(UUID, UUID, UUID) CASCADE;

-- =============================================
-- DROP ALL POLICIES (RLS)
-- =============================================
-- Users policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

DROP POLICY IF EXISTS "Users can delete own profile" ON public.users;

-- Wallets policies
DROP POLICY IF EXISTS "Users can view own wallets" ON public.wallets;

DROP POLICY IF EXISTS "Users can create own wallets" ON public.wallets;

DROP POLICY IF EXISTS "Users can update own wallets" ON public.wallets;

DROP POLICY IF EXISTS "Users can delete own wallets" ON public.wallets;

-- Categories policies
DROP POLICY IF EXISTS "Users can view own categories" ON public.categories;

DROP POLICY IF EXISTS "Users can create own categories" ON public.categories;

DROP POLICY IF EXISTS "Users can update own categories" ON public.categories;

DROP POLICY IF EXISTS "Users can delete own categories" ON public.categories;

-- Transactions policies
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;

DROP POLICY IF EXISTS "Users can create own transactions" ON public.transactions;

DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;

DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;

-- Transaction images policies
DROP POLICY IF EXISTS "Users can view own transaction images" ON public.transaction_images;

DROP POLICY IF EXISTS "Users can create own transaction images" ON public.transaction_images;

DROP POLICY IF EXISTS "Users can update own transaction images" ON public.transaction_images;

DROP POLICY IF EXISTS "Users can delete own transaction images" ON public.transaction_images;

-- Transfers policies
DROP POLICY IF EXISTS "Users can view own transfers" ON public.transfers;

DROP POLICY IF EXISTS "Users can create own transfers" ON public.transfers;

DROP POLICY IF EXISTS "Users can update own transfers" ON public.transfers;

DROP POLICY IF EXISTS "Users can delete own transfers" ON public.transfers;

-- =============================================
-- DROP ALL TABLES
-- =============================================
-- Drop tables in correct order (considering foreign key dependencies)
DROP TABLE IF EXISTS public.transaction_images CASCADE;

DROP TABLE IF EXISTS public.transactions CASCADE;

DROP TABLE IF EXISTS public.transfers CASCADE;

DROP TABLE IF EXISTS public.categories CASCADE;

DROP TABLE IF EXISTS public.wallets CASCADE;

DROP TABLE IF EXISTS public.users CASCADE;

-- =============================================
-- DROP CUSTOM TYPES
-- =============================================
DROP TYPE IF EXISTS public.category_type CASCADE;

-- =============================================
-- DROP INDEXES
-- =============================================
-- Indexes will be automatically dropped with tables, but just in case:
DROP INDEX IF EXISTS public.idx_wallets_user_id;

DROP INDEX IF EXISTS public.idx_wallets_active;

DROP INDEX IF EXISTS public.idx_categories_user_id;

DROP INDEX IF EXISTS public.idx_categories_type;

DROP INDEX IF EXISTS public.idx_categories_parent_id;

DROP INDEX IF EXISTS public.idx_transactions_user_id;

DROP INDEX IF EXISTS public.idx_transactions_wallet_id;

DROP INDEX IF EXISTS public.idx_transactions_category_id;

DROP INDEX IF EXISTS public.idx_transactions_date;

DROP INDEX IF EXISTS public.idx_transaction_images_user_id;

DROP INDEX IF EXISTS public.idx_transaction_images_transaction_id;

DROP INDEX IF EXISTS public.idx_transfers_user_id;

DROP INDEX IF EXISTS public.idx_transfers_date;

DROP INDEX IF EXISTS public.idx_transfers_wallets;

-- =============================================
-- DISABLE RLS ON ALL TABLES (just in case)
-- =============================================
ALTER TABLE
  IF EXISTS public.users DISABLE ROW LEVEL SECURITY;

ALTER TABLE
  IF EXISTS public.wallets DISABLE ROW LEVEL SECURITY;

ALTER TABLE
  IF EXISTS public.categories DISABLE ROW LEVEL SECURITY;

ALTER TABLE
  IF EXISTS public.transactions DISABLE ROW LEVEL SECURITY;

ALTER TABLE
  IF EXISTS public.transaction_images DISABLE ROW LEVEL SECURITY;

ALTER TABLE
  IF EXISTS public.transfers DISABLE ROW LEVEL SECURITY;

-- =============================================
-- RESET COMPLETE
-- =============================================
-- Now you can run in this order:
-- 1. schema.sql (to create tables, functions, triggers)
-- 2. policies.sql (to set up RLS policies)
-- 3. storage.sql (to set up storage buckets and policies)
SELECT
  'Database reset complete! You can now run schema.sql, policies.sql, and storage.sql' AS message;