-- In-app update source for the Finoteku app (written by the app repo's release CI
-- with the service key, read by every app). Idempotent: the table may already exist.
CREATE TABLE IF NOT EXISTS public.app_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_versions
  ADD COLUMN IF NOT EXISTS build_number integer,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS changelog text,
  ADD COLUMN IF NOT EXISTS apk_url text,
  ADD COLUMN IF NOT EXISTS is_mandatory boolean NOT NULL DEFAULT false;

-- one row per released version; CI upserts on it
CREATE UNIQUE INDEX IF NOT EXISTS app_versions_version_key ON public.app_versions (version);

ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'app_versions' AND policyname = 'Anyone can read app versions') THEN
    CREATE POLICY "Anyone can read app versions" ON public.app_versions FOR SELECT USING (true);
  END IF;
END $$;
GRANT SELECT ON public.app_versions TO anon, authenticated;
