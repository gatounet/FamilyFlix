begin;

alter table public.copies
  drop constraint if exists copies_media_source_scope_fkey;

drop index if exists public.copies_media_source_scope_idx;
drop index if exists public.media_sources_owner_name_key;
drop index if exists public.media_sources_household_name_key;

alter table public.media_sources
  drop constraint if exists media_sources_scope_key;

alter table public.media_sources
  drop constraint if exists media_sources_household_scope_key;

alter table public.media_sources
  add constraint media_sources_household_scope_key unique (id, household_id);

alter table public.copies
  add constraint copies_media_source_scope_fkey
  foreign key (media_source_id, household_id)
  references public.media_sources (id, household_id)
  on delete set null (media_source_id);

create index copies_media_source_scope_idx
  on public.copies (media_source_id, household_id);

create unique index media_sources_household_name_key
  on public.media_sources (household_id, lower(btrim(name)));

create index if not exists media_sources_household_owner_idx
  on public.media_sources (household_id, owner_id);

drop policy if exists media_sources_insert on public.media_sources;
drop policy if exists media_sources_update on public.media_sources;
drop policy if exists media_sources_delete on public.media_sources;

create policy media_sources_insert
on public.media_sources
for insert
to authenticated
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.households h
    where h.id = media_sources.household_id
      and h.created_by = (select auth.uid())
  )
);

create policy media_sources_update
on public.media_sources
for update
to authenticated
using (
  exists (
    select 1
    from public.households h
    where h.id = media_sources.household_id
      and h.created_by = (select auth.uid())
  )
)
with check (
  owner_id = (select auth.uid())
  and exists (
    select 1
    from public.households h
    where h.id = media_sources.household_id
      and h.created_by = (select auth.uid())
  )
);

create policy media_sources_delete
on public.media_sources
for delete
to authenticated
using (
  exists (
    select 1
    from public.households h
    where h.id = media_sources.household_id
      and h.created_by = (select auth.uid())
  )
);

commit;
