# Supabase Configuration for Finoteku

## 🚀 Complete Setup Guide

### 1. Create Supabase Project
1. **Visit**: [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. **Click**: "New Project"
3. **Fill in**:
   - **Name**: `finoteku-app`
   - **Database Password**: Generate strong password (save it!)
   - **Region**: Choose closest timezone (e.g., `Southeast Asia (Singapore)` for Indonesia)
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

### 4. Database Setup (Single Step)
1. **Go to**: Supabase Dashboard > SQL Editor
2. **Open** `supabase/setup.sql` in your text editor.
3. **Copy ALL content** from `setup.sql`.
4. **Paste** into the Supabase SQL Editor.
5. **Click**: "Run" to execute.

> **Note**: This single script will:
> - Create all tables (Users, Wallets, Transactions, etc.)
> - Configure indexes and triggers
> - Setup "Asia/Jakarta" timezone defaults
> - Enable Row Level Security (RLS) policies
> - Create Storage Buckets (Avatars, Transaction Images)
> - Setup Storage Policies

### 5. Verify Setup
Run this query in SQL Editor to confirm everything is ready:
```sql
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
```
Should show: `users`, `wallets`, `categories`, `transactions`, `transaction_images`, `transfers`, `bot_links`, `notification_reminders`.

### 6. Test Your App
1. **Run** your Flutter app: `flutter run`
2. **Try** creating an account.
3. **Check** that your user is created in the `users` table with timezone `Asia/Jakarta`.

## 📁 Project Structure
```
supabase/
├── README.md           # This setup guide
├── setup.sql           # COMPLETE database setup script
└── migrations/         # (Optional) Future migrations
```

## 🔄 Reset Database (Destructive)
If you need to wipe everything and start over:
1. Open SQL Editor.
2. Run content from `supabase/resetdb.sql`.
3. Re-run `supabase/setup.sql`.
