---
title: "R01 — contrato mínimo de consumo de mídia existente"
source: "ADR0032; packages/coelo_api/lib/src/media/media_read_contract.dart; media_reader.dart; media_session.dart; packages/coelo_database/supabase/functions/_shared/r2_s3.ts"
status: "existing-read-contract;upload-http-contract-pending"
generated_at: "2026-09-08T14:54:00-03:00"
---

# Consumo comum confirmado no código

Este registro publica o contrato já existente; não cria outra plataforma nem certifica um endpoint. Os três arquivos Dart abaixo são exportados por `packages/coelo_api/lib/coelo_api.dart`. C04/C05 podem usá-los em seus consumidores próprios, sem editar os contratos públicos ou o composition root reservado.

| Parte | Contrato existente | Limite |
|---|---|---|
| Leitura | `MediaReader.read(MediaReadRequest(assetId: ..., rendition: MediaReadRendition.original ou preview))` | Identificador e rendition não concedem acesso; adapter real precisa reautorizar ator/entidade/finalidade no servidor. |
| Resposta | `MediaReadResult`: assetId correlacionado, state available/processing/expired/unavailable; ticket somente quando available | Ticket contém URL HTTPS, headers e expiresAt. Não registrar/persistir nem reutilizar depois de expirar. |
| Sessão | `SessionMediaReader(delegate: ..., session: mediaSession)` | `MediaSession` tem construtor sem argumentos; instância pertence ao contexto já autorizado. O wrapper rejeita asset divergente, ticket vencido e resultado de sessão invalidada. |
| Limpeza | `MediaSession.registerPurge(callback)` retorna unregister; `invalidate()` invalida sincronamente e aguarda todos os callbacks | Cache/tickets/bytes/players locais devem ser limpos. Consumir retorno somente após a checagem de run; isso não revoga URL no servidor. |
| Transporte R2 | `_shared/r2_s3.ts`, get limitado e put, commit6fd676e2 | Apenas servidor; assinatura e credenciais jamais entram em Flutter. Não substitui catálogo, política ou gateway autorizado. |

Estados processing/expired/unavailable devem aparecer honestamente no consumidor. Sem retry/polling implícito; reemitir leitura somente por comportamento nominal autorizado e sessão válida. Testes locais devem cobrir actor/context swap, resultado atrasado, ID divergente, expiração e limpeza, preservando composição de cada família visual.

## Contratos ainda não publicados como prontos

- Não há aqui endpoint HTTP universal de upload, finalização, remoção ou leitura autenticada certificado. Adapters por domínio existentes devem ser inspecionados antes de criar outro.
- C02 mantém o núcleo de mídia. Deve propor a menor extensão/reutilização de upload no handoff com ator/escopo/finalidade/entidade, request id/versionamento, bytes/MIME real/checksum/dimensões, estados/finalização, leitura/revogação/cleanup e assinatura dos métodos. Não inventar limite diferente da ADR0032 nem duplicar catálogos.
- Catálogo R2 de imagem I003 tem44/44 pgTAP locais; XLSX I005 é outro ramo do mesmo catálogo e segue WIP. Isso não disponibiliza automaticamente upload de plantas/fotos de Locais ou publicadores do Principal.
- C04/C05 podem avançar nos estados e lifetime de seus consumidores com delegados controlados, declarando o adapter real pendente. Isso verifica parte do cliente; não fecha mídia completa, backend ou E2E.

Ownership: C00 conserva os contratos públicos e auth/root; C02 propõe núcleo/adapter comum sob reserva; C04/C05 escrevem consumidores próprios. Mudança nos três arquivos públicos exige reserva nominal. Nenhum pacote remoto novo é autorizado por este documento.
