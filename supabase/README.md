# Supabase Configuration for Finoteku

## 🚀 Complete Setup Guide

### 1. Create Supabase Project
1. **Visit**: [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. **Click**: "New Project"
3. **Fill in**:
   - **Name**: `finoteku-app`
   - **Database Password**: Generate strong password (save it!)
   - **Region**: Choose closest to your users (e.g., `Southeast Asia (Singapore)` for Indonesia)
4. **Click**: "Create new project"
5. **Wait**: 2-3 minutes for project to be ready

### 2. Get Your Credentials
1. **Go to**: Project Dashboard > Settings > API
2. **Copy these values**:
   ```
   Project URL: https://xxxxxxxxxxxxx.supabase.co
   anon public: eyJhbGciOiJIUzI1NiIsI...
   service_role: eyJhbGciOiJIUzI1NiIsI... (keep secret!)
   ```

### 3. Configure Your App
1. **Copy** `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. **Edit** `.env` file:
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
   ```

### 4. Setup Database Schema
1. **Go to**: Supabase Dashboard > SQL Editor
2. **Copy and paste** content from `supabase/schema.sql`
3. **Click**: "Run" to create all tables and relationships

### 5. Setup Row Level Security (RLS)
1. **In SQL Editor**, copy and paste content from `supabase/policies.sql`
2. **Click**: "Run" to enable security policies
3. This ensures users can only access their own data

### 6. Setup Storage Buckets
1. **Go to**: Supabase Dashboard > Storage
2. **Create bucket**:
   - **Name**: `transaction-images`
   - **Public**: ❌ (Private)
   - **File size limit**: 5MB
   - **Allowed MIME types**: `image/jpeg,image/png,image/webp`
3. **Create bucket**:
   - **Name**: `avatars`
   - **Public**: ✅ (Public)
   - **File size limit**: 2MB
   - **Allowed MIME types**: `image/jpeg,image/png,image/webp`

### 7. Setup Storage Policies
1. **In SQL Editor**, copy and paste content from `supabase/storage.sql`
2. **Click**: "Run" to configure storage security policies

### 8. Verify Setup
Run these queries in SQL Editor to verify everything is set up correctly:

#### Check Tables
```sql
SELECT schemaname, tablename FROM pg_tables 
WHERE schemaname = 'public';
```
Should show: `users`, `wallets`, `categories`, `transactions`, `transaction_images`, `transfers`

#### Check RLS Policies
```sql
SELECT schemaname, tablename, policyname FROM pg_policies 
WHERE schemaname = 'public';
```
Should show multiple policies for each table.

#### Check Storage Buckets
```sql
SELECT * FROM storage.buckets;
```
Should show: `avatars` (public: true), `transaction-images` (public: false)

### 9. Test Your App
1. **Run** your Flutter app: `flutter run`
2. **Try** creating an account
3. **Test** uploading an avatar
4. **Check** if data appears in Supabase Dashboard

## 📁 Project Structure
```
supabase/
├── README.md           # This setup guide
├── schema.sql          # Database tables and relationships
├── policies.sql        # Row Level Security policies
└── storage.sql         # Storage buckets configuration
```

## 🔐 Security Features
- ✅ **Row Level Security (RLS)**: Users can only access their own data
- ✅ **Authentication Required**: All operations require valid user session
- ✅ **Storage Security**: File uploads are user-scoped
- ✅ **Input Validation**: Server-side data validation

## 🗃️ Database Schema Overview

### Tables:
1. **users** - Extended user information
2. **wallets** - User's financial accounts (Cash, Bank, E-wallet, etc.) with custom icons
3. **categories** - Income/Expense categories (customizable)
4. **transactions** - Financial transactions
5. **transaction_images** - Receipt/proof images
6. **transfers** - Money transfers between wallets

### Storage:
1. **avatars/** - User profile pictures (public)
2. **transaction-images/** - Receipt images (private)

## 🚨 Security Notes
- ✅ Never commit `.env` file to Git
- ✅ Keep service_role key secret
- ✅ All user data is protected by RLS
- ✅ File uploads are user-scoped

## 🐛 Troubleshooting

### Error: "new row violates row-level security policy"
- **Solution**: Make sure RLS policies are created (run `policies.sql`)
- **Check**: User is authenticated when performing operations

### Error: "Bucket not found"
- **Solution**: Create storage buckets in Supabase Dashboard
- **Check**: Bucket names are exactly `avatars` and `transaction-images`

### Error: "relation does not exist"
- **Solution**: Run `schema.sql` to create database tables
- **Check**: All tables are created in the `public` schema

### Error: "File too large"
- **Solution**: Compress images or check bucket size limits
- **Note**: Avatars max 2MB, transaction images max 5MB
- ✅ Use service role key only in secure environments
- ✅ Enable 2FA on Supabase account

## Next Steps
1. Complete Supabase project setup
2. Update `.env` file with your credentials
3. Run database migrations
4. Test connection with Flutter app
5. Implement authentication flow

---

## 🔄 Reset Database (Destructive Reset)
Gunakan hanya jika ingin benar‑benar mulai bersih (SEMUA data hilang).

### Langkah Cepat
1. (Opsional) Backup data penting:
    ```bash
    pg_dump --data-only "$SUPABASE_DB_URL" > backup-data.sql
    ```
2. Buka Supabase Dashboard → SQL Editor.
3. Jalankan isi file: `supabase/resetdb.sql`.
4. Setelah sukses, jalankan BERURUTAN:
    1. `supabase/schema.sql`
    2. `supabase/policies.sql`
    3. `supabase/storage.sql`
5. (Opsional) Seed kategori & wallet default.
6. Login dari aplikasi untuk menciptakan row di `public.users` via trigger.

### Verifikasi Pasca Reset
```sql
SELECT tablename FROM pg_tables WHERE schemaname='public';
SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname='public';
SELECT * FROM storage.buckets;
```

### Kenapa Ada `resetdb.sql`?
File ini membersihkan: storage objects, policies, triggers, functions, RLS policies, tabel, types, index. Aman untuk memastikan tidak ada sisa struktur lama yang konflik.

### Catatan Trigger Saldo
- Versi final fungsi & trigger saldo ADA di `schema.sql` (3 trigger: insert/update/delete).
- Duplikasi `update_wallet_balance` & trigger gabungan SUDAH dihapus dari `policies.sql` agar tidak double update.

### Normalisasi Data (Jika Sebelum Reset Ingin Migrasi Saja)
Jika memilih migrasi incremental (tanpa reset penuh):
```sql
-- Pastikan kolom is_hidden
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false;
-- Ubah semua amount negatif jadi positif
UPDATE public.transactions SET amount = ABS(amount) WHERE amount < 0;
-- Tambahkan constraint (jika belum)
ALTER TABLE public.transactions
   ADD CONSTRAINT transactions_amount_positive CHECK (amount > 0) NOT VALID;
ALTER TABLE public.transactions VALIDATE CONSTRAINT transactions_amount_positive;
```
Lalu recalculation:
```sql
DO $$
DECLARE r RECORD; BEGIN
   FOR r IN SELECT id FROM public.users LOOP
      PERFORM public.recalculate_all_wallet_balances(r.id);
   END LOOP;
END;$$;
```

### Seed Minimal (Contoh)
```sql
INSERT INTO public.categories (user_id, name, type)
SELECT u.id, x.name, x.type::category_type
FROM public.users u
CROSS JOIN (VALUES
   ('Gaji','income'),
   ('Bonus','income'),
   ('Makan','expense'),
   ('Transport','expense'),
   ('Langganan','expense')
) AS x(name, type)
ON CONFLICT DO NOTHING;
```

### Checklist Selesai
- [ ] resetdb.sql sukses (pesan konfirmasi)
- [ ] schema.sql sukses
- [ ] policies.sql sukses (tanpa buat fungsi saldo duplikat)
- [ ] storage.sql sukses (bucket muncul)
- [ ] Login user baru berhasil & row di `public.users`
- [ ] Buat dompet + transaksi tes (saldo berubah sesuai)

---

Jika butuh skrip otomatis (CLI) nanti bisa ditambahkan. Dokumentasi ini cukup untuk proses manual aman.
