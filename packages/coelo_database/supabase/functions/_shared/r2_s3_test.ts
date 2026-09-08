import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1.0.14";
import { R2Client, R2TransportError, validateR2Config } from "./r2_s3.ts";

// Synthetic, non-working credentials for deterministic signing only.
const config = {
  endpoint: "https://account.r2.cloudflarestorage.com",
  region: "auto",
  accessKeyId: "access-key",
  secretAccessKey: "secret-key",
  bucket: "coelo-moments-private",
};
const now = () => new Date("2026-08-21T12:00:00.000Z");

Deno.test("GET reads actual chunks within the server-selected byte limit", async () => {
  for (const length of [undefined, "4"]) {
    const client = new R2Client(config, {
      now,
      fetch: (request) => {
        assertEquals(request.method, "GET");
        assertEquals(request.redirect, "error");
        const body = new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new Uint8Array([1, 2]));
            controller.enqueue(new Uint8Array([3, 4]));
            controller.close();
          },
        });
        return Promise.resolve(
          new Response(body, {
            headers: length ? { "content-length": length } : {},
          }),
        );
      },
    });
    assertEquals(await client.get("a/b", 4), new Uint8Array([1, 2, 3, 4]));
  }
});

Deno.test("GET cancels overflow even when Content-Length lies or is absent", async () => {
  for (const length of [undefined, "2"]) {
    let cancelled = false;
    const client = new R2Client(config, {
      now,
      fetch: () =>
        Promise.resolve(
          new Response(
            new ReadableStream({
              start(controller) {
                controller.enqueue(new Uint8Array(5));
              },
              cancel() {
                cancelled = true;
              },
            }),
            { headers: length ? { "content-length": length } : {} },
          ),
        ),
    });
    await assertRejects(
      () => client.get("a/b", 4),
      R2TransportError,
      "r2_size_limit",
    );
    assertEquals(cancelled, true);
  }
});

Deno.test("GET rejects oversized or malformed declared length before reading", async () => {
  for (const length of ["5", "0", "-1", "1.5", "NaN", "9007199254740992"]) {
    let cancelled = false;
    const client = new R2Client(config, {
      now,
      fetch: () =>
        Promise.resolve(
          new Response(
            new ReadableStream({
              cancel() {
                cancelled = true;
              },
            }),
            { headers: { "content-length": length } },
          ),
        ),
    });
    await assertRejects(() => client.get("a/b", 4), R2TransportError);
    assertEquals(cancelled, true);
  }
});

Deno.test("GET rejects empty, truncated, and partial objects", async () => {
  for (
    const [body, headers, status] of [
      [null, {}, 200],
      [new Uint8Array(0), {}, 200],
      [new Uint8Array(2), { "content-length": "4" }, 200],
      [new Uint8Array(2), {}, 206],
      [null, {}, 403],
      [null, {}, 404],
      [null, {}, 500],
    ] as const
  ) {
    const client = new R2Client(config, {
      now,
      fetch: () => Promise.resolve(new Response(body, { headers, status })),
    });
    await assertRejects(() => client.get("a/b", 4), R2TransportError);
  }
});

Deno.test("GET validates limits before any request", async () => {
  let requests = 0;
  const client = new R2Client(config, {
    now,
    fetch: () => {
      requests++;
      throw new Error("unexpected");
    },
  });
  for (
    const limit of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]
  ) {
    await assertRejects(
      () => client.get("a/b", limit),
      R2TransportError,
      "r2_invalid_limit",
    );
  }
  assertEquals(requests, 0);
});

Deno.test("GET sanitizes network and body errors without retry", async () => {
  for (const bodyFailure of [false, true]) {
    let requests = 0;
    const client = new R2Client(config, {
      now,
      fetch: () => {
        requests++;
        if (!bodyFailure) throw new Error("private URL and payload");
        return Promise.resolve(
          new Response(
            new ReadableStream({
              start(controller) {
                controller.error(new Error("private URL and payload"));
              },
            }),
          ),
        );
      },
    });
    const error = await assertRejects(
      () => client.get("a/b", 4),
      R2TransportError,
    );
    assertEquals(error.message, "r2_transport_failed");
    assertEquals(requests, 1);
  }
});

Deno.test("PUT sends a stable copy with signed MIME and rejects redirects", async () => {
  let requests = 0;
  const bytes = new Uint8Array([1, 2, 3]);
  const client = new R2Client(config, {
    now,
    fetch: async (request) => {
      requests++;
      assertEquals(request.method, "PUT");
      assertEquals(request.redirect, "error");
      assertEquals(
        request.headers.get("content-type"),
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      );
      assertEquals(
        new Uint8Array(await request.arrayBuffer()),
        new Uint8Array([1, 2, 3]),
      );
      return new Response(null);
    },
  });
  const pending = client.put(
    "exports/form/responses.xlsx",
    bytes,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  );
  bytes.fill(9);
  await pending;
  assertEquals(requests, 1);
});

