drop policy if exists copies_all on public.copies;

create policy copies_select
  on public.copies
  for select
  to authenticated
  using ((select private.is_household_member(household_id)));

create policy copies_insert
  on public.copies
  for insert
  to authenticated
  with check (
    owner_id = (select auth.uid())
    and (select private.is_household_member(household_id))
  );

create policy copies_update
  on public.copies
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and (select private.is_household_member(household_id))
  );

create policy copies_delete
  on public.copies
  for delete
  to authenticated
  using (owner_id = (select auth.uid()));
