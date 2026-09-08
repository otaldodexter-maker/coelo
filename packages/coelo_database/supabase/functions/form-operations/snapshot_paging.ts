import {
  expandSubmission,
  type ExportRow,
  type ExportSubmission,
  type XlsxCellValue,
  xlsxCivilDate,
  type XlsxColumn,
  xlsxMediaLink,
  type XlsxRow,
  type XlsxWorkbookSheet,
} from "./export_contract.ts";

type SnapshotObject = Record<string, unknown>;
export type XlsxSnapshotItem = Readonly<
  {
    itemId: string;
    kind: string;
    label: string;
    helpText: string | null;
    position: number;
    required: boolean;
    config: Readonly<SnapshotObject>;
    options: readonly Readonly<
      { optionId: string; label: string; position: number }
    >[];
  }
>;
type XlsxSnapshotVersion = Readonly<
  {
    versionId: string;
    versionNumber: number;
    state: string;
    sections: readonly Readonly<
      {
        sectionId: string;
        title: string;
        description: string | null;
        position: number;
        items: readonly XlsxSnapshotItem[];
      }
    >[];
    conditions: readonly Readonly<SnapshotObject>[];
  }
>;
export type XlsxSnapshotSchema = Readonly<
  {
    formId: string;
    formTitle: string;
    versions: readonly XlsxSnapshotVersion[];
  }
>;
type XlsxSnapshotValue = Readonly<
  {
    kind: string;
    value?: string | boolean;
    minorUnits?: string;
    currency?: string;
    optionId?: string;
    assetId?: string;
  }
>;
export type XlsxSnapshotSubmission = Readonly<
  {
    responseId: string;
    occurrenceId: string;
    versionId: string;
    metadata: Readonly<
      {
        form_id: string;
        identity_mode: "identified" | "anonymous";
        respondent?: string;
        submitted_at?: string;
      }
    >;
    answers: readonly Readonly<
      { itemId: string; values: readonly XlsxSnapshotValue[] }
    >[];
  }
>;
const snapshotUuid = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const object = (value: unknown): value is SnapshotObject =>
  value !== null && typeof value === "object" && !Array.isArray(value);
function requireSnapshot(valid: unknown): asserts valid {
  if (!valid) throw new Error("export_snapshot_invalid");
}
function exactKeys(
  value: SnapshotObject,
  required: readonly string[],
  optional: readonly string[] = [],
): boolean {
  return required.every((key) => Object.hasOwn(value, key)) &&
    Object.keys(value).every((key) =>
      required.includes(key) || optional.includes(key)
    );
}
function frozen<T>(value: T): T {
  if (value !== null && typeof value === "object") {
    for (const item of Object.values(value)) frozen(item);
    Object.freeze(value);
  }
  return value;
}
const allItems = (version: XlsxSnapshotVersion) =>
  version.sections.flatMap((section) => section.items);
const kinds = new Set([
  "short_text",
  "integer",
  "decimal",
  "money",
  "date",
  "yes_no",
  "single_choice",
  "multiple_choice",
  "scale",
  "photo",
  "gallery",
  "information",
]);

