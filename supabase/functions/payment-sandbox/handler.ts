import { corsHeaders } from "../_shared/cors.ts";

export type SandboxPaymentEvent = {
  mode: "sandbox";
  event_id: string;
  subscription_id: string;
  user_id: string;
  type:
    | "payment_succeeded"
    | "subscription_cancelled"
    | "payment_refunded"
    | "payment_chargeback";
  sequence: number;
  amount_minor: number;
  currency: string;
  occurred_at: string;
  period_end: string | null;
};
type Options = {
  enabled: boolean;
  supabaseUrl: string;
  secret: string;
  apply: (
    event: SandboxPaymentEvent,
    sha256: string,
    signal?: AbortSignal,
  ) => Promise<unknown>;
  now?: () => number;
  timeoutMs?: number;
};
export class SandboxEventRejected extends Error {}
const encoder = new TextEncoder();
const headers = {
  ...corsHeaders,
  "Access-Control-Allow-Headers": `${
    corsHeaders["Access-Control-Allow-Headers"]
  }, x-rad-sandbox-signature`,
  "Content-Type": "application/json",
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });
const hex = (data: ArrayBuffer) =>
  Array.from(new Uint8Array(data), (n) => n.toString(16).padStart(2, "0")).join(
    "",
  );
function localTarget(value: string): boolean {
  try {
    const url = new URL(value);
    return ["http:", "https:"].includes(url.protocol) &&
      ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname) &&
      !url.username && !url.password && url.pathname === "/" && !url.search &&
      !url.hash;
  } catch {
    return false;
  }
}
function eventFrom(value: unknown, now: number): SandboxPaymentEvent | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const event = value as Record<string, unknown>;
  const keys = [
    "mode",
    "event_id",
    "subscription_id",
    "user_id",
    "type",
    "sequence",
    "amount_minor",
    "currency",
    "occurred_at",
    "period_end",
  ];
  if (
    Object.keys(event).some((k) => !keys.includes(k)) ||
    event.mode !== "sandbox" ||
    typeof event.event_id !== "string" ||
    !/^[A-Za-z0-9_.:-]{1,128}$/.test(event.event_id) ||
    typeof event.subscription_id !== "string" ||
    !/^[A-Za-z0-9_.:-]{1,128}$/.test(event.subscription_id) ||
    typeof event.user_id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      event.user_id,
    ) ||
    typeof event.type !== "string" ||
    ![
      "payment_succeeded",
      "subscription_cancelled",
      "payment_refunded",
      "payment_chargeback",
    ].includes(event.type) ||
    !Number.isInteger(event.sequence) || Number(event.sequence) < 1 ||
    Number(event.sequence) > 999999999 ||
    !Number.isInteger(event.amount_minor) || Number(event.amount_minor) < 0 ||
    Number(event.amount_minor) > 1000000000 ||
    typeof event.currency !== "string" || !/^[A-Z]{3}$/.test(event.currency) ||
    typeof event.occurred_at !== "string"
  ) return null;
  const occurred = Date.parse(event.occurred_at);
  const end = typeof event.period_end === "string"
    ? Date.parse(event.period_end)
    : NaN;
  if (
    !Number.isFinite(occurred) || occurred > now + 300000 ||
    (event.type !== "subscription_cancelled" &&
      Number(event.amount_minor) < 1) ||
    (event.type === "payment_succeeded" &&
      (!Number.isFinite(end) || end <= occurred)) ||
    (event.period_end != null && !Number.isFinite(end))
  ) return null;
  return {
    mode: "sandbox",
    event_id: event.event_id,
    subscription_id: event.subscription_id,
    user_id: event.user_id,
    type: event.type as SandboxPaymentEvent["type"],
    sequence: Number(event.sequence),
    amount_minor: Number(event.amount_minor),
    currency: event.currency,
    occurred_at: new Date(occurred).toISOString(),
    period_end: Number.isFinite(end) ? new Date(end).toISOString() : null,
  };
}

