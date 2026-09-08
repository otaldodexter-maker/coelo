import { assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  hmacHex,
  MultipartS3Client,
  multipartS3Config,
  sha256Hex,
} from "./multipart_s3.ts";

Deno.test("multipart S3 fails closed without all server-side credentials", () => {
  assertThrows(() => multipartS3Config({}));
  assertThrows(() =>
    multipartS3Config({
      FORMS_S3_ENDPOINT: "https://example.test/storage/v1/s3",
      FORMS_S3_REGION: "us-east-1",
      FORMS_S3_ACCESS_KEY_ID: "key",
    })
  );
  assertEquals(
    multipartS3Config({
      FORMS_S3_ENDPOINT: "https://example.test/storage/v1/s3",
      FORMS_S3_REGION: "us-east-1",
      FORMS_S3_ACCESS_KEY_ID: "key",
      FORMS_S3_SECRET_ACCESS_KEY: "secret",
    }).region,
    "us-east-1",
  );
});

Deno.test("uses WebCrypto SHA-256 and HMAC for SigV4 material", async () => {
  assertEquals(
    await sha256Hex("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
  assertEquals(
    await hmacHex("key", "The quick brown fox jumps over the lazy dog"),
    "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
  );
});

const config = {
  endpoint: "https://project.storage.supabase.co/storage/v1/s3",
  region: "sa-east-1",
  accessKeyId: "access-key",
  secretAccessKey: "secret-key",
};
const now = () => new Date("2026-08-13T15:16:17.000Z");

Deno.test("initiates a signed multipart upload and reads its upload id", async () => {
  let captured: Request | undefined;
  const client = new MultipartS3Client(config, {
    now,
    fetch: (request) => {
      captured = request;
      return Promise.resolve(
        new Response(
          "<InitiateMultipartUploadResult><UploadId>opaque-upload</UploadId></InitiateMultipartUploadResult>",
          { status: 200 },
        ),
      );
    },
  });

  const result = await client.initiate(
    "coelo-forms-private",
    "exports/a b/file.zip",
    "application/zip",
  );

  assertEquals(result.uploadId, "opaque-upload");
  assertEquals(captured?.method, "POST");
  assertEquals(
    captured?.url,
    "https://project.storage.supabase.co/storage/v1/s3/coelo-forms-private/exports/a%20b/file.zip?uploads=",
  );
  assertEquals(captured?.headers.get("content-type"), "application/zip");
  assertEquals(captured?.headers.get("x-amz-date"), "20260813T151617Z");
  assertEquals(
    captured?.headers.get("authorization"),
    "AWS4-HMAC-SHA256 Credential=access-key/20260813/sa-east-1/s3/aws4_request, SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, Signature=b26425ba33234a2a94ad0eed3c76a96477adc10f4462aae344a62740b2c1e018",
  );
});

Deno.test("uploads one signed part and returns the normalized ETag", async () => {
  let captured: Request | undefined;
  const client = new MultipartS3Client(config, {
    now,
    fetch: (request) => {
      captured = request;
      return Promise.resolve(
        new Response(null, { status: 200, headers: { etag: '"part-etag"' } }),
      );
    },
  });

  const result = await client.uploadPart(
    "coelo-forms-private",
    "exports/file.zip",
    "upload+id",
    7,
    new Uint8Array([1, 2, 3]),
  );

  assertEquals(result, { partNumber: 7, etag: '"part-etag"' });
  assertEquals(captured?.method, "PUT");
  assertEquals(
    captured?.url,
    "https://project.storage.supabase.co/storage/v1/s3/coelo-forms-private/exports/file.zip?partNumber=7&uploadId=upload%2Bid",
  );
  assertEquals(
    new Uint8Array(await captured!.arrayBuffer()),
    new Uint8Array([1, 2, 3]),
  );
});

Deno.test("completes with parts ordered by number and XML-escaped ETags", async () => {
  let captured: Request | undefined;
  const client = new MultipartS3Client(config, {
    now,
    fetch: (request) => {
      captured = request;
      return Promise.resolve(
        new Response(
          "<CompleteMultipartUploadResult><ETag>&quot;final&quot;</ETag></CompleteMultipartUploadResult>",
          { status: 200 },
        ),
      );
    },
  });

  const result = await client.complete(
    "bucket",
    "exports/file.zip",
    "upload-id",
    [
      { partNumber: 2, etag: '"two&more"' },
      { partNumber: 1, etag: '"one"' },
    ],
  );

  assertEquals(result.etag, '"final"');
  assertEquals(captured?.method, "POST");
  assertEquals(
    await captured!.text(),
    "<CompleteMultipartUpload><Part><PartNumber>1</PartNumber><ETag>&quot;one&quot;</ETag></Part><Part><PartNumber>2</PartNumber><ETag>&quot;two&amp;more&quot;</ETag></Part></CompleteMultipartUpload>",
  );
});

Deno.test("aborts the exact signed multipart upload", async () => {
  let captured: Request | undefined;
  const client = new MultipartS3Client(config, {
    now,
    fetch: (request) => {
      captured = request;
      return Promise.resolve(new Response(null, { status: 204 }));
    },
  });

  await client.abort("bucket", "exports/file.zip", "upload-id");

  assertEquals(captured?.method, "DELETE");
  assertEquals(captured?.url.endsWith("?uploadId=upload-id"), true);
});

Deno.test("treats an already expired multipart upload as successfully aborted", async () => {
  const client = new MultipartS3Client(config, {
    now,
    fetch: () => Promise.resolve(new Response(null, { status: 404 })),
  });
  await client.abort("bucket", "exports/file.zip", "expired-upload-id");
});

Deno.test("fails closed on S3 errors and missing protocol fields", async () => {
  const failing = new MultipartS3Client(config, {
    now,
    fetch: () => Promise.resolve(new Response("denied", { status: 403 })),
  });
  await assertRejects(
    () => failing.initiate("bucket", "file.zip", "application/zip"),
    Error,
    "multipart_s3_http_403",
  );

  const missingEtag = new MultipartS3Client(config, {
    now,
    fetch: () => Promise.resolve(new Response(null, { status: 200 })),
  });
  await assertRejects(
    () =>
      missingEtag.uploadPart(
        "bucket",
        "file.zip",
        "upload-id",
        1,
        new Uint8Array(),
      ),
    Error,
    "multipart_s3_missing_etag",
  );
});

Deno.test("rejects an embedded S3 completion error even when HTTP status is 200", async () => {
  const client = new MultipartS3Client(config, {
    now,
    fetch: () =>
      Promise.resolve(
        new Response(
          "<Error><Code>InvalidPart</Code><Message>One or more parts were invalid.</Message></Error>",
          { status: 200 },
        ),
      ),
  });

  await assertRejects(
    () =>
      client.complete("bucket", "file.zip", "upload-id", [{
        partNumber: 1,
        etag: '"one"',
      }]),
    Error,
    "multipart_s3_complete_error",
  );
});

Deno.test("signs and sends the same immutable part despite caller mutation", async () => {
  const body = new Uint8Array([1, 2, 3]);
  let sent: Uint8Array | undefined;
  let digest: string | null = null;
  const client = new MultipartS3Client(config, {
    now,
    fetch: async (request) => {
      sent = new Uint8Array(await request.arrayBuffer());
      digest = request.headers.get("x-amz-content-sha256");
      return new Response(null, { headers: { etag: '"part"' } });
    },
  });
  const pending = client.uploadPart(
    "bucket",
    "file.xlsx",
    "upload-id",
    1,
    body,
  );
  body.fill(9);
  await pending;
  assertEquals(sent, new Uint8Array([1, 2, 3]));
  assertEquals(digest, await sha256Hex(sent!));
});

Deno.test("refuses redirects and attaches a live deadline signal", async () => {
  const client = new MultipartS3Client(config, {
    now,
    fetch: (request) => {
      assertEquals(request.redirect, "error");
      assertEquals(request.signal.aborted, false);
      return Promise.resolve(new Response(null, { status: 302 }));
    },
  });
  await assertRejects(
    () => client.initiate("bucket", "file.xlsx", "application/octet-stream"),
    Error,
    "multipart_s3_http_302",
  );
});

Deno.test("sanitizes fetch errors without leaking provider URLs or credentials", async () => {
  const client = new MultipartS3Client(config, {
    now,
    fetch: () =>
      Promise.reject(new Error("https://private.test/?token=secret")),
  });
  const error = await assertRejects(
    () => client.initiate("bucket", "file.xlsx", "application/octet-stream"),
    Error,
  );
  assertEquals(error.message, "multipart_s3_transport_error");
});

Deno.test("cancels oversized XML without buffering the remainder", async () => {
  let cancelled = false;
  let pulls = 0;
  const client = new MultipartS3Client(config, {
    now,
    fetch: () =>
      Promise.resolve(
        new Response(
          new ReadableStream({
            start(controller) {
              controller.enqueue(new Uint8Array(65 * 1024));
            },
            pull(controller) {
              if (pulls++ === 0) controller.enqueue(new Uint8Array([1]));
              else controller.close();
            },
            cancel() {
              cancelled = true;
            },
          }),
        ),
      ),
  });
  await assertRejects(
    () => client.initiate("bucket", "file.xlsx", "application/octet-stream"),
    Error,
    "multipart_s3_response_too_large",
  );
  assertEquals(cancelled, true);
});

Deno.test("cancels rejected HTTP response bodies", async () => {
  let cancelled = false;
  const client = new MultipartS3Client(config, {
    now,
    fetch: () =>
      Promise.resolve(
        new Response(
          new ReadableStream({
            cancel() {
              cancelled = true;
            },
          }),
          { status: 403 },
        ),
      ),
  });
  await assertRejects(() => client.abort("bucket", "file.xlsx", "upload-id"));
  assertEquals(cancelled, true);
});

Deno.test("rejects malformed or ambiguous completion protocol fields", async () => {
  for (
    const xml of [
      "<Error><Message>sensitive</Message></Error>",
      "<CompleteMultipartUploadResult></CompleteMultipartUploadResult>",
      "<CompleteMultipartUploadResult><ETag>unquoted</ETag></CompleteMultipartUploadResult>",
      '<CompleteMultipartUploadResult><ETag>"one"</ETag><ETag>"two"</ETag></CompleteMultipartUploadResult>',
    ]
  ) {
    const client = new MultipartS3Client(config, {
      now,
      fetch: () => Promise.resolve(new Response(xml)),
    });
    await assertRejects(() =>
      client.complete("bucket", "file.xlsx", "upload-id", [
        { partNumber: 1, etag: '"part"' },
      ])
    );
  }
});

Deno.test("validates upload IDs and ETags before issuing another request", async () => {
  let calls = 0;
  const client = new MultipartS3Client(config, {
    now,
    fetch: () => {
      calls++;
      return Promise.resolve(new Response(null));
    },
  });
  for (const uploadId of ["has space", "a\nb", "x".repeat(1025)]) {
    await assertRejects(() => client.abort("bucket", "file.xlsx", uploadId));
  }
  for (const etag of ["unquoted", '"bad\nvalue"', `"${"x".repeat(1024)}"`]) {
    await assertRejects(() =>
      client.complete("bucket", "file.xlsx", "upload-id", [
        { partNumber: 1, etag },
      ])
    );
  }
  assertEquals(calls, 0);
});

Deno.test("rejects invalid initiate IDs and XML declarations", async () => {
  for (
    const xml of [
      "<InitiateMultipartUploadResult><UploadId>has space</UploadId></InitiateMultipartUploadResult>",
      "<InitiateMultipartUploadResult><UploadIdWrong>wrong</UploadIdWrong></InitiateMultipartUploadResult>",
      '<!DOCTYPE x [<!ENTITY x "private">]><InitiateMultipartUploadResult><UploadId>&x;</UploadId></InitiateMultipartUploadResult>',
    ]
  ) {
    const client = new MultipartS3Client(config, {
      now,
      fetch: () => Promise.resolve(new Response(xml)),
    });
    await assertRejects(() =>
      client.initiate("bucket", "file.xlsx", "application/octet-stream")
    );
  }
});

Deno.test("enforces the 30 second deadline through fetch and response body", async () => {
  let fetchAborted = false;
  let bodyCancelled = false;
  const pendingFetch = new MultipartS3Client(config, {
    fetch: (request) => {
      request.signal.addEventListener("abort", () => {
        fetchAborted = true;
      });
      return new Promise<Response>(() => {});
    },
  });
  const pendingBody = new MultipartS3Client(config, {
    fetch: () =>
      Promise.resolve(
        new Response(
          new ReadableStream({
            cancel() {
              bodyCancelled = true;
            },
          }),
        ),
      ),
  });
  await Promise.all([pendingFetch, pendingBody].map((client) =>
    assertRejects(
      () => client.initiate("bucket", "file.xlsx", "application/octet-stream"),
      Error,
      "multipart_s3_timeout",
    )
  ));
  assertEquals(fetchAborted, true);
  assertEquals(bodyCancelled, true);
});

Deno.test("requires a complete successful S3 response document", async () => {
  for (
    const [status, xml] of [
      [
        206,
        '<CompleteMultipartUploadResult><ETag>"part"</ETag></CompleteMultipartUploadResult>',
      ],
      [200, '<Other><ETag>"part"</ETag></Other>'],
      [200, '<CompleteMultipartUploadResult><ETag>"part"</ETag>'],
    ] as const
  ) {
    const client = new MultipartS3Client(config, {
      fetch: () => Promise.resolve(new Response(xml, { status })),
    });
    await assertRejects(() =>
      client.complete("bucket", "file.xlsx", "upload-id", [
        { partNumber: 1, etag: '"part"' },
      ])
    );
  }
});

Deno.test("rejects non UTF8 protocol bytes and unquoted response ETags", async () => {
  const invalidXml = new MultipartS3Client(config, {
    fetch: () => Promise.resolve(new Response(new Uint8Array([0xff]))),
  });
  await assertRejects(() =>
    invalidXml.initiate("bucket", "file.xlsx", "application/octet-stream")
  );
  const invalidEtag = new MultipartS3Client(config, {
    fetch: () =>
      Promise.resolve(new Response(null, { headers: { etag: "unquoted" } })),
  });
  await assertRejects(() =>
    invalidEtag.uploadPart(
      "bucket",
      "file.xlsx",
      "upload-id",
      1,
      new Uint8Array([1]),
    )
  );
});

Deno.test("rejects result fields in comments and unbalanced XML children", async () => {
  for (
    const content of [
      '<!--<ETag>"fake"</ETag>-->',
      '<ETag>"ok"</ETag><broken>',
      '<Nested><ETag>"fake"</ETag></Nested>',
      '<ETag>"ok"</ETag><?provider data?>',
      '<ETag><![CDATA["fake"]]></ETag>',
      '<ETag>"&unsupported;"</ETag>',
      '<ETag>"&#0;"</ETag>',
      '<ETag>"&#xD800;"</ETag>',
      '<ETag>"&#x110000;"</ETag>',
      '<ETag>"one"</etag>',
      '<ETag>"ok"</ETag><ChecksumSHA256>unterminated',
      '<ETag>"ok"</ETag>unexpected text',
    ]
  ) {
    const client = new MultipartS3Client(config, {
      fetch: () =>
        Promise.resolve(
          new Response(
            `<CompleteMultipartUploadResult>${content}</CompleteMultipartUploadResult>`,
          ),
        ),
    });
    await assertRejects(() =>
      client.complete("bucket", "file.xlsx", "upload-id", [
        { partNumber: 1, etag: '"part"' },
      ])
    );
  }
  const client = new MultipartS3Client(config, {
    fetch: () =>
      Promise.resolve(
        new Response(
          "<InitiateMultipartUploadResult><!--<UploadId>fake</UploadId>--></InitiateMultipartUploadResult>",
        ),
      ),
  });
  await assertRejects(() =>
    client.initiate("bucket", "file.xlsx", "application/octet-stream")
  );
});

Deno.test("accepts flat S3 result documents with declaration namespace and escaped fields", async () => {
  const replies = [
    '<?xml version = "1.0" encoding = "UTF-8"?>\n<InitiateMultipartUploadResult xmlns = "http://s3.amazonaws.com/doc/2006-03-01/">\n<Bucket>bucket</Bucket><Key>exports/a&amp;b.xlsx</Key><UploadId>opaque&#43;id&amp;value</UploadId>\n</InitiateMultipartUploadResult>',
    "<?xml version='1.0' encoding='utf-8' standalone='yes'?>\n<CompleteMultipartUploadResult xmlns='http://s3.amazonaws.com/doc/2006-03-01/'><Location>https://example.test/a&amp;b</Location><Bucket>bucket</Bucket><Key>exports/a&amp;b.xlsx</Key><ETag>&#34;final&amp;etag&#x22;</ETag><ChecksumSHA256>checksum=</ChecksumSHA256><ChecksumType>FULL_OBJECT</ChecksumType></CompleteMultipartUploadResult>",
  ];
  const client = new MultipartS3Client(config, {
    fetch: () => Promise.resolve(new Response(replies.shift()!)),
  });
  assertEquals(
    await client.initiate("bucket", "file.xlsx", "application/octet-stream"),
    {
      uploadId: "opaque+id&value",
    },
  );
  assertEquals(
    await client.complete("bucket", "file.xlsx", "opaque+id&value", [
      { partNumber: 1, etag: '"part"' },
    ]),
    { etag: '"final&etag"' },
  );
});
