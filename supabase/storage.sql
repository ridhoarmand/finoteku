-- Storage configuration for Finoteku
-- Execute this in Supabase SQL Editor

-- STEP 1: Create storage buckets programmatically
-- Insert transaction-images bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('transaction-images', 'transaction-images', false, 5242880) -- 5MB limit
ON CONFLICT (id) DO NOTHING;

-- Insert avatars bucket if it doesn't exist  
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('avatars', 'avatars', true, 2097152) -- 2MB limit
ON CONFLICT (id) DO NOTHING;

-- STEP 2: Enable RLS on storage.objects (usually enabled by default)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- STEP 3: Create storage policies

-- Drop existing policies first (if they exist)
DROP POLICY IF EXISTS "Users can upload their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own transaction images" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

-- Storage policies for transaction-images bucket
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

-- Storage policies for avatars bucket
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

-- Create function to generate signed URL for transaction images
CREATE OR REPLACE FUNCTION public.get_transaction_image_url(file_path TEXT)
RETURNS TEXT AS $$
DECLARE
    signed_url TEXT;
BEGIN
    -- Check if user owns the file
    IF NOT EXISTS (
        SELECT 1 FROM storage.objects 
        WHERE bucket_id = 'transaction-images' 
        AND name = file_path 
        AND auth.uid()::text = (storage.foldername(name))[1]
    ) THEN
        RETURN NULL;
    END IF;
    
    -- Generate signed URL (valid for 1 hour)
    SELECT storage.sign(file_path, 3600, 'transaction-images') INTO signed_url;
    RETURN signed_url;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to clean up orphaned transaction image files
CREATE OR REPLACE FUNCTION public.cleanup_orphaned_transaction_images()
RETURNS void AS $$
BEGIN
    -- Delete storage objects that don't have corresponding transaction_images records
    DELETE FROM storage.objects 
    WHERE bucket_id = 'transaction-images' 
    AND NOT EXISTS (
        SELECT 1 FROM public.transaction_images 
        WHERE image_url LIKE '%' || storage.objects.name || '%'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create scheduled function to run cleanup (if you have pg_cron extension)
-- SELECT cron.schedule('cleanup-transaction-images', '0 2 * * *', 'SELECT public.cleanup_orphaned_transaction_images();');
