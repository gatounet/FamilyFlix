import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type JsonObject = Record<string, unknown>;

function certification(payload: JsonObject, mediaType: string): string | null {
  if (mediaType === "tv") {
    const ratings = payload.content_ratings as JsonObject | undefined;
    const countries = Array.isArray(ratings?.results)
      ? ratings.results as JsonObject[]
      : [];
    const french = countries.find((country) => country.iso_3166_1 === "FR");
    return typeof french?.rating === "string" && french.rating !== ""
      ? french.rating
      : null;
  }
  const releaseDates = payload.release_dates as JsonObject | undefined;
  const countries = Array.isArray(releaseDates?.results)
    ? releaseDates.results as JsonObject[]
    : [];
  const french = countries.find((country) => country.iso_3166_1 === "FR");
  const releases = Array.isArray(french?.release_dates)
    ? french.release_dates as JsonObject[]
    : [];
  const ranked = [...releases].sort((a, b) => {
    const rank = (value: unknown) => value === 3 ? 0 : value === 4 ? 1 : 9;
    return rank(a.type) - rank(b.type);
  });
  const item = ranked.find((release) =>
    typeof release.certification === "string" && release.certification !== ""
  );
  return typeof item?.certification === "string" ? item.certification : null;
}

function compactMedia(payload: JsonObject, mediaType: string) {
  const credits = payload.credits as JsonObject | undefined;
  const videos = payload.videos as JsonObject | undefined;
  const cast = Array.isArray(credits?.cast) ? credits.cast as JsonObject[] : [];
  const videoItems = Array.isArray(videos?.results)
    ? videos.results as JsonObject[]
    : [];
  return {
    tmdb_id: payload.id,
    media_type: mediaType,
    title: mediaType === "tv" ? payload.name : payload.title,
    original_title: mediaType === "tv"
      ? payload.original_name
      : payload.original_title,
    overview: payload.overview,
    release_date: mediaType === "tv"
      ? payload.first_air_date || null
      : payload.release_date || null,
    poster_path: payload.poster_path || null,
    backdrop_path: payload.backdrop_path || null,
    runtime: mediaType === "tv"
      ? (Array.isArray(payload.episode_run_time) ? payload.episode_run_time[0] : null)
      : payload.runtime || null,
    vote_average: payload.vote_average || null,
    certification: certification(payload, mediaType),
    number_of_seasons: mediaType === "tv" ? payload.number_of_seasons || null : null,
    seasons: mediaType === "tv" && Array.isArray(payload.seasons)
      ? (payload.seasons as JsonObject[])
        .filter((season) => Number(season.season_number) > 0)
        .map((season) => ({
          number: season.season_number,
          name: season.name,
          episode_count: season.episode_count,
        }))
      : [],
    genres: Array.isArray(payload.genres)
      ? (payload.genres as JsonObject[]).map((genre) => genre.name)
      : [],
    cast: cast.slice(0, 16).map((person) => ({
      id: person.id,
      name: person.name,
      character: person.character,
      profile_path: person.profile_path || null,
    })),
    videos: videoItems
      .filter((video) =>
        (video.site === "YouTube" || video.site === "Vimeo") &&
        ["Trailer", "Teaser", "Clip", "Featurette"].includes(
          String(video.type),
        )
      )
      .sort((a, b) => Number(b.official) - Number(a.official))
      .slice(0, 12)
      .map((video) => ({
        id: video.id,
        name: video.name,
        key: video.key,
        site: video.site,
        type: video.type,
        official: video.official === true,
      })),
  };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const token = Deno.env.get("TMDB_READ_TOKEN");
    if (!token) {
      return Response.json(
        { error: "TMDB_READ_TOKEN_NOT_CONFIGURED" },
        { status: 503, headers: corsHeaders },
      );
    }
    const body = await request.json();
    const rawItems = Array.isArray(body?.items)
      ? body.items
      : (Array.isArray(body?.movie_ids) ? body.movie_ids : [body?.movie_id])
        .map((id: unknown) => ({ tmdb_id: id, media_type: "movie" }));
    const items = rawItems
      .map((item: JsonObject) => ({
        tmdb_id: Number(item?.tmdb_id),
        media_type: item?.media_type === "tv" ? "tv" : "movie",
      }))
      .filter((item: { tmdb_id: number }) => Number.isInteger(item.tmdb_id) && item.tmdb_id > 0)
      .filter((item: { tmdb_id: number; media_type: string }, index: number, all: Array<{ tmdb_id: number; media_type: string }>) =>
        all.findIndex((other) => other.tmdb_id === item.tmdb_id && other.media_type === item.media_type) === index
      )
      .slice(0, 50);
    if (items.length === 0) {
      return Response.json(
        { error: "INVALID_MOVIE_IDS" },
        { status: 400, headers: corsHeaders },
      );
    }

    const movies = await Promise.all(items.map(async (item) => {
      const url = new URL(`https://api.themoviedb.org/3/${item.media_type}/${item.tmdb_id}`);
      url.searchParams.set("language", "fr-FR");
      url.searchParams.set(
        "append_to_response",
        item.media_type === "tv"
          ? "credits,videos,content_ratings"
          : "credits,videos,release_dates",
      );
      url.searchParams.set("include_video_language", "fr,en,null");
      const response = await fetch(url, {
        headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      });
      if (!response.ok) return null;
      return compactMedia(await response.json(), item.media_type);
    }));

    return Response.json(
      { movies: movies.filter((movie) => movie !== null) },
      { headers: corsHeaders },
    );
  } catch {
    return Response.json(
      { error: "UNEXPECTED_ERROR" },
      { status: 500, headers: corsHeaders },
    );
  }
});
