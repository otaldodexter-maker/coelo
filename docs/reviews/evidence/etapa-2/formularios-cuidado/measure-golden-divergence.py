"""Descreve ONDE dois goldens diferem, sem abrir imagem.

Companheiro de 2026-09-09-golden-divergence-measurement.md. Existe porque a
leitura de imagem falha por timeout de hook neste ambiente e porque percentual
de pixels sozinho nao distingue tela redesenhada de mudanca de renderizacao.

Para cada par masterImage/testImage produz: percentual de pixels diferentes,
percentual de LINHAS atingidas, percentual de COLUNAS atingidas e a faixa
vertical entre a primeira e a ultima linha diferente.

Como ler: diferenca concentrada numa faixa e conteudo que mudou; diferenca
espalhada por quase toda linha e toda coluna, com a gravidade caindo conforme
a largura cresce, e renderizacao.

So depende da biblioteca padrao. Le PNG de 8 bits nao entrelacado, RGB ou RGBA,
que e o que o comparador do flutter_test grava. Nao escreve nada.

Uso:
    python measure-golden-divergence.py <diretorio> [limite]

O diretorio e varrido em busca de **/failures/*_masterImage.png, que so existem
depois de uma execucao de teste com golden reprovado.
"""
import struct, zlib, sys, os, glob


def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    pos, idat, w = 8, [], None
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if ctype == b'IHDR':
            w, h, depth, color, comp, filt, inter = struct.unpack('>IIBBBBB', body)
            if depth != 8 or inter != 0 or color not in (2, 6):
                return None
            channels = 4 if color == 6 else 3
        elif ctype == b'IDAT':
            idat.append(body)
        elif ctype == b'IEND':
            break
        pos += 12 + length
    if w is None:
        return None
    raw = zlib.decompress(b''.join(idat))
    stride = w * channels
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        ft = raw[p]; p += 1
        line = bytearray(raw[p:p + stride]); p += stride
        if ft == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ft == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif ft == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, channels, bytes(out)


def describe(master, test):
    a, b = read_png(master), read_png(test)
    if not a or not b or a[0] != b[0] or a[1] != b[1] or a[2] != b[2]:
        return None
    w, h, ch, pa = a
    pb = b[3]
    stride = w * ch
    rows_hit, total_diff = 0, 0
    first_row, last_row = None, None
    cols = bytearray(w)
    for y in range(h):
        base = y * stride
        hit = 0
        for x in range(w):
            i = base + x * ch
            if pa[i] != pb[i] or pa[i + 1] != pb[i + 1] or pa[i + 2] != pb[i + 2]:
                hit += 1
                cols[x] = 1
        if hit:
            rows_hit += 1
            total_diff += hit
            if first_row is None:
                first_row = y
            last_row = y
    cols_hit = sum(cols)
    return {
        'w': w, 'h': h,
        'pct': round(100.0 * total_diff / (w * h), 2),
        'rows_pct': round(100.0 * rows_hit / h, 1),
        'cols_pct': round(100.0 * cols_hit / w, 1),
        'band': None if first_row is None else round(100.0 * (last_row - first_row + 1) / h, 1),
    }


target = sys.argv[1]
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 6
found = sorted(glob.glob(os.path.join(target, '**', 'failures', '*_masterImage.png'), recursive=True))
print('pares disponiveis:', len(found))
for master in found[:limit]:
    test = master.replace('_masterImage.png', '_testImage.png')
    if not os.path.exists(test):
        continue
    d = describe(master, test)
    name = os.path.basename(master).replace('_masterImage.png', '')
    if not d:
        print('%-52s (nao comparavel)' % name[:52])
        continue
    print('%-52s %sx%s  pixels %5s%%  linhas afetadas %5s%%  colunas %5s%%  faixa vertical %5s%%'
          % (name[:52], d['w'], d['h'], d['pct'], d['rows_pct'], d['cols_pct'], d['band']))
