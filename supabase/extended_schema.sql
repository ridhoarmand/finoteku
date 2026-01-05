-- =============================================
-- Extended Finoteku Schema: Bot Links & Notification Reminders
-- Jalankan SQL ini di Supabase SQL Editor
-- =============================================

-- =============================================
-- 1) BOT LINKS - Multi-platform chat integration
-- =============================================
CREATE TABLE IF NOT EXISTS public.bot_links (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  platform TEXT NOT NULL,              -- 'telegram', 'whatsapp', dll
  platform_user_id TEXT NOT NULL,      -- ID user di platform (e.g., telegram_id)
  platform_username TEXT,              -- Username di platform (nullable)
  is_active BOOLEAN DEFAULT TRUE,
  -- AI Configuration (per-user, optional)
  ai_provider TEXT DEFAULT 'none',     -- 'none', 'gemini', 'openai', 'anthropic'
  ai_api_key TEXT,                     -- Encrypted API key (nullable)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('Asia/Jakarta'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('Asia/Jakarta'::text, NOW()) NOT NULL,
  -- Constraints
  UNIQUE(platform, platform_user_id),  -- Satu ID platform hanya bisa link ke 1 user
  UNIQUE(user_id, platform)            -- Satu user hanya bisa punya 1 link per platform
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bot_links_user_id ON public.bot_links(user_id);
CREATE INDEX IF NOT EXISTS idx_bot_links_platform_lookup ON public.bot_links(platform, platform_user_id);

-- RLS
ALTER TABLE public.bot_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own bot links" ON public.bot_links;
CREATE POLICY "Users can view own bot links" ON public.bot_links
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own bot links" ON public.bot_links;
CREATE POLICY "Users can create own bot links" ON public.bot_links
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own bot links" ON public.bot_links;
CREATE POLICY "Users can update own bot links" ON public.bot_links
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own bot links" ON public.bot_links;
CREATE POLICY "Users can delete own bot links" ON public.bot_links
  FOR DELETE USING (auth.uid() = user_id);

-- Trigger untuk updated_at
DROP TRIGGER IF EXISTS set_updated_at ON public.bot_links;
CREATE TRIGGER set_updated_at BEFORE UPDATE
  ON public.bot_links FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- 2) NOTIFICATION REMINDERS - Cross-device sync
-- =============================================
CREATE TABLE IF NOT EXISTS public.notification_reminders (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  hour INT NOT NULL CHECK (hour >= 0 AND hour <= 23),
  minute INT NOT NULL CHECK (minute >= 0 AND minute <= 59),
  is_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('Asia/Jakarta'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('Asia/Jakarta'::text, NOW()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notification_reminders_user_id ON public.notification_reminders(user_id);

-- RLS
ALTER TABLE public.notification_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own reminders" ON public.notification_reminders;
CREATE POLICY "Users can view own reminders" ON public.notification_reminders
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own reminders" ON public.notification_reminders;
CREATE POLICY "Users can create own reminders" ON public.notification_reminders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own reminders" ON public.notification_reminders;
CREATE POLICY "Users can update own reminders" ON public.notification_reminders
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own reminders" ON public.notification_reminders;
CREATE POLICY "Users can delete own reminders" ON public.notification_reminders
  FOR DELETE USING (auth.uid() = user_id);

-- Trigger untuk updated_at
DROP TRIGGER IF EXISTS set_updated_at ON public.notification_reminders;
CREATE TRIGGER set_updated_at BEFORE UPDATE
  ON public.notification_reminders FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- 3) FUNCTION: Lookup user by platform (untuk Edge Function)
-- =============================================
CREATE OR REPLACE FUNCTION public.get_user_by_platform_id(
  p_platform TEXT,
  p_platform_user_id TEXT
) RETURNS TABLE (
  user_id UUID,
  ai_provider TEXT,
  ai_api_key TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT bl.user_id, bl.ai_provider, bl.ai_api_key
  FROM public.bot_links bl
  WHERE bl.platform = p_platform
    AND bl.platform_user_id = p_platform_user_id
    AND bl.is_active = TRUE
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute untuk service role (Edge Function)
GRANT EXECUTE ON FUNCTION public.get_user_by_platform_id(TEXT, TEXT) TO service_role;
