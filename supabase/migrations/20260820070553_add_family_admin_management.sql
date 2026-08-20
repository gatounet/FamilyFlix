alter type public.household_role add value if not exists 'admin' after 'owner';

create or replace function public.configure_family_join(p_household_id uuid, p_password text)
returns text language plpgsql security definer set search_path = '' as $function$
declare v_user_id uuid := auth.uid(); v_number text;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (select 1 from public.household_members where household_id = p_household_id and user_id = v_user_id and role in ('owner', 'admin')) then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if char_length(p_password) < 8 or char_length(p_password) > 72 then raise exception 'PASSWORD_LENGTH'; end if;
  select family_number into v_number from public.family_join_settings where household_id = p_household_id;
  if v_number is null then
    loop
      v_number := lpad((floor(random() * 100000000))::bigint::text, 8, '0');
      exit when not exists (select 1 from public.family_join_settings where family_number = v_number);
    end loop;
  end if;
  insert into public.family_join_settings (household_id, family_number, password_hash, enabled, updated_at)
  values (p_household_id, v_number, extensions.crypt(p_password, extensions.gen_salt('bf', 10)), true, now())
  on conflict (household_id) do update set password_hash = excluded.password_hash, enabled = true, updated_at = now();
  return v_number;
end;
$function$;

create or replace function public.get_family_join_number(p_household_id uuid)
returns text language plpgsql security definer set search_path = '' as $function$
declare v_user_id uuid := auth.uid(); v_number text;
begin
  if v_user_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (select 1 from public.household_members where household_id = p_household_id and user_id = v_user_id and role in ('owner', 'admin')) then
    raise exception 'ADMIN_REQUIRED';
  end if;
  select family_number into v_number from public.family_join_settings where household_id = p_household_id and enabled;
  return v_number;
end;
$function$;

create or replace function public.add_family_member_by_email(p_household_id uuid, p_email text, p_display_name text)
returns uuid language plpgsql security definer set search_path = '' as $function$
declare v_actor_id uuid := auth.uid(); v_target_id uuid;
begin
  if v_actor_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (select 1 from public.household_members where household_id = p_household_id and user_id = v_actor_id and role in ('owner', 'admin')) then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if char_length(btrim(p_display_name)) not between 1 and 80 then raise exception 'INVALID_DISPLAY_NAME'; end if;
  select id into v_target_id from auth.users where lower(email) = lower(btrim(p_email)) limit 1;
  if v_target_id is null then raise exception 'USER_NOT_FOUND'; end if;
  if exists (select 1 from public.household_members where user_id = v_target_id) then raise exception 'USER_ALREADY_IN_FAMILY'; end if;
  insert into public.household_members (household_id, user_id, display_name, role)
  values (p_household_id, v_target_id, btrim(p_display_name), 'member');
  return v_target_id;
end;
$function$;

create or replace function public.set_family_member_role(p_household_id uuid, p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path = '' as $function$
declare v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if p_role not in ('admin', 'member') then raise exception 'INVALID_ROLE'; end if;
  if not exists (select 1 from public.households where id = p_household_id and created_by = v_actor_id) then raise exception 'OWNER_REQUIRED'; end if;
  if p_user_id = v_actor_id then raise exception 'OWNER_ROLE_IMMUTABLE'; end if;
  update public.household_members set role = p_role::public.household_role
  where household_id = p_household_id and user_id = p_user_id and role <> 'owner';
  if not found then raise exception 'MEMBER_NOT_FOUND'; end if;
end;
$function$;

create or replace function public.remove_family_member(p_household_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $function$
declare v_actor_id uuid := auth.uid();
begin
  if v_actor_id is null then raise exception 'AUTHENTICATION_REQUIRED'; end if;
  if not exists (select 1 from public.households where id = p_household_id and created_by = v_actor_id) then raise exception 'OWNER_REQUIRED'; end if;
  if p_user_id = v_actor_id then raise exception 'OWNER_CANNOT_BE_REMOVED'; end if;
  if not exists (select 1 from public.household_members where household_id = p_household_id and user_id = p_user_id and role <> 'owner') then
    raise exception 'MEMBER_NOT_FOUND';
  end if;
  delete from public.copies where household_id = p_household_id and owner_id = p_user_id;
  delete from public.watchlists where household_id = p_household_id and user_id = p_user_id;
  delete from public.household_members where household_id = p_household_id and user_id = p_user_id and role <> 'owner';
end;
$function$;

revoke all on function public.configure_family_join(uuid, text) from public, anon;
revoke all on function public.get_family_join_number(uuid) from public, anon;
revoke all on function public.add_family_member_by_email(uuid, text, text) from public, anon;
revoke all on function public.set_family_member_role(uuid, uuid, text) from public, anon;
revoke all on function public.remove_family_member(uuid, uuid) from public, anon;
grant execute on function public.configure_family_join(uuid, text) to authenticated;
grant execute on function public.get_family_join_number(uuid) to authenticated;
grant execute on function public.add_family_member_by_email(uuid, text, text) to authenticated;
grant execute on function public.set_family_member_role(uuid, uuid, text) to authenticated;
grant execute on function public.remove_family_member(uuid, uuid) to authenticated;
