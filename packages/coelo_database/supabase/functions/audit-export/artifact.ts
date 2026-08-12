import * as XLSX from "xlsx";

export type AuditRow = Record<string, unknown>;

const COLUMNS = [
  "id",
  "occurred_at",
  "actor_name",
  "actor_role_code",
  "institution_name",
  "action_code",
  "resource_type",
  "resource_id",
  "outcome",
  "correlation_id",
  "origin",
  "context_kind",
  "context_id",
] as const;

export function safeSpreadsheetCell(value: unknown): string {
  const text = String(value ?? "");
  return /^[=+\-@\t\r]/.test(text) ? `'${text}` : text;
}

function csvCell(value: unknown): string {
  return `"${safeSpreadsheetCell(value).replaceAll('"', '""')}"`;
}

export function buildAuditArtifact(rows: AuditRow[], format: "csv" | "xlsx") {
  const sanitized = rows.map((row) =>
    Object.fromEntries(
      COLUMNS.map((column) => [column, safeSpreadsheetCell(row[column])]),
    )
  );
  if (format === "csv") {
    const content = [
      COLUMNS.map(csvCell).join(","),
      ...sanitized.map((row) =>
        COLUMNS.map((column) => csvCell(row[column])).join(",")
      ),
    ].join("\r\n");
    return {
      bytes: new TextEncoder().encode(content),
      mime: "text/csv",
      extension: "csv",
    };
  }
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(
    workbook,
    XLSX.utils.json_to_sheet(sanitized, { header: [...COLUMNS] }),
    "Auditoria",
  );
  return {
    bytes: new Uint8Array(
      XLSX.write(workbook, {
        type: "array",
        bookType: "xlsx",
        compression: true,
      }) as ArrayBuffer,
    ),
    mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    extension: "xlsx",
  };
}