export function createPaymentSandboxHandler(options: Options) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers });
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    // Refuses hosted/production databases even if an enabled flag is mistakenly set.
    if (
      !options.enabled || options.secret.length < 32 ||
      !localTarget(options.supabaseUrl)
    ) return json(503, { error: "payment_sandbox_disabled" });
    const signature = /^t=([0-9]{10,12}),v1=([0-9a-f]{64})$/.exec(
      req.headers.get("x-rad-sandbox-signature") ?? "",
    );
    const now = (options.now ?? Date.now)();
    if (!signature || Math.abs(now / 1000 - Number(signature[1])) > 300) {
      return json(401, { error: "invalid_sandbox_signature" });
    }
    let raw: Uint8Array<ArrayBuffer>;
    try {
      const reader = req.body?.getReader();
      const chunks: Uint8Array[] = [];
      let length = 0;
      if (reader) {
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            length += value.length;
            if (length > 32768) {
              await reader.cancel();
              return json(413, { error: "sandbox_event_too_large" });
            }
            chunks.push(value);
          }
        } finally {
          reader.releaseLock();
        }
      }
      raw = new Uint8Array(length);
      let offset = 0;
      for (const chunk of chunks) {
        raw.set(chunk, offset);
        offset += chunk.length;
      }
      const key = await crypto.subtle.importKey(
        "raw",
        encoder.encode(options.secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["verify"],
      );
      const supplied = new Uint8Array(
        signature[2].match(/../g)!.map((pair) => parseInt(pair, 16)),
      );
      const prefix = encoder.encode(`${signature[1]}.`);
      const signed = new Uint8Array(prefix.length + raw.length);
      signed.set(prefix);
      signed.set(raw, prefix.length);
      if (!await crypto.subtle.verify("HMAC", key, supplied, signed)) {
        return json(401, { error: "invalid_sandbox_signature" });
      }
    } catch {
      return json(400, { error: "invalid_sandbox_event" });
    }
    let event: SandboxPaymentEvent | null;
    try {
      event = eventFrom(
        JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(raw)),
        now,
      );
    } catch {
      event = null;
    }
    if (!event) return json(400, { error: "invalid_sandbox_event" });
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const sha256 = hex(
        await crypto.subtle.digest(
          "SHA-256",
          encoder.encode(JSON.stringify(event)),
        ),
      );
      const deadline = new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(new Error("payment_timeout"));
        }, options.timeoutMs ?? 15000);
      });
      const result = await Promise.race([
        options.apply(event, sha256, controller.signal),
        deadline,
      ]);
      const row = result as Record<string, unknown> | null;
      if (
        !row || row.mode !== "sandbox" || typeof row.duplicate !== "boolean" ||
        !["applied", "ignored_stale", "ignored_terminal"].includes(
          String(row.decision),
        )
      ) throw new Error("invalid_result");
      return json(200, {
        mode: "sandbox",
        duplicate: row.duplicate,
        decision: row.decision,
      });
    } catch (error) {
      if (error instanceof SandboxEventRejected) {
        return json(422, { error: "sandbox_event_rejected" });
      }
      return json(503, { error: "payment_sandbox_unavailable" });
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  };
}

export async function handler(req: Request): Promise<Response> {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return await createPaymentSandboxHandler({
    enabled: Deno.env.get("RAD_PAYMENT_SANDBOX_ENABLED") === "true" &&
      !!serviceKey,
    supabaseUrl: url,
    secret: Deno.env.get("RAD_PAYMENT_SANDBOX_SECRET") ?? "",
    apply: async (event, sha256, signal) => {
      const response = await fetch(
        `${url}/rest/v1/rpc/apply_sandbox_payment_event`,
        {
          method: "POST",
          redirect: "error",
          signal,
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ p_event: event, p_payload_sha256: sha256 }),
        },
      );
      if (!response.ok) {
        const failure = await response.json().catch(() => ({}));
        if (["22023", "23503"].includes(failure?.code)) {
          throw new SandboxEventRejected();
        }
        throw new Error("sandbox_database_unavailable");
      }
      return await response.json();
    },
  })(req);
}
