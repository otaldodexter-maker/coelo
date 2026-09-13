---
source: "Owner R10 MP4 fixture request; revision 497a070ba"
status: "blocked-environment"
generated_at: "2026-09-13"
---

# C1 — fixture MP4 decodificável

Foi solicitada uma fixture MP4 real, reproduzível, de um segundo, cor laranja
sólida e sem áudio ou dados pessoais, para a prova UI do chat privado.

Nenhum gerador autorizado está disponível nesta worktree: `ffmpeg` não está no
PATH e o Python instalado não possui `imageio_ffmpeg`. Nenhuma dependência ou
ferramenta foi instalada. Portanto não há arquivo MP4, codec, tamanho, duração
ou validação `matchesDeclaredType` a reportar.

Próximo passo seguro: disponibilizar um binário `ffmpeg` já aprovado no PATH
ou um ambiente que já contenha `imageio_ffmpeg`; gerar com duração de um
segundo, vídeo H.264/MP4 sem faixa de áudio, então validar com `ffprobe` e com
`matchesDeclaredType(bytes, 'video/mp4')` antes de anexar a fixture.
