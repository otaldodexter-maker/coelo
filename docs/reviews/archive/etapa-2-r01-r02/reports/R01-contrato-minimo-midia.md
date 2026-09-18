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

## Upload comum integrado — 2026-09-08T15:50:03-03:00
Recibo 2026-09-08T15:51:42-03:00: push atômico e ls-remote confirmaram origin/dev e branch C00 em **e9e615706ec1d24602a3753e2678ecc809e96dd8**, incluindo305f9824/2980151e e documentação. Publicação Git verificada; nenhum deploy/aplicação remota.


C02/r26 recebido; release dos quatro arquivos I007 aceito. Origem0a94f2da→C00305f9824; exports públicos/testes por barrel em2980151e. **89/89 Dart PASS** na C00, analyzer5arquivos limpo, formatter sem alterações. Log C:/Users/adrie/AppData/Local/Temp/coelo-c00-media-upload-1550.log. Contrato cliente disponível em package:coelo_api/coelo_api.dart; mediaUploadId permanece fora dos exports públicos.

MediaUploadGateway está ligado a target imutável e contexto autorizado do adapter. SessionMediaUploader coordena prepare→PUT→finalize, correlaciona IDs/alvo, rejeita ticket vencido/headers de sessão, cerca cada await com MediaSession e purga transferência em falha/finalização. Resposta ambígua chama reconcile uma vez, sem DELETE/PUT automático; READY exige receipt medido. Caller preserva requestId/finalizeRequestId por intenção e purga seus buffers; source.clear não é cancelamento da transferência já copiada. Transporte concreto deve implementar cancelamento, proibir redirects/cookies/interceptador Auth e comprovar esses limites.

C04/C05 podem consumir o mesmo núcleo nos adapters/consumidores próprios, sem gateways/assinadores concorrentes. Usar APIs de domínio existentes e manter versões, parents, tenant/contexto real e segredo anônimo onde aplicável no adapter. Não inventar UUID para entidade ainda não existente nem fabricar receipt a partir do arquivo local. Sem adapter/endpoint nominal manter indisponibilidade honesta. Preview/decoder/R2/catalogo tipado, retenção/cleanup e testes reais permanecem abertos.

Deltas: forms.upload recebe evidência do núcleo cliente; forms.resolve-file/download/expire-file/delete-file e consumidores C04/C05 mantêm suas dependências e aceites próprios, sem contar89como teste de cada ação. Nenhuma promoção FE/BE/E2E e nenhum percentual novo por biblioteca integrada. C02 continua candidato XLSX132casos sem novo replay comunicado;49PASS/abort permanece último resultado real do perfil fixo. Push desta integração pendente até recibo; nenhum deploy/aplicação remota.
