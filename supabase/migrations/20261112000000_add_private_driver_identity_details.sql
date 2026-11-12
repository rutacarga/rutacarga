create table if not exists public.driver_verification_private_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  national_id text not null check (national_id ~ '^[0-9A-Za-z.-]{5,20}$'),
  phone_whatsapp text not null check (phone_whatsapp ~ '^\+?[0-9]{10,15}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.driver_verification_private_data is 'Datos personales privados usados exclusivamente para verificar conductores; nunca exponer en directorios públicos.';
create unique index if not exists driver_verification_private_data_national_id_uidx
  on public.driver_verification_private_data (lower(national_id));
alter table public.driver_verification_private_data enable row level security;
revoke all on public.driver_verification_private_data from anon, public;
grant select, insert, update on public.driver_verification_private_data to authenticated;
drop policy if exists "Drivers read own verification private data" on public.driver_verification_private_data;
create policy "Drivers read own verification private data"
on public.driver_verification_private_data for select to authenticated
using (user_id = (select auth.uid()));
drop policy if exists "Admins read verification private data" on public.driver_verification_private_data;
create policy "Admins read verification private data"
on public.driver_verification_private_data for select to authenticated
using ((select public.is_ruta_carga_admin()));
drop policy if exists "Eligible drivers insert own verification private data" on public.driver_verification_private_data;
create policy "Eligible drivers insert own verification private data"
on public.driver_verification_private_data for insert to authenticated
with check (
 user_id = (select auth.uid())
 and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid())
    and p.role in ('driver'::public.account_role,'owner'::public.account_role,'owner_driver'::public.account_role)
    and p.verification_status not in ('verified'::public.verification_state,'suspended'::public.verification_state)
 )
);
drop policy if exists "Eligible drivers update own verification private data" on public.driver_verification_private_data;
create policy "Eligible drivers update own verification private data"
on public.driver_verification_private_data for update to authenticated
using (
 user_id = (select auth.uid())
 and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid())
    and p.role in ('driver'::public.account_role,'owner'::public.account_role,'owner_driver'::public.account_role)
    and p.verification_status not in ('verified'::public.verification_state,'suspended'::public.verification_state)
 )
 and not exists (
  select 1 from public.driver_verifications v
  where v.user_id = (select auth.uid())
    and v.status not in ('rejected'::public.verification_state,'not_submitted'::public.verification_state)
 )
)
with check (
 user_id = (select auth.uid())
 and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid())
    and p.role in ('driver'::public.account_role,'owner'::public.account_role,'owner_driver'::public.account_role)
    and p.verification_status not in ('verified'::public.verification_state,'suspended'::public.verification_state)
 )
);
create or replace function public.submit_driver_verification(p_document_storage_path text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare uid uuid := auth.uid();
begin
 if uid is null then raise exception 'Debes iniciar sesión'; end if;
 if not exists(
   select 1 from public.profiles
   where id=uid
     and role in ('driver'::public.account_role,'owner'::public.account_role,'owner_driver'::public.account_role)
     and verification_status not in ('verified'::public.verification_state,'suspended'::public.verification_state)
 ) then raise exception 'Esta cuenta no puede solicitar verificación'; end if;
 if not exists(
   select 1 from public.driver_verification_private_data d
   where d.user_id=uid
     and d.national_id ~ '^[0-9A-Za-z.-]{5,20}$'
     and d.phone_whatsapp ~ '^\+?[0-9]{10,15}$'
 ) then raise exception 'Completa una cédula válida y un celular/WhatsApp válido antes de enviar'; end if;
 insert into public.driver_verifications(user_id,document_storage_path,status,submitted_at)
 values(uid,null,'pending'::public.verification_state,now())
 on conflict(user_id) do update
 set document_storage_path=null,status='pending'::public.verification_state,
     review_notes=null,submitted_at=now(),reviewed_at=null,reviewed_by=null,updated_at=now()
 where public.driver_verifications.status in ('not_submitted'::public.verification_state,'rejected'::public.verification_state);
 if not found then raise exception 'Ya existe una solicitud pendiente o aprobada'; end if;
end;
$function$;
revoke all on function public.submit_driver_verification(text) from public, anon;
grant execute on function public.submit_driver_verification(text) to authenticated;