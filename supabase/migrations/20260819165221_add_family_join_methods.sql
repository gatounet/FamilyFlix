create table public.family_join_settings (
  household_id uuid primary key references public.households(id) on delete cascade,
  family_number text not null unique,
  password_hash text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint family_join_number_format check (family_number ~ '^[0-9]{8}$')
);

alter table public.family_join_settings enable row level security;
revoke all on public.family_join_settings from anon, authenticated;

create policy family_join_settings_deny_direct_access
  on public.family_join_settings
  for all
  to authenticated
  using (false)
  with check (false);

create or replace function public.configure_family_join(
  p_household_id uuid, p_password text
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_number text;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (
    select 1 from public.household_members
    where household_id = p_household_id
      and user_id = v_user_id and role = 'owner'
  ) then raise exception 'OWNER_REQUIRED'; end if;
  if char_length(p_password) < 8 or char_length(p_password) > 72 then
    raise exception 'PASSWORD_LENGTH';
  end if;

  select family_number into v_number
  from public.family_join_settings where household_id = p_household_id;
  if v_number is null then
    loop
      v_number := lpad((floor(random() * 100000000))::bigint::text, 8, '0');
      exit when not exists (
        select 1 from public.family_join_settings where family_number = v_number
      );
    end loop;
  end if;

  insert into public.family_join_settings (
    household_id, family_number, password_hash, enabled, updated_at
  ) values (
    p_household_id, v_number,
    extensions.crypt(p_password, extensions.gen_salt('bf', 10)), true, now()
  ) on conflict (household_id) do update
    set password_hash = excluded.password_hash, enabled = true, updated_at = now();
  return v_number;
end;
$$;

create or replace function public.get_family_join_number(p_household_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_number text;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (
    select 1 from public.household_members
    where household_id = p_household_id
      and user_id = v_user_id and role = 'owner'
  ) then raise exception 'OWNER_REQUIRED'; end if;
  select family_number into v_number from public.family_join_settings
  where household_id = p_household_id and enabled;
  return v_number;
end;
$$;

create or replace function public.add_family_member_by_email(
  p_household_id uuid, p_email text, p_display_name text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_owner_id uuid := auth.uid();
  v_target_id uuid;
begin
  if v_owner_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (
    select 1 from public.household_members
    where household_id = p_household_id
      and user_id = v_owner_id and role = 'owner'
  ) then raise exception 'OWNER_REQUIRED'; end if;
  if char_length(btrim(p_display_name)) not between 1 and 80 then
    raise exception 'INVALID_DISPLAY_NAME';
  end if;
  select id into v_target_id from auth.users
  where lower(email) = lower(btrim(p_email)) limit 1;
  if v_target_id is null then raise exception 'USER_NOT_FOUND'; end if;
  if exists (select 1 from public.household_members where user_id = v_target_id) then
    raise exception 'USER_ALREADY_IN_FAMILY';
  end if;
  insert into public.household_members (household_id, user_id, display_name, role)
  values (p_household_id, v_target_id, btrim(p_display_name), 'member');
  return v_target_id;
end;
$$;

create or replace function public.join_household_by_credentials(
  p_family_number text, p_password text, p_display_name text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_household_id uuid;
  v_hash text;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if char_length(btrim(p_display_name)) not between 1 and 80 then
    raise exception 'INVALID_DISPLAY_NAME';
  end if;
  if exists (select 1 from public.household_members where user_id = v_user_id) then
    raise exception 'USER_ALREADY_IN_FAMILY';
  end if;
  select household_id, password_hash into v_household_id, v_hash
  from public.family_join_settings
  where family_number = btrim(p_family_number) and enabled;
  if v_household_id is null or extensions.crypt(p_password, v_hash) <> v_hash then
    raise exception 'INVALID_FAMILY_CREDENTIALS';
  end if;
  insert into public.household_members (household_id, user_id, display_name, role)
  values (v_household_id, v_user_id, btrim(p_display_name), 'member');
  return v_household_id;
end;
$$;

revoke all on function public.configure_family_join(uuid, text) from public, anon;
revoke all on function public.get_family_join_number(uuid) from public, anon;
revoke all on function public.add_family_member_by_email(uuid, text, text) from public, anon;
revoke all on function public.join_household_by_credentials(text, text, text) from public, anon;
grant execute on function public.configure_family_join(uuid, text) to authenticated;
grant execute on function public.get_family_join_number(uuid) to authenticated;
grant execute on function public.add_family_member_by_email(uuid, text, text) to authenticated;
grant execute on function public.join_household_by_credentials(text, text, text) to authenticated;