/** The hash is a server fingerprint of jsonb, not JSON.stringify bytes. */
export function parseXlsxSnapshotSchema(
  input: unknown,
  formId?: string,
): XlsxSnapshotSchema {
  const value = structuredClone(input);
  requireSnapshot(
    object(value) && exactKeys(value, ["formId", "formTitle", "versions"]) &&
      snapshotUuid(value.formId) && (!formId || value.formId === formId) &&
      typeof value.formTitle === "string" && Array.isArray(value.versions),
  );
  const ids = new Set<string>();
  const numbers = new Set<number>();
  const claim = (id: unknown) => {
    requireSnapshot(snapshotUuid(id) && !ids.has(id));
    ids.add(id);
  };
  let previousVersion = 0;
  for (const version of value.versions) {
    requireSnapshot(
      object(version) &&
        exactKeys(version, [
          "versionId",
          "versionNumber",
          "state",
          "sections",
          "conditions",
        ]) && Number.isSafeInteger(version.versionNumber) &&
        Number(version.versionNumber) > previousVersion &&
        !numbers.has(Number(version.versionNumber)) &&
        ["working", "published", "superseded"].includes(
          String(version.state),
        ) &&
        Array.isArray(version.sections) && Array.isArray(version.conditions),
    );
    claim(version.versionId);
    previousVersion = Number(version.versionNumber);
    numbers.add(previousVersion);
    const items = new Map<string, SnapshotObject>();
    let previousSection = -1;
    for (const section of version.sections) {
      requireSnapshot(
        object(section) &&
          exactKeys(section, [
            "sectionId",
            "title",
            "description",
            "position",
            "items",
          ]) && typeof section.title === "string" &&
          (section.description === null ||
            typeof section.description === "string") &&
          Number.isSafeInteger(section.position) &&
          Number(section.position) >= 0 &&
          Number(section.position) >= previousSection &&
          Array.isArray(section.items),
      );
      claim(section.sectionId);
      previousSection = Number(section.position);
      let previousItem = -1;
      for (const item of section.items) {
        requireSnapshot(
          object(item) &&
            exactKeys(item, [
              "itemId",
              "kind",
              "label",
              "helpText",
              "position",
              "required",
              "config",
              "options",
            ]) && kinds.has(String(item.kind)) &&
            typeof item.label === "string" &&
            (item.helpText === null || typeof item.helpText === "string") &&
            typeof item.required === "boolean" && object(item.config) &&
            Number.isSafeInteger(item.position) && Number(item.position) >= 0 &&
            Number(item.position) >= previousItem &&
            Array.isArray(item.options),
        );
        claim(item.itemId);
        previousItem = Number(item.position);
        items.set(String(item.itemId), item);
        let previousOption = -1;
        for (const option of item.options) {
          requireSnapshot(
            object(option) &&
              exactKeys(option, ["optionId", "label", "position"]) &&
              typeof option.label === "string" &&
              Number.isSafeInteger(option.position) &&
              Number(option.position) >= 0 &&
              Number(option.position) >= previousOption,
          );
          claim(option.optionId);
          previousOption = Number(option.position);
        }
        requireSnapshot(
          ["single_choice", "multiple_choice"].includes(String(item.kind)) ||
            item.options.length === 0,
        );
      }
    }
    for (const condition of version.conditions) {
      requireSnapshot(
        object(condition) &&
          exactKeys(condition, [
            "sourceItemId",
            "targetItemId",
            "kind",
            "expectedYesNo",
            "sourceOptionId",
          ]) && snapshotUuid(condition.sourceItemId) &&
          snapshotUuid(condition.targetItemId) &&
          condition.sourceItemId !== condition.targetItemId &&
          items.has(condition.sourceItemId) &&
          items.has(condition.targetItemId),
      );
      const source = items.get(String(condition.sourceItemId))!;
      requireSnapshot(
        condition.kind === "yes_no"
          ? source.kind === "yes_no" &&
            typeof condition.expectedYesNo === "boolean" &&
            condition.sourceOptionId === null
          : condition.kind === "choice" &&
            ["single_choice", "multiple_choice"].includes(
              String(source.kind),
            ) && condition.expectedYesNo === null &&
            (source.options as SnapshotObject[]).some((option) =>
              option.optionId === condition.sourceOptionId
            ),
      );
    }
  }
  return frozen(value as unknown as XlsxSnapshotSchema);
}

function exactNumber(value: unknown, integer = false): number {
  if (
    typeof value !== "string" || !/^-?(?:0|[1-9]\d*)(?:\.\d+)?$/.test(value) ||
    (integer && value.includes("."))
  ) throw new Error("xlsx_number_unrepresentable");
  const normalized = (text: string) =>
    text.replace(/\.0+$/, "").replace(/(\.\d*?)0+$/, "$1").replace(/^-0$/, "0");
  const decimal = normalized(value);
  const significant = decimal.replace("-", "").replace(".", "").replace(
    /^0+/,
    "",
  ).replace(/0+$/, "");
  const number = Number(decimal);
  if (
    significant.length > 15 || !Number.isFinite(number) ||
    (number !== 0 && Math.abs(number) < 2.2250738585072014e-308) ||
    (integer && !Number.isSafeInteger(number)) ||
    normalized(
        number.toLocaleString("en-US", {
          useGrouping: false,
          maximumSignificantDigits: 21,
        }),
      ) !== decimal
  ) throw new Error("xlsx_number_unrepresentable");
  return number;
}

