DROP POLICY IF EXISTS "Usuario registra su propio contacto" ON public.company_public_contacts;
DROP POLICY IF EXISTS "Usuario actualiza su propio contacto" ON public.company_public_contacts;

CREATE POLICY "Empresa gestiona su contacto privado"
ON public.company_public_contacts
FOR INSERT
TO authenticated
WITH CHECK (
  company_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'company'::public.account_role
      AND p.verification_status <> 'suspended'::public.verification_state
  )
  AND (
    publicly_visible = false
    OR public.empresa_ruta_carga_verificada((SELECT auth.uid()))
  )
);

CREATE POLICY "Empresa actualiza su contacto privado"
ON public.company_public_contacts
FOR UPDATE
TO authenticated
USING (
  company_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'company'::public.account_role
      AND p.verification_status <> 'suspended'::public.verification_state
  )
)
WITH CHECK (
  company_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'company'::public.account_role
      AND p.verification_status <> 'suspended'::public.verification_state
  )
  AND (
    publicly_visible = false
    OR public.empresa_ruta_carga_verificada((SELECT auth.uid()))
  )
);
