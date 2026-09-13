---
source: "Owner R10 MP4 fixture request; revision 497a070ba"
status: "local-proof-ready"
generated_at: "2026-09-13"
---

# C1 — fixture MP4 decodificável

`r10-chat-inline-orange-1s.mp4` é uma fixture sintética sem dados pessoais,
com 1 segundo de cor sólida `#D63C00`, vídeo H.264/yuv420p de 320x180 a 30 fps
e sem faixa de áudio. Tem 2.446 bytes, abaixo do limite técnico inicial de
10 MiB.

Foi gerada sem alterar PATH ou configuração global, com o binário isolado
fornecido por `imageio-ffmpeg 0.6.0`, instalado somente em
`C:\\Users\\adrie\\Documents\\Coelo-backups\\r10-video-tools`:

```powershell
& 'C:\Users\adrie\Documents\Coelo-backups\r10-video-tools\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe' `
  -f lavfi -i 'color=c=#D63C00:s=320x180:r=30:d=1' -an -c:v libx264 `
  -pix_fmt yuv420p -movflags +faststart -y `
  'docs\reviews\evidence\etapa-2\r10-chat-inline\fixtures\r10-chat-inline-orange-1s.mp4'
```

Validação local em 2026-09-13:

- `ffmpeg -v error -i <fixture> -f null -` terminou com código 0, decodificando
  os 30 frames;
- inspeção do mesmo binário: duração `00:00:01.00`, `h264 (High)` / `avc1`,
  `yuv420p(progressive)`, 320x180, 30 fps; não há stream de áudio;
- SHA-256:
  `D1D8941A1C1B97B39105DFDC4B73DE4956E3833A5A568B91268A4829F869FB2F`;
- cabeçalho: `000000206674797069736f6d`; a verificação atual de
  `matchesDeclaredType(bytes, 'video/mp4')` aceita o arquivo porque
  `bytes[4:8] == 'ftyp'`.

Esta é apenas uma prova local de fixture e player. Ela não executa upload,
ticket de leitura, CORS ou fluxo E2E do backend privado.
