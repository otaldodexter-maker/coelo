import * as XLSX from "xlsx";

// Enforced before SheetJS inflates a workbook; keeps this Edge within its
// memory budget and the import contract's 5,000 data-row ceiling.
export const MAX_XLSX_ARCHIVE_ENTRIES = 256;
export const MAX_XLSX_UNCOMPRESSED_BYTES = 24 * 1024 * 1024;
export const MAX_XLSX_COMPRESSION_RATIO = 100;
export const MAX_XLSX_SHEETS = 1;
export const MAX_XLSX_SHEET_ROWS = 5001; // header + 5,000 data rows
export const MAX_XLSX_SHEET_COLUMNS = 32;
export const MAX_XLSX_SHEET_CELLS = MAX_XLSX_SHEET_ROWS * MAX_XLSX_SHEET_COLUMNS;

function u16(bytes: Uint8Array, offset: number) {
  return bytes[offset]! | (bytes[offset + 1]! << 8);
}

function u32(bytes: Uint8Array, offset: number) {
  return (bytes[offset]! | (bytes[offset + 1]! << 8) | (bytes[offset + 2]! << 16) | (bytes[offset + 3]! << 24)) >>> 0;
}

function fail(code: string): never {
  throw new Error(code);
}

/** Inspects ZIP metadata before the XLSX parser can decompress member bodies. */
export function validateXlsxArchive(bytes: Uint8Array) {
  if (bytes.length < 22 || bytes[0] !== 0x50 || bytes[1] !== 0x4b) fail("invalid_xlsx_signature");
  const start = Math.max(0, bytes.length - 0xffff - 22);
  let eocd = -1;
  for (let offset = bytes.length - 22; offset >= start; offset--) {
    if (u32(bytes, offset) === 0x06054b50) { eocd = offset; break; }
  }
  if (eocd < 0 || eocd + 22 > bytes.length) fail("invalid_xlsx_archive");
  const disk = u16(bytes, eocd + 4);
  const directoryDisk = u16(bytes, eocd + 6);
  const entriesOnDisk = u16(bytes, eocd + 8);
  const entries = u16(bytes, eocd + 10);
  const directorySize = u32(bytes, eocd + 12);
  const directoryOffset = u32(bytes, eocd + 16);
  if (disk !== 0 || directoryDisk !== 0 || entriesOnDisk !== entries || entries === 0 || entries > MAX_XLSX_ARCHIVE_ENTRIES) fail("invalid_xlsx_archive");
  if (directorySize === 0 || directoryOffset + directorySize > eocd) fail("invalid_xlsx_archive");

  let cursor = directoryOffset;
  const directoryEnd = directoryOffset + directorySize;
  let uncompressed = 0;
  for (let entry = 0; entry < entries; entry++) {
    if (cursor + 46 > directoryEnd || u32(bytes, cursor) !== 0x02014b50) fail("invalid_xlsx_archive");
    const flags = u16(bytes, cursor + 8);
    const method = u16(bytes, cursor + 10);
    const compressed = u32(bytes, cursor + 20);
    const expanded = u32(bytes, cursor + 24);
    const nameLength = u16(bytes, cursor + 28);
    const extraLength = u16(bytes, cursor + 30);
    const commentLength = u16(bytes, cursor + 32);
    const length = 46 + nameLength + extraLength + commentLength;
    if (cursor + length > directoryEnd || (flags & 0x1) !== 0 || (method !== 0 && method !== 8)) fail("invalid_xlsx_archive");
    if ((compressed === 0 && expanded !== 0) || (compressed !== 0 && expanded > compressed * MAX_XLSX_COMPRESSION_RATIO)) fail("xlsx_compression_ratio_exceeded");
    uncompressed += expanded;
    if (uncompressed > MAX_XLSX_UNCOMPRESSED_BYTES) fail("xlsx_uncompressed_size_exceeded");
    cursor += length;
  }
  if (cursor !== directoryEnd) fail("invalid_xlsx_archive");
}

/** Limits parsed workbook geometry before it is converted into an in-memory matrix. */
export function validateXlsxWorkbook(book: XLSX.WorkBook) {
  if (book.SheetNames.length === 0) fail("empty_import");
  if (book.SheetNames.length > MAX_XLSX_SHEETS) fail("xlsx_too_many_sheets");
  const sheet = book.Sheets[book.SheetNames[0]!];
  const reference = sheet?.["!ref"];
  if (!reference) fail("empty_import");
  let range: XLSX.Range;
  try { range = XLSX.utils.decode_range(reference); } catch { fail("invalid_xlsx_sheet_range"); }
  const rows = range.e.r - range.s.r + 1;
  const columns = range.e.c - range.s.c + 1;
  if (range.s.r < 0 || range.s.c < 0 || rows < 1 || columns < 1 || rows > MAX_XLSX_SHEET_ROWS || columns > MAX_XLSX_SHEET_COLUMNS || rows * columns > MAX_XLSX_SHEET_CELLS) fail("xlsx_sheet_limit_exceeded");
}
