---
title: "Proposta futura de dados para Saúde e Segurança"
source: "specs/020-superadmin-health-safety.md; docs/data/data-model.md; docs/security/lgpd-security-media.md; packages/coelo_database/migrations; decisions/0010-private-media-r2.md; decisions/0015-contextual-people-authorizations-attendance.md"
status: "proposed"
generated_at: "2026-08-03"
---

# Proposta futura de dados para Saúde e Segurança

## Propósito e limites

Este documento registra uma direção para a fase produtiva. Não aprova nomes
físicos definitivos, migration, RLS, RPC, grant ou retenção. A UI da spec 020
continua local e demonstrativa.

As migrations atuais já oferecem `people`, `child_contexts`, atribuições
contextuais de profissionais, eventos/destinatários e `audit.audit_logs`, mas
não contêm medicamentos, doses, alergias/restrições ou Perfil de Cuidado.
`guardian_context_permissions` protege o acesso do responsável ao contexto da
instituição; ela não representa autorização familiar inversa para a instituição
ler saúde global.

## Entidades candidatas

### Núcleo global da criança

- `child_health_access_grants`: `id`, `child_person_id`, `child_context_id`,
  `institution_id`, `guardian_link_id`, escopos autorizados, `status`, início,
  expiração, revogação, ator e timestamps. Deve provar coerência entre criança,
  contexto e instituição.
- `child_medications`: identidade estável, `child_person_id`, criador
  responsável, status de ciclo, ativo/inativo e timestamps.
- `child_medication_versions`: versão imutável com nome livre, dose, unidade,
  via, início/fim, instruções, observações, metadado opcional de prescrição,
  indicador de dispensa e motivo/ator de correção.
- `child_medication_schedules`: versão, hora exata, contexto `home` ou
  `institution`, instituição opcional e ordem estável.
- `child_allergy_restrictions`: criança, nome, tipo, classificação, reação,
  gravidade, orientação, observações, status e timestamps; mudanças preservam
  histórico/auditoria.
- `care_profile_catalog`: chave estável, grupo, nome, ordem e status. A
  governança deste catálogo exige aprovação própria.
- `child_care_profile_items`: criança, chave de catálogo ou nome livre para
  Outro, orientações, sinais, adaptações, observações, documento futuro, status
  e timestamps.

### Operação privada por tenant

- `child_medication_reviews`: versão, instituição, status, motivo obrigatório
  na recusa, ator e timestamps. Aprovação de uma instituição não aprova outra.
- `institution_medication_policies`: instituição e escopo grupo/atividade,
  antecedência, tolerância, expiração do claim e escalonamento.
- `institution_medication_recipients`: política, perfil/capacidade e ordem de
  escalonamento, sem copiar autorização apenas para o cliente.
- `medication_dose_occurrences`: horário/versionamento, vencimento,
  instituição, estado, autor, horário real, resultado e motivo obrigatório
  quando aplicável. Registros passados são imutáveis.
- `medication_dose_claims`: ocorrência, membership/ator, assumido em, expira em,
  liberado em e estado. Somente um claim ativo pode existir por ocorrência.
- `health_acknowledgement_notifications`: objeto/versionamento, instituição,
  audiência configurada e timestamps, sem payload sensível em push.
- `health_acknowledgement_receipts`: notificação, membership/ator e ciência em;
  não compartilha semântica com claim de dose.

Auditoria deve reutilizar `audit.audit_logs` com referência minimizada,
before/after estritamente necessário, justificativa e contexto do ator, sem
replicar dados clínicos integrais.

## Constraints e integridade candidatas

- toda referência de criança aponta para `people` do tipo criança;
- grant combina o mesmo `child_person_id`, `child_context_id` e
  `institution_id` e nunca amplia acesso após revogação/expiração;
- horário possui XOR: casa sem instituição ou instituição preenchida;
- uma versão possui ao menos um horário e frequência é sempre derivada;
- revisão é única por versão e instituição e só aprova a versão vigente;
- edição relevante cria nova versão, invalida reviews e não altera ocorrências
  passadas;
- ocorrência de dose é única por horário e instante esperado;
- claim ativo é único e adquirido/liberado por operação atômica;
- recusa de review e resultados Não administrado/Recusado exigem motivo;
- inativação substitui delete físico em registros de cuidado.

## RLS, RPCs e concorrência

Tabelas expostas devem ser deny-by-default, com grants explícitos. Leitura
global exige sessão válida, `child_context` ativo e grant familiar de saúde
vigente. RLS não pode revelar existência de criança, vínculo ou operação fora
do contexto autorizado.

Reviews, políticas, destinatários, claims, ocorrências e recibos permanecem
tenant-owned. Uma instituição pode ver o dado global autorizado, mas não a
operação privada produzida por outro tenant.

Comandos sensíveis devem usar RPC/Edge Function server-side com `search_path`
fixo, autorização efetiva, idempotência e auditoria. Entrypoints candidatos:
submeter nova versão, revisar por instituição, adquirir/liberar claim, registrar
resultado, inativar registro, marcar ciência e corrigir excepcionalmente como
Owner. O claim deve usar lock/constraint transacional, nunca check-and-set no
cliente.

## Mídia, LGPD e retenção

Prescrições e documentos devem referenciar o futuro contrato privado de R2,
com metadados no Postgres e URL temporária emitida server-side. Não armazenar
bytes, URL pública ou segredo no Flutter. A ADR 0010 permanece proposta e sua
validação ao vivo está bloqueada.

`OQ-003` precisa definir base legal, controlador/operador, retenção, descarte,
direitos do titular e resposta a incidentes antes da implementação produtiva.
Push e logs não carregam conteúdo sensível.

## Testes obrigatórios da fase futura

- criança sem contexto, grant ausente/expirado/revogado e tentativa por ID;
- dois tenants ligados à mesma criança sem vazamento operacional;
- horários em instituições diferentes e dose em casa;
- aprovação por instituição e versão antiga rejeitada;
- edição invalidando reviews e preservando ocorrências passadas;
- dois claims concorrentes, liberação, expiração e resultado idempotente;
- motivos obrigatórios, inativação sem delete e auditoria minimizada;
- RLS, grants, ausência de `anon`, `search_path`, RPCs e testes transacionais
  cross-tenant/cross-unit/cross-group;
- mídia sem URL pública, expiração e negação de acesso fora do contexto.

## Gate para implementação

Antes de qualquer migration: resolver `OQ-003`, concluir/aprovar o contrato R2,
aprovar threat model e spec técnica, validar nomes contra o schema vigente e
obter revisão humana explícita de segurança, LGPD e isolamento multi-tenant.
