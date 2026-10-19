/** A sandbox receipt is a simulation, never evidence of email/SMS/push delivery. */
type Row = Record<string, unknown>;
type Db = (path: string, init: RequestInit) => Promise<unknown>;
export type SandboxEnvelope = {
  delivery_id: string;
  notification_id: string;
  user_id: string;
  channel: "email" | "sms" | "push";
  transport: "sandbox";
};
export type SandboxTransport = (envelope: SandboxEnvelope) => Promise<void>;
export class NotificationWorkerError extends Error {
  constructor() {
    super("notification_outbox_unavailable");
  }
}
const uuid = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);

export async function dispatchSandboxNotifications(
  db: Db,
  transport: SandboxTransport,
  maximum = 10,
) {
  if (!Number.isInteger(maximum) || maximum < 1 || maximum > 25) {
    throw new RangeError("invalid_batch_limit");
  }
  const counts = {
    mode: "sandbox" as const,
    claimed: 0,
    sandbox_receipts: 0,
    retry_scheduled: 0,
    failed: 0,
    stale: 0,
  };
  for (let i = 0; i < maximum; i++) {
    let claim: unknown;
    try {
      claim = await db("rpc/claim_sandbox_notification", {
        method: "POST",
        body: "{}",
      });
    } catch {
      throw new NotificationWorkerError();
    }
    if (!Array.isArray(claim)) throw new NotificationWorkerError();
    if (claim.length === 0) break;
    if (
      claim.length !== 1 || claim[0] === null || typeof claim[0] !== "object"
    ) throw new NotificationWorkerError();
    const row = claim[0] as Row;
    if (
      !uuid(row.id) || !uuid(row.notification_id) || !uuid(row.user_id) ||
      !uuid(row.lease_token) ||
      row.transport !== "sandbox" || !Number.isInteger(row.attempts) ||
      Number(row.attempts) < 1 || Number(row.attempts) > 3 ||
      !["email", "sms", "push"].includes(String(row.channel))
    ) throw new NotificationWorkerError();
    counts.claimed++;
    let success = true;
    try {
      await transport({
        delivery_id: row.id,
        notification_id: row.notification_id,
        user_id: row.user_id,
        channel: row.channel as SandboxEnvelope["channel"],
        transport: "sandbox",
      });
    } catch {
      success = false;
    }
    let finished: unknown;
    try {
      finished = await db("rpc/finish_sandbox_notification", {
        method: "POST",
        body: JSON.stringify({
          p_delivery_id: row.id,
          p_lease_token: row.lease_token,
          p_success: success,
        }),
      });
    } catch {
      throw new NotificationWorkerError();
    }
    if (finished === false) counts.stale++;
    else if (finished !== true) throw new NotificationWorkerError();
    else if (success) counts.sandbox_receipts++;
    else if (Number(row.attempts) >= 3) counts.failed++;
    else counts.retry_scheduled++;
  }
  return counts;
}