function answerCell(
  value: XlsxSnapshotValue,
  item: XlsxSnapshotItem,
  origin?: string,
): XlsxCellValue {
  switch (value.kind) {
    case "text":
      requireSnapshot(
        item.kind === "short_text" && typeof value.value === "string",
      );
      return value.value;
    case "integer":
      requireSnapshot(item.kind === "integer" || item.kind === "scale");
      return exactNumber(value.value, true);
    case "decimal":
      requireSnapshot(item.kind === "decimal");
      return exactNumber(value.value);
    case "money": {
      requireSnapshot(
        item.kind === "money" && typeof value.currency === "string" &&
          value.currency === item.config.currency,
      );
      if (value.currency !== "BRL") {
        throw new Error("xlsx_currency_unrepresentable");
      }
      const minor = exactNumber(value.minorUnits, true);
      const amount = minor / 100;
      if (Math.round(amount * 100) !== minor) {
        throw new Error("xlsx_number_unrepresentable");
      }
      return amount;
    }
    case "date":
      requireSnapshot(item.kind === "date" && typeof value.value === "string");
      return xlsxCivilDate(value.value);
    case "boolean":
      requireSnapshot(
        item.kind === "yes_no" && typeof value.value === "boolean",
      );
      return value.value;
    case "choice": {
      requireSnapshot(
        item.kind === "single_choice" || item.kind === "multiple_choice",
      );
      const option = item.options.find((option) =>
        option.optionId === value.optionId
      );
      requireSnapshot(option);
      return option.label;
    }
    case "media":
      requireSnapshot(
        (item.kind === "photo" || item.kind === "gallery") &&
          snapshotUuid(value.assetId),
      );
      return xlsxMediaLink(origin ?? "", value.assetId);
    default:
      throw new Error("export_snapshot_invalid");
  }
}

export function parseXlsxSubmission(
  input: unknown,
  schema: XlsxSnapshotSchema,
): XlsxSnapshotSubmission {
  const value = structuredClone(input);
  requireSnapshot(
    object(value) &&
      exactKeys(value, [
        "responseId",
        "occurrenceId",
        "versionId",
        "metadata",
        "answers",
      ]) && snapshotUuid(value.responseId) &&
      snapshotUuid(value.occurrenceId) && snapshotUuid(value.versionId) &&
      object(value.metadata) && Array.isArray(value.answers),
  );
  const version = schema.versions.find((version) =>
    version.versionId === value.versionId
  );
  requireSnapshot(version);
  const metadata = value.metadata;
  requireSnapshot(
    metadata.form_id === schema.formId &&
      (metadata.identity_mode === "anonymous"
        ? exactKeys(metadata, ["form_id", "identity_mode"])
        : metadata.identity_mode === "identified" &&
          exactKeys(metadata, [
            "form_id",
            "identity_mode",
            "respondent",
            "submitted_at",
          ]) && typeof metadata.respondent === "string" &&
          typeof metadata.submitted_at === "string" &&
          /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/
            .test(metadata.submitted_at) &&
          Number.isFinite(Date.parse(metadata.submitted_at))),
  );
  const seen = new Set<string>();
  const items = allItems(version);
  for (const answer of value.answers) {
    requireSnapshot(
      object(answer) && exactKeys(answer, ["itemId", "values"]) &&
        snapshotUuid(answer.itemId) && !seen.has(answer.itemId) &&
        Array.isArray(answer.values),
    );
    seen.add(answer.itemId);
    const item = items.find((item) => item.itemId === answer.itemId);
    requireSnapshot(item && item.kind !== "information");
    requireSnapshot(
      item.kind === "photo"
        ? answer.values.length >= 1 && answer.values.length <= 5
        : ["multiple_choice", "gallery"].includes(item.kind) ||
          answer.values.length === 1,
    );
    const references = new Set<string>();
    for (const cell of answer.values) {
      requireSnapshot(object(cell) && typeof cell.kind === "string");
      const fields = cell.kind === "money"
        ? ["kind", "minorUnits", "currency"]
        : cell.kind === "choice"
        ? ["kind", "optionId"]
        : cell.kind === "media"
        ? ["kind", "assetId"]
        : ["kind", "value"];
      requireSnapshot(exactKeys(cell, fields));
      if (cell.kind === "media") {
        requireSnapshot(
          (item.kind === "photo" || item.kind === "gallery") &&
            snapshotUuid(cell.assetId) && !references.has(cell.assetId),
        );
        references.add(cell.assetId);
      } else {
        if (cell.kind === "choice") {
          requireSnapshot(
            snapshotUuid(cell.optionId) && !references.has(cell.optionId),
          );
          references.add(cell.optionId);
        }
        answerCell(cell as XlsxSnapshotValue, item);
      }
    }
  }
  return frozen(value as unknown as XlsxSnapshotSubmission);
}

