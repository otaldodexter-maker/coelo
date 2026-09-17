---
title: "Decisões do Owner na Mesa R16 (17/09/2026)"
source: "Owner em 2026-09-17 (artefato QsXjfhhDGjrXAF1yCPaoEs, coleção `decisoes`, 91/91 decididos); R16-pendencias.md; inventario-etapa-2.json; decisions/0043-r15-closure-r16-opening-20260917.md"
status: "accepted"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
lifecycle: "current"
supersedes: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md e decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md (somente o enquadramento das ações fora do MVP: passam de `deferred-post-mvp` a `v1` e saem dos denominadores FE/BE da Etapa 2)"
audience: "team"
---

# ADR 0044 — Decisões do Owner na Mesa R16

Em 17/09/2026, após o fechamento da R15 (ADR 0043), o Owner respondeu num artefato
próprio aos 91 itens que ainda constavam como pendentes da Etapa 2, um a um, com um
destino: **Executar na R16**, **Etapa 3 (tela a tela)**, **V1 / pós-MVP**, **Sem
necessidade** ou **Reprovar / rever**. Este documento é a fonte canônica dessas
decisões. Ele **não** certifica implementação: estados por `action_id` só mudam por
delta com evidência.

## 1. Critério de encerramento da Etapa 2

O Owner decidiu que a Etapa 2 se mede pelo **E2E do MVP**; FE e BE passam a ser
tratados por code review contínuo e pela revisão tela a tela da Etapa 3 (o BE junto,
quando a tela expuser o problema), com revisão de backend em cadência quinzenal.

## 2. Ações fora do MVP → V1 (33)

Importação/exportação (exceto respostas de Formulários, ADR 0031), MFA ×3 (E9),
Catálogo de UI e `plans.assign` (ADR 0039) e `institutions.status/files/locations-map`
recebem escopo **`v1`** no inventário: continuam rastreadas, mas **saem dos
denominadores** de FE e BE da Etapa 2 (já estavam fora do E2E ativo). Efeito no corte:

| Métrica | Antes (232/219/186) | Depois (V1 fora) |
|---|---|---|
| FE verificado | 207/232 (89,2%) | **198/199 (99,5%)** |
| BE concluído | 185/219 (84,5%) | **185/186 (99,5%)** |
| E2E verificado | 184/186 (98,9%) | **184/186 (98,9%)** |

## 3. Owner items

- **Executar na R16 (7)**: owner.r12-04, owner.r12-05, owner.r12-06, owner.r12-08, owner.r12-18, owner.r12-33, owner.r12-49.
- **Etapa 3, tela a tela (7)**: owner.r12-10, owner.r12-19, owner.r12-23, owner.r12-29, owner.r12-30, owner.r12-46, owner.r12-53 — ficam `deferred` na fila (não voltam à execução da R16; entram na revisão visual da Etapa 3 com as specs 064/065/067).

## 4. Resíduos H

- **Executar na R16 (12)**: H18, H19, H20, H21, H22, H24, H25, H27, H28, H08, H13, H23.
- **Etapa 3 (10)**: H02, H03, H04, H07, H09, H10, H12, H14, H16, H26.

## 5. Contrato, dívida técnica e ambiente

- **R16**: oq048-membership, testes-vermelhos, recipients-bug, can-remove, momentos-ux, celular-mascara, orfaos-cardapio, form-diario, forms-v2-qa, espelho-cli, h02-aal2.
- **Etapa 3**: goldens, cors-r2, deploy-publico, activity-msg, smtp-reset, specs-064-069. Nota do Owner sobre goldens: "provavelmente basta componentizar um cabeçalho (widgtes) e usar para os demais. Talvez os goldens vermelhos sejam referencias antigas que devem ser excluídas e substituídas."
- **Sem necessidade**: `stream` (Stream genérico encerrado sem contrato).
- **Reprovar / rever**: `participants-vazio` — nota do Owner: "Se for para teste, tudo bem ter usuário sintético, se for na "vida" real, tudo bem criar uma ativadde sem participante. Asssim se for para teste executar na r16 e ser for vida real sem necessidade". Leitura da coordenação: uma atividade sem participantes é válida na vida real (sem correção de produto); para a prova de `r12-05` na R16, usar participantes sintéticos.

## 6. Tabela completa (91 decisões)

