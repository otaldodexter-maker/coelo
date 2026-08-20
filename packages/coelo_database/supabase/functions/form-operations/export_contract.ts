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
    ...submission.metadata,
  };
  const simple = submission.answers.filter((answer) => !answer.multiValued);
  for (const answer of simple) base[answer.question] = answer.values[0] ?? "";
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

export function encodeXlsx(rows: ExportRow[]): Uint8Array {
  const headers = [...new Set(rows.flatMap((row) => Object.keys(row)))];
  const matrix = [
    headers,
    ...rows.map((row) =>
      headers.map((header) => neutralizeSpreadsheetFormula(row[header] ?? ""))
    ),
  ];
  const worksheet = XLSX.utils.aoa_to_sheet(matrix);
  rows.forEach((row, rowIndex) => {
    headers.forEach((header, columnIndex) => {
      const value = row[header] ?? "";
      if (!value.startsWith("/forms/media/")) return;
      const address = XLSX.utils.encode_cell({
        r: rowIndex + 1,
        c: columnIndex,
      });
      worksheet[address].v = "Ver foto";
      worksheet[address].l = { Target: value };
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
    for await (const chunk of item.entry.source()) {
      for (
        let offset = 0;
        offset < chunk.byteLength;
        offset += outputChunkBytes
      ) {
        yield chunk.slice(offset, offset + outputChunkBytes);
      }
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

export async function* streamXlsx(
  rowsFactory: () => AsyncIterable<ExportRow>,
  outputChunkBytes = 256 * 1024,
): AsyncIterable<Uint8Array> {
  if (!Number.isSafeInteger(outputChunkBytes) || outputChunkBytes < 1024) {
    throw new Error("invalid_xlsx_output_chunk_size");
  }
  const headers: string[] = [];
  const knownHeaders = new Set<string>();
  for await (const row of rowsFactory()) {
    for (const header of Object.keys(row)) {
      if (!knownHeaders.has(header)) {
        if (headers.length >= 512) throw new Error("xlsx_column_limit");
        knownHeaders.add(header);
        headers.push(header);
      }
    }
  }
  if (!headers.length) throw new Error("empty_export");

  const cell = (reference: string, value: string) => {
    const safe = neutralizeSpreadsheetFormula(value);
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
        headers.map((header, column) => cell(`${excelColumn(column)}1`, header))
          .join("")
      }</row>`,
    );
    let rowNumber = 2;
    for await (const row of rowsFactory()) {
      yield textEncoder.encode(
        `<row r="${rowNumber}">${
          headers.map((header, column) => {
            const value = row[header] ?? "";
            return cell(
              `${excelColumn(column)}${rowNumber}`,
              value.startsWith("/forms/media/") ? "Ver foto" : value,
            );
          }).join("")
        }</row>`,
      );
      rowNumber++;
    }
    yield textEncoder.encode("</sheetData><hyperlinks>");
    rowNumber = 2;
    let relationshipId = 1;
    for await (const row of rowsFactory()) {
      for (let column = 0; column < headers.length; column++) {
        if ((row[headers[column]] ?? "").startsWith("/forms/media/")) {
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
    for await (const row of rowsFactory()) {
      for (const header of headers) {
        const value = row[header] ?? "";
        if (value.startsWith("/forms/media/")) {
          yield textEncoder.encode(
            `<Relationship Id="rId${relationshipId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${
              xmlAttribute(value)
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
  const entries: RepeatableArchiveEntry[] = [
    {
      name: "[Content_Types].xml",
      source: repeat(
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
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
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      ),
    },
    { name: "xl/worksheets/sheet1.xml", source: sheet },
    { name: "xl/worksheets/_rels/sheet1.xml.rels", source: relationships },
  ];
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
