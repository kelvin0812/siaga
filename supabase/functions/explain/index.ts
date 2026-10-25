// Merang's "explain" function: the only place that talks to Gemini. The API key lives here as a secret and never in the app.
//
// Secrets (Supabase dashboard > Edge Functions > Secrets):
//   GEMINI_API_KEY            required
//   GEMINI_MODEL              optional, the first model to try (default gemini-3.5-flash-lite)
//   GEMINI_FALLBACK_MODELS    optional, comma separated, tried in order when the first is busy or out of quota
//
// The app sends a small read-only snapshot of numbers (see core.ts). It cannot send free text to the model. If anything
// goes wrong we answer with an error and the app falls back to its own fixed wording, so Merang never goes silent.
import { buildPrompt, parseGeminiResponse, parseRequest, Throttle } from './core.ts';

const clean = (m: string) => m.trim().replace(/^models\//, '');
// A light model first: it is quick, and the newest models are often overloaded or tightly rate-limited on the free tier.
// (The 2.5 models now answer 404 for new keys, so they are not listed.) Each model has its own quota.
const MODELS = [
  Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.5-flash-lite',
  ...(Deno.env.get('GEMINI_FALLBACK_MODELS') ?? 'gemini-3.8-flash,gemini-3.5-flash').split(','),
].map(clean).filter((m, i, all) => m.length > 0 && all.indexOf(m) === i);
const ALLOWED_ORIGINS = ['https://siaga-app.vercel.app'];
const throttle = new Throttle(20, 60_000); // 20 questions a minute per visitor, per function instance
const BUSY = [429, 500, 502, 503, 504]; // worth trying again or trying the next model
const DEADLINE_MS = 9000; // the whole answer, across retries; the app gives up a little later

function corsFor(origin: string | null): Record<string, string> {
  const ok = origin !== null && (ALLOWED_ORIGINS.includes(origin) || /^http:\/\/localhost(:\d+)?$/.test(origin));
  return {
    'Access-Control-Allow-Origin': ok ? origin! : ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

function json(body: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** One call to one model. Returns the parsed JSON, or the HTTP status when it did not work (0 = timeout or network). */
async function callModel(model: string, key: string, system: string, user: string, timeoutMs: number): Promise<{ data: unknown } | { status: number }> {
  // The 2.5 Flash models "think" before answering, which is slow and eats the output budget. A short explanation does not need it.
  const thinking = /^gemini-2\.5-flash/.test(model) ? { thinkingConfig: { thinkingBudget: 0 } } : {};
  try {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: 'user', parts: [{ text: user }] }],
        generationConfig: { temperature: 0.3, maxOutputTokens: 2048, ...thinking },
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) {
      // The reason goes to our private function logs, never to the caller.
      console.error('gemini http', model, res.status, (await res.text()).slice(0, 300));
      return { status: res.status };
    }
    return { data: await res.json() };
  } catch (e) {
    console.error('gemini error', model, e instanceof Error ? `${e.name}: ${e.message}` : String(e));
    return { status: 0 };
  }
}

Deno.serve(async (req) => {
  const cors = corsFor(req.headers.get('origin'));
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405, cors);

  const key = Deno.env.get('GEMINI_API_KEY');
  if (!key) return json({ error: 'not configured' }, 503, cors);

  const visitor = (req.headers.get('x-forwarded-for') ?? 'unknown').split(',')[0].trim();
  if (!throttle.allow(visitor, Date.now())) return json({ error: 'slow down' }, 429, cors);

  let body: unknown;
  try {
    const raw = await req.text();
    if (raw.length > 4000) return json({ error: 'too large' }, 413, cors);
    body = JSON.parse(raw);
  } catch {
    return json({ error: 'bad json' }, 400, cors);
  }
  const parsed = parseRequest(body);
  if ('error' in parsed) return json({ error: parsed.error }, 400, cors);

  const { system, user } = buildPrompt(parsed);
  const started = Date.now();
  for (const model of MODELS) {
    for (let attempt = 0; attempt < 2; attempt++) {
      const left = DEADLINE_MS - (Date.now() - started);
      if (left < 1500) break;
      const out = await callModel(model, key, system, user, Math.min(6000, left));
      if ('data' in out) {
        const text = parseGeminiResponse(out.data);
        if (text !== null) return json({ text, model }, 200, cors);
        console.error('gemini unusable', model, JSON.stringify(out.data).slice(0, 400));
        break; // an answer we will not use: do not ask the same model again
      }
      if (out.status === 429) break; // out of quota: asking again will not help, try the next model
      if (!BUSY.includes(out.status) && out.status !== 0) break; // a real refusal (key, model name): try the next model
      if (attempt === 0) await sleep(400); // a short pause, then one more try
    }
  }
  console.error('no model answered');
  return json({ error: 'upstream' }, 502, cors);
});
