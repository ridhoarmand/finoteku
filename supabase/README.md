# Supabase Configuration for Finoteku

## Setup Instructions

### 1. Create Supabase Project
1. Go to [https://supabase.com](https://supabase.com)
2. Sign up/Login to your account
3. Create a new project:
   - **Name**: `finoteku-app`
   - **Database Password**: [Generate strong password]
   - **Region**: Choose closest to your users
4. Wait for project to be ready (2-3 minutes)

### 2. Get Project Credentials
After project is created, go to **Settings > API**:
- **Project URL**: `https://your-project-id.supabase.co`
- **Project API Key (anon public)**: `eyJ...` (public key)
- **Project API Key (service_role)**: `eyJ...` (private key - keep secret!)

### 3. Environment Configuration
Create `.env` file in project root with:
```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

### 4. Database Schema
Execute the SQL commands in `supabase/schema.sql` in your Supabase SQL Editor.

### 5. Row Level Security (RLS)
Execute the RLS policies in `supabase/policies.sql` for data security.

### 6. Storage Configuration  
Configure storage buckets using `supabase/storage.sql` for receipt files.

## Project Structure
```
supabase/
├── schema.sql          # Database tables and relationships
├── policies.sql        # Row Level Security policies
├── storage.sql         # Storage buckets configuration
├── functions.sql       # Database functions and triggers
└── seed.sql           # Sample data for development
```

## Security Notes
- ✅ Never commit `.env` file to Git
- ✅ Use Row Level Security for all tables
- ✅ Validate all inputs on client and server
- ✅ Use service role key only in secure environments
- ✅ Enable 2FA on Supabase account

## Next Steps
1. Complete Supabase project setup
2. Update `.env` file with your credentials
3. Run database migrations
4. Test connection with Flutter app
5. Implement authentication flow
