-- Sample data for Finoteku development
-- Execute this after schema.sql and policies.sql
-- Only for development/testing purposes

-- Note: This assumes you have a test user with a specific UUID
-- Replace 'your-test-user-uuid' with actual test user UUID from auth.users

-- Sample categories (Income)
INSERT INTO public.categories (id, user_id, name, type, icon) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'your-test-user-uuid', 'Salary', 'income', 'work'),
('550e8400-e29b-41d4-a716-446655440002', 'your-test-user-uuid', 'Freelance', 'income', 'laptop'),
('550e8400-e29b-41d4-a716-446655440003', 'your-test-user-uuid', 'Investment', 'income', 'trending_up'),
('550e8400-e29b-41d4-a716-446655440004', 'your-test-user-uuid', 'Gift', 'income', 'card_giftcard'),
('550e8400-e29b-41d4-a716-446655440005', 'your-test-user-uuid', 'Other Income', 'income', 'add_circle');

-- Sample categories (Expense)
INSERT INTO public.categories (id, user_id, name, type, icon) VALUES
('550e8400-e29b-41d4-a716-446655440006', 'your-test-user-uuid', 'Food & Dining', 'expense', 'restaurant'),
('550e8400-e29b-41d4-a716-446655440007', 'your-test-user-uuid', 'Transportation', 'expense', 'directions_car'),
('550e8400-e29b-41d4-a716-446655440008', 'your-test-user-uuid', 'Shopping', 'expense', 'shopping_cart'),
('550e8400-e29b-41d4-a716-446655440009', 'your-test-user-uuid', 'Bills & Utilities', 'expense', 'receipt'),
('550e8400-e29b-41d4-a716-44665544000a', 'your-test-user-uuid', 'Healthcare', 'expense', 'local_hospital'),
('550e8400-e29b-41d4-a716-44665544000b', 'your-test-user-uuid', 'Entertainment', 'expense', 'movie'),
('550e8400-e29b-41d4-a716-44665544000c', 'your-test-user-uuid', 'Education', 'expense', 'school'),
('550e8400-e29b-41d4-a716-44665544000d', 'your-test-user-uuid', 'Travel', 'expense', 'flight');

-- Sub-categories for Food & Dining
INSERT INTO public.categories (id, user_id, name, type, parent_id, icon) VALUES
('550e8400-e29b-41d4-a716-44665544000e', 'your-test-user-uuid', 'Restaurant', 'expense', '550e8400-e29b-41d4-a716-446655440006', 'restaurant'),
('550e8400-e29b-41d4-a716-44665544000f', 'your-test-user-uuid', 'Fast Food', 'expense', '550e8400-e29b-41d4-a716-446655440006', 'fastfood'),
('550e8400-e29b-41d4-a716-446655440010', 'your-test-user-uuid', 'Groceries', 'expense', '550e8400-e29b-41d4-a716-446655440006', 'local_grocery_store'),
('550e8400-e29b-41d4-a716-446655440011', 'your-test-user-uuid', 'Coffee & Tea', 'expense', '550e8400-e29b-41d4-a716-446655440006', 'local_cafe');

-- Sample wallets
INSERT INTO public.wallets (id, user_id, name, balance, currency, icon) VALUES
('550e8400-e29b-41d4-a716-446655440020', 'your-test-user-uuid', 'Cash', 500000.00, 'IDR', 'money'),
('550e8400-e29b-41d4-a716-446655440021', 'your-test-user-uuid', 'BCA Savings', 15000000.00, 'IDR', 'account_balance'),
('550e8400-e29b-41d4-a716-446655440022', 'your-test-user-uuid', 'Mandiri Checking', 8500000.00, 'IDR', 'account_balance'),
('550e8400-e29b-41d4-a716-446655440023', 'your-test-user-uuid', 'GoPay', 250000.00, 'IDR', 'account_balance_wallet'),
('550e8400-e29b-41d4-a716-446655440024', 'your-test-user-uuid', 'OVO', 150000.00, 'IDR', 'account_balance_wallet'),
('550e8400-e29b-41d4-a716-446655440025', 'your-test-user-uuid', 'BCA Credit Card', -2500000.00, 'IDR', 'credit_card');