Deno.test("PUT rejects empty bytes and unsafe MIME before network", async () => {
  let requests = 0;
  const client = new R2Client(config, {
    now,
    fetch: () => {
      requests++;
      throw new Error("unexpected");
    },
  });
  await assertRejects(
    () => client.put("a/b", new Uint8Array(), "image/png"),
    R2TransportError,
  );
  for (
    const mime of [
      "",
      "image/png\r\nx-private: value",
      " image/png",
      "image/png ",
    ]
  ) {
    await assertRejects(
      () => client.put("a/b", new Uint8Array([1]), mime),
      R2TransportError,
    );
  }
  assertEquals(requests, 0);
});

Deno.test("PUT fails safely without retry on failed writes", async () => {
  for (const status of [302, 403, 500, null]) {
    let requests = 0;
    const client = new R2Client(config, {
      now,
      fetch: () => {
        requests++;
        if (status === null) throw new Error("private URL");
        return Promise.resolve(
          new Response("private upstream body", { status }),
        );
      },
    });
    const error = await assertRejects(
      () => client.put("a/b", new Uint8Array([1]), "image/png"),
      R2TransportError,
    );
    assertEquals(
      error.message,
      status === null ? "r2_transport_failed" : `r2_http_${status}`,
    );
    assertEquals(requests, 1);
  }
});

Deno.test("validates unsafe endpoints without echoing configuration", () => {
  for (
    const endpoint of [
      "not a URL containing synthetic private input",
      "http://account.r2.cloudflarestorage.com",
      "https://user:synthetic@account.r2.cloudflarestorage.com",
      `${config.endpoint}?query=synthetic`,
      `${config.endpoint}#fragment`,
      `${config.endpoint}?`,
      `${config.endpoint}#`,
    ]
  ) {
    const error = assertThrows(
      () => new R2Client({ ...config, endpoint }),
      R2TransportError,
    );
    assertEquals(error.message, "r2_invalid_endpoint");
  }
});

Deno.test("rejects missing configuration and invalid buckets through the constructor", () => {
  for (const field of Object.keys(config)) {
    assertThrows(
      () => new R2Client({ ...config, [field]: " " }),
      R2TransportError,
      "r2_not_configured",
    );
  }
  for (const bucket of ["/private", "UPPERCASE", "x", "bucket/path"]) {
    assertThrows(
      () => new R2Client({ ...config, bucket }),
      R2TransportError,
      "r2_invalid_bucket",
    );
  }
});

Deno.test("retains a frozen validated config independent of caller mutation", async () => {
  const mutable = { ...config };
  const client = new R2Client(mutable, { now });
  mutable.endpoint = "https://unexpected.invalid";
  mutable.bucket = "different-bucket";
  assertEquals(Object.isFrozen(client.config), true);
  assertEquals(
    (await client.presignGet("institution/asset/original")).url.hostname,
    "account.r2.cloudflarestorage.com",
  );
  assertEquals(
    validateR2Config({ ...config, endpoint: `${config.endpoint}/` }).endpoint,
    config.endpoint,
  );
});

Deno.test("matches an independently derived SigV4 GET vector", async () => {
  // Independently computed from the literal AWS canonical request with Python
  // stdlib hashlib/hmac, not from this module's helpers.
  const signed = await new R2Client(config, { now }).presignGet(
    "institution/asset/original",
  );
  assertEquals(
    signed.url.pathname,
    "/coelo-moments-private/institution/asset/original",
  );
  assertEquals(
    signed.url.searchParams.get("X-Amz-Signature"),
    "a657cee6c6df6a264414ed3e73d1e8f5a5325b9348a3553938360b2066618324",
  );
  assertEquals(signed.url.searchParams.get("X-Amz-Expires"), "120");
  assertEquals(signed.requiredHeaders, {});
});

Deno.test("rejects unsafe keys and out-of-bound TTLs", async () => {
  const client = new R2Client(config, { now });
  for (const key of ["", "/absolute", "a//b", "a/./b", "a/../b", "a/"]) {
    await assertRejects(
      () => client.presignGet(key),
      R2TransportError,
      "r2_invalid_key",
    );
  }
  for (const ttl of [0, -1, 1.5, 901, NaN, Infinity]) {
    await assertRejects(
      () => client.presignGet("a/b", ttl),
      R2TransportError,
      "r2_invalid_expiry",
    );
    await assertRejects(
      () => client.presignPut("a/b", "image/webp", ttl),
      R2TransportError,
      "r2_invalid_expiry",
    );
  }
  for (const ttl of [1, 900]) {
    assertEquals(
      (await client.presignGet("a/b", ttl)).url.searchParams.get(
        "X-Amz-Expires",
      ),
      `${ttl}`,
    );
  }
});

