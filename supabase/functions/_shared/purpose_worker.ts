import { bodyJson } from "./rad_contract.ts";

export type WorkerDb = (path: string, init?: RequestInit) => Promise<unknown>;
export async function purposeAuthorized(
  expected: string,
  supplied: string | null,
): Promise<boolean> {
  if (
    expected.length < 32 || expected.length > 512 || !supplied ||
    supplied.length > 512
  ) return false;
  const buffers = await Promise.all(
    [expected, supplied].map((s) =>
      crypto.subtle.digest("SHA-256", new TextEncoder().encode(s))
    ),
  );
  const [a, b] = buffers.map((v) => new Uint8Array(v));
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}
export function workerDatabase(url: string, key: string): WorkerDb {
  return async (path, init) => {
    const response = await fetch(`${url}/rest/v1/${path}`, {
      ...init,
      signal: AbortSignal.timeout(10000),
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
    });
    if (!response.ok) {
      throw Object.assign(new Error("worker_database_failed"), {
        status: response.status,
      });
    }
    return bodyJson(response, 2 * 1024 * 1024);
  };
}
