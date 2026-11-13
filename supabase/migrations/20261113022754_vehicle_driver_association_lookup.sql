create or replace function public.find_driver_for_association(p_whatsapp text)
returns table(driver_id uuid,full_name text,city text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_phone text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  if not exists(select 1 from public.profiles where id=auth.uid() and role::text in ('owner','owner_driver','company')) then
    raise exception 'Esta búsqueda está disponible para propietarios y empresas.';
  end if;
  v_phone:=regexp_replace(coalesce(p_whatsapp,''),'[^0-9]','','g');
  if length(v_phone)<10 or length(v_phone)>15 then raise exception 'Escribe el WhatsApp completo del conductor.'; end if;
  return query select p.id,p.full_name,p.city
    from public.profiles p left join public.driver_verification_private_data d on d.user_id=p.id
    where p.role::text in ('driver','owner_driver')
      and regexp_replace(coalesce(nullif(p.phone_whatsapp,''),d.phone_whatsapp,''),'[^0-9]','','g')=v_phone
    order by p.created_at desc limit 5;
end; $$;

create or replace function public.find_vehicle_for_association(p_plate text)
returns table(vehicle_id uuid,plate text,city text,owner_name text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_plate text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  if not exists(select 1 from public.profiles where id=auth.uid() and role::text in ('driver','owner_driver')) then
    raise exception 'Esta búsqueda está disponible para cuentas de conductor.';
  end if;
  v_plate:=upper(regexp_replace(coalesce(p_plate,''),'[^A-Za-z0-9]','','g'));
  if length(v_plate)<5 or length(v_plate)>10 then raise exception 'Escribe una placa válida.'; end if;
  return query select v.id,v.plate,v.city,coalesce(cv.legal_name,p.full_name)
    from public.vehicles v join public.profiles p on p.id=v.owner_id
    left join public.company_verifications cv on cv.user_id=p.id
    where upper(regexp_replace(v.plate,'[^A-Za-z0-9]','','g'))=v_plate
    order by v.created_at desc limit 5;
end; $$;

create or replace function public.list_my_vehicle_driver_associations()
returns table(association_id uuid,owner_id uuid,driver_id uuid,vehicle_id uuid,plate text,driver_name text,owner_name text,status text,requested_by uuid,is_requester boolean,owner_accepted_at timestamptz,driver_accepted_at timestamptz,created_at timestamptz,ended_at timestamptz)
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión.'; end if;
  return query select a.id,a.owner_id,a.driver_id,a.vehicle_id,v.plate,d.full_name,coalesce(cv.legal_name,o.full_name),
    a.status,a.requested_by,a.requested_by=auth.uid(),a.owner_accepted_at,a.driver_accepted_at,a.created_at,a.ended_at
    from public.vehicle_driver_associations a join public.vehicles v on v.id=a.vehicle_id
    join public.profiles d on d.id=a.driver_id join public.profiles o on o.id=a.owner_id
    left join public.company_verifications cv on cv.user_id=o.id
    where auth.uid()=a.owner_id or auth.uid()=a.driver_id
    order by a.created_at desc limit 100;
end; $$;

revoke all on function public.find_driver_for_association(text) from public,anon;
revoke all on function public.find_vehicle_for_association(text) from public,anon;
revoke all on function public.list_my_vehicle_driver_associations() from public,anon;
grant execute on function public.find_driver_for_association(text) to authenticated;
grant execute on function public.find_vehicle_for_association(text) to authenticated;
grant execute on function public.list_my_vehicle_driver_associations() to authenticated;
create index if not exists vehicle_driver_associations_requested_by_idx on public.vehicle_driver_associations(requested_by);
create index if not exists vehicle_driver_associations_ended_by_idx on public.vehicle_driver_associations(ended_by);
drop policy if exists "Participants can view vehicle driver associations" on public.vehicle_driver_associations;
create policy "Participants can view vehicle driver associations" on public.vehicle_driver_associations
for select to authenticated using ((select auth.uid())=owner_id or (select auth.uid())=driver_id);
