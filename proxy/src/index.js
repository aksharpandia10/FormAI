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

    if (pathname === "/webhook/revenuecat" && request.method === "POST") {
      return handleRevenueCatWebhook(request, env);
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

async function handleRevenueCatWebhook(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  const event = body.event;
  if (!event) return new Response("OK", { status: 200 });

  const redditEventType = {
    INITIAL_PURCHASE:          { tracking_type: "Purchase" },
    NON_SUBSCRIPTION_PURCHASE: { tracking_type: "Purchase" },
    PAYWALL_IMPRESSION:        { tracking_type: "Lead" },
    PAYWALL_CLOSE:             { tracking_type: "Custom", custom_event_name: "PaywallClose" },
    PAYWALL_CANCEL:            { tracking_type: "Custom", custom_event_name: "PaywallCancel" },
  }[event.type];

  if (!redditEventType) return new Response("OK", { status: 200 });

  const email = event.subscriber_attributes?.["$email"]?.value ?? "";
  const eventTime = new Date(event.purchased_at_ms ?? event.event_timestamp_ms ?? Date.now()).toISOString();
  const price = event.price ?? 0;
  const currency = event.currency ?? "USD";
  const appUserId = event.app_user_id ?? "";
  const transactionId = event.transaction_id ?? "";
  const productId = event.product_id ?? "";

  const [hashedEmail, hashedUserId] = await Promise.all([
    email     ? sha256(email.toLowerCase().trim()) : null,
    appUserId ? sha256(appUserId)                  : null,
  ]);

  const isPurchase = event.type === "INITIAL_PURCHASE" || event.type === "NON_SUBSCRIPTION_PURCHASE";
  const promises = [];

  if (env.REDDIT_ACCESS_TOKEN) {
    promises.push(sendRedditConversion({ env, eventTime, hashedEmail, hashedUserId, transactionId, productId, redditEventType, price, currency, isPurchase }));
  }

  if (env.TIKTOK_ACCESS_TOKEN) {
    promises.push(sendTikTokConversion({ env, eventTime, hashedEmail, hashedUserId, transactionId, productId, price, currency, isPurchase, eventType: event.type }));
  }

  await Promise.allSettled(promises);
  return new Response("OK", { status: 200 });
}

async function sendRedditConversion({ env, eventTime, hashedEmail, hashedUserId, transactionId, productId, redditEventType, price, currency, isPurchase }) {
  const user = {};
  if (hashedEmail)  user.email       = hashedEmail;
  if (hashedUserId) user.external_id = hashedUserId;

  const event = {
    event_at: new Date(eventTime).getTime(),
    action_source: "APP",
    type: redditEventType,
    user,
  };

  if (isPurchase) {
    event.metadata = {
      value: price,
      currency,
      item_count: 1,
      conversion_id: transactionId,
      products: productId ? [{ id: productId, name: productId, category: "Subscription" }] : undefined,
    };
  }

  const payload = {
    data: { events: [event] },
  };

  const res = await fetch("https://ads-api.reddit.com/api/v3/pixels/a2_j5epi182mvig/conversion_events", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.REDDIT_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error(`Reddit Conversions API error ${res.status}: ${text}`);
  }
}

async function sendTikTokConversion({ env, eventTime, hashedEmail, hashedUserId, transactionId, productId, price, currency, isPurchase, eventType }) {
  const tiktokEventName = {
    INITIAL_PURCHASE:          "CompletePayment",
    NON_SUBSCRIPTION_PURCHASE: "CompletePayment",
    PAYWALL_IMPRESSION:        "ViewContent",
    PAYWALL_CLOSE:             "CustomizeProduct",
    PAYWALL_CANCEL:            "CustomizeProduct",
  }[eventType];

  if (!tiktokEventName) return;

  const user = {};
  if (hashedEmail)  user.email    = [hashedEmail];
  if (hashedUserId) user.external_id = [hashedUserId];

  const properties = {};
  if (isPurchase) {
    properties.value    = price;
    properties.currency = currency;
    if (transactionId) properties.order_id = transactionId;
    properties.contents = productId
      ? [{ content_id: productId, content_type: "product", quantity: 1, price }]
      : [{ content_id: "formai_subscription", content_type: "product", quantity: 1, price }];
  }

  const payload = {
    event_source: "web",
    event_source_id: "D93J223C77UCTR173MKG",
    data: [{
      event: tiktokEventName,
      event_time: Math.floor(new Date(eventTime).getTime() / 1000),
      user,
      properties,
    }],
  };

  const res = await fetch("https://business-api.tiktok.com/open_api/v1.3/event/track/", {
    method: "POST",
    headers: {
      "Access-Token": env.TIKTOK_ACCESS_TOKEN,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error(`TikTok Events API error ${res.status}: ${text}`);
  }
}

async function sha256(str) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
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
