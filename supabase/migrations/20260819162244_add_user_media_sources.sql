create table public.media_sources (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  owner_id uuid not null,
  name text not null,
  default_format public.media_format not null default 'other',
  details text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint media_sources_name_length
    check (char_length(btrim(name)) between 1 and 80),
  constraint media_sources_details_length
    check (details is null or char_length(details) <= 240),
  constraint media_sources_household_owner_fkey
    foreign key (household_id, owner_id)
    references public.household_members (household_id, user_id)
    on delete cascade,
  constraint media_sources_scope_key
    unique (id, household_id, owner_id)
);

create unique index media_sources_owner_name_key
  on public.media_sources (household_id, owner_id, lower(btrim(name)));

create index media_sources_household_id_idx
  on public.media_sources (household_id);

create index media_sources_owner_id_idx
  on public.media_sources (owner_id);

alter table public.media_sources enable row level security;

create policy media_sources_select
  on public.media_sources
  for select
  to authenticated
  using ((select private.is_household_member(household_id)));

create policy media_sources_insert
  on public.media_sources
  for insert
  to authenticated
  with check (
    owner_id = (select auth.uid())
    and (select private.is_household_member(household_id))
  );

create policy media_sources_update
  on public.media_sources
  for update
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and (select private.is_household_member(household_id))
  );

create policy media_sources_delete
  on public.media_sources
  for delete
  to authenticated
  using (owner_id = (select auth.uid()));

grant select, insert, update, delete
  on public.media_sources
  to authenticated;

alter table public.copies
  add column media_source_id uuid;

alter table public.copies
  add constraint copies_media_source_scope_fkey
  foreign key (media_source_id, household_id, owner_id)
  references public.media_sources (id, household_id, owner_id)
  on delete set null (media_source_id);

create index copies_media_source_scope_idx
  on public.copies (media_source_id, household_id, owner_id);
