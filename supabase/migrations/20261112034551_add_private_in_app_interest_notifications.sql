create table public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in ('load_interest_received','interest_status_changed')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 300),
  related_request_id uuid references public.load_interest_requests(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index user_notifications_recipient_created_idx
  on public.user_notifications (recipient_id, created_at desc);

alter table public.user_notifications enable row level security;

revoke all on table public.user_notifications from public, anon, authenticated;
grant select on table public.user_notifications to authenticated;
grant update (read_at) on table public.user_notifications to authenticated;

create policy "Users read their own notifications"
  on public.user_notifications
  for select
  to authenticated
  using ((select auth.uid()) = recipient_id);

create policy "Users mark their own notifications as read"
  on public.user_notifications
  for update
  to authenticated
  using ((select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = recipient_id);

create or replace function private.create_interest_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_body text;
  v_type text;
  v_recipient uuid;
begin
  if TG_OP = 'INSERT' then
    v_recipient := NEW.company_id;
    v_type := 'load_interest_received';
    v_title := 'Nuevo interés en una carga';
    v_body := 'Un transportador manifestó interés en una de tus cargas.';
  elsif TG_OP = 'UPDATE' and NEW.status is distinct from OLD.status then
    v_recipient := NEW.transporter_id;
    v_type := 'interest_status_changed';
    v_title := 'Actualización de tu solicitud';
    if NEW.status = 'contacted' then
      v_body := 'La empresa actualizó tu solicitud y desea ponerse en contacto.';
    elsif NEW.status = 'closed' then
      v_body := 'La empresa actualizó el estado de tu solicitud.';
    else
      return NEW;
    end if;
  else
    return NEW;
  end if;

  if v_recipient is not null then
    insert into public.user_notifications
      (recipient_id, event_type, title, body, related_request_id)
    values
      (v_recipient, v_type, v_title, v_body, NEW.id);
  end if;

  return NEW;
end;
$$;

revoke all on function private.create_interest_notification() from public, anon, authenticated;

drop trigger if exists trg_notify_new_load_interest on public.load_interest_requests;
create trigger trg_notify_new_load_interest
  after insert on public.load_interest_requests
  for each row execute function private.create_interest_notification();

drop trigger if exists trg_notify_interest_status_change on public.load_interest_requests;
create trigger trg_notify_interest_status_change
  after update of status on public.load_interest_requests
  for each row
  when (old.status is distinct from new.status)
  execute function private.create_interest_notification();
