create or replace function public.transfer_media_source(
  p_household_id uuid,
  p_source_id uuid,
  p_destination_id uuid,
  p_for_family boolean default false,
  p_update_format boolean default true
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_member_role text;
  v_destination_format public.media_format;
  v_updated_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_source_id = p_destination_id then
    raise exception 'Source and destination must be different';
  end if;

  select hm.role::text
  into v_member_role
  from public.household_members hm
  where hm.household_id = p_household_id
    and hm.user_id = v_user_id;

  if v_member_role is null then
    raise exception 'Household membership required';
  end if;

  if p_for_family and v_member_role not in ('owner', 'admin') then
    raise exception 'Family administrator role required';
  end if;

  if not exists (
    select 1
    from public.media_sources source
    where source.id = p_source_id
      and source.household_id = p_household_id
      and source.is_active
  ) then
    raise exception 'Source media location not found';
  end if;

  select destination.default_format
  into v_destination_format
  from public.media_sources destination
  where destination.id = p_destination_id
    and destination.household_id = p_household_id
    and destination.is_active;

  if v_destination_format is null then
    raise exception 'Destination media location not found';
  end if;

  update public.copies copy
  set media_source_id = p_destination_id,
      format = case
        when p_update_format then v_destination_format
        else copy.format
      end
  where copy.household_id = p_household_id
    and copy.media_source_id = p_source_id
    and (p_for_family or copy.owner_id = v_user_id);

  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$$;

revoke all on function public.transfer_media_source(
  uuid,
  uuid,
  uuid,
  boolean,
  boolean
) from public, anon;

grant execute on function public.transfer_media_source(
  uuid,
  uuid,
  uuid,
  boolean,
  boolean
) to authenticated;
