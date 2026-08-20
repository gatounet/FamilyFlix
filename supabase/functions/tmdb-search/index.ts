import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
    const query = typeof body?.query === "string" ? body.query.trim() : "";
    if (query.length < 2 || query.length > 120) {
      return Response.json(
        { error: "INVALID_QUERY" },
        { status: 400, headers: corsHeaders },
      );
    }

    const url = new URL("https://api.themoviedb.org/3/search/movie");
    url.searchParams.set("query", query);
    url.searchParams.set("language", "fr-FR");
    url.searchParams.set("include_adult", "false");
    url.searchParams.set("page", "1");

    const tmdbResponse = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
    });

    if (!tmdbResponse.ok) {
      return Response.json(
        { error: "TMDB_REQUEST_FAILED" },
        { status: 502, headers: corsHeaders },
      );
    }

    const payload = await tmdbResponse.json();
    const results = Array.isArray(payload.results)
      ? payload.results.slice(0, 20).map((movie: Record<string, unknown>) => ({
          tmdb_id: movie.id,
          title: movie.title,
          original_title: movie.original_title,
          overview: movie.overview,
          release_date: movie.release_date || null,
          poster_path: movie.poster_path || null,
        }))
      : [];

    return Response.json({ results }, { headers: corsHeaders });
  } catch {
    return Response.json(
      { error: "UNEXPECTED_ERROR" },
      { status: 500, headers: corsHeaders },
    );
  }
});
