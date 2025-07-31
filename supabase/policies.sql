-- Row Level Security Policies for Finoteku
-- Execute this after schema.sql

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;

-- Users Policies
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Wallets Policies
CREATE POLICY "Users can view own wallets" ON public.wallets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallets" ON public.wallets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wallets" ON public.wallets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own wallets" ON public.wallets
    FOR DELETE USING (auth.uid() = user_id);

-- Categories Policies
CREATE POLICY "Users can view own categories" ON public.categories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories" ON public.categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories" ON public.categories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories" ON public.categories
    FOR DELETE USING (auth.uid() = user_id);

-- Transactions Policies
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions" ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions" ON public.transactions
    FOR DELETE USING (auth.uid() = user_id);

-- Transfers Policies
CREATE POLICY "Users can view own transfers" ON public.transfers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transfers" ON public.transfers
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transfers" ON public.transfers
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transfers" ON public.transfers
    FOR DELETE USING (auth.uid() = user_id);

-- Transaction Images Policies
CREATE POLICY "Users can view own transaction images" ON public.transaction_images
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transaction images" ON public.transaction_images
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transaction images" ON public.transaction_images
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transaction images" ON public.transaction_images
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile on signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update wallet balance on transaction changes
CREATE OR REPLACE FUNCTION public.update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle INSERT
    IF TG_OP = 'INSERT' THEN
        -- Determine if it's income or expense based on category
        DECLARE
            category_type TEXT;
        BEGIN
            SELECT type INTO category_type 
            FROM public.categories 
            WHERE id = NEW.category_id;
            
            IF category_type = 'income' THEN
                UPDATE public.wallets 
                SET balance = balance + NEW.amount 
                WHERE id = NEW.wallet_id;
            ELSIF category_type = 'expense' THEN
                UPDATE public.wallets 
                SET balance = balance - NEW.amount 
                WHERE id = NEW.wallet_id;
            END IF;
        END;
        RETURN NEW;
    END IF;

    -- Handle UPDATE
    IF TG_OP = 'UPDATE' THEN
        DECLARE
            old_category_type TEXT;
            new_category_type TEXT;
        BEGIN
            -- Get old and new category types
            SELECT type INTO old_category_type 
            FROM public.categories 
            WHERE id = OLD.category_id;
            
            SELECT type INTO new_category_type 
            FROM public.categories 
            WHERE id = NEW.category_id;
            
            -- Revert old transaction
            IF old_category_type = 'income' THEN
                UPDATE public.wallets 
                SET balance = balance - OLD.amount 
                WHERE id = OLD.wallet_id;
            ELSIF old_category_type = 'expense' THEN
                UPDATE public.wallets 
                SET balance = balance + OLD.amount 
                WHERE id = OLD.wallet_id;
            END IF;
            
            -- Apply new transaction
            IF new_category_type = 'income' THEN
                UPDATE public.wallets 
                SET balance = balance + NEW.amount 
                WHERE id = NEW.wallet_id;
            ELSIF new_category_type = 'expense' THEN
                UPDATE public.wallets 
                SET balance = balance - NEW.amount 
                WHERE id = NEW.wallet_id;
            END IF;
        END;
        RETURN NEW;
    END IF;

    -- Handle DELETE
    IF TG_OP = 'DELETE' THEN
        DECLARE
            category_type TEXT;
        BEGIN
            SELECT type INTO category_type 
            FROM public.categories 
            WHERE id = OLD.category_id;
            
            IF category_type = 'income' THEN
                UPDATE public.wallets 
                SET balance = balance - OLD.amount 
                WHERE id = OLD.wallet_id;
            ELSIF category_type = 'expense' THEN
                UPDATE public.wallets 
                SET balance = balance + OLD.amount 
                WHERE id = OLD.wallet_id;
            END IF;
        END;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update wallet balance on transaction changes
CREATE TRIGGER update_wallet_balance_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_wallet_balance();

-- Create function to handle transfer transactions
CREATE OR REPLACE FUNCTION public.handle_transfer()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Deduct from source wallet
        UPDATE public.wallets 
        SET balance = balance - (NEW.amount + NEW.fee)
        WHERE id = NEW.from_wallet_id;
        
        -- Add to destination wallet
        UPDATE public.wallets 
        SET balance = balance + NEW.amount
        WHERE id = NEW.to_wallet_id;
        
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Revert old transfer
        UPDATE public.wallets 
        SET balance = balance + (OLD.amount + OLD.fee)
        WHERE id = OLD.from_wallet_id;
        
        UPDATE public.wallets 
        SET balance = balance - OLD.amount
        WHERE id = OLD.to_wallet_id;
        
        -- Apply new transfer
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

-- Trigger to handle transfer balance updates
CREATE TRIGGER handle_transfer_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.transfers
    FOR EACH ROW EXECUTE FUNCTION public.handle_transfer();
