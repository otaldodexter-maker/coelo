import { assertThrows } from "jsr:@std/assert@1.0.14";
import * as XLSX from "xlsx";
import { MAX_XLSX_ARCHIVE_ENTRIES, MAX_XLSX_UNCOMPRESSED_BYTES, validateXlsxArchive, validateXlsxWorkbook } from "./xlsx_guard.ts";

function u16(value: number) { return [value & 0xff, (value >>> 8) & 0xff]; }
function u32(value: number) { return [value & 0xff, (value >>> 8) & 0xff, (value >>> 16) & 0xff, (value >>> 24) & 0xff]; }

function archive({ entries = 1, compressed = 1, expanded = 1 }: { entries?: number; compressed?: number; expanded?: number }) {
  const name = [120];
  const central = [0x50, 0x4b, 0x01, 0x02, 20, 0, 20, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...u32(compressed), ...u32(expanded), ...u16(name.length), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, ...name];
  const eocd = [0x50, 0x4b, 0x05, 0x06, 0, 0, 0, 0, ...u16(entries), ...u16(entries), ...u32(central.length), ...u32(0), 0, 0];
  return new Uint8Array([...central, ...eocd]);
}

Deno.test("xlsx guard rejects central directories with too many entries before parsing", () => {
  assertThrows(() => validateXlsxArchive(archive({ entries: MAX_XLSX_ARCHIVE_ENTRIES + 1 })), Error, "invalid_xlsx_archive");
});

Deno.test("xlsx guard rejects archive members with unsafe uncompressed size", () => {
  assertThrows(() => validateXlsxArchive(archive({ expanded: MAX_XLSX_UNCOMPRESSED_BYTES + 1 })), Error, "xlsx_compression_ratio_exceeded");
});

Deno.test("xlsx guard rejects oversized sheet dimensions before matrix conversion", () => {
  const book = XLSX.utils.book_new();
  const sheet = XLSX.utils.aoa_to_sheet([["institution_id"]]);
  sheet["!ref"] = "A1:AG2";
  XLSX.utils.book_append_sheet(book, sheet, "Unidades");
  assertThrows(() => validateXlsxWorkbook(book), Error, "xlsx_sheet_limit_exceeded");
});
