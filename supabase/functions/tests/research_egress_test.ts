import { createResearchEgressFetch } from "../research-sync/egress.ts";

Deno.test("research transport stays unavailable without a fixed HTTPS gateway and purpose token", () => {
  for (
    const url of [
      "",
      "http://gateway.example.com/fetch",
      "https://127.0.0.1/fetch",
      "https://gateway.example.com/wrong",
      "https://gateway.example.com/fetch?token=private",
    ]
  ) {
    if (
      createResearchEgressFetch({
        url,
        token: "synthetic-purpose-token".repeat(3),
      })
    ) throw new Error("unsafe gateway configuration");
  }
  if (
    createResearchEgressFetch({
      url: "https://gateway.example.com/fetch",
      token: "",
    })
  ) throw new Error("missing purpose token");
});

Deno.test("research gateway receives no caller credentials and preserves the complete source response", async () => {
  const text = "متن کامل evidence";
  const bytes = new TextEncoder().encode(text);
  const token = "synthetic-purpose-token".repeat(3);
  const transport = createResearchEgressFetch({
    url: "https://gateway.example.com/fetch",
    token,
    fetch: (url, init) => {
      if (
        String(url) !== "https://gateway.example.com/fetch" ||
        init?.redirect !== "error"
      ) throw new Error("gateway not fixed");
      const body = JSON.parse(String(init?.body));
      if (
        Object.keys(body).join() !== "url" ||
        body.url !== "https://www.canada.ca/study"
      ) throw new Error("private caller data forwarded");
      if (
        new Headers(init?.headers).get("Authorization") !== "Bearer " + token
      ) throw new Error("purpose authentication missing");
      return Promise.resolve(
        Response.json({
          status: 200,
          headers: { "content-type": "text/html", "set-cookie": "private" },
          body_base64: btoa(String.fromCharCode(...bytes)),
        }),
      );
    },
  });
  const response = await transport!("https://www.canada.ca/study", {
    headers: {
      Authorization: "Bearer PRIVATE_USER_TOKEN",
      Cookie: "PRIVATE_SESSION",
    },
  });
  if (await response.text() !== text || response.headers.has("set-cookie")) {
    throw new Error("source bytes or header boundary");
  }
});

Deno.test("gateway errors, invalid envelopes and oversized evidence fail closed", async () => {
  for (
    const reply of [
      () => Response.json({ error: "robots_disallowed" }, { status: 422 }),
      () =>
        Response.json({ status: 200, headers: {}, body_base64: "invalid!" }),
      () =>
        Response.json({
          status: 200,
          headers: {},
          body_base64: btoa("x".repeat(1_000_001)),
        }),
    ]
  ) {
    const transport = createResearchEgressFetch({
      url: "https://gateway.example.com/fetch",
      token: "synthetic-purpose-token".repeat(3),
      fetch: () => Promise.resolve(reply()),
    });
    let rejected = false;
    try {
      await transport!("https://www.canada.ca/study", {});
    } catch {
      rejected = true;
    }
    if (!rejected) throw new Error("unsafe gateway reply accepted");
  }
});
