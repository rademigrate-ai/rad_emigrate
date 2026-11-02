import { contractValid } from "../_shared/rad_contract.ts";

// Load the actual deployed entrypoint, capturing only its Deno.serve callback.
// No listener/provider/DB is created. Gateway acceptance remains a hosted gate.
Deno.test("official deployed entrypoint is disabled by default and authenticates before DB", async () => {
  const variables = [
    "RAD_OFFICIAL_SOURCE_WORKER_ENABLED",
    "RAD_OFFICIAL_SOURCE_DISCOVERY_ENABLED",
    "RAD_OFFICIAL_SOURCE_WORKER_TOKEN",
  ];
  const previous = variables.map((key) => Deno.env.get(key));
  const originalServe = Object.getOwnPropertyDescriptor(Deno, "serve")!;
  type Handler = (request: Request) => Response | Promise<Response>;
  const token = "synthetic-official-entrypoint-token-".repeat(2);
  try {
    Deno.env.set("RAD_OFFICIAL_SOURCE_WORKER_TOKEN", token);
    Deno.env.delete("RAD_OFFICIAL_SOURCE_DISCOVERY_ENABLED");
    for (const enabled of [false, true]) {
      if (enabled) Deno.env.set("RAD_OFFICIAL_SOURCE_WORKER_ENABLED", "true");
      else Deno.env.delete("RAD_OFFICIAL_SOURCE_WORKER_ENABLED");
      let accept: (handler: Handler) => void;
      const handlerPromise = new Promise<Handler>((resolve) =>
        accept = resolve
      );
      Object.defineProperty(Deno, "serve", {
        configurable: true,
        enumerable: originalServe.enumerable,
        writable: true,
        value: (handler: Handler) => accept(handler),
      });
      await import(`../official-source-worker/index.ts?activation=${enabled}`);
      const handler = await handlerPromise;
      for (const suffix of ["", "?dispatch=1"]) {
        const response = await handler(
          new Request(
            "https://worker.example.invalid" + suffix,
            {
              method: "POST",
              headers: { "x-rad-official-source-token": "wrong" },
            },
          ),
        );
        const body = await response.json();
        if (
          response.status !== (enabled ? 403 : 503) ||
          body.error !==
            (enabled ? "forbidden" : "official_source_worker_disabled")
        ) {
          throw Error("entrypoint default or authentication bypass");
        }
      }
      const methodResponse = await handler(
        new Request("https://worker.example.invalid", { method: "GET" }),
      );
      if (methodResponse.status !== 405) {
        throw Error("unexpected method accepted");
      }
      // This import also resolves the same generated wire-contract bundle used
      // in the entrypoint; no synthetic success response is accepted as proof.
      if (
        contractValid("official_source_worker_response", { error: "forbidden" })
      ) {
        throw Error("auth failure reported as completed work");
      }
    }
  } finally {
    Object.defineProperty(Deno, "serve", originalServe);
    variables.forEach((key, index) => {
      if (previous[index] === undefined) Deno.env.delete(key);
      else Deno.env.set(key, previous[index]!);
    });
  }
});
