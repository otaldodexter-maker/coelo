export type ExportAnswer = {
  itemId: string;
  question: string;
  values: string[];
  multiValued: boolean;
};

export type ExportSubmission = {
  responseId: string;
  occurrenceId: string;
  versionId: string;
  metadata: Record<string, string>;
  answers: ExportAnswer[];
};

export type ExportRow = Record<string, string>;

/** A Gregorian calendar day, without a time or timezone. Generic Date is not accepted. */
export type XlsxCivilDate = Readonly<{ kind: "date"; value: string }>;
export type XlsxMediaLink = Readonly<{ kind: "media"; target: string }>;
export type XlsxCellValue =
  | string
  | number
  | boolean
  | XlsxCivilDate
  | XlsxMediaLink;
export type XlsxRow = Readonly<Record<string, XlsxCellValue>>;
export type XlsxOptions = Readonly<{ columns: readonly string[] }>;
export type XlsxColumn = Readonly<{ key: string; label: string }>;
export type XlsxWorkbookSheet = Readonly<
  {
    name: string;
    columns: readonly XlsxColumn[];
    rows: () => AsyncIterable<XlsxRow>;
  }
>;

export function xlsxMediaLink(origin: string, assetId: string): XlsxMediaLink {
  let url: URL;
  try {
    url = new URL(origin);
  } catch {
    throw new Error("invalid_xlsx_media_origin");
  }
  if (
    url.protocol !== "https:" || url.origin !== origin || url.username ||
    url.password
  ) throw new Error("invalid_xlsx_media_origin");
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      assetId,
    )
  ) throw new Error("invalid_xlsx_media_asset");
  return Object.freeze({
    kind: "media",
    target: `${origin}/forms/media/${assetId}`,
  });
}

function mediaTarget(value: XlsxCellValue): string | undefined {
  return typeof value === "object" && value.kind === "media"
    ? value.target
    : isMediaLink(value)
    ? value
    : undefined;
}

function workbookSheets<
  T extends { name: string; columns: readonly XlsxColumn[] },
>(sheets: readonly T[]): readonly T[] {
  const names = new Set<string>();
  if (!Array.isArray(sheets) || !sheets.length) {
    throw new Error("invalid_xlsx_sheets");
  }
  return Object.freeze(sheets.map((sheet: T) => {
    if (
      typeof sheet.name !== "string" || !sheet.name || sheet.name.length > 31 ||
      /[\\/?*\[\]:]/.test(sheet.name) || names.has(sheet.name.toLowerCase())
    ) throw new Error("invalid_xlsx_sheets");
    names.add(sheet.name.toLowerCase());
    if (
      !Array.isArray(sheet.columns) ||
      sheet.columns.some((column) =>
        !column || typeof column.key !== "string" ||
        typeof column.label !== "string"
      )
    ) throw new Error("invalid_xlsx_columns");
    explicitXlsxColumns({ columns: sheet.columns.map((column) => column.key) });
    return Object.freeze({
      ...sheet,
      columns: Object.freeze(
        sheet.columns.map((column) => Object.freeze({ ...column })),
      ),
    });
  }));
}

export function xlsxCivilDate(value: string): XlsxCivilDate {
  if (
    typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
    value.length !== 10
  ) {
    throw new Error("invalid_xlsx_civil_date");
  }
  const [year, month, day] = value.split("-").map(Number);
  const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > days[month - 1]) {
    throw new Error("invalid_xlsx_civil_date");
  }
  // Excel's 1900 date-system capacity, not a restriction on Forms answers.
  if (year < 1900) throw new Error("xlsx_civil_date_out_of_range");
  return Object.freeze({ kind: "date", value });
}

function civilDateSerial(date: XlsxCivilDate): number {
  const [year, month, day] = date.value.split("-").map(Number);
  // UTC is used only for integer day arithmetic. Excel reserves the fictitious
  // serial 60 for 1900-02-29, which strict Gregorian validation never accepts.
  return (Date.UTC(year, month - 1, day) - Date.UTC(1899, 11, 31)) / 86400000 +
    (date.value >= "1900-03-01" ? 1 : 0);
}

