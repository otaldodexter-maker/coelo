---
title: "Chat — consumidor de imagem autorizado"
source: "Prompt 4; MediaReader/MediaSession; recorte visual aprovado pelo Coordenador em 2026-09-07"
status: "approved-local-implementation; remote-gate-open"
generated_at: "2026-09-07"
---

# Chat Image Consumer Implementation Plan

> Execução: writer único E2E3 nesta worktree; subagentes somente revisão independente.

**Goal:** abrir imagem canônica por ação explícita e autorização temporária,
sem reter conteúdo após expiração ou troca de contexto.

**Architecture:** tile existente recebe MediaReader/MediaSession opcionais;
dialog privado consome preview pelo contrato puro e registra purge. Página e
router apenas encaminham dependências aprovadas, sem reader simulado normal.

**Tech Stack:** Flutter/Dart, coelo_api e CoeloAdminDialogShell existentes.

## Restrições globais

- Só Superadmin/pacotes consumidos; Chat único. Sem upload novo nesta fatia.
- Nunca ler downloadUrl legado, bucket/key, logar ticket, persistir imagem,
  fazer prefetch ou polling. Retry explícito reautoriza.
- Baseline principal: Popup de Bug; tile conserva anatomia existente.
- Estados: loading/available/processing/expired/unavailable; negação de sessão
  limpa ticket, remove imagem e impede novas leituras.
- Evict se refere ao cache Flutter do provider usado; servidor/gateway ainda
  deve controlar cache HTTP/browser. Não prometer revogação remota por evict.

## 1. Diálogo e ciclo de vida

Arquivos: criar `apps/superadmin/lib/features/chat/presentation/widgets/superadmin_chat_image_dialog.dart`
e `apps/superadmin/test/features/chat/presentation/superadmin_chat_image_dialog_test.dart`.

Interface: `SuperadminChatImageDialog(assetId: String, reader: MediaReader,
session: MediaSession)`. Somente dependências reais; testes injetam reader
determinístico em widget isolado, nunca no composition root normal.

- [ ] RED: reader recebe apenas assetId/preview; pending não duplica chamada;
  available usa ticket validado; processing/expired/unavailable não exibem URL.
- [ ] RED: session invalidada antes/durante/depois da leitura, resultado errado,
  expiração e dispose não mantêm imagem; retry é explícito.
- [ ] Implementar guarda de geração, SessionMediaReader, timer por expiresAt,
  unregister purge e eviction do NetworkImage exato; não capturar URL em logs.
- [ ] Usar shell neutro existente e retorno de foco da rota. Corpo com conteúdo
  limitado pelos tokens; estados textuais seguros; sem overlay Material paralelo.
- [ ] Executar teste focal e review independente antes de integrar consumidor.

## 2. Tile, página e composição

Arquivos: tile/page Chat existentes; `superadmin_app.dart` e
`superadmin_router.dart` apenas campos/encaminhamento na reserva M03.

Interfaces aditivas: `MediaReader? mediaReader`, `MediaSession? mediaSession`.
Tile só abre imagem com assetId canônico e sessão ativa. Se faltar transporte,
ação permanece honestamente indisponível; anexo legado não vira ativo por ID.

- [ ] RED: nenhuma leitura antes da ação; URI legada ignorada; botão/foco e
  dialog único; troca de contexto fecha preview antigo; falta de reader não
  seleciona fixture; página encaminha a dependência canônica.
- [ ] Implementar ação Abrir imagem terciária na tile existente, ownership da
  rota e foco de retorno; remover somente o próprio diálogo ao trocar/dispor.
- [ ] Acrescentar novos goldens candidatos nominais, sem sobrescrever histórico:
  claro/escuro, 375/768/1024/1440, texto 200%, loading/processing/expired/
  unavailable/available, foco/hover e reduced motion.
- [ ] Rodar Flutter test focal e Chat não-golden, analyzer e validador visual;
  inspecionar imagens e receber review independente.
- [ ] Registrar evidências/commit; gate E2E segue aberto até transporte, Auth,
  catálogo e R2 reais, incluindo reload/negado/revogado/cleanup.

Sem mutation remota, nova dependência, alteração Scope/main ou nova política
de retenção. Campo Scope/main futuro será serializado pelo Coordenador.
