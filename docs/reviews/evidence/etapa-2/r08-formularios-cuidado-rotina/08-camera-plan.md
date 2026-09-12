---
source: "Gate nominal C0 R08 G3; docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md; docs/knowledge/team/superadmin-forms-production.md; ADR0032; coelo-ui/form-layout-contracts"
status: "desenho focal antes da implementação; captura autorizada C0; cardinalidade preservada"
generated_at: "2026-09-12"
---

# Foto — captura web no upload de resposta existente

Recorte: `apps/superadmin -> Formulários -> Responder -> Foto -> forms.upload`. H20, imagem da dose de medicação, permanece separado. Base integrada `origin/dev 7cc6d4e7b`, merge G3 `8b9e784e5`.

Objetivo: permitir que o usuário capture uma foto na câmera, confira e confirme o envio pelo contrato R2 já existente. Não criar gateway, bucket, configuração, dependência global ou escolha de arquivo disfarçada de câmera.

## Fonte e limites

Foto usa câmera; Galeria usa imagens existentes. O backend vigente exige Foto com uma imagem. A fonte de13/08 permite até cinco, mas C0 determinou preservar o contrato efetivo e conferir fontes finais posteriores antes de ampliar. Este pacote mantém uma imagem e não altera SQL. Não foi localizada spec de Formulários com nome01/09 na busca focal; caminho solicitado ao C0, sem tomar ausência como aprovação de mudança.

O fluxo de avatar/Perfil e seu crop não se aplica à resposta Foto. A captura web usa o SDK condicional já disponível; não adiciona um seletor de arquivo HTML nem duplica o FilePicker de Galeria.

## Desenho mínimo

1. Um port de câmera oferece iniciar, preview, capturar bytes e encerrar. O diálogo recebe uma factory injetável para testes. Implementação web usa `getUserMedia` com vídeo e sem áudio; outras plataformas apresentam indisponibilidade honesta.
2. A ação **Capturar foto** abre um diálogo responsivo com título persistente, instrução curta, preview, **Cancelar** e **Usar foto**. A primária só habilita quando o vídeo está pronto. Erro de permissão/dispositivo apresenta mensagem e retry. Espaçamento usa tokens Coelo; em375/200 as ações e o conteúdo permanecem acessíveis por rolagem.
3. Capturar desenha o frame em canvas, limita o maior lado a2560px e codifica JPEG localmente. O serviço de upload continua validando MIME/bytes/checksum e o servidor permanece autoritativo. Não cria áudio, vídeo persistido ou URL externa de preview.
4. Cancelar, fechar, mudar contexto, sair do app ou encontrar erro encerra todas as tracks. Resolução tardia de permissão depois do fechamento encerra imediatamente o stream recebido. Bytes tardios são zerados quando o consumidor já saiu.
5. O campo existente de imagem recebe o callback de captura e mantém prepare/PUT/finalize, retry e descarte do ativo pendente. Produz `FormAnswer.photo`; uma imagem confirmada desabilita nova captura até remoção explícita. Galeria continua com FilePicker.

## Prova prevista e parada

Testes focais do port/diálogo: sucesso, erro/retry, cancelar, fechamento antes de iniciar terminar, encerramento de sessão/contexto, bytes tardios e375/200. Testes do campo Foto: captura somente, limite1, segredo anônimo no payload de gateway, confirmação antes de inserir a resposta. Regressão reutiliza testes de upload/resposta/viewer já pertinentes, sem lotes duplicados.

O adapter web terá análise estática explícita. Prova física de câmera no navegador exige runtime/slot G0 e não será inferida dos doubles. Encerrar a fatia em local-green + wiring/evidência se o runtime não estiver disponível, continuar o próximo gate autorizado até o corte R08.
