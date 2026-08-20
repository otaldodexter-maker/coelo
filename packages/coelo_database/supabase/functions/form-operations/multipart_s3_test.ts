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
    "multipart_s3_complete_InvalidPart",
  );
});
