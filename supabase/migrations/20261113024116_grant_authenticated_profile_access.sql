-- Allow signed-in users to read/update profiles; row access remains restricted by RLS.
-- The existing SELECT policy permits own profile + admin reads.
-- The existing UPDATE policy permits updates only to the caller's own profile.
grant select, update on table public.profiles to authenticated;
