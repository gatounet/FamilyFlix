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

    const requestedType = ["movie", "tv", "all"].includes(body?.media_type)
      ? body.media_type
      : "all";
    const year = typeof body?.year === "string" && /^\d{4}$/.test(body.year)
      ? body.year
      : "";
    const endpoint = requestedType === "all" ? "multi" : requestedType;
    const url = new URL(`https://api.themoviedb.org/3/search/${endpoint}`);
    url.searchParams.set("query", query);
    url.searchParams.set("language", "fr-FR");
    url.searchParams.set("include_adult", "false");
    url.searchParams.set("page", "1");
    if (year !== "" && requestedType !== "all") {
      url.searchParams.set(
        requestedType === "tv" ? "year" : "primary_release_year",
        year,
      );
    }

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
      ? payload.results
        .filter((item: Record<string, unknown>) =>
          requestedType !== "all" || ["movie", "tv"].includes(String(item.media_type))
        )
        .map((item: Record<string, unknown>) => {
          const mediaType = requestedType === "all"
            ? String(item.media_type)
            : requestedType;
          return {
            tmdb_id: item.id,
            media_type: mediaType,
            title: mediaType === "tv" ? item.name : item.title,
            original_title: mediaType === "tv"
              ? item.original_name
              : item.original_title,
            overview: item.overview,
            release_date: mediaType === "tv"
              ? item.first_air_date || null
              : item.release_date || null,
            poster_path: item.poster_path || null,
          };
        })
        .filter((item: Record<string, unknown>) =>
          year === "" || String(item.release_date).startsWith(year)
        )
        .slice(0, 20)
      : [];

    return Response.json({ results }, { headers: corsHeaders });
  } catch {
    return Response.json(
      { error: "UNEXPECTED_ERROR" },
      { status: 500, headers: corsHeaders },
    );
  }
});