const civilDateFormat = "yyyy-mm-dd";

function explicitXlsxColumns(
  options?: XlsxOptions,
): readonly string[] | undefined {
  if (options === undefined) return undefined;
  if (
    !Array.isArray(options.columns) || !options.columns.length ||
    options.columns.some((column) => typeof column !== "string") ||
    new Set(options.columns).size !== options.columns.length
  ) {
    throw new Error("invalid_xlsx_columns");
  }
  if (options.columns.length > 512) throw new Error("xlsx_column_limit");
  return Object.freeze([...options.columns]);
}

function xlsxCellValue(value: XlsxCellValue): XlsxCellValue {
  if (typeof value === "string") return neutralizeSpreadsheetFormula(value);
  if (typeof value === "boolean") return value;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (
    value !== null && typeof value === "object" && !(value instanceof Date) &&
    !Array.isArray(value) && Object.keys(value).length === 2 &&
    value.kind === "media" && typeof value.target === "string"
  ) {
    try {
      const url = new URL(value.target);
      const asset = url.pathname.slice("/forms/media/".length);
      const checked = xlsxMediaLink(url.origin, asset);
      if (checked.target === value.target) return checked;
    } catch { /* return only the sanitized contract error below */ }
    throw new Error("invalid_xlsx_media_link");
  }
  if (
    value !== null && typeof value === "object" && !Array.isArray(value) &&
    !(value instanceof Date) &&
    Object.hasOwn(value, "kind") && Object.hasOwn(value, "value") &&
    Object.keys(value).length === 2 && value.kind === "date"
  ) {
    return xlsxCivilDate(value.value);
  }
  throw new Error("invalid_xlsx_cell_value");
}

function validateXlsxRow(row: XlsxRow, columns?: ReadonlySet<string>): void {
  for (const [key, value] of Object.entries(row)) {
    if (columns && !columns.has(key)) throw new Error("xlsx_column_mismatch");
    xlsxCellValue(value);
  }
}

function xlsxRowCell(row: XlsxRow, column: string): XlsxCellValue {
  return Object.hasOwn(row, column) ? row[column] : "";
}

function isMediaLink(value: XlsxCellValue): value is string {
  return typeof value === "string" && value.startsWith("/forms/media/");
}

export function opaqueArtifactPath(artifactId: string): string {
  return `${artifactId.slice(0, 2)}/${artifactId}`;
}

export function neutralizeSpreadsheetFormula(value: string): string {
  return /^[\t\r\n ]*[=+\-@]/.test(value) ? `'${value}` : value;
}

export function expandSubmission(submission: ExportSubmission): ExportRow[] {
  const base: ExportRow = {
    response_id: submission.responseId,
    occurrence_id: submission.occurrenceId,
    version_id: submission.versionId,
  };
  // Separate namespaces prevent user-provided labels from replacing identity
  // or expansion columns. Always include the item ID, even in sparse pages.
  for (const [key, value] of Object.entries(submission.metadata)) {
    base[`Metadado [${encodeURIComponent(key)}]`] = value;
  }
  const simple = submission.answers.filter((answer) => !answer.multiValued);
  for (const answer of simple) {
    base[`Resposta [${encodeURIComponent(answer.itemId)}] ${answer.question}`] =
      answer.values[0] ?? "";
  }
  const multi = submission.answers.filter((answer) => answer.multiValued);
  if (multi.length === 0) return [base];
  const rows: ExportRow[] = [];
  for (const answer of multi) {
    const values = answer.values.length === 0 ? [""] : answer.values;
    for (const value of values) {
      rows.push({
        ...base,
        "Pergunta expandida": answer.question,
        item_id: answer.itemId,
        valor_expandido: value,
      });
    }
  }
  return rows;
}

