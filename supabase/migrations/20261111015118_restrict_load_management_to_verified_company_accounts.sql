-- Separate operational publishing from administrator privileges.
-- Only a verified company account may create or edit its own real loads.
-- Admins retain read/oversight access and existing legacy listings remain visible.

DROP POLICY IF EXISTS "Verified companies publish loads" ON public.company_loads;
CREATE POLICY "Verified companies publish loads"
ON public.company_loads
FOR INSERT
TO authenticated
WITH CHECK (
  company_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'company'::public.account_role
      AND p.verification_status = 'verified'::public.verification_state
  )
  AND public.empresa_ruta_carga_verificada((SELECT auth.uid()))
);

DROP POLICY IF EXISTS "Companies update their own loads" ON public.company_loads;
CREATE POLICY "Companies update their own loads"
ON public.company_loads
FOR UPDATE
TO authenticated
USING (
  company_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'company'::public.account_role
      AND p.verification_status = 'verified'::public.verification_state
  )
  AND public.empresa_ruta_carga_verificada((SELECT auth.uid()))
)
WITH CHECK (
  company_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'company'::public.account_role
      AND p.verification_status = 'verified'::public.verification_state
  )
  AND public.empresa_ruta_carga_verificada((SELECT auth.uid()))
);
