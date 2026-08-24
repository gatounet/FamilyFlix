create or replace function public.get_platform_stats()
returns table (
  family_count bigint,
  user_count bigint,
  owned_work_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null or not exists (
    select 1
    from auth.users admin_user
    where admin_user.id = v_user_id
      and lower(admin_user.email) = lower('starz.gatounet@gmail.com')
  ) then
    raise exception 'Platform administrator access required'
      using errcode = '42501';
  end if;

  return query
  select
    (select count(*) from public.households),
    (select count(*) from auth.users),
    (select count(distinct copy.movie_id) from public.copies copy);
end;
$$;

revoke all on function public.get_platform_stats() from public, anon;
grant execute on function public.get_platform_stats() to authenticated;
