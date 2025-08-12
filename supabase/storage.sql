-- Konfigurasi Storage Finoteku (jalankan di Supabase SQL Editor)

-- LANGKAH 1: Buat bucket jika belum ada
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('transaction-images', 'transaction-images', false, 5242880) -- 5MB limit
ON CONFLICT (id) DO NOTHING; -- Bucket transaksi (private)

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('avatars', 'avatars', true, 2097152) -- 2MB limit
ON CONFLICT (id) DO NOTHING; -- Bucket avatar (public)

-- LANGKAH 2 (opsional): Enable RLS di storage.objects bila belum
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- LANGKAH 3: Hapus policy lama untuk hindari konflik
DROP POLICY IF EXISTS "Users can upload their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

-- Policy bucket transaction-images
CREATE POLICY "Users can upload their own transaction images" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'transaction-images' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );
CREATE POLICY "Users can view their own transaction images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'transaction-images' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );
CREATE POLICY "Users can update their own transaction images" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'transaction-images' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );
CREATE POLICY "Users can delete their own transaction images" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'transaction-images' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Policy bucket avatars
CREATE POLICY "Users can upload their own avatar" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );
CREATE POLICY "Anyone can view avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Users can update their own avatar" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );
CREATE POLICY "Users can delete their own avatar" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Fungsi membuat signed URL (1 jam) untuk gambar transaksi
CREATE OR REPLACE FUNCTION public.get_transaction_image_url(file_path TEXT)
RETURNS TEXT AS $$
DECLARE
    signed_url TEXT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM storage.objects 
        WHERE bucket_id = 'transaction-images' 
        AND name = file_path 
        AND auth.uid()::text = (storage.foldername(name))[1]
    ) THEN
        RETURN NULL;
    END IF;
    SELECT storage.sign(file_path, 3600, 'transaction-images') INTO signed_url;
    RETURN signed_url;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fungsi bersihkan file yatim (tidak ada record)
CREATE OR REPLACE FUNCTION public.cleanup_orphaned_transaction_images()
RETURNS void AS $$
BEGIN
    DELETE FROM storage.objects 
    WHERE bucket_id = 'transaction-images' 
    AND NOT EXISTS (
        SELECT 1 FROM public.transaction_images 
        WHERE image_url LIKE '%' || storage.objects.name || '%'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Buat fungsi terjadwal untuk menjalankan pembersihan (jika Anda memiliki ekstensi pg_cron)
-- SELECT cron.schedule('cleanup-transaction-images', '0 2 * * *', 'SELECT public.cleanup_orphaned_transaction_images();');