| Grupo | Item | Título | Decisão | Observação do Owner |
|---|---|---|---|---|
| E2E do MVP | `agora.publish` | Agora › publicar para Famílias (leitura pelo responsável) | **Executar na R16** |  |
| E2E do MVP | `forms.location-answer` | Formulários › responder pergunta de Local | **Executar na R16** |  |
| Owner items | `owner.r12-04` | Owner item owner.r12-04 — daily-routine.list, attendance.dashboard | **Executar na R16** |  |
| Owner items | `owner.r12-05` | Owner item owner.r12-05 — attendance.create | **Executar na R16** |  |
| Owner items | `owner.r12-06` | Owner item owner.r12-06 — attendance.create, daily-routine.apply | **Executar na R16** |  |
| Owner items | `owner.r12-08` | Owner item owner.r12-08 — attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | **Executar na R16** |  |
| Owner items | `owner.r12-10` | Owner item owner.r12-10 — child-safety.list | **Etapa 3 (tela a tela)** |  |
| Owner items | `owner.r12-18` | Owner item owner.r12-18 — child-safety.create | **Executar na R16** |  |
| Owner items | `owner.r12-19` | Owner item owner.r12-19 — sem action_id | **Etapa 3 (tela a tela)** |  |
| Owner items | `owner.r12-23` | Owner item owner.r12-23 — access-profiles.create | **Etapa 3 (tela a tela)** |  |
| Owner items | `owner.r12-29` | Owner item owner.r12-29 — health-care.create, health-care.edit, health-care.detail | **Etapa 3 (tela a tela)** |  |
| Owner items | `owner.r12-30` | Owner item owner.r12-30 — health-care.create, health-care.edit, health-care.detail | **Etapa 3 (tela a tela)** |  |
| Owner items | `owner.r12-33` | Owner item owner.r12-33 — medication.create, medication.edit, medication.detail | **Executar na R16** |  |
| Owner items | `owner.r12-46` | Owner item owner.r12-46 — account.profile | **Etapa 3 (tela a tela)** |  |
| Owner items | `owner.r12-49` | Owner item owner.r12-49 — assessments.entry, assessments.gradebook, assessments.detail, assessments.close, assessments.reopen | **Executar na R16** |  |
| Owner items | `owner.r12-53` | Owner item owner.r12-53 — sem action_id | **Etapa 3 (tela a tela)** |  |
| Ações fora do MVP | `groups.import` | Turmas / Importar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `groups.export` | Turmas / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.upload` | Importações / Upload — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.preview` | Importações / Preview — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.confirm` | Importações / Confirmar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.status` | Importações / Status — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.download` | Importações / Baixar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.list` | Importações / Hub — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `imports.create` | Importações / Nova — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `institutions.import` | Instituições / Importar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `institutions.export` | Instituições / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `units.import` | Unidades / Importar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `units.export` | Unidades / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `units.people-export` | Unidade / Pessoas / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `profile-files.import` | Arquivos de perfil / Importar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `profile-files.preview` | Arquivos de perfil / Preview — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `profile-files.confirm` | Arquivos de perfil / Confirmar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `profile-files.status` | Arquivos de perfil / Status — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `profile-files.export` | Arquivos de perfil / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `profile-files.download` | Arquivos de perfil / Baixar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `attendance.export` | Assiduidade / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `audit.export` | Auditoria / Exportar — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `institutions.files` | Instituições / Arquivos — importação/exportação (ADR 0031 adia; só Formulários exporta) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `auth.mfa` | Auth / MFA — MFA (E9: fora do MVP) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `account.mfa` | Conta / MFA — MFA (E9: fora do MVP) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `internal-users.mfa` | Usuários internos / MFA — MFA (E9: fora do MVP) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `catalog.list` | Catálogo / Lista — Catálogo de UI e Planos (V1/V2, ADR 0039) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `catalog.validate` | Catálogo / Validar — Catálogo de UI e Planos (V1/V2, ADR 0039) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `catalog.sync` | Catálogo / Sincronizar — Catálogo de UI e Planos (V1/V2, ADR 0039) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `catalog.publish` | Catálogo / Publicar — Catálogo de UI e Planos (V1/V2, ADR 0039) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `plans.assign` | Planos / Atribuir — Catálogo de UI e Planos (V1/V2, ADR 0039) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `institutions.status` | Instituições / Ativar-desativar — Instituições (fora do MVP por decisão) | **V1 / pós-MVP** |  |
| Ações fora do MVP | `institutions.locations-map` | Instituição / Mapa e locais — Instituições (fora do MVP por decisão) | **V1 / pós-MVP** |  |
| Resíduos H | `H02` | H02 — Atualização oficial a partir do Sobre | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H03` | H03 — Composição das quatro abas de Perfil | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H04` | H04 — Compositor produtivo de Circular e blocos intercalados | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H07` | H07 — Hash de edição/revogação sem `conversation_id` | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H09` | H09 — Disparo agendado de expiração Agora | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H10` | H10 — Múltiplas regras de audiência em Formulários | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H12` | H12 — Controles de mínimo/máximo de seleção | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H14` | H14 — Sino sem `action_id`/subaceite | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H16` | H16 — Leitura people-based de cuidado | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H18` | H18 — Unicidade global concorrente de `@` | **Executar na R16** |  |
| Resíduos H | `H19` | H19 — Responsável vazio em Medicação | **Executar na R16** |  |
| Resíduos H | `H20` | H20 — Imagem da dose sem gateway | **Executar na R16** |  |
| Resíduos H | `H21` | H21 — Limite de texto/rodapé de Circular | **Executar na R16** |  |
| Resíduos H | `H22` | H22 — Descritor privado de Circular | **Executar na R16** |  |
| Resíduos H | `H24` | H24 — Rótulos do Sobre | **Executar na R16** |  |
| Resíduos H | `H25` | H25 — Alvo de redimensionamento de tabela | **Executar na R16** |  |
| Resíduos H | `H26` | H26 — Opcional, escala legada e opções vazias | **Etapa 3 (tela a tela)** |  |
| Resíduos H | `H27` | H27 — Sinal de atualização de Momentos | **Executar na R16** |  |
| Resíduos H | `H28` | H28 — Filtros, avatar e buffers de Pessoas | **Executar na R16** |  |
| Resíduos H | `H08` | H08 — Avisos: duplicar aviso (spec 069) | **Executar na R16** |  |
| Resíduos H | `H13` | H13 — Avisos: CTA de item relacionado (spec 069) | **Executar na R16** |  |
| Resíduos H | `H23` | H23 — Avisos: visual do CTA (spec 069) | **Executar na R16** |  |
| ADR 0038 | `adr0038-local-interno` | ADR 0038 — Local interno em Formulários (IDs fixados na publicação; revisão conserva valor) | **Etapa 3 (tela a tela)** |  |
| Contrato, dívida técnica e ambiente | `oq048-membership` | Onboarding de responsável sem membership institucional (OQ-048) | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `goldens` | 139 goldens vermelhos em 33 suítes (censo 17/09) | **Etapa 3 (tela a tela)** | provavelmente basta componentizar um cabeçalho (widgtes) e usar para os demais. Talvez os goldens vermelhos sejam referencias antigas que devem ser excluídas e substituídas. |
| Contrato, dívida técnica e ambiente | `testes-vermelhos` | 21 testes funcionais pré-existentes vermelhos | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `cors-r2` | CORS dos buckets R2 (coelo-media-prod só 3014/3016; coelo-documents-prod nenhuma origem) | **Etapa 3 (tela a tela)** |  |
| Contrato, dívida técnica e ambiente | `deploy-publico` | Deploy público do frontend (superadmin.coelo.me não existe) | **Etapa 3 (tela a tela)** |  |
| Contrato, dívida técnica e ambiente | `recipients-bug` | Destinatários de cuidado contam membership guardian como equipe | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `participants-vazio` | Chamada em contexto Atividade nasce com participants [] (3 crianças ativas, modo all) | **Reprovar / rever** | Se for para teste, tudo bem ter usuário sintético, se for na "vida" real, tudo bem criar uma ativadde sem participante. Asssim se for para teste executar na r16 e ser for vida real sem necessidade |
| Contrato, dívida técnica e ambiente | `activity-msg` | ACTIVITY_INVALID_REFERENCE 422 mapeado para "Confira a conexão" | **Etapa 3 (tela a tela)** |  |
| Contrato, dívida técnica e ambiente | `can-remove` | Agora: can_remove só para o autor, RPC aceita administradores | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `momentos-ux` | Momentos: publicador não bloqueia 2º toque; feed mostra "Curtido por Maria e outras 531 pessoas" de demonstração | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `celular-mascara` | Conta: Celular sem máscara/normalização (r12-46) | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `orfaos-cardapio` | Cardápios: 2 ativos de imagem órfãos em cardápio publicado (imutável) | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `form-diario` | Formulário QA 4555ba07 ficou com agendamento Diário (30 ocorrências) | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `forms-v2-qa` | superadmin_forms_*_v2 negando a identidade QA; P0002 → 500 em ids inexistentes; account-media 422 em vez de 403 | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `espelho-cli` | Espelho CLI supabase/migrations com cópias não rastreadas; migration repair exige a cópia | **Executar na R16** |  |
| Contrato, dívida técnica e ambiente | `stream` | Stream genérico | **Sem necessidade** |  |
| Contrato, dívida técnica e ambiente | `smtp-reset` | SMTP próprio e prova detalhada do reset de senha (E8/E10) | **Etapa 3 (tela a tela)** |  |
| Contrato, dívida técnica e ambiente | `specs-064-069` | Specs 064–069 escritas sem implementação (perfil transversal, Perfis de cuidado §5, ciclo de vida OQ-033, Locais OQ-034, perfis oficiais OQ-032, Avisos) | **Etapa 3 (tela a tela)** |  |
| Contrato, dívida técnica e ambiente | `h02-aal2` | H02: atualização oficial a partir do Sobre exige AAL2 (MFA fora do MVP) | **Executar na R16** |  |

## Consequências

- Inventário: delta `r15-coordenacao/deltas-mesa-r16-v1-20260917.json` (escopo `v1`, 33 ações); `validate-trackers.cjs` e `apply-tracker-delta.cjs` reconhecem o escopo `v1` fora dos denominadores FE/BE.
- `R16-pendencias.md` reordenado por estas decisões; Owner items e H de Etapa 3 marcados como transferidos; `stream` encerrado.
- `ETAPA-2-estado-atual.md`, `current-state.md`, skills e `docs/knowledge` passam a publicar os percentuais do MVP.
