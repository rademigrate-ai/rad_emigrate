import {
  decimal,
  decimalJson,
  fetchObservation,
} from "../currency-refresh/providers.ts";
import { createCurrencyHandler } from "../currency-refresh/handler.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
  }
}
const now = new Date("2026-10-19T12:00:00Z");
Deno.test("FX decimals preserve numeric lexemes and expand exponents without binary rounding", () => {
  equal(
    (decimalJson('{"rate":0.123456789012345678,"date":"2026-10-19"}') as {
      rate: string;
    }).rate,
    "0.123456789012345678",
  );
  equal(decimal("1.23456789012345678e-1"), "0.123456789012345678");
  for (
    const input of [
      "0",
      "-1",
      "NaN",
      "1e999",
      "0.0000000000000000001",
      "1.5;DROP",
    ]
  ) {
    let denied = false;
    try {
      decimal(input);
    } catch {
      denied = true;
    }
    equal(denied, true);
  }
});
Deno.test("FX primary/fallback provenance, mirror fallback, exact pair and no arbitrary URLs", async () => {
  const urls: string[] = [];
  const fetcher = ((url: string, init: RequestInit) => {
    urls.push(url);
    equal(init.redirect, "error");
    if (!url.startsWith("https://latest.currency-api.pages.dev/")) {
      return Promise.resolve(new Response("outage", { status: 503 }));
    }
    return Promise.resolve(
      new Response(
        '{"date":"2026-10-19","eur":{"irr":49999.123456789012345678}}',
        { headers: { "content-type": "application/json" } },
      ),
    );
  }) as typeof fetch;
  const value = await fetchObservation("EUR", "IRR", fetcher, now);
  equal(value.provider, "fawazahmed0");
  equal(value.rate, "49999.123456789012345678");
  equal(urls.length, 3);
  let denied = false;
  try {
    await fetchObservation("http://127.0.0.1", "USD", fetcher, now);
  } catch {
    denied = true;
  }
  equal(denied, true);
  equal(urls.length, 3);
});
Deno.test("FX rejects stale/future/invalid dates and wrong primary pair", async () => {
  for (const date of ["2026-10-20", "2026-10-01", "2026-02-30"]) {
    let denied = false;
    try {
      await fetchObservation(
        "EUR",
        "USD",
        (() =>
          Promise.resolve(
            Response.json({
              date,
              base: "eur",
              quote: "usd",
              rate: 1.5,
              eur: { usd: 1.5 },
            }),
          )) as typeof fetch,
        now,
      );
    } catch {
      denied = true;
    }
    equal(denied, true);
  }
});
Deno.test("FX worker denies missing purpose token before network or database", async () => {
  let calls = 0;
  const handler = createCurrencyHandler({
    enabled: true,
    token: "x".repeat(32),
    database: () => {
      calls++;
      return Promise.resolve(null);
    },
  });
  equal(
    (await handler(
      new Request("https://local.test", {
        method: "POST",
        body: '{"pairs":[]}',
      }),
    )).status,
    403,
  );
  equal(calls, 0);
});