export function encodeCsv(rows: ExportRow[]): Uint8Array {
  if (rows.length === 0) return new TextEncoder().encode("");
  const headers = [...new Set(rows.flatMap((row) => Object.keys(row)))];
  const cell = (value: string) => {
    const safe = neutralizeSpreadsheetFormula(value);
    return `"${safe.replaceAll('"', '""')}"`;
  };
  const lines = [headers.map(cell).join(",")];
  for (const row of rows) {
    lines.push(headers.map((header) => cell(row[header] ?? "")).join(","));
  }
  return new TextEncoder().encode(`\uFEFF${lines.join("\r\n")}\r\n`);
}

export async function* streamCsv(
  rowsFactory: () => AsyncIterable<ExportRow>,
): AsyncIterable<Uint8Array> {
  const headers: string[] = [];
  const known = new Set<string>();
  for await (const row of rowsFactory()) {
    for (const header of Object.keys(row)) {
      if (!known.has(header)) {
        if (headers.length >= 512) throw new Error("csv_column_limit");
        known.add(header);
        headers.push(header);
      }
    }
  }
  if (!headers.length) throw new Error("empty_export");
  const cell = (value: string) =>
    `"${neutralizeSpreadsheetFormula(value).replaceAll('"', '""')}"`;
  yield new TextEncoder().encode(`\uFEFF${headers.map(cell).join(",")}\r\n`);
  for await (const row of rowsFactory()) {
    yield new TextEncoder().encode(
      `${headers.map((header) => cell(row[header] ?? "")).join(",")}\r\n`,
    );
  }
}

export function encodeXlsx(
  rows: readonly XlsxRow[],
  options?: XlsxOptions,
): Uint8Array {
  const columns = explicitXlsxColumns(options);
  const known = columns && new Set(columns);
  for (const row of rows) validateXlsxRow(row, known);
  const headers = columns ??
    [...new Set(rows.flatMap((row) => Object.keys(row)))];
  const matrix = [
    [...headers],
    ...rows.map((row) =>
      headers.map((header) => {
        const value = xlsxCellValue(xlsxRowCell(row, header));
        return typeof value === "object" && value.kind === "date"
          ? { t: "n", v: civilDateSerial(value), z: civilDateFormat }
          : typeof value === "object"
          ? "Ver mídia"
          : value;
      })
    ),
  ];
  const worksheet = XLSX.utils.aoa_to_sheet(matrix);
  rows.forEach((row, rowIndex) => {
    headers.forEach((header, columnIndex) => {
      const value = xlsxRowCell(row, header);
      const target = mediaTarget(value);
      if (!target) return;
      const address = XLSX.utils.encode_cell({
        r: rowIndex + 1,
        c: columnIndex,
      });
      worksheet[address].v = typeof value === "object"
        ? "Ver mídia"
        : "Ver foto";
      worksheet[address].l = { Target: target };
    });
  });
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, "Respostas");
  return XLSX.write(workbook, {
    type: "array",
    bookType: "xlsx",
    compression: true,
  }) as Uint8Array;
}

export function encodeXlsxWorkbook(
  sheets: readonly Readonly<
    { name: string; columns: readonly XlsxColumn[]; rows: readonly XlsxRow[] }
  >[],
): Uint8Array {
  const workbook = XLSX.utils.book_new();
  for (const sheet of workbookSheets(sheets)) {
    const keys = sheet.columns.map((column) => column.key);
    const single = XLSX.read(encodeXlsx(sheet.rows, { columns: keys }), {
      type: "array",
      cellNF: true,
    });
    const worksheet = single.Sheets.Respostas;
    sheet.columns.forEach((column, index) => {
      worksheet[XLSX.utils.encode_cell({ r: 0, c: index })] = {
        t: "s",
        v: neutralizeSpreadsheetFormula(column.label),
      };
    });
    XLSX.utils.book_append_sheet(workbook, worksheet, sheet.name);
  }
  return new Uint8Array(
    XLSX.write(workbook, {
      type: "array",
      bookType: "xlsx",
      compression: true,
    }),
  );
}

