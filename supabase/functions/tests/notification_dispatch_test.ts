import { promiseStub } from "./promise_stub.ts";
import {
  dispatchSandboxNotifications,
  NotificationWorkerError,
  type SandboxEnvelope,
} from "../notification-dispatch/worker.ts";
const id = (last: string) =>
  `47000000-0000-4000-8000-${last.padStart(12, "0")}`;
const claim = () => ({
  id: id("1"),
  notification_id: id("2"),
  user_id: id("3"),
  lease_token: id("4"),
  channel: "email",
  transport: "sandbox",
  attempts: 1,
});
function equal(a: unknown, b: unknown) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(`Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
  }
}

Deno.test("notifications: empty outbox creates no sandbox receipt or transport call", async () => {
  let sends = 0;
  const result = await dispatchSandboxNotifications(
    promiseStub( () => []),
    promiseStub( () => {
      sends++;
    }),
  );
  equal(result, {
    mode: "sandbox",
    claimed: 0,
    sandbox_receipts: 0,
    retry_scheduled: 0,
    failed: 0,
    stale: 0,
  });
  equal(sends, 0);
});

Deno.test("notifications: accepted sandbox receipt uses its lease without exposing content", async () => {
  let claimed = false;
  let ack: unknown;
  const envelopes: SandboxEnvelope[] = [];
  const result = await dispatchSandboxNotifications(promiseStub( (path, init) => {
    if (path.includes("claim_")) {
      if (claimed) return [];
      claimed = true;
      return [{
        ...claim(),
        title: "private fixture",
        body: "private body",
        destination: "private destination",
      }];
    }
    ack = JSON.parse(String(init.body));
    return true;
  }), promiseStub( (value) => {
    envelopes.push(value);
  }));
  equal(result.sandbox_receipts, 1);
  equal(ack, {
    p_delivery_id: id("1"),
    p_lease_token: id("4"),
    p_success: true,
  });
  equal(envelopes, [{
    delivery_id: id("1"),
    notification_id: id("2"),
    user_id: id("3"),
    channel: "email",
    transport: "sandbox",
  }]);
});

Deno.test("notifications: transport failure schedules a bounded retry without raw diagnostics", async () => {
  let acknowledged: unknown;
  const result = await dispatchSandboxNotifications(promiseStub( (path, init) => {
    if (path.includes("claim_")) return [claim()];
    acknowledged = JSON.parse(String(init.body));
    return true;
  }), promiseStub( () => {
    throw new Error("private provider diagnostic");
  }), 1);
  equal(result.retry_scheduled, 1);
  equal(acknowledged, {
    p_delivery_id: id("1"),
    p_lease_token: id("4"),
    p_success: false,
  });
});

Deno.test("notifications: stale or revoked lease does not count as delivery", async () => {
  const result = await dispatchSandboxNotifications(
    promiseStub( (path) => path.includes("claim_") ? [claim()] : false),
    async () => {},
    1,
  );
  equal(result.sandbox_receipts, 0);
  equal(result.stale, 1);
});

Deno.test("notifications: third failed attempt is terminal rather than a scheduled retry", async () => {
  const result = await dispatchSandboxNotifications(
    promiseStub( (path) =>
      path.includes("claim_") ? [{ ...claim(), attempts: 3 }] : true),
    promiseStub( () => {
      throw new Error("synthetic failure");
    }),
    1,
  );
  equal(result.failed, 1);
  equal(result.retry_scheduled, 0);
});

Deno.test("notifications: malformed and non-sandbox claims cannot invoke transport", async () => {
  for (
    const value of [
      null,
      {},
      [null],
      [{ ...claim(), transport: "email_provider" }],
      [{ ...claim(), lease_token: "invalid" }],
      [claim(), claim()],
    ]
  ) {
    let sends = 0;
    let failed = false;
    try {
      await dispatchSandboxNotifications(promiseStub( () => value), promiseStub( () => {
        sends++;
      }));
    } catch (error) {
      failed = error instanceof NotificationWorkerError;
    }
    equal(failed, true);
    equal(sends, 0);
  }
});

Deno.test("notifications: unavailable or malformed acknowledgement never retries transport", async () => {
  for (const fail of [true, false]) {
    let sends = 0;
    let failed = false;
    try {
      await dispatchSandboxNotifications(promiseStub( (path) => {
        if (path.includes("claim_")) return [claim()];
        if (fail) throw new Error("private database diagnostic");
        return null;
      }), promiseStub( () => {
        sends++;
      }));
    } catch (error) {
      failed = error instanceof NotificationWorkerError &&
        error.message === "notification_outbox_unavailable";
    }
    equal(failed, true);
    equal(sends, 1);
  }
});

Deno.test("notifications: batch cap bounds transport and rejects invalid limits", async () => {
  let sends = 0;
  const result = await dispatchSandboxNotifications(
    promiseStub( (path) => path.includes("claim_") ? [claim()] : true),
    promiseStub( () => {
      sends++;
    }),
    3,
  );
  equal(result.claimed, 3);
  equal(sends, 3);
  for (const maximum of [0, 26, NaN, 1.5]) {
    let failed = false;
    try {
      await dispatchSandboxNotifications(
        promiseStub( () => []),
        async () => {},
        maximum,
      );
    } catch (error) {
      failed = error instanceof RangeError;
    }
    equal(failed, true);
  }
});
