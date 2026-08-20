drop policy if exists copies_delete on public.copies;

create policy copies_delete
  on public.copies
  for delete
  to authenticated
  using (
    owner_id = (select auth.uid())
    or exists (
      select 1
      from public.household_members hm
      where hm.household_id = copies.household_id
        and hm.user_id = (select auth.uid())
        and hm.role in ('owner', 'admin')
    )
  );
