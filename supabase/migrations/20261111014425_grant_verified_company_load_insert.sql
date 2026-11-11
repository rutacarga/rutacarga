-- Allow authenticated verified companies to create real loads.
-- Row-level security still restricts company_id to auth.uid() and requires
-- empresa_ruta_carga_verificada(company_id). Column grants prevent clients
-- from overriding generated IDs and audit timestamps.
grant insert (
  company_id,
  origin_city,
  destination_city,
  cargo_type,
  vehicle_type,
  loading_date,
  payment,
  description,
  status
) on table public.company_loads to authenticated;
