import { assertEquals } from "jsr:@std/assert@1.0.14";

import { isAcceptableSvg } from "./svg_contract.ts";

const bytes = (text: string) => new TextEncoder().encode(text);
const icon = (inner: string) =>
  `<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">${inner}</svg>\n`;

Deno.test("svg do icone: fundo + path e aceito", () => {
  assertEquals(isAcceptableSvg(bytes(icon('<rect width="512" height="512" rx="128" fill="#2A6F97"/><path d="M256 96l48 128h136l-110 80 42 128-116-84-116 84 42-128-110-80h136z" fill="#FFFFFF"/>'))), true);
  assertEquals(isAcceptableSvg(bytes(icon('<circle cx="256" cy="256" r="200" fill="#000"/>').replace(/^<\?xml[^>]*\?>\n/, ""))), true, "sem declaracao xml tambem vale");
});

Deno.test("svg do icone: script, handler, referencia externa e foreignObject sao recusados", () => {
  assertEquals(isAcceptableSvg(bytes(icon('<script>alert(1)</script>'))), false);
  assertEquals(isAcceptableSvg(bytes(icon('<rect width="1" height="1" onload="alert(1)"/>'))), false);
  assertEquals(isAcceptableSvg(bytes(icon('<image href="https://evil.example/x.png"/>'))), false);
  assertEquals(isAcceptableSvg(bytes(icon('<use xlink:href="#x"/>'))), false);
  assertEquals(isAcceptableSvg(bytes(icon('<foreignObject><div>x</div></foreignObject>'))), false);
  assertEquals(isAcceptableSvg(bytes(icon('<rect fill="url(#g)"/>'))), false);
  assertEquals(isAcceptableSvg(bytes(icon('<a href="javascript:alert(1)"><rect/></a>'))), false);
  assertEquals(isAcceptableSvg(bytes('<!DOCTYPE svg [<!ENTITY x "y">]>' + icon(""))), false);
});

Deno.test("svg do icone: nao-svg, binario e tamanho sao recusados", () => {
  assertEquals(isAcceptableSvg(bytes("<html><svg xmlns=\"http://www.w3.org/2000/svg\"></svg></html>")), false, "raiz precisa ser <svg>");
  assertEquals(isAcceptableSvg(bytes('<svg viewBox="0 0 1 1"></svg>')), false, "xmlns obrigatorio");
  assertEquals(isAcceptableSvg(new Uint8Array([0x89, 0x50, 0x4e, 0x47])), false, "png nao e svg");
  assertEquals(isAcceptableSvg(new Uint8Array(0)), false);
  assertEquals(isAcceptableSvg(bytes(icon("<!-- " + "x".repeat(300 * 1024) + " -->"))), false, "acima de 256 KiB");
});