type ByteSource = Uint8Array | AsyncIterable<Uint8Array>;
type ArchiveEntry = Readonly<
  { name: string; source: ByteSource; compress?: boolean }
>;
type RepeatableArchiveEntry = Readonly<{
  name: string;
  source: () => AsyncIterable<Uint8Array>;
}>;
const textEncoder = new TextEncoder();

const xmlText = (value: string) =>
  value.replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const xmlAttribute = (value: string) =>
  xmlText(value).replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");

function excelColumn(index: number): string {
  let result = "";
  for (let value = index + 1; value > 0; value = Math.floor((value - 1) / 26)) {
    result = String.fromCharCode(65 + ((value - 1) % 26)) + result;
  }
  return result;
}

async function* zipEntries(
  entries: AsyncIterable<ArchiveEntry> | Iterable<ArchiveEntry>,
  outputChunkBytes: number,
): AsyncIterable<Uint8Array> {
  const queue: Uint8Array[] = [];
  let failure: Error | undefined;
  const enqueue = (bytes: Uint8Array) => {
    for (
      let offset = 0;
      offset < bytes.byteLength;
      offset += outputChunkBytes
    ) {
      queue.push(bytes.slice(offset, offset + outputChunkBytes));
    }
  };
  const zip = new Zip((error, bytes) => {
    if (error) failure = error;
    else enqueue(bytes);
  });
  for await (const entry of entries) {
    const file = entry.compress
      ? new ZipDeflate(entry.name, { level: 6 })
      : new ZipPassThrough(entry.name);
    zip.add(file);
    const source = entry.source instanceof Uint8Array
      ? {
        async *[Symbol.asyncIterator]() {
          yield entry.source as Uint8Array;
        },
      }
      : entry.source;
    let pending: Uint8Array | undefined;
    for await (const chunk of source) {
      if (pending) {
        file.push(pending, false);
        if (failure) throw failure;
        while (queue.length > 0) yield queue.shift()!;
      }
      pending = chunk;
    }
    file.push(pending ?? new Uint8Array(), true);
    if (failure) throw failure;
    while (queue.length > 0) yield queue.shift()!;
  }
  zip.end();
  if (failure) throw failure;
  while (queue.length > 0) yield queue.shift()!;
}

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let index = 0; index < 256; index++) {
    let value = index;
    for (let bit = 0; bit < 8; bit++) {
      value = (value >>> 1) ^ ((value & 1) ? 0xEDB88320 : 0);
    }
    table[index] = value >>> 0;
  }
  return table;
})();
const write16 = (view: DataView, offset: number, value: number) =>
  view.setUint16(offset, value, true);
const write32 = (view: DataView, offset: number, value: number) =>
  view.setUint32(offset, value, true);

