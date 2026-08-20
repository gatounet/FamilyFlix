begin;

alter table public.movies
  add column if not exists media_type text not null default 'movie',
  add column if not exists number_of_seasons integer;

alter table public.movies
  drop constraint if exists movies_tmdb_id_key;

alter table public.movies
  drop constraint if exists movies_media_type_check;

alter table public.movies
  add constraint movies_media_type_check
  check (media_type in ('movie', 'tv'));

alter table public.movies
  drop constraint if exists movies_number_of_seasons_check;

alter table public.movies
  add constraint movies_number_of_seasons_check
  check (number_of_seasons is null or number_of_seasons > 0);

create unique index if not exists movies_provider_media_tmdb_key
  on public.movies (metadata_provider, media_type, tmdb_id);

alter table public.copies
  add column if not exists ownership_scope text not null default 'movie',
  add column if not exists season_numbers integer[];

alter table public.copies
  drop constraint if exists copies_ownership_scope_check;

alter table public.copies
  add constraint copies_ownership_scope_check check (
    (ownership_scope = 'movie' and season_numbers is null)
    or (ownership_scope = 'complete_series' and season_numbers is null)
    or (
      ownership_scope in ('single_season', 'selected_seasons')
      and season_numbers is not null
      and cardinality(season_numbers) > 0
      and 0 < all(season_numbers)
      and (
        ownership_scope <> 'single_season'
        or cardinality(season_numbers) = 1
      )
    )
  );

create index if not exists copies_season_numbers_idx
  on public.copies using gin (season_numbers);

commit;
