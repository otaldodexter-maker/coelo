import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.14";
import { validateImageMetrics } from "./media_image_contract.ts";

const MiB = 1024 * 1024;
const metrics = {
  mimeType: "image/webp",
  byteSize: MiB,
  width: 512,
  height: 512,
  sha256: "a".repeat(64),
};

Deno.test("accepts allowed decoded image formats without changing metrics", () => {
  for (const mimeType of ["image/jpeg", "image/png", "image/webp"]) {
    const input = { ...metrics, mimeType };
    assertEquals(validateImageMetrics("photo", "source", input), input);
  }
});

Deno.test("returns an immutable copy, not a mutable decoder object", () => {
  const input = { ...metrics };
  const result = validateImageMetrics("photo", "source", input);
  input.width = 1;
  assertEquals(result.width, 512);
  assertEquals(Object.isFrozen(result), true);
});

Deno.test("rejects unsupported real formats, even if a filename could claim JPEG", () => {
  for (
    const mimeType of [
      "image/gif",
      "image/svg+xml",
      "image/heic",
      "image/heif",
      "image/avif",
      "image/jpeg; charset=utf-8",
      "IMAGE/JPEG",
      "",
    ]
  ) {
    assertThrows(() =>
      validateImageMetrics("photo", "source", { ...metrics, mimeType })
    );
  }
});

const policies = [
  {
    purpose: "avatar",
    sourceBytes: 8 * MiB,
    pixels: 25_000_000,
    masterBytes: 2 * MiB,
    width: 1024,
    height: 1024,
  },
  {
    purpose: "logo",
    sourceBytes: 8 * MiB,
    pixels: 25_000_000,
    masterBytes: 2 * MiB,
    width: 1024,
    height: 1024,
  },
  {
    purpose: "cover",
    sourceBytes: 12 * MiB,
    pixels: 36_000_000,
    masterBytes: 3 * MiB,
    width: 2400,
    height: 800,
  },
  {
    purpose: "photo",
    sourceBytes: 10 * MiB,
    pixels: 36_000_000,
    masterBytes: 4 * MiB,
    width: 2560,
    height: 2560,
  },
  {
    purpose: "map",
    sourceBytes: 20 * MiB,
    pixels: 64_000_000,
    masterBytes: 8 * MiB,
    width: 6000,
    height: 6000,
  },
] as const;

for (const policy of policies) {
  Deno.test(`${policy.purpose}: exact source byte and pixel limits are inclusive`, () => {
    const width = Math.sqrt(policy.pixels);
    const source = {
      ...metrics,
      byteSize: policy.sourceBytes,
      width,
      height: width,
    };
    assertEquals(
      validateImageMetrics(policy.purpose, "source", source),
      source,
    );
    assertThrows(() =>
      validateImageMetrics(policy.purpose, "source", {
        ...source,
        byteSize: policy.sourceBytes + 1,
      })
    );
    assertThrows(() =>
      validateImageMetrics(policy.purpose, "source", {
        ...source,
        width: width + 1,
      })
    );
  });
  Deno.test(`${policy.purpose}: exact normalized master bounds are inclusive`, () => {
    const master = {
      ...metrics,
      byteSize: policy.masterBytes,
      width: policy.width,
      height: policy.height,
    };
    assertEquals(
      validateImageMetrics(policy.purpose, "master", master),
      master,
    );
    assertThrows(() =>
      validateImageMetrics(policy.purpose, "master", {
        ...master,
        byteSize: policy.masterBytes + 1,
      })
    );
    assertThrows(() =>
      validateImageMetrics(policy.purpose, "master", {
        ...master,
        width: policy.width + 1,
      })
    );
    assertThrows(() =>
      validateImageMetrics(policy.purpose, "master", {
        ...master,
        height: policy.height + 1,
      })
    );
  });
}

Deno.test("checks minimum source dimensions without imposing a source crop", () => {
  for (const purpose of ["avatar", "logo"]) {
    assertThrows(() =>
      validateImageMetrics(purpose, "source", { ...metrics, width: 255 })
    );
    assertThrows(() =>
      validateImageMetrics(purpose, "source", { ...metrics, height: 255 })
    );
    validateImageMetrics(purpose, "source", {
      ...metrics,
      width: 256,
      height: 512,
    });
  }
  validateImageMetrics("cover", "source", {
    ...metrics,
    width: 1200,
    height: 500,
  });
  assertThrows(() =>
    validateImageMetrics("cover", "source", {
      ...metrics,
      width: 1199,
      height: 400,
    })
  );
  assertThrows(() =>
    validateImageMetrics("cover", "source", {
      ...metrics,
      width: 1200,
      height: 399,
    })
  );
});

Deno.test("requires approved avatar and cover master crops but preserves logo aspect", () => {
  assertThrows(() =>
    validateImageMetrics("avatar", "master", { ...metrics, height: 256 })
  );
  validateImageMetrics("logo", "master", { ...metrics, height: 256 });
  validateImageMetrics("cover", "master", {
    ...metrics,
    width: 1200,
    height: 400,
  });
  assertThrows(() =>
    validateImageMetrics("cover", "master", {
      ...metrics,
      width: 1200,
      height: 401,
    })
  );
});

Deno.test("rejects invalid numeric values and unsafe pixel multiplication", () => {
  for (const field of ["byteSize", "width", "height"]) {
    for (
      const value of [
        0,
        -1,
        0.5,
        NaN,
        Infinity,
        Number.MAX_SAFE_INTEGER + 1,
        "512",
        null,
        undefined,
      ]
    ) {
      assertThrows(() =>
        validateImageMetrics("photo", "source", { ...metrics, [field]: value })
      );
    }
  }
  assertThrows(() =>
    validateImageMetrics("photo", "source", {
      ...metrics,
      width: Number.MAX_SAFE_INTEGER,
      height: Number.MAX_SAFE_INTEGER,
    })
  );
});

Deno.test("requires a canonical SHA256 value without claiming to compute it", () => {
  for (
    const sha256 of [
      null,
      undefined,
      12,
      "",
      "a".repeat(63),
      "A".repeat(64),
      "z".repeat(64),
    ]
  ) {
    assertThrows(() =>
      validateImageMetrics("photo", "source", { ...metrics, sha256 })
    );
  }
});

Deno.test("rejects malformed envelopes and unrecognized server policy or stage", () => {
  for (
    const input of [null, undefined, [], "file.jpg", {}, {
      ...metrics,
      objectKey: "synthetic-private",
    }]
  ) {
    assertThrows(() => validateImageMetrics("photo", "source", input));
  }
  for (
    const purpose of [
      "chat",
      "unknown",
      "__proto__",
      "constructor",
      null,
      undefined,
    ]
  ) {
    assertThrows(() => validateImageMetrics(purpose, "source", metrics));
  }
  for (const stage of ["preview", "unknown", null, undefined]) {
    assertThrows(() => validateImageMetrics("photo", stage, metrics));
  }
});

Deno.test("errors never echo decoder or private input", () => {
  const error = assertThrows(
    () =>
      validateImageMetrics("photo", "source", {
        ...metrics,
        mimeType: "synthetic-sensitive-value",
      }),
    Error,
  );
  assertEquals(error.message, "media_image_metrics_invalid");
});