async function* storedZipEntries(
  entries: readonly RepeatableArchiveEntry[],
  outputChunkBytes: number,
): AsyncIterable<Uint8Array> {
  const metadata: Array<{
    name: Uint8Array;
    crc: number;
    size: number;
    offset: number;
    entry: RepeatableArchiveEntry;
  }> = [];
  let archiveOffset = 0;
  for (const entry of entries) {
    const name = textEncoder.encode(entry.name);
    let crc = 0xFFFFFFFF;
    let size = 0;
    for await (const chunk of entry.source()) {
      size += chunk.byteLength;
      if (size > 0xFFFFFFFF) throw new Error("zip64_not_supported");
      for (const byte of chunk) {
        crc = crcTable[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
      }
    }
    metadata.push({
      name,
      crc: (crc ^ 0xFFFFFFFF) >>> 0,
      size,
      offset: archiveOffset,
      entry,
    });
    archiveOffset += 30 + name.byteLength + size;
  }
  for (const item of metadata) {
    const local = new Uint8Array(30 + item.name.byteLength);
    const view = new DataView(local.buffer);
    write32(view, 0, 0x04034B50);
    write16(view, 4, 20);
    write16(view, 6, 0x0800);
    write32(view, 14, item.crc);
    write32(view, 18, item.size);
    write32(view, 22, item.size);
    write16(view, 26, item.name.byteLength);
    local.set(item.name, 30);
    yield local;
    let writtenSize = 0;
    let writtenCrc = 0xFFFFFFFF;
    for await (const chunk of item.entry.source()) {
      writtenSize += chunk.byteLength;
      if (writtenSize > item.size) throw new Error("xlsx_snapshot_changed");
      for (const byte of chunk) {
        writtenCrc = crcTable[(writtenCrc ^ byte) & 0xFF] ^ (writtenCrc >>> 8);
      }
      for (
        let offset = 0;
        offset < chunk.byteLength;
        offset += outputChunkBytes
      ) {
        yield chunk.slice(offset, offset + outputChunkBytes);
      }
    }
    if (
      writtenSize !== item.size ||
      ((writtenCrc ^ 0xFFFFFFFF) >>> 0) !== item.crc
    ) {
      throw new Error("xlsx_snapshot_changed");
    }
  }
  const centralOffset = archiveOffset;
  for (const item of metadata) {
    const central = new Uint8Array(46 + item.name.byteLength);
    const view = new DataView(central.buffer);
    write32(view, 0, 0x02014B50);
    write16(view, 4, 20);
    write16(view, 6, 20);
    write16(view, 8, 0x0800);
    write32(view, 16, item.crc);
    write32(view, 20, item.size);
    write32(view, 24, item.size);
    write16(view, 28, item.name.byteLength);
    write32(view, 42, item.offset);
    central.set(item.name, 46);
    yield central;
    archiveOffset += central.byteLength;
  }
  const end = new Uint8Array(22);
  const endView = new DataView(end.buffer);
  write32(endView, 0, 0x06054B50);
  write16(endView, 8, metadata.length);
  write16(endView, 10, metadata.length);
  write32(endView, 12, archiveOffset - centralOffset);
  write32(endView, 16, centralOffset);
  yield end;
}

async function xlsxArchiveEntries(
  rowsFactory: () => AsyncIterable<XlsxRow>,
  options?: XlsxOptions,
  labels?: readonly string[],
): Promise<RepeatableArchiveEntry[]> {
  const columns = explicitXlsxColumns(options);
  const headers: string[] = columns ? [...columns] : [];
  const knownHeaders = new Set<string>(headers);
  let hasCivilDates = false;
  const checkedRows = async function* () {
    for await (const row of rowsFactory()) {
      validateXlsxRow(row, columns ? knownHeaders : undefined);
      yield row;
    }
  };
  for await (const row of checkedRows()) {
    hasCivilDates ||= Object.values(row).some((value) =>
      typeof value === "object" && value.kind === "date"
    );
    for (const header of Object.keys(row)) {
      if (!knownHeaders.has(header)) {
        if (headers.length >= 512) throw new Error("xlsx_column_limit");
        knownHeaders.add(header);
        headers.push(header);
      }
    }
  }
  if (!headers.length) throw new Error("empty_export");

  const cell = (reference: string, value: XlsxCellValue) => {
    const safe = xlsxCellValue(value);
    if (typeof safe === "object" && safe.kind === "date") {
      if (!hasCivilDates) throw new Error("xlsx_snapshot_changed");
      return `<c r="${reference}" s="1" t="n"><v>${
        civilDateSerial(safe)
      }</v></c>`;
    }
    if (typeof safe === "object") return cell(reference, "Ver mídia");
    if (typeof safe === "number") {
      return `<c r="${reference}" t="n"><v>${safe}</v></c>`;
    }
    if (typeof safe === "boolean") {
      return `<c r="${reference}" t="b"><v>${safe ? 1 : 0}</v></c>`;
    }
    return `<c r="${reference}" t="inlineStr"><is><t xml:space="preserve">${
      xmlText(safe)
    }</t></is></c>`;
  };
  const sheet = async function* () {
    yield textEncoder.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData>',
    );
    yield textEncoder.encode(
      `<row r="1">${
        headers.map((header, column) =>
          cell(`${excelColumn(column)}1`, labels?.[column] ?? header)
        )
          .join("")
      }</row>`,
    );
    let rowNumber = 2;
    for await (const row of checkedRows()) {
      yield textEncoder.encode(
        `<row r="${rowNumber}">${
          headers.map((header, column) => {
            const value = xlsxRowCell(row, header);
            return cell(
              `${excelColumn(column)}${rowNumber}`,
              isMediaLink(value) ? "Ver foto" : value,
            );
          }).join("")
        }</row>`,
      );
      rowNumber++;
    }
    yield textEncoder.encode("</sheetData><hyperlinks>");
    rowNumber = 2;
    let relationshipId = 1;
    for await (const row of checkedRows()) {
      for (let column = 0; column < headers.length; column++) {
        if (mediaTarget(xlsxRowCell(row, headers[column]))) {
          yield textEncoder.encode(
            `<hyperlink ref="${
              excelColumn(column)
            }${rowNumber}" r:id="rId${relationshipId}"/>`,
          );
          relationshipId++;
        }
      }
      rowNumber++;
    }
    yield textEncoder.encode("</hyperlinks></worksheet>");
  };
  const relationships = async function* () {
    yield textEncoder.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    let relationshipId = 1;
    for await (const row of checkedRows()) {
      for (const header of headers) {
        const value = xlsxRowCell(row, header);
        const target = mediaTarget(value);
        if (target) {
          yield textEncoder.encode(
            `<Relationship Id="rId${relationshipId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${
              xmlAttribute(target)
            }" TargetMode="External"/>`,
          );
          relationshipId++;
        }
      }
    }
    yield textEncoder.encode("</Relationships>");
  };
  const repeat = (value: string) => () => ({
    async *[Symbol.asyncIterator]() {
      yield textEncoder.encode(value);
    },
  });
  const stylesOverride = hasCivilDates
    ? '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    : "";
  const stylesRelationship = hasCivilDates
    ? '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    : "";
  const entries: RepeatableArchiveEntry[] = [
    {
      name: "[Content_Types].xml",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
          stylesOverride + "</Types>",
      ),
    },
    {
      name: "_rels/.rels",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      ),
    },
    {
      name: "xl/workbook.xml",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Respostas" sheetId="1" r:id="rId1"/></sheets></workbook>',
      ),
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
          stylesRelationship + "</Relationships>",
      ),
    },
    { name: "xl/worksheets/sheet1.xml", source: sheet },
    { name: "xl/worksheets/_rels/sheet1.xml.rels", source: relationships },
  ];
  if (hasCivilDates) {
    entries.push({
      name: "xl/styles.xml",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/></numFmts><fonts count="1"><font/></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
      ),
    });
  }
  return entries;
}