/** Every pass reads sealed submissions; no row arrays or Cartesian expansion are retained. */
export function createVersionedXlsxSheets(
  schema: XlsxSnapshotSchema,
  submissions: () => AsyncIterable<XlsxSnapshotSubmission>,
  origin?: string,
  options: Readonly<{ maxRows?: number }> = {},
): readonly XlsxWorkbookSheet[] {
  const maxRows = options.maxRows ?? 50_000;
  if (!Number.isSafeInteger(maxRows) || maxRows < 1) {
    throw new Error("export_lease_row_limit");
  }
  const metadata: XlsxColumn[] = [
    "form_id",
    "response_id",
    "occurrence_id",
    "version_id",
    "version_number",
    "identity_mode",
    "respondent",
    "submitted_at",
  ].map((key) => ({ key, label: key }));
  const sheets: XlsxWorkbookSheet[] = [];
  for (const version of schema.versions) {
    const items = allItems(version).filter((item) =>
      item.kind !== "information"
    );
    for (const mode of ["Respostas", "Valores", "Mídias"] as const) {
      if (
        mode === "Valores" &&
        !items.some((item) =>
          ["single_choice", "multiple_choice"].includes(item.kind)
        )
      ) continue;
      if (
        mode === "Mídias" &&
        !items.some((item) => ["photo", "gallery"].includes(item.kind))
      ) continue;
      const columns = mode === "Respostas"
        ? [
          ...metadata,
          ...items.map((item) => ({
            key: item.itemId,
            label: `${item.label} [${item.itemId}]${
              item.kind === "money" && typeof item.config.currency === "string"
                ? ` (${item.config.currency})`
                : ""
            }`,
          })),
        ]
        : [
          ...metadata,
          ...[
            "item_id",
            "Pergunta expandida",
            "value_index",
            ...(mode === "Valores"
              ? ["option_id", "value"]
              : ["asset_id", "media"]),
          ].map((key) => ({ key, label: key })),
        ];
      sheets.push({
        name: `${mode} v${version.versionNumber}`,
        columns,
        rows: async function* () {
          let count = 0;
          let materialized = 0;
          for await (const submission of submissions()) {
            materialized += 1 +
              submission.answers.reduce(
                (total, answer) =>
                  total +
                  answer.values.filter((value) =>
                    value.kind === "choice" || value.kind === "media"
                  ).length,
                0,
              );
            if (materialized > maxRows) {
              throw new Error("export_lease_row_limit");
            }
            if (submission.versionId !== version.versionId) {
              continue;
            }
            const base: Record<string, XlsxCellValue> = {
              form_id: schema.formId,
              response_id: submission.responseId,
              occurrence_id: submission.occurrenceId,
              version_id: version.versionId,
              version_number: version.versionNumber,
              identity_mode: submission.metadata.identity_mode,
            };
            if (submission.metadata.identity_mode === "identified") {
              base.respondent = submission.metadata.respondent!;
              base.submitted_at = submission.metadata.submitted_at!;
            }
            if (mode === "Respostas") {
              for (const answer of submission.answers) {
                const item = items.find((item) =>
                  item.itemId === answer.itemId
                )!;
                if (
                  ["photo", "gallery", "multiple_choice"].includes(item.kind)
                ) {
                  if (answer.values.length) {
                    base[item.itemId] = `Ver ${
                      item.kind === "multiple_choice" ? "Valores" : "Mídias"
                    } v${version.versionNumber} (${answer.values.length})`;
                  }
                } else if (answer.values.length) {
                  base[item.itemId] = answerCell(
                    answer.values[0],
                    item,
                    origin,
                  );
                }
              }
              if (++count > 1048575) throw new Error("xlsx_row_limit");
              yield base;
            } else {
              for (const answer of submission.answers) {
                const item = items.find((item) =>
                  item.itemId === answer.itemId
                )!;
                if (
                  !(mode === "Valores"
                    ? ["single_choice", "multiple_choice"]
                    : ["photo", "gallery"]).includes(item.kind)
                ) continue;
                for (let index = 0; index < answer.values.length; index++) {
                  const cell = answer.values[index];
                  const row: XlsxRow = {
                    ...base,
                    item_id: item.itemId,
                    "Pergunta expandida": item.label,
                    value_index: index + 1,
                    ...(mode === "Valores"
                      ? {
                        option_id: cell.optionId!,
                        value: answerCell(cell, item, origin),
                      }
                      : {
                        asset_id: cell.assetId!,
                        media: answerCell(cell, item, origin),
                      }),
                  };
                  if (++count > 1048575) throw new Error("xlsx_row_limit");
                  yield row;
                }
              }
            }
          }
        },
      });
    }
  }
  return Object.freeze(sheets);
}

