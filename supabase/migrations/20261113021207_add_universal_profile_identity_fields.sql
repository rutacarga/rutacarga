ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS national_id text;
