import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const required = [
  "R2_ACCOUNT_ID",
  "R2_ACCESS_KEY_ID",
  "R2_SECRET_ACCESS_KEY",
  "R2_BUCKET",
  "R2_TEST_PREFIX"
];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required env var: ${key}`);
  }
}

const fixturePath = new URL("../fixtures/synthetic-media.txt", import.meta.url);
const body = await readFile(fixturePath);
const checksum = createHash("sha256").update(body).digest("hex");
const assetId = `spike-${Date.now()}`;
const objectKey = `${process.env.R2_TEST_PREFIX}/${assetId}/original.txt`;
const endpoint = `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;

const client = new S3Client({
  region: "auto",
  endpoint,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY
  }
});

const putCommand = new PutObjectCommand({
  Bucket: process.env.R2_BUCKET,
  Key: objectKey,
  Body: body,
  ContentType: "text/plain"
});

const getCommand = new GetObjectCommand({
  Bucket: process.env.R2_BUCKET,
  Key: objectKey
});

const putUrl = await getSignedUrl(client, putCommand, { expiresIn: 300 });
const getUrl = await getSignedUrl(client, getCommand, { expiresIn: 120 });

console.log(JSON.stringify({
  result: "presigned_urls_generated",
  bucket: process.env.R2_BUCKET,
  objectKey,
  byteSize: body.length,
  checksum,
  putUrlRedacted: redactSignedUrl(putUrl),
  getUrlRedacted: redactSignedUrl(getUrl)
}, null, 2));

if (process.env.R2_EXECUTE_LIVE_HTTP === "true") {
  const upload = await fetch(putUrl, {
    method: "PUT",
    headers: { "Content-Type": "text/plain" },
    body
  });

  if (!upload.ok) {
    throw new Error(`PUT failed: ${upload.status} ${upload.statusText}`);
  }

  const read = await fetch(getUrl);
  if (!read.ok) {
    throw new Error(`GET failed: ${read.status} ${read.statusText}`);
  }

  const downloaded = Buffer.from(await read.arrayBuffer());
  const downloadedChecksum = createHash("sha256").update(downloaded).digest("hex");

  if (downloadedChecksum !== checksum) {
    throw new Error("Downloaded checksum did not match fixture checksum");
  }

  await client.send(new DeleteObjectCommand({
    Bucket: process.env.R2_BUCKET,
    Key: objectKey
  }));

  console.log(JSON.stringify({
    result: "live_upload_read_delete_passed",
    objectKey,
    byteSize: downloaded.length,
    checksum: downloadedChecksum
  }, null, 2));
}

function redactSignedUrl(url) {
  const parsed = new URL(url);
  return `${parsed.origin}${parsed.pathname}?redacted_signature=true`;
}
