# Supabase Setup Guide untuk Finoteku

## 🚀 Quick Setup

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

### 4. Setup Database
1. **Go to**: Supabase Dashboard > SQL Editor
2. **Execute** these files in order:
   - `supabase/schema.sql` (creates tables)
   - `supabase/policies.sql` (sets up security)
   - `supabase/storage.sql` (configures file storage)
   - `supabase/seed.sql` (optional - sample data)

### 5. Setup Storage Buckets
1. **Go to**: Supabase Dashboard > Storage
2. **Create bucket**:
   - **Name**: `transaction-images`
   - **Public**: ❌ (Private)
3. **Create bucket**:
   - **Name**: `avatars`
   - **Public**: ✅ (Public)

### 6. Test Connection
1. **Run app**:
   ```bash
   flutter run
   ```
2. **Check console** for "✅ Supabase initialized successfully"

## 📋 Detailed Setup Steps

### Database Schema Setup

#### Step 1: Run Schema
```sql
-- Copy and paste content from supabase/schema.sql
-- This creates all tables, indexes, and triggers
```

#### Step 2: Run Policies
```sql
-- Copy and paste content from supabase/policies.sql
-- This sets up Row Level Security
```

#### Step 3: Run Storage
```sql
-- Copy and paste content from supabase/storage.sql
-- This configures file storage policies
```

#### Step 4: Run Seed Data (Optional)
```sql
-- Copy and paste content from supabase/seed.sql
-- This adds sample data for testing
-- IMPORTANT: Replace 'your-test-user-uuid' with actual user ID
```

### Authentication Setup

#### Enable Email Authentication
1. **Go to**: Authentication > Settings
2. **Enable**: Email authentication
3. **Configure**: Site URL: `http://localhost:3000` (for development)

#### Optional: Social Authentication
1. **Go to**: Authentication > Settings > Auth Providers
2. **Enable**: Google, Apple, etc. (if needed)
3. **Configure**: OAuth credentials

### Security Configuration

#### Row Level Security (RLS)
- ✅ **Enabled** on all tables
- ✅ **Policies** restrict data access to user's own records
- ✅ **User profiles** automatically created on signup

#### API Security
- ✅ **anon key**: Safe to use in client apps
- ❌ **service_role key**: Never expose in client code
- ✅ **CORS**: Configured for your domain

## 🔧 Development Workflow

### 1. Local Development
```bash
# Start Flutter app
flutter run

# Check Supabase connection in console
# Should see: "✅ Supabase initialized successfully"
```

### 2. Testing Authentication
```dart
// In your app, test signup/signin
final authService = ref.read(authServiceProvider);

// Sign up
await authService.signUp(
  email: 'test@example.com',
  password: 'securepassword',
  fullName: 'Test User',
);

// Sign in
await authService.signIn(
  email: 'test@example.com',
  password: 'securepassword',
);
```

### 3. Database Operations
```dart
// Get Supabase client
final supabase = ref.read(supabaseProvider);

// Insert data
await supabase.from('wallets').insert({
  'name': 'My Wallet',
  'balance': 1000000,
  'currency': 'IDR',
});

// Query data
final wallets = await supabase
    .from('wallets')
    .select()
    .eq('user_id', SupabaseService.currentUserId);
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. "Supabase not initialized"
**Problem**: App crashes with initialization error
**Solution**: 
- Check `.env` file exists and has correct values
- Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Ensure you copied from correct location in Supabase dashboard

#### 2. "Invalid API key"
**Problem**: Authentication fails
**Solution**:
- Double-check anon key in `.env`
- Make sure you copied the full key (starts with `eyJ`)
- Verify project URL is correct

#### 3. "Row Level Security policy violation"
**Problem**: Database queries fail
**Solution**:
- Run `supabase/policies.sql` to set up RLS
- Make sure user is authenticated before queries
- Check user ID matches in policies

#### 4. "Storage bucket not found"
**Problem**: File upload fails
**Solution**:
- Create `transaction-images` and `avatars` buckets manually
- Run `supabase/storage.sql` for policies
- Check bucket names match exactly

### Debug Mode
Set `DEBUG_MODE=true` in `.env` for detailed logging:
```env
DEBUG_MODE=true
LOG_LEVEL=debug
```

### Production Checklist
- [ ] Environment set to `production`
- [ ] Real Supabase project (not test)
- [ ] Strong database password
- [ ] RLS enabled on all tables
- [ ] Storage policies configured
- [ ] `.env` file not committed to Git
- [ ] Service role key secured
- [ ] CORS configured for production domain

## 📚 Next Steps

1. **Authentication UI**: Implement login/signup screens
2. **Data Sync**: Set up offline-first sync
3. **Real-time Updates**: Enable live data updates
4. **Push Notifications**: Configure with Supabase
5. **Analytics**: Add user behavior tracking

## 🔗 Useful Links

- [Supabase Dashboard](https://supabase.com/dashboard)
- [Supabase Flutter Docs](https://supabase.com/docs/reference/dart)
- [Flutter Integration Guide](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Storage Management](https://supabase.com/docs/guides/storage)

---

**Need Help?** Check the Supabase documentation or contact the development team.