export async function* streamXlsx(
  rowsFactory: () => AsyncIterable<XlsxRow>,
  outputChunkBytes = 256 * 1024,
  options?: XlsxOptions,
): AsyncIterable<Uint8Array> {
  if (!Number.isSafeInteger(outputChunkBytes) || outputChunkBytes < 1024) {
    throw new Error("invalid_xlsx_output_chunk_size");
  }
  yield* storedZipEntries(
    await xlsxArchiveEntries(rowsFactory, options),
    outputChunkBytes,
  );
}

export async function* streamXlsxWorkbook(
  requested: readonly XlsxWorkbookSheet[],
  outputChunkBytes = 256 * 1024,
): AsyncIterable<Uint8Array> {
  if (!Number.isSafeInteger(outputChunkBytes) || outputChunkBytes < 1024) {
    throw new Error("invalid_xlsx_output_chunk_size");
  }
  const sheets = workbookSheets(requested);
  const entries: RepeatableArchiveEntry[] = [];
  let styles: RepeatableArchiveEntry | undefined;
  for (let i = 0; i < sheets.length; i++) {
    const sheet = sheets[i];
    const parts = await xlsxArchiveEntries(sheet.rows, {
      columns: sheet.columns.map((column) => column.key),
    }, sheet.columns.map((column) => column.label));
    for (const part of parts) {
      if (part.name === "xl/styles.xml") styles = part;
      if (part.name.startsWith("xl/worksheets/")) {
        entries.push({
          ...part,
          name: part.name.replace("sheet1.xml", `sheet${i + 1}.xml`),
        });
      }
    }
  }
  const repeat = (value: string) =>
    async function* () {
      yield textEncoder.encode(value);
    };
  const relationshipsNamespace =
    "http://schemas.openxmlformats.org/package/2006/relationships";
  entries.unshift(
    {
      name: "[Content_Types].xml",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
          sheets.map((_, i) =>
            `<Override PartName="/xl/worksheets/sheet${
              i + 1
            }.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`
          ).join("") +
          (styles
            ? '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            : "") +
          "</Types>",
      ),
    },
    {
      name: "_rels/.rels",
      source: repeat(
        `<Relationships xmlns="${relationshipsNamespace}"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
      ),
    },
    {
      name: "xl/workbook.xml",
      source: repeat(
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
          sheets.map((sheet, i) =>
            `<sheet name="${xmlAttribute(sheet.name)}" sheetId="${
              i + 1
            }" r:id="rId${i + 1}"/>`
          ).join("") + "</sheets></workbook>",
      ),
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      source: repeat(
        `<Relationships xmlns="${relationshipsNamespace}">` +
          sheets.map((_, i) =>
            `<Relationship Id="rId${
              i + 1
            }" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${
              i + 1
            }.xml"/>`
          ).join("") +
          (styles
            ? '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            : "") +
          "</Relationships>",
      ),
    },
  );
  if (styles) entries.push(styles);
  yield* storedZipEntries(entries, outputChunkBytes);
}