Deno.test("matches an independently derived SigV4 PUT vector with signed MIME", async () => {
  // Python stdlib literal canonical request SHA256:
  // 911da620d72c05368d174dd2d4a1a0f3e0dd669d639896b53f210613e4f90425.
  const signed = await new R2Client(config, { now }).presignPut(
    "institution/asset/original",
    "image/webp",
    300,
  );
  assertEquals(
    signed.url.searchParams.get("X-Amz-Signature"),
    "03d32940e93c433211c05ba2d0fbff18f358c2f07e4af8aaacec9e61394d0803",
  );
  assertEquals(
    signed.url.searchParams.get("X-Amz-SignedHeaders"),
    "content-type;host",
  );
  assertEquals(signed.requiredHeaders, { "content-type": "image/webp" });
});

Deno.test("encodes valid key characters without changing key segments", async () => {
  const signed = await new R2Client(config, { now }).presignGet(
    "a/é space!()*/%2F?hash#",
  );
  assertEquals(
    signed.url.pathname,
    "/coelo-moments-private/a/%C3%A9%20space%21%28%29%2A/%252F%3Fhash%23",
  );
  assertEquals(signed.url.hash, "");
});

Deno.test("HEAD returns metadata and rejects absent or invalid metadata", async () => {
  const requests: Request[] = [];
  const valid = new R2Client(config, {
    now,
    fetch: (request) => {
      requests.push(request);
      return Promise.resolve(
        new Response(null, {
          headers: {
            "content-length": "42",
            "content-type": "image/webp; charset=binary",
            etag: "synthetic-etag",
          },
        }),
      );
    },
  });
  assertEquals(await valid.head("a/b"), {
    byteSize: 42,
    mimeType: "image/webp",
    etag: "synthetic-etag",
  });
  assertEquals(requests[0].method, "HEAD");
  assertEquals(
    requests[0].url.startsWith(`${config.endpoint}/${config.bucket}/a/b?`),
    true,
  );
  const invalidHeaders: Record<string, string>[] = [
    { "content-type": "image/webp" },
    { "content-length": "invalid", "content-type": "image/webp" },
    { "content-length": "0", "content-type": "image/webp" },
    { "content-length": "-1", "content-type": "image/webp" },
    { "content-length": "1.5", "content-type": "image/webp" },
    { "content-length": "9007199254740992", "content-type": "image/webp" },
    { "content-length": "42" },
  ];
  for (const headers of invalidHeaders) {
    const client = new R2Client(config, {
      now,
      fetch: () => Promise.resolve(new Response(null, { headers })),
    });
    await assertRejects(
      () => client.head("a/b"),
      R2TransportError,
      "r2_invalid_metadata",
    );
  }
});

Deno.test("DELETE is idempotent on 404 and rejects other unsuccessful responses", async () => {
  for (const status of [204, 404, 403, 500]) {
    const requests: Request[] = [];
    const client = new R2Client(config, {
      now,
      fetch: (request) => {
        requests.push(request);
        return Promise.resolve(new Response(null, { status }));
      },
    });
    if (status === 204 || status === 404) await client.delete("a/b");
    else {await assertRejects(
        () => client.delete("a/b"),
        R2TransportError,
        `r2_http_${status}`,
      );}
    assertEquals(requests[0].method, "DELETE");
  }
});

Deno.test("HEAD never treats missing or failed objects as successful metadata", async () => {
  for (const status of [404, 500]) {
    const client = new R2Client(config, {
      now,
      fetch: () => Promise.resolve(new Response(null, { status })),
    });
    const error = await assertRejects(
      () => client.head("a/b"),
      R2TransportError,
    );
    assertEquals(error.message, `r2_http_${status}`);
  }
});

Deno.test("PUT accepts inclusive TTL bounds and keeps escaped traversal literal", async () => {
  const client = new R2Client(config, { now });
  for (const ttl of [1, 900]) {
    const signed = await client.presignPut("a/%2e%2e/b", "image/webp", ttl);
    assertEquals(signed.url.pathname, "/coelo-moments-private/a/%252e%252e/b");
    assertEquals(signed.url.searchParams.get("X-Amz-Expires"), `${ttl}`);
    assertEquals(signed.requiredHeaders, { "content-type": "image/webp" });
  }
});
