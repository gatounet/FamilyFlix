create table public.movie_reviews (
  household_id uuid not null,
  user_id uuid not null,
  movie_id uuid not null references public.movies(id) on delete cascade,
  rating smallint,
  comment text,
  is_favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (household_id, user_id, movie_id),
  constraint movie_reviews_member_fkey
    foreign key (household_id, user_id)
    references public.household_members(household_id, user_id)
    on delete cascade,
  constraint movie_reviews_rating_check
    check (rating is null or rating between 1 and 5),
  constraint movie_reviews_comment_length
    check (comment is null or char_length(comment) <= 1500),
  constraint movie_reviews_has_content
    check (
      rating is not null
      or nullif(btrim(comment), '') is not null
      or is_favorite
    )
);

create index movie_reviews_movie_id_idx
  on public.movie_reviews (movie_id);

alter table public.movie_reviews enable row level security;

create policy movie_reviews_select
  on public.movie_reviews
  for select
  to authenticated
  using ((select private.is_household_member(household_id)));

create policy movie_reviews_insert
  on public.movie_reviews
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and (select private.is_household_member(household_id))
  );

create policy movie_reviews_update
  on public.movie_reviews
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (select private.is_household_member(household_id))
  );

create policy movie_reviews_delete
  on public.movie_reviews
  for delete
  to authenticated
  using (user_id = (select auth.uid()));

grant select, insert, update, delete
  on public.movie_reviews
  to authenticated;
