const GEMINI_MODEL    = "gemini-3.5-flash";
const GEMINI_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const MAX_FRAMES = 100;

const RATE_LIMIT = 25;
const RATE_WINDOW_SECONDS = 3600;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return corsResponse(null, 204);
    }

    const pathname = new URL(request.url).pathname;

    if (pathname === "/youtube-search" && request.method === "GET") {
      return handleYouTubeSearch(request, env);
    }

    if (request.method !== "POST" || pathname !== "/analyze") {
      return corsResponse(JSON.stringify({ error: "Not found" }), 404);
    }

    const serviceKey = request.headers.get("X-Service-Key");
    if (!serviceKey || serviceKey !== env.SERVICE_KEY) {
      return corsResponse(JSON.stringify({ error: "Unauthorized" }), 401);
    }

    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
    const rateLimitKey = `rate:${ip}`;
    const currentCount = parseInt(await env.RATE_LIMIT.get(rateLimitKey) ?? "0");
    if (currentCount >= RATE_LIMIT) {
      return corsResponse(JSON.stringify({ error: "Too many requests. Please wait a while and try again." }), 429);
    }
    await env.RATE_LIMIT.put(rateLimitKey, String(currentCount + 1), {
      expirationTtl: RATE_WINDOW_SECONDS,
    });

    let body;
    try {
      body = await request.json();
    } catch {
      return corsResponse(JSON.stringify({ error: "Invalid JSON" }), 400);
    }

    const { frames, systemPrompt, userText } = body;

    if (!frames || !Array.isArray(frames) || frames.length === 0) {
      return corsResponse(JSON.stringify({ error: "frames required" }), 400);
    }
    if (!systemPrompt || !userText) {
      return corsResponse(JSON.stringify({ error: "systemPrompt and userText required" }), 400);
    }
    if (frames.length > MAX_FRAMES) {
      return corsResponse(JSON.stringify({ error: `Max ${MAX_FRAMES} frames allowed` }), 400);
    }

    const parts = frames.map((base64) => ({
      inline_data: { mime_type: "image/jpeg", data: base64 },
    }));
    parts.push({ text: userText });

    const geminiBody = {
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents: [{ role: "user", parts }],
      generationConfig: {
        maxOutputTokens: 2048,
        thinkingConfig: { thinkingBudget: -1 },
      },
    };

    const geminiRes = await fetch(`${GEMINI_ENDPOINT}?key=${env.GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiBody),
    });

    const geminiData = await geminiRes.json();

    if (!geminiRes.ok) {
      return corsResponse(
        JSON.stringify({ error: geminiData?.error?.message ?? "Gemini error" }),
        geminiRes.status
      );
    }

    const text = geminiData?.candidates?.[0]?.content?.parts
      ?.filter(p => !p.thought)
      ?.map(p => p.text)
      ?.join("") ?? null;
    if (!text) {
      return corsResponse(JSON.stringify({ error: "Empty response from Gemini" }), 502);
    }

    return corsResponse(JSON.stringify({ text }), 200);
  },
};

async function handleYouTubeSearch(request, env) {
  const q = new URL(request.url).searchParams.get("q");
  if (!q) return corsResponse(JSON.stringify({ error: "q required" }), 400);

  const serviceKey = request.headers.get("X-Service-Key");
  if (!serviceKey || serviceKey !== env.SERVICE_KEY) {
    return corsResponse(JSON.stringify({ error: "Unauthorized" }), 401);
  }

  const searchURL = `https://www.googleapis.com/youtube/v3/search?part=id&q=${encodeURIComponent(q)}&type=video&videoDuration=short&maxResults=10&key=${env.YOUTUBE_API_KEY}`;
  const res = await fetch(searchURL);
  const data = await res.json();
  return corsResponse(JSON.stringify(data), res.status);
}

function corsResponse(body, status) {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, X-Service-Key",
    },
  });
}
