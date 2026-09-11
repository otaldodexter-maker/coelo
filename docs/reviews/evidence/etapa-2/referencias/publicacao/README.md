Referencias da familia visual Publicacao (Coelo Principal dentro do Superadmin).

- `aprovadas-20260911/`: as 12 telas aprovadas pelo Owner em 11/09/2026 as 17:19
  no canvas "Publicar no Coelo" (artefato 7d13d4ef, versao 4): agora, acontece,
  momentos, circular, evento e lancar-chamada, cada uma em `-mobile-375.png` e
  `-web-1440.png`. Sao a referencia vigente para goldens novos dessas telas.
- `canvas-fonte/`: fonte regeneravel das imagens (`gen.py` gera os artboards
  `.dc.html` e o `canvas.json`; os `.jpg`/`.png` sao recortes do golden real do
  Superadmin e fotos sinteticas). Para regenerar: `python gen.py` e abrir cada
  `.dc.html` no Chrome (headless com `--window-size` igual ao frame do
  `canvas.json`).
- Referencias originais do Owner (o Owner salva os quatro PNG aqui quando
  puder): agora-publicar.png, acontece-publicar.png, momentos-publicar-1.png,
  momentos-publicar-2.png. Descricao na skill coelo-ui,
  references/principal-visual-surfaces.md, secao "Familia Publicacao".
