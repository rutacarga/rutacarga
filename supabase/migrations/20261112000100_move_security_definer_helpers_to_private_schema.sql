-- Keep SECURITY DEFINER authorization helpers outside PostgREST's exposed public schema.
-- The public wrappers remain SECURITY INVOKER so existing RLS policies and frontend
-- checks keep working, while the privileged implementations live in private.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE CREATE ON SCHEMA private FROM anon, authenticated;
GRANT USAGE ON SCHEMA private TO anon, authenticated;

CREATE OR REPLACE FUNCTION private.is_ruta_carga_verified_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND role = 'admin'::public.account_role
      AND verification_status = 'verified'::public.verification_state
  );
$function$;

CREATE OR REPLACE FUNCTION private.is_ruta_carga_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.is_ruta_carga_verified_admin();
$function$;

CREATE OR REPLACE FUNCTION private.empresa_ruta_carga_verificada(p_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = p_company_id
      AND p.verification_status = 'verified'::public.verification_state
      AND (
        (
          p.role = 'company'::public.account_role
          AND EXISTS (
            SELECT 1
            FROM public.company_verifications AS cv
            WHERE cv.user_id = p.id
              AND cv.status = 'verified'::public.verification_state
          )
        )
        OR p.role = 'admin'::public.account_role
      )
  );
$function$;

REVOKE ALL ON FUNCTION private.is_ruta_carga_verified_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_ruta_carga_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.empresa_ruta_carga_verificada(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.is_ruta_carga_verified_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_ruta_carga_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION private.empresa_ruta_carga_verificada(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_ruta_carga_verified_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.is_ruta_carga_verified_admin();
$function$;

CREATE OR REPLACE FUNCTION public.is_ruta_carga_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.is_ruta_carga_admin();
$function$;

CREATE OR REPLACE FUNCTION public.empresa_ruta_carga_verificada(p_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
  SELECT private.empresa_ruta_carga_verificada(p_company_id);
$function$;

REVOKE ALL ON FUNCTION public.is_ruta_carga_verified_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_ruta_carga_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.empresa_ruta_carga_verificada(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.is_ruta_carga_verified_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_ruta_carga_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.empresa_ruta_carga_verificada(uuid) TO authenticated;