-- Sample transactions (last 30 days)
INSERT INTO public.transactions (id, user_id, wallet_id, category_id, amount, notes, date) VALUES
-- Income transactions
('550e8400-e29b-41d4-a716-446655440030', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-446655440001', 12000000.00, 'Monthly Salary', CURRENT_DATE - INTERVAL '5 days'),
('550e8400-e29b-41d4-a716-446655440031', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-446655440002', 3500000.00, 'Website Development Project', CURRENT_DATE - INTERVAL '10 days'),
('550e8400-e29b-41d4-a716-446655440032', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440022', '550e8400-e29b-41d4-a716-446655440003', 850000.00, 'Stock Dividend', CURRENT_DATE - INTERVAL '15 days'),

-- Expense transactions
('550e8400-e29b-41d4-a716-446655440033', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440020', '550e8400-e29b-41d4-a716-44665544000e', 250000.00, 'Dinner at Sushi Restaurant', CURRENT_DATE - INTERVAL '1 days'),
('550e8400-e29b-41d4-a716-446655440034', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440023', '550e8400-e29b-41d4-a716-446655440007', 45000.00, 'GoJek ride to office', CURRENT_DATE - INTERVAL '2 days'),
('550e8400-e29b-41d4-a716-446655440035', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-446655440010', 450000.00, 'Weekly groceries', CURRENT_DATE - INTERVAL '3 days'),
('550e8400-e29b-41d4-a716-446655440036', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440025', '550e8400-e29b-41d4-a716-446655440008', 1200000.00, 'New smartphone', CURRENT_DATE - INTERVAL '7 days'),
('550e8400-e29b-41d4-a716-446655440037', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440022', '550e8400-e29b-41d4-a716-446655440009', 850000.00, 'Electricity bill', CURRENT_DATE - INTERVAL '12 days'),
('550e8400-e29b-41d4-a716-446655440038', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440024', '550e8400-e29b-41d4-a716-446655440011', 35000.00, 'Morning coffee', CURRENT_DATE - INTERVAL '1 days'),
('550e8400-e29b-41d4-a716-446655440039', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440020', '550e8400-e29b-41d4-a716-44665544000f', 85000.00, 'McDonald lunch', CURRENT_DATE - INTERVAL '4 days'),
('550e8400-e29b-41d4-a716-44665544003a', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-44665544000a', 350000.00, 'Doctor consultation', CURRENT_DATE - INTERVAL '8 days');

-- Sample transfer
INSERT INTO public.transfers (id, user_id, from_wallet_id, to_wallet_id, amount, fee, notes, date) VALUES
('550e8400-e29b-41d4-a716-446655440040', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-446655440020', 1000000.00, 0.00, 'Cash withdrawal from ATM', CURRENT_DATE - INTERVAL '6 days'),
('550e8400-e29b-41d4-a716-446655440041', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440021', '550e8400-e29b-41d4-a716-446655440023', 500000.00, 2500.00, 'Top up GoPay', CURRENT_DATE - INTERVAL '14 days');

-- Sample transaction images
INSERT INTO public.transaction_images (id, user_id, transaction_id, image_url, description) VALUES
('550e8400-e29b-41d4-a716-446655440080', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440033', 'your-test-user-uuid/receipts/sushi-receipt.jpg', 'Receipt from sushi restaurant'),
('550e8400-e29b-41d4-a716-446655440081', 'your-test-user-uuid', '550e8400-e29b-41d4-a716-446655440037', 'your-test-user-uuid/receipts/electricity-bill.jpg', 'Electricity bill payment');

-- Update wallet balances to reflect transactions (this is normally handled by triggers)
-- But for seed data, we'll set them manually since we're inserting historical data
UPDATE public.wallets SET balance = 500000.00 WHERE id = '550e8400-e29b-41d4-a716-446655440020'; -- Cash
UPDATE public.wallets SET balance = 15000000.00 WHERE id = '550e8400-e29b-41d4-a716-446655440021'; -- BCA Savings  
UPDATE public.wallets SET balance = 8500000.00 WHERE id = '550e8400-e29b-41d4-a716-446655440022'; -- Mandiri
UPDATE public.wallets SET balance = 250000.00 WHERE id = '550e8400-e29b-41d4-a716-446655440023'; -- GoPay
UPDATE public.wallets SET balance = 150000.00 WHERE id = '550e8400-e29b-41d4-a716-446655440024'; -- OVO
UPDATE public.wallets SET balance = -2500000.00 WHERE id = '550e8400-e29b-41d4-a716-446655440025'; -- Credit Card
