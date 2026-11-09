-- Create the default "Cash" wallet in the signup trigger instead of in the app.
-- The app did it right after signUp, which fails under RLS when email confirmation
-- is on (no session yet), and never ran for other signup paths.
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');

  INSERT INTO public.wallets (user_id, name, balance, currency, icon, is_hidden)
  VALUES (NEW.id, 'Cash', 0, 'IDR', 'cash', false);

  RETURN NEW;
END;
$$;
