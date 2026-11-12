-- Reconciliation record for changes already applied to staging and production.
-- IMPORTANT: This file documents the deployed definitions; do not re-apply it to
-- projects whose migration history already contains:
--   staging: 20261112222952, 20261112223037, 20261112223607
--   production: 20261112222951, 20261112223026, 20261112223609
--
-- Driver submission: require valid private identity data, permit only eligible
-- roles/states, keep document path NULL (driver UI currently does not upload),
-- and synchronize profile.verification_status to pending.
CREATE OR REPLACE FUNCTION public.submit_driver_verification(p_document_storage_path text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = uid
      AND role IN ('driver'::public.account_role, 'owner'::public.account_role, 'owner_driver'::public.account_role)
      AND verification_status NOT IN ('verified'::public.verification_state, 'suspended'::public.verification_state)
  ) THEN
    RAISE EXCEPTION 'Esta cuenta no puede solicitar verificación';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.driver_verification_private_data d
    WHERE d.user_id = uid
      AND d.national_id ~ '^[0-9A-Za-z.-]{5,20}$'
      AND d.phone_whatsapp ~ '^\+?[0-9]{10,15}$'
  ) THEN
    RAISE EXCEPTION 'Completa una cédula válida y un celular/WhatsApp válido antes de enviar';
  END IF;

  INSERT INTO public.driver_verifications(user_id, document_storage_path, status, submitted_at)
  VALUES (uid, NULL, 'pending'::public.verification_state, now())
  ON CONFLICT (user_id) DO UPDATE
    SET document_storage_path = NULL,
        status = 'pending'::public.verification_state,
        review_notes = NULL,
        submitted_at = now(),
        reviewed_at = NULL,
        reviewed_by = NULL,
        updated_at = now()
    WHERE public.driver_verifications.status IN (
      'not_submitted'::public.verification_state,
      'rejected'::public.verification_state
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ya existe una solicitud pendiente o aprobada';
  END IF;

  UPDATE public.profiles
  SET verification_status = 'pending'::public.verification_state,
      updated_at = now()
  WHERE id = uid;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_driver_verification(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_driver_verification(text) TO authenticated;

-- Company submission: validate ownership of any uploaded object before saving
-- its private storage path; preserve guarded resubmission state transitions.
CREATE OR REPLACE FUNCTION public.submit_company_verification(
  p_legal_name text,
  p_nit text,
  p_transport_authorization_reference text,
  p_document_storage_path text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_legal_name text := pg_catalog.btrim(p_legal_name);
  v_nit text := pg_catalog.btrim(p_nit);
  v_reference text := nullif(pg_catalog.btrim(p_transport_authorization_reference), '');
  v_document_path text := nullif(pg_catalog.btrim(p_document_storage_path), '');
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión'; END IF;
  IF v_legal_name IS NULL OR pg_catalog.char_length(v_legal_name) NOT BETWEEN 2 AND 200 THEN
    RAISE EXCEPTION 'La razón social debe tener entre 2 y 200 caracteres';
  END IF;
  IF v_nit IS NULL OR pg_catalog.char_length(v_nit) NOT BETWEEN 5 AND 30 THEN
    RAISE EXCEPTION 'El NIT debe tener entre 5 y 30 caracteres';
  END IF;
  IF v_reference IS NOT NULL AND pg_catalog.char_length(v_reference) > 120 THEN
    RAISE EXCEPTION 'La referencia de autorización no puede superar 120 caracteres';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_user_id
      AND p.role = 'company'::public.account_role
      AND p.verification_status <> 'suspended'::public.verification_state
  ) THEN
    RAISE EXCEPTION 'Solo una cuenta de empresa no suspendida puede solicitar verificación';
  END IF;

  IF v_document_path IS NOT NULL AND (
    pg_catalog.split_part(v_document_path, '/', 1) <> v_user_id::text
    OR NOT EXISTS (
      SELECT 1 FROM storage.objects o
      WHERE o.bucket_id = 'company-documents'
        AND o.name = v_document_path
        AND o.owner = v_user_id
    )
  ) THEN
    RAISE EXCEPTION 'El documento no existe en tu carpeta privada o no te pertenece';
  END IF;

  INSERT INTO public.company_verifications (
    user_id, legal_name, nit, transport_authorization_reference,
    document_storage_path, status, submitted_at
  )
  VALUES (
    v_user_id, v_legal_name, v_nit, v_reference,
    v_document_path, 'pending'::public.verification_state, pg_catalog.now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET legal_name = EXCLUDED.legal_name,
        nit = EXCLUDED.nit,
        transport_authorization_reference = EXCLUDED.transport_authorization_reference,
        document_storage_path = EXCLUDED.document_storage_path,
        status = 'pending'::public.verification_state,
        submitted_at = pg_catalog.now(),
        review_notes = NULL,
        reviewed_at = NULL,
        reviewed_by = NULL
  WHERE public.company_verifications.status IN (
    'rejected'::public.verification_state,
    'not_submitted'::public.verification_state
  );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ya existe una solicitud pendiente, aprobada o suspendida';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_company_verification(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_company_verification(text, text, text, text) TO authenticated;
