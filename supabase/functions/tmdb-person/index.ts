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
    const body = await request.json();
    const personId = body?.person_id;
    if (!token) {
      return Response.json(
        { error: "TMDB_READ_TOKEN_NOT_CONFIGURED" },
        { status: 503, headers: corsHeaders },
      );
    }
    if (!Number.isInteger(personId) || personId <= 0) {
      return Response.json(
        { error: "INVALID_PERSON_ID" },
        { status: 400, headers: corsHeaders },
      );
    }
    const url = new URL(`https://api.themoviedb.org/3/person/${personId}`);
    url.searchParams.set("language", "fr-FR");
    url.searchParams.set("append_to_response", "movie_credits");
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
    if (!response.ok) {
      return Response.json(
        { error: "TMDB_REQUEST_FAILED" },
        { status: 502, headers: corsHeaders },
      );
    }
    const person = await response.json();
    const cast = Array.isArray(person.movie_credits?.cast)
      ? person.movie_credits.cast
      : [];
    const knownFor = cast
      .sort((a: Record<string, unknown>, b: Record<string, unknown>) =>
        Number(b.popularity) - Number(a.popularity)
      )
      .slice(0, 8)
      .map((movie: Record<string, unknown>) => ({
        id: movie.id,
        title: movie.title,
        character: movie.character,
        release_date: movie.release_date || null,
        poster_path: movie.poster_path || null,
      }));
    return Response.json({
      id: person.id,
      name: person.name,
      biography: person.biography || "",
      birthday: person.birthday || null,
      place_of_birth: person.place_of_birth || null,
      profile_path: person.profile_path || null,
      known_for: knownFor,
    }, { headers: corsHeaders });
  } catch {
    return Response.json(
      { error: "UNEXPECTED_ERROR" },
      { status: 500, headers: corsHeaders },
    );
  }
});
