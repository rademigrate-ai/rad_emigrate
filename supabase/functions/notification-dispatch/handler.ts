import { corsHeaders } from "../_shared/cors.ts";
import { dispatchSandboxNotifications } from "./worker.ts";

type Options = {
  enabled: boolean;
  supabaseUrl: string;
  environment?: string;
  stagingProject?: string;
  invocationToken: string;
  database: (path: string, init?: RequestInit) => Promise<unknown>;
  timeoutMs?: number;
};
const headers = {
  ...corsHeaders,
  "Access-Control-Allow-Headers": `${
    corsHeaders["Access-Control-Allow-Headers"]
  }, x-rad-notification-token`,
  "Content-Type": "application/json",
};
const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });

export function safeSandboxTarget(
  value: string,
  environment?: string,
  project?: string,
): boolean {
  try {
    const url = new URL(value);
    if (
      url.username || url.password || url.pathname !== "/" || url.search ||
      url.hash
    ) return false;
    if (["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)) {
      return ["http:", "https:"].includes(url.protocol);
    }
    return environment === "staging" && typeof project === "string" &&
      /^[a-z]{20}$/.test(project) &&
      project !== "inshddthftkhcdosoqcn" && url.protocol === "https:" &&
      !url.port &&
      url.hostname === `${project}.supabase.co`;
  } catch {
    return false;
  }
}

async function tokenMatches(
  expected: string,
  supplied: string,
): Promise<boolean> {
  if (!supplied || supplied.length > 512) return false;
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all(
    [expected, supplied].map((value) =>
      crypto.subtle.digest("SHA-256", encoder.encode(value))
    ),
  );
  const a = new Uint8Array(left), b = new Uint8Array(right);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

export function createNotificationDispatchHandler(options: Options) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers });
    if (req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }
    if (
      !options.enabled || options.invocationToken.length < 32 ||
      options.invocationToken.length > 512 ||
      !safeSandboxTarget(
        options.supabaseUrl,
        options.environment,
        options.stagingProject,
      )
    ) {
      return json(503, { error: "notification_sandbox_disabled" });
    }
    if (
      !await tokenMatches(
        options.invocationToken,
        req.headers.get("x-rad-notification-token") ?? "",
      )
    ) {
      return json(403, { error: "forbidden" });
    }
    let limit = 10;
    const reader = req.body?.getReader();
    if (reader) {
      try {
        let length = 0;
        const chunks: Uint8Array[] = [];
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          length += value.length;
          if (length > 4096) {
            await reader.cancel();
            return json(413, { error: "request_too_large" });
          }
          chunks.push(value);
        }
        const bytes = new Uint8Array(length);
        let offset = 0;
        for (const chunk of chunks) {
          bytes.set(chunk, offset);
          offset += chunk.length;
        }
        const payload = length
          ? JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes))
          : {};
        if (
          payload === null || typeof payload !== "object" ||
          Array.isArray(payload) ||
          Object.keys(payload).some((key) => key !== "limit") ||
          (payload.limit !== undefined &&
            (!Number.isInteger(payload.limit) || payload.limit < 1 ||
              payload.limit > 20))
        ) {
          return json(400, { error: "invalid_dispatch_request" });
        }
        limit = payload.limit ?? 10;
      } catch {
        return json(400, { error: "invalid_dispatch_request" });
      } finally {
        reader.releaseLock();
      }
    }
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const deadline = new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(new Error("dispatch_timeout"));
        }, options.timeoutMs ?? 10000);
      });
      const dispatch = dispatchSandboxNotifications(
        async (path, init) => {
          if (controller.signal.aborted) throw new Error("dispatch_timeout");
          return await options.database(path, {
            ...init,
            signal: controller.signal,
          });
        },
        async () => {},
        limit,
      ); // sandbox receipt only; no external provider
      return json(200, await Promise.race([dispatch, deadline]));
    } catch {
      return json(503, { error: "notification_dispatch_unavailable" });
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  };
}

export const handler = (req: Request) => {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return createNotificationDispatchHandler({
    enabled: Deno.env.get("RAD_NOTIFICATION_SANDBOX_ENABLED") === "true",
    supabaseUrl: url,
    environment: Deno.env.get("APP_ENV"),
    stagingProject: Deno.env.get("RAD_STAGING_PROJECT_REF"),
    invocationToken: Deno.env.get("RAD_NOTIFICATION_WORKER_TOKEN") ?? "",
    database: async (path, init) => {
      if (!url || !key) throw new Error("backend_unavailable");
      const response = await fetch(`${url}/rest/v1/${path}`, {
        ...init,
        redirect: "error",
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
      });
      if (!response.ok) throw new Error("backend_unavailable");
      return await response.json();
    },
  })(req);
};
