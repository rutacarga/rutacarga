create table if not exists public.vehicle_driver_associations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','active','rejected','ended')),
  owner_accepted_at timestamptz,
  driver_accepted_at timestamptz,
  ended_by uuid references public.profiles(id) on delete set null,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_driver_associations_vehicle_owner_match
    check (owner_id <> '00000000-0000-0000-0000-000000000000'::uuid)
);

create index if not exists vehicle_driver_associations_owner_idx
  on public.vehicle_driver_associations(owner_id, status, created_at desc);
create index if not exists vehicle_driver_associations_driver_idx
  on public.vehicle_driver_associations(driver_id, status, created_at desc);
create index if not exists vehicle_driver_associations_vehicle_idx
  on public.vehicle_driver_associations(vehicle_id, status, created_at desc);

create unique index if not exists vehicle_driver_associations_open_pair_uidx
  on public.vehicle_driver_associations(vehicle_id, driver_id)
  where status in ('pending','active');

alter table public.vehicle_driver_associations enable row level security;
drop policy if exists "Participants can view vehicle driver associations" on public.vehicle_driver_associations;
create policy "Participants can view vehicle driver associations"
  on public.vehicle_driver_associations
  for select to authenticated
  using (auth.uid() = owner_id or auth.uid() = driver_id);

revoke insert, update, delete on public.vehicle_driver_associations from anon, authenticated;
grant select on public.vehicle_driver_associations to authenticated;

create or replace function public.request_vehicle_driver_association(p_vehicle_id uuid,p_driver_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner_id uuid; v_driver_role text; v_association_id uuid; v_status text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  select owner_id into v_owner_id from public.vehicles where id=p_vehicle_id;
  if v_owner_id is null then raise exception 'No encontramos ese vehículo.'; end if;
  select role::text into v_driver_role from public.profiles where id=p_driver_id;
  if v_driver_role not in ('driver','owner_driver') then raise exception 'La cuenta seleccionada no tiene perfil de conductor.'; end if;
  if auth.uid() <> v_owner_id and auth.uid() <> p_driver_id then raise exception 'Solo el propietario o el conductor pueden solicitar esta asociación.'; end if;
  if exists(select 1 from public.vehicle_driver_associations where vehicle_id=p_vehicle_id and driver_id=p_driver_id and status in ('pending','active')) then
    raise exception 'Ya existe una asociación pendiente o activa entre este vehículo y conductor.';
  end if;
  v_status := case when v_owner_id=p_driver_id then 'active' else 'pending' end;
  insert into public.vehicle_driver_associations(owner_id,vehicle_id,driver_id,requested_by,status,owner_accepted_at,driver_accepted_at)
  values(v_owner_id,p_vehicle_id,p_driver_id,auth.uid(),v_status,
    case when auth.uid()=v_owner_id then now() end,
    case when auth.uid()=p_driver_id then now() end)
  returning id into v_association_id;
  if v_owner_id=p_driver_id then
    update public.vehicle_driver_associations set owner_accepted_at=now(),driver_accepted_at=now(),updated_at=now() where id=v_association_id;
  end if;
  return v_association_id;
end; $$;

create or replace function public.respond_vehicle_driver_association(p_association_id uuid,p_accept boolean)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare v_assoc public.vehicle_driver_associations%rowtype; v_owner_accepted timestamptz; v_driver_accepted timestamptz;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  select * into v_assoc from public.vehicle_driver_associations where id=p_association_id for update;
  if not found then raise exception 'No encontramos la solicitud.'; end if;
  if auth.uid() <> v_assoc.owner_id and auth.uid() <> v_assoc.driver_id then raise exception 'No tienes permiso para responder esta solicitud.'; end if;
  if v_assoc.status <> 'pending' then raise exception 'Esta solicitud ya no está pendiente.'; end if;
  if auth.uid()=v_assoc.requested_by then raise exception 'La solicitud debe ser respondida por la otra parte.'; end if;
  if not p_accept then
    update public.vehicle_driver_associations set status='rejected',updated_at=now() where id=p_association_id;
    return 'rejected';
  end if;
  v_owner_accepted:=v_assoc.owner_accepted_at; v_driver_accepted:=v_assoc.driver_accepted_at;
  if auth.uid()=v_assoc.owner_id then v_owner_accepted:=now(); end if;
  if auth.uid()=v_assoc.driver_id then v_driver_accepted:=now(); end if;
  update public.vehicle_driver_associations set owner_accepted_at=v_owner_accepted,driver_accepted_at=v_driver_accepted,
    status=case when v_owner_accepted is not null and v_driver_accepted is not null then 'active' else 'pending' end,
    updated_at=now() where id=p_association_id;
  return case when v_owner_accepted is not null and v_driver_accepted is not null then 'active' else 'pending' end;
end; $$;

create or replace function public.end_vehicle_driver_association(p_association_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_assoc public.vehicle_driver_associations%rowtype;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  select * into v_assoc from public.vehicle_driver_associations where id=p_association_id for update;
  if not found then raise exception 'No encontramos la asociación.'; end if;
  if auth.uid() <> v_assoc.owner_id and auth.uid() <> v_assoc.driver_id then raise exception 'No tienes permiso para finalizar esta asociación.'; end if;
  if v_assoc.status not in ('pending','active') then return false; end if;
  update public.vehicle_driver_associations set status='ended',ended_by=auth.uid(),ended_at=now(),updated_at=now() where id=p_association_id;
  return true;
end; $$;

revoke all on function public.request_vehicle_driver_association(uuid,uuid) from public,anon;
revoke all on function public.respond_vehicle_driver_association(uuid,boolean) from public,anon;
revoke all on function public.end_vehicle_driver_association(uuid) from public,anon;
grant execute on function public.request_vehicle_driver_association(uuid,uuid) to authenticated;
grant execute on function public.respond_vehicle_driver_association(uuid,boolean) to authenticated;
grant execute on function public.end_vehicle_driver_association(uuid) to authenticated;
