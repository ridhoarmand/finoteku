-- =============================================
-- Finoteku Database Schema (Supabase)
-- Simple Personal Finance Tracker
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- CUSTOM TYPES
-- =============================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'category_type') THEN
        CREATE TYPE category_type AS ENUM ('income', 'expense');
    END IF;
END $$;

-- =============================================
-- TABLES
-- =============================================

-- Users (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    currency TEXT DEFAULT 'IDR',
    timezone TEXT DEFAULT 'Asia/Jakarta',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Wallets (simplified)
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency TEXT NOT NULL DEFAULT 'IDR',
    icon TEXT, -- Icon path from assets (banks/*.svg or ewallets/*.svg)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Categories (simplified)
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    type category_type NOT NULL,
    parent_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    icon_code_point BIGINT, -- Store Material Icons codePoint for custom icons (changed to BIGINT)
    color BIGINT, -- Store color as ARGB integer - changed to BIGINT to support unsigned 32-bit values
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Transactions (simplified)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    wallet_id UUID REFERENCES public.wallets(id) ON DELETE RESTRICT NOT NULL,
    category_id UUID REFERENCES public.categories(id) ON DELETE RESTRICT,
    amount DECIMAL(15,2) NOT NULL,
    notes TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Transaction Images (for multiple image uploads)
CREATE TABLE IF NOT EXISTS public.transaction_images (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE CASCADE NOT NULL,
    image_url TEXT NOT NULL,
    image_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Transfers (simplified)
CREATE TABLE IF NOT EXISTS public.transfers (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    from_wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
    to_wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    fee DECIMAL(15,2) DEFAULT 0.00,
    notes TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX idx_wallets_active ON public.wallets(user_id, is_active);
CREATE INDEX idx_categories_user_id ON public.categories(user_id);
CREATE INDEX idx_categories_type ON public.categories(user_id, type);
CREATE INDEX idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX idx_transactions_wallet_id ON public.transactions(wallet_id);
CREATE INDEX idx_transactions_category_id ON public.transactions(category_id);
CREATE INDEX idx_transactions_date ON public.transactions(user_id, date);
CREATE INDEX idx_transaction_images_user_id ON public.transaction_images(user_id);
CREATE INDEX idx_transaction_images_transaction_id ON public.transaction_images(transaction_id);
CREATE INDEX idx_transfers_user_id ON public.transfers(user_id);
CREATE INDEX idx_transfers_date ON public.transfers(user_id, date);
CREATE INDEX idx_transfers_wallets ON public.transfers(from_wallet_id, to_wallet_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to all tables
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.wallets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.transfers FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- WALLET BALANCE UPDATE TRIGGERS
-- =============================================

-- Function to update wallet balance when transaction changes
CREATE OR REPLACE FUNCTION public.update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle INSERT (new transaction)
    IF TG_OP = 'INSERT' THEN
        UPDATE public.wallets 
        SET balance = balance + NEW.amount
        WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
        RETURN NEW;
    END IF;
    
    -- Handle UPDATE (modify existing transaction)
    IF TG_OP = 'UPDATE' THEN
        -- If wallet changed, update both old and new wallet
        IF OLD.wallet_id != NEW.wallet_id THEN
            -- Remove from old wallet
            UPDATE public.wallets 
            SET balance = balance - OLD.amount
            WHERE id = OLD.wallet_id AND user_id = OLD.user_id;
            
            -- Add to new wallet
            UPDATE public.wallets 
            SET balance = balance + NEW.amount
            WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
        ELSE
            -- Same wallet, just update the difference
            UPDATE public.wallets 
            SET balance = balance - OLD.amount + NEW.amount
            WHERE id = NEW.wallet_id AND user_id = NEW.user_id;
        END IF;
        RETURN NEW;
    END IF;
    
    -- Handle DELETE (remove transaction)
    IF TG_OP = 'DELETE' THEN
        UPDATE public.wallets 
        SET balance = balance - OLD.amount
        WHERE id = OLD.wallet_id AND user_id = OLD.user_id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Add triggers to automatically update wallet balance
CREATE TRIGGER update_wallet_balance_on_transaction_insert
    AFTER INSERT ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

CREATE TRIGGER update_wallet_balance_on_transaction_update
    AFTER UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

CREATE TRIGGER update_wallet_balance_on_transaction_delete
    AFTER DELETE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

-- =============================================
-- WALLET BALANCE RECALCULATION FUNCTIONS
-- =============================================

-- Function to recalculate wallet balance from transactions
CREATE OR REPLACE FUNCTION public.recalculate_wallet_balance(p_wallet_id UUID, p_user_id UUID)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    calculated_balance DECIMAL(15,2);
BEGIN
    -- Calculate balance from sum of all transactions
    SELECT COALESCE(SUM(amount), 0) 
    INTO calculated_balance
    FROM public.transactions 
    WHERE wallet_id = p_wallet_id AND user_id = p_user_id;
    
    -- Update wallet with calculated balance
    UPDATE public.wallets 
    SET balance = calculated_balance,
        updated_at = TIMEZONE('utc'::text, NOW())
    WHERE id = p_wallet_id AND user_id = p_user_id;
    
    RETURN calculated_balance;
END;
$$ LANGUAGE plpgsql;

-- Function to recalculate all wallet balances for a user
CREATE OR REPLACE FUNCTION public.recalculate_all_wallet_balances(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    wallet_record RECORD;
BEGIN
    FOR wallet_record IN 
        SELECT id FROM public.wallets WHERE user_id = p_user_id
    LOOP
        PERFORM public.recalculate_wallet_balance(wallet_record.id, p_user_id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- CATEGORY TYPE CHANGE HANDLING
-- =============================================

-- Function to handle category type changes
CREATE OR REPLACE FUNCTION public.handle_category_type_change()
RETURNS TRIGGER AS $$
BEGIN
    -- If category type changed, flip all transaction amounts
    IF OLD.type != NEW.type THEN
        -- Update all transactions using this category
        UPDATE public.transactions 
        SET amount = -amount,
            updated_at = TIMEZONE('utc'::text, NOW())
        WHERE category_id = NEW.id AND user_id = NEW.user_id;
        
        -- Recalculate all affected wallet balances
        PERFORM public.recalculate_all_wallet_balances(NEW.user_id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for category type changes
CREATE TRIGGER handle_category_type_change_trigger
    AFTER UPDATE ON public.categories
    FOR EACH ROW 
    WHEN (OLD.type IS DISTINCT FROM NEW.type)
    EXECUTE FUNCTION public.handle_category_type_change();

-- =============================================
-- TRANSFER TRANSACTIONS FUNCTION
-- =============================================

-- Function to transfer transactions from one wallet to another
CREATE OR REPLACE FUNCTION public.transfer_transactions_to_wallet(
    p_from_wallet_id UUID,
    p_to_wallet_id UUID,
    p_user_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    transaction_count INTEGER;
BEGIN
    -- Count transactions to be transferred
    SELECT COUNT(*) INTO transaction_count
    FROM public.transactions
    WHERE wallet_id = p_from_wallet_id AND user_id = p_user_id;
    
    -- Transfer transactions
    UPDATE public.transactions
    SET wallet_id = p_to_wallet_id,
        updated_at = TIMEZONE('utc'::text, NOW())
    WHERE wallet_id = p_from_wallet_id AND user_id = p_user_id;
    
    -- Recalculate balances for both wallets
    PERFORM public.recalculate_wallet_balance(p_from_wallet_id, p_user_id);
    PERFORM public.recalculate_wallet_balance(p_to_wallet_id, p_user_id);
    
    RETURN transaction_count;
END;
$$ LANGUAGE plpgsql;

-- Function to transfer transactions from one category to another
CREATE OR REPLACE FUNCTION public.transfer_transactions_to_category(
    p_from_category_id UUID,
    p_to_category_id UUID,
    p_user_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    transaction_count INTEGER;
    from_category_type category_type;
    to_category_type category_type;
BEGIN
    -- Get category types
    SELECT type INTO from_category_type FROM public.categories WHERE id = p_from_category_id;
    SELECT type INTO to_category_type FROM public.categories WHERE id = p_to_category_id;
    
    -- Count transactions to be transferred
    SELECT COUNT(*) INTO transaction_count
    FROM public.transactions
    WHERE category_id = p_from_category_id AND user_id = p_user_id;
    
    -- Transfer transactions
    UPDATE public.transactions
    SET category_id = p_to_category_id,
        -- Flip amount if category types are different
        amount = CASE 
            WHEN from_category_type != to_category_type THEN -amount
            ELSE amount
        END,
        updated_at = TIMEZONE('utc'::text, NOW())
    WHERE category_id = p_from_category_id AND user_id = p_user_id;
    
    -- Recalculate all wallet balances if amounts were flipped
    IF from_category_type != to_category_type THEN
        PERFORM public.recalculate_all_wallet_balances(p_user_id);
    END IF;
    
    RETURN transaction_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- DELETE USER ACCOUNT FUNCTIONS
-- =============================================

-- Function to clean up user storage files
CREATE OR REPLACE FUNCTION public.cleanup_user_storage_files(user_id_param UUID)
RETURNS void AS $$
BEGIN
    -- Delete avatar files for the user
    DELETE FROM storage.objects 
    WHERE bucket_id = 'avatars' 
    AND (storage.foldername(name))[1] = user_id_param::text;
    
    -- Delete transaction image files for the user
    DELETE FROM storage.objects 
    WHERE bucket_id = 'transaction-images' 
    AND (storage.foldername(name))[1] = user_id_param::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete all user data and account
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- Delete user data in correct order (to handle foreign key constraints)
    
    -- 1. Delete transaction images first (references transactions)
    DELETE FROM public.transaction_images WHERE user_id = current_user_id;
    
    -- 2. Delete transactions (references wallets and categories)
    DELETE FROM public.transactions WHERE user_id = current_user_id;
    
    -- 3. Delete transfers (references wallets)
    DELETE FROM public.transfers WHERE user_id = current_user_id;
    
    -- 4. Delete categories (may have parent-child relationships)
    DELETE FROM public.categories WHERE user_id = current_user_id;
    
    -- 5. Delete wallets
    DELETE FROM public.wallets WHERE user_id = current_user_id;
    
    -- 6. Delete user profile (this will cascade to auth.users due to FK relationship)
    DELETE FROM public.users WHERE id = current_user_id;
    
    -- 7. Delete from auth.users (this should be done last)
    DELETE FROM auth.users WHERE id = current_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comprehensive function that deletes both data and files
CREATE OR REPLACE FUNCTION public.delete_user_account_complete()
RETURNS void AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current authenticated user ID
    current_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;

    -- First clean up storage files
    PERFORM public.cleanup_user_storage_files(current_user_id);
    
    -- Then delete all user data
    PERFORM public.delete_user_account();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
