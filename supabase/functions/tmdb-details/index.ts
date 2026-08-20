import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type JsonObject = Record<string, unknown>;

function certification(payload: JsonObject): string | null {
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

function compactMovie(payload: JsonObject) {
  const credits = payload.credits as JsonObject | undefined;
  const videos = payload.videos as JsonObject | undefined;
  const cast = Array.isArray(credits?.cast) ? credits.cast as JsonObject[] : [];
  const videoItems = Array.isArray(videos?.results)
    ? videos.results as JsonObject[]
    : [];
  return {
    tmdb_id: payload.id,
    title: payload.title,
    original_title: payload.original_title,
    overview: payload.overview,
    release_date: payload.release_date || null,
    poster_path: payload.poster_path || null,
    backdrop_path: payload.backdrop_path || null,
    runtime: payload.runtime || null,
    vote_average: payload.vote_average || null,
    certification: certification(payload),
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
    const rawIds = Array.isArray(body?.movie_ids)
      ? body.movie_ids
      : [body?.movie_id];
    const movieIds = [...new Set(rawIds)]
      .filter((id) => Number.isInteger(id) && id > 0)
      .slice(0, 50) as number[];
    if (movieIds.length === 0) {
      return Response.json(
        { error: "INVALID_MOVIE_IDS" },
        { status: 400, headers: corsHeaders },
      );
    }

    const movies = await Promise.all(movieIds.map(async (movieId) => {
      const url = new URL(`https://api.themoviedb.org/3/movie/${movieId}`);
      url.searchParams.set("language", "fr-FR");
      url.searchParams.set(
        "append_to_response",
        "credits,videos,release_dates",
      );
      url.searchParams.set("include_video_language", "fr,en,null");
      const response = await fetch(url, {
        headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      });
      if (!response.ok) return null;
      return compactMovie(await response.json());
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