export type ZipMediaEntry = { name: string; bytes: Uint8Array };
export type ZipMediaSource = { name: string; source: ByteSource };

export function encodeZip(input: {
  workbook: Uint8Array;
  manifest: Record<string, unknown>;
  media: ZipMediaEntry[];
}): Uint8Array {
  const files: Record<string, Uint8Array> = {
    "respostas.xlsx": input.workbook,
    "manifesto.json": strToU8(JSON.stringify(input.manifest, null, 2)),
  };
  for (const entry of input.media) {
    if (!/^[0-9a-z-]+\.(?:jpe?g|png|webp)$/i.test(entry.name)) {
      throw new Error("invalid opaque media name");
    }
    files[`midias/${entry.name}`] = entry.bytes;
  }
  return zipSync(files, { level: 6 });
}

export async function* streamZip(input: {
  workbook: ByteSource;
  manifest: Record<string, unknown>;
  media: ZipMediaEntry[] | AsyncIterable<ZipMediaSource>;
  outputChunkBytes?: number;
}): AsyncIterable<Uint8Array> {
  const outputChunkBytes = input.outputChunkBytes ?? 256 * 1024;
  if (!Number.isSafeInteger(outputChunkBytes) || outputChunkBytes < 1024) {
    throw new Error("invalid_zip_output_chunk_size");
  }
  const entries = async function* (): AsyncIterable<ArchiveEntry> {
    yield { name: "respostas.xlsx", source: input.workbook };
    yield {
      name: "manifesto.json",
      source: strToU8(JSON.stringify(input.manifest, null, 2)),
      compress: true,
    };
    const media = Array.isArray(input.media)
      ? input.media.map((entry) => ({ name: entry.name, source: entry.bytes }))
      : input.media;
    for await (const entry of media) {
      if (!/^[0-9a-z-]+\.(?:jpe?g|png|webp)$/i.test(entry.name)) {
        throw new Error("invalid opaque media name");
      }
      yield {
        name: `midias/${entry.name}`,
        source: entry.source,
      };
    }
  };
  yield* zipEntries(entries(), outputChunkBytes);
}
import { strToU8, Zip, ZipDeflate, ZipPassThrough, zipSync } from "fflate";
import * as XLSX from "xlsx";