export type SnapshotPage = Readonly<{
  kind: string;
  submissions?: ExportSubmission[];
  rows?: ExportRow[];
  media?: Array<{ asset_id: string; storage_path: string; mime_type: string }>;
  has_more: boolean;
  next_cursor?: string | null;
}>;

export type SnapshotPageLoader = (
  cursor: string | null,
) => Promise<SnapshotPage>;

export async function* createSnapshotRows(
  loadPage: SnapshotPageLoader,
  options: Readonly<{
    maxRows?: number;
    onPageReleased?: () => void;
  }> = {},
): AsyncIterable<ExportRow> {
  const maxRows = options.maxRows ?? 50_000;
  let cursor: string | null = null;
  let emitted = 0;
  let kind: string | undefined;
  const cursors = new Set<string>();
  do {
    const snapshot = await loadPage(cursor);
    if (
      !snapshot || typeof snapshot.kind !== "string" ||
      typeof snapshot.has_more !== "boolean"
    ) {
      throw new Error("export_snapshot_invalid");
    }
    if (kind !== undefined && snapshot.kind !== kind) {
      throw new Error("export_snapshot_kind_changed");
    }
    kind = snapshot.kind;
    const nextCursor = snapshot.has_more ? snapshot.next_cursor : null;
    if (snapshot.has_more) {
      if (typeof nextCursor !== "string" || !nextCursor) {
        throw new Error("export_cursor_missing");
      }
      if (cursors.has(nextCursor)) throw new Error("export_cursor_repeated");
      cursors.add(nextCursor);
    }
    const pageRows = snapshot.kind === "anonymous_participation"
      ? snapshot.rows ?? []
      : (snapshot.submissions ?? []).flatMap(expandSubmission);
    if (snapshot.has_more && pageRows.length === 0) {
      throw new Error("export_page_empty");
    }
    for (const row of pageRows) {
      emitted++;
      if (emitted > maxRows) throw new Error("export_lease_row_limit");
      yield row;
    }
    options.onPageReleased?.();
    cursor = nextCursor ?? null;
  } while (cursor);
  if (emitted === 0) throw new Error("empty_export");
}

export async function* createSnapshotMedia(
  loadPage: SnapshotPageLoader,
): AsyncIterable<
  { asset_id: string; storage_path: string; mime_type: string }
> {
  let cursor: string | null = null;
  do {
    const snapshot = await loadPage(cursor);
    for (const asset of snapshot.media ?? []) yield asset;
    cursor = snapshot.has_more ? snapshot.next_cursor ?? null : null;
    if (snapshot.has_more && !cursor) throw new Error("export_cursor_missing");
  } while (cursor);
}
