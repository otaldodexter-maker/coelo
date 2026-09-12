---
fonte: C0; G3 d3d3d5d630dda094f2df93bb70523cb716470e0e; fix725155ec0825d8ace09ac7cc49f3a8f69d75da78
status: revisao-focal-concluida-achado-corrigido-localmente
data_geracao: 2026-09-12
---

# Revisão G4 da captura Foto de G3

Recorte autorizado C0: apps/superadmin → Formulários → Responder → Foto;
ciclo de vida, resultado tardio, troca de contexto, descarte do stream e bytes
encaminhados ao R2. Revisão somente leitura; nenhum arquivo de G3 editado,
nenhum Flutter/Chrome executado por G4 para esta revisão. Foto continua única.

## Achado P2 confirmado e corrigido

No SHA d3d3d5d63, `forms_camera_capture.dart:69–77` chama setState diretamente
no callback de purge. `forms_gallery_answer_field.dart:105–110` invalida a
sessão ao desmontar o campo. Remover o formulário mantendo o Navigator e o
modal de câmera vivos dispara purge durante finalizeTree/lockState. O modal
continua mounted, mas setState é proibido nessa fase e a invalidação falha.
O stream já era fechado antes da exceção; não foi constatada exposição de mídia.

G4 encaminhou o caminho concreto a G3/C0. G3 reproduziu com teste de proprietário
descartado e captura pendente: RED 0PASS/1FAIL, depois GREEN 9PASS/0FAIL e analyze0.
Fontes G3: `09-camera-purge.md`, `09-camera-purge-red.log` e respectivos logs verdes
na evidência r08-formularios-cuidado-rotina. Resultados atribuídos a G3, sem rerun G4.

Fix725155ec0 revisado: fecha câmera e limpa flags sincronicamente; somente o
repaint é adiado para pós-frame quando schedulerPhase=persistentCallbacks,
com mounted conferido. O teste mantém o modal, verifica câmera fechada, nenhuma
exceção, bytes tardios zerados e mensagem de sessão encerrada. Achado atendido.

## Demais caminhos inspecionados

- A geração/sessão invalida resultados de start/capture; stream retornado após
  cancelamento é fechado, bytes de captura tardia são zerados.
- PopScope fecha o stream antes da animação; lifecycle fora de resumed encerra
  captura e exige retry explícito. Dispose remove observer e registro de purge.
- getUserMedia usa vídeo sem áudio; close para tracks e limpa srcObject.
- Foto passa pelo mesmo FormsImageUpload: valida MIME/limite/checksum, prepare,
  PUT isolado sem redirect, finalize com vínculo, purge/cancel e zero dos bytes.

Nenhum outro achado concreto no recorte. Isto não certifica câmera física,
permissão real do navegador, UI/E2E ou upload R2 pela tela. Não altera contrato
nem projeção de conhecimento; integração e verificação conjunta pertencem a C0.
