---
title: "Auditoria — projeção minimizada de sessão autenticada"
source: "20260827233000_superadmin_internal_auth_context.sql; 20260901190927_deploy_superadmin_internal_auth.sql; adapter e widgets de Auditoria"
status: "local-green; autorização do reader e E2E abertos"
generated_at: "2026-09-08"
---

# Contrato e RED

As projeções de lista/detalhe da fundação 039 retornam `actor.kind=auth_session`, `id=null`, `display_name=Sessão autenticada`, `role_code=null`. Não é um Usuário Interno identificado nem uma Pessoa. O adapter exigia papel não vazio e transformava os dois payloads válidos em `AuditUnavailableException`: dois REDs reproduzidos.

## Correção

`AuditActor.roleCode` pode ser nulo. O parser aceita essa ausência para `auth_session`, rejeitando ID ou papel não nulos nesse tipo. Os demais atores conservam papel obrigatório. O resumo, a timeline e o detalhe omitem a linha/segmento de papel ausente, inclusive na semântica, sem inventar `system`, `owner`, Pessoa ou literal `null`.

## Verificação

- 2 REDs lista/detalhe antes da correção; ambos PASS depois.
- 4 negativos de projeção incoerente: papel ausente em Pessoa/interno; papel ou ID indevido em sessão.
- 2 estados de widgets em 375 px, texto 200%, claro/escuro, com semântica e ausência de overflow.
- 2 novos goldens com Nunito Sans e Material Icons reais, gerados somente para esse novo estado e inspecionados visualmente. Nenhum master antigo atualizado.
- Regressão final: 50/50 testes de adapter, widgets, controller e diretório PASS, incluindo os novos goldens sem `--update-goldens`.
- Analyzer, validador de contratos visuais, diff check e review independente: PASS.
- Um erro de compilação da fixture intermediária (campo obrigatório omitido) foi corrigido; não foi contabilizado como RED de produto.

## Gate de backend encontrado

Os wrappers `audit_list_events_for_superadmin`/`audit_get_event_for_superadmin` ainda dependem de `audit_assert_permission` → `current_person_id` e `audit_authorization_scope` → `platform_memberships`. Suportar eventos internos não equivale a autorizar um leitor interno 039. A spec027 descreve Pessoa/vínculo; a transição exige recorte nominal, inventário da base/grants e negativas próprias. Não substituir helper, combinar realms ou criar Pessoa sintética.

Nenhum SQL/Docker foi executado pelo root. Exportação continua indisponível no MVP; métodos e testes legados de exportação não foram ativados nem alterados. Conhecimento: no-op, correção de compatibilidade com projeção já aprovada, sem regra nova. Nenhuma promoção a E2E.
