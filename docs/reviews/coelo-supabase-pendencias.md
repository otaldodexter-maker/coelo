---
title: "Pendências Coelo — Supabase por tela e ação"
source: "docs/reviews/2026-08-25-coelo-supabase-screen-integration.md; decisions/0020-backend-authorization-application-security.md; specs aprovadas por dominio; auditoria consolidada em 2026-08-26; Git dev cd1ea97c e inventario remoto read-only em 2026-09-01"
status: "living"
generated_at: "2026-08-26"
updated_at: "2026-09-01"
action_count: 207
family_count: 37
---

# Pendências Coelo — Supabase

## 0. Etapa 2 — resumo recuperável do backend e banco

> **Regras do MVP aprovadas em 2026-09-01:** (1) importação/exportação real não
> será construída no Supabase durante o MVP, exceto a exportação individual de
> cada resposta de Formulário; os demais jobs, arquivos, RPCs, Edge Functions e
> persistência ficam `deferred-post-mvp` e não bloqueiam a Etapa 2;
> (2) toda mídia privada do MVP usa Supabase Storage. Cloudflare R2 não existe
> no ambiente atual e fica fora do MVP. Ver ADRs 0030 e 0031.

Os percentuais publicados abaixo permanecem como baseline pré-reclassificação
para não inventar precisão. A família Importações e os subfluxos de arquivo
precisam de crosswalk nominal antes de recalcular o denominador do MVP; nenhum
item diferido será contado como `done`. No encerramento formal do MVP, o
coordenador deve perguntar ao Owner se deseja implementar import/export real e
se deseja avaliar evolução de Supabase Storage para R2.

**Inventário remoto read-only de 2026-09-01:** o projeto de produção ainda
possui a Edge Function ativa `import-export-jobs` v2 e migrations históricas de
import/export para Instituições, Unidades, Formulários e hub genérico, inclusive
`20260901190449`, `20260901190719` e `20260901193727`. Esses artefatos são
legado anterior à ADR 0031: ficam congelados, não recebem expansão, não entram
no wiring do MVP e não contam como `done`. Nenhum rollback/drop foi autorizado;
eventual desativação exige pacote forward-only específico e coordenado.

### ETA Supabase supersedente — execução líquida

Esta tabela substitui todas as estimativas Supabase anteriores para planejamento
da Etapa 2. Schema compartilhado, fixtures, replay, RLS, negativos, Advisors e
cutover são contabilizados uma vez por pacote/domínio, nunca repetidos por
`action_id`. O tempo exclui espera por decisão, Flutter e E2E. Import/export
real e R2 valem 0 h no MVP.

| Família backend | Pendência Supabase restante | ETA líquida |
| --- | --- | ---: |
| Auth | Sessão, lifecycle e prova remota restante | 3–5 h |
| Shell/contexto | Bootstrap, troca de contexto e revogação | 1–2 h |
| Instituições | Gateways, RLS, negativos e remoto | 2–3 h |
| Unidades | Hierarquia, gateways, RLS e remoto | 3–5 h |
| Turmas | CRUD, membros, RLS e remoto | 3–5 h |
| Pessoas | Identidade, vínculos, gateways e negativos | 4–7 h |
| Perfis de acesso | Realm interno, anti-escalation e auditoria | 4–7 h |
| Modelos de acesso | Realm, capabilities, versão e auditoria | 4–7 h |
| Convites | Emissão, expiração, revogação e outbox | 2–4 h |
| Atividades | Gateways nominais, escopo e replay | 2–3 h |
| Avaliações | Schema, commands, concorrência e auditoria | 2–4 h |
| Alunos | Vínculos, transferência, revogação e negativos | 4–7 h |
| Assiduidade | Commands, idempotência e fechamento; export fora | 2–3 h |
| Rotina diária | Modelos, aplicação, publicação e versão | 3–5 h |
| Agenda | Schema, RLS, RPCs e notificações após spec | 6–10 h |
| Chat | Mensagens, recibos, revogação, mídia e Realtime | 5–8 h |
| Avisos | Lifecycle, audiência, agendamento e recibos | 4–6 h |
| Formulários — autoria | Versão, distribuição, commands e publicação | 6–10 h |
| Formulários — respostas | Respostas, anonimato, métricas e exportação individual | 7–12 h |
| Formulários — mídia | Supabase Storage, expiração e exclusão | 5–8 h |
| Acontece | Metadados, audiência, publicação e Storage | 4–6 h |
| Agora | Publicação, audiência, expiração e Storage | 3–5 h |
| Momentos | Publicação, audiência, remoção e Storage | 4–6 h |
| Menu Coelo (Principal) | Contratos backend das prévias no Superadmin | 3–5 h |
| Segurança infantil | Evidências, suspensão, RLS e auditoria | 5–8 h |
| Saúde/cuidado | Dados sensíveis, mídia, histórico e auditoria | 7–12 h |
| Medicação | Contrato sensível após decisão | 7–12 h |
| Importações | Fluxo real diferido para pós-MVP | 0 h |
| Arquivos de perfis import/export | Fluxo real diferido para pós-MVP | 0 h |
| Auditoria | Imutabilidade, retenção e cross-tenant; export fora | 2–3 h |
| Suporte | Schema, conversa, status e permissões | 6–10 h |
| Conta/configurações | Senha, sessões e dados após Auth | 3–5 h |
| Catálogo | Tooling local, se mantido | 1–2 h |
| Planos/assinaturas | Contrato, autorização e lifecycle | 5–8 h |
| Cardápios/modelos | Publicação, imagem e audiência | 6–10 h |
| Usuários internos | Identidade, lifecycle, privilégios e auditoria | 5–8 h |
| Erros backend | Envelope e mapeamento seguro | 1–2 h |

As 37 famílias somam **134–223 h líquidas**. Cinco pacotes transversais —
ledger/replay; ACL + `SECURITY DEFINER` + RLS; Auth/realm; harness + lint +
Advisors; Storage/Edge + cleanup + secret scan — acrescentam **18–30 h** uma
única vez. Portanto, o **total sequencial Supabase estrito é 152–253 h
líquidas**. No modelo considerado para os possíveis prompts — cinco worktrees
verticais ponta a ponta, com subagentes locais por domínio e o coordenador como
único owner de ledger, ordem de migrations, deploy e cutover — a parcela
Supabase entra no caminho crítico por **38–64 h de calendário**. Cinco
worktrees não significam cinco escritores simultâneos na produção: migrations
são sequenciais, cada pacote deve passar replay/pgTAP/RLS isoladamente e a
promoção remota permanece serial. Sem essa disciplina, usar como teto
operacional a faixa anterior de **70–115 h**. Os 207 IDs permanecem baseline
pré-crosswalk e não devem ser somados individualmente para produzir ETA.

### Checkpoint final de consolidação — 2026-09-01

Todas as migrations, adapters, contratos e testes recebidos foram preservados
no histórico único. As linhas antigas desta seção que dizem “integrar branch”
devem ser lidas como concluídas no aspecto Git; elas não significam que a
família Supabase atingiu `done`, recebeu deploy ou passou todos os negativos.

| Família / ações backend | Entregue e consolidado na Etapa 2 | O que ficou aberto no Supabase | Estado de camada |
| --- | --- | --- | --- |
| Auth — login/logout/recovery/reset | Fundação hospedada, lifecycle, identidades internas, configuração remota e migration que adia MFA interno até o gate formal do MVP. | Smoke humano hospedado, SMTP/recovery real e fechamento de todos os gates da família. | Subpacote remoto comprovado; família ainda não `done`. |
| Pessoas, Segurança, Usuários internos, Perfis, Modelos e Saúde | Gateways, contratos e pgTAP candidatos preservados; detalhe de Pessoa composto. | P0 de realm/lookup/autorização, 4 falhas pgTAP em permissões, Auth/Convites internos, RLS e decisões de dados sensíveis. | Parcial/local; não `done`. |
| Instituições, Unidades, Turmas, Atividades e Avaliações | Migrations/gateways de Estruturas e pacote de Avaliações incorporados. | Replay por pacote, OQ-032, grants/RLS/negativos, remoto e aprovação por família. | Candidato local; sem promoção familiar. |
| Planos, Cardápios, Formulários, Importações e Agenda | Migrations e contratos de leitura/operação incorporados no manifesto único. | Reconciliar ledger, commands que não sejam import/export, RLS, auditoria e negativos antes de qualquer deploy. Jobs/arquivos de import/export estão `deferred-post-mvp`. | Parcial/local; não `done`. |
| Chat, Avisos, Convites e Circulares | Migrations nominais ordenadas no manifesto e adapters locais preservados. | Replay/pgTAP por domínio, tenant A/B, revogação, outbox/Realtime/mídia, persistência/reload e remoto. | Parcial/local; não `done`. |
| Acontece, Agora, Momentos e Perfil | Migration de fundação do recorte preservada. | Contratos de audiência, metadata, Supabase Storage privado, retenção, remoção, RLS e auditoria. R2 está fora do MVP. | Aberto/bloqueado pelos demais contratos. |
| Macro — ledger, RLS, grants e auditoria | Manifesto consolidado e harness de replay aceita extensão revisada depois da fundação. | Replay integral compatível, Advisors, deny-by-default, IDOR/BOLA, cross-tenant e fechamento das decisões abertas. | P0 antes de deploy amplo. |

**Contagem oficial após a consolidação:** 3/37 famílias `local-green` =
**8,11%** de avanço técnico por família; 0/37 famílias `done` = **0,00%** de
conclusão estrita Supabase. Na leitura granular existem 39/202 ações com
evidência local = **19,31%**, mas esse indicador não substitui o gate canônico
por família e não autoriza promoção ou deploy.

Esta seção é o ponto de retomada obrigatório da **Etapa 2** para a skill
`coelo-supabase`. “Feito” aqui distingue análise estática, ambiente local e
remoto. Fixture Flutter, migration escrita ou RLS apenas habilitada nunca contam
como backend concluído.

**Estado geral Supabase em 2026-09-01:** 3/37 famílias `local-green` (8,11%),
0/37 `done`. Restam 34/37 famílias (91,89%) sem gate local completo e todas as
37 famílias ainda carecem de conclusão Supabase integral.

**Geral conhecido:** 0/228 unidades exclusivamente backend `done` (0,00%): 207
`action_id` e 21 gates gerais Supabase; o gate geral de `/dev` Flutter foi
excluído. **Etapa 2:** 0/37 famílias `done` (0,00%). O subpacote remoto de
fundação Auth é `remote-green`, mas não fecha ainda uma ação ou família Auth.

| Percentual Supabase da Etapa 2 | Concluído | Restante | Interpretação |
| --- | ---: | ---: | --- |
| Progresso técnico local por família | 8,11% (3/37) | 91,89% (34/37) | Prova local suficiente somente em três famílias. |
| Conclusão do lado Supabase `done` | 0,00% (0/37) | 100,00% (37/37) | Encerra a família backend inteira sem exigir Flutter; nenhuma família atingiu todos os gates Supabase. |

> **Leitura correta:** o avanço Supabase já comprovado como pacote local completo
> é **8,11%**. Há outras famílias em implementação ou revisão estática que ainda
> não entram nesse numerador. O `done` em 0,00% decorre de gates do próprio
> backend ainda abertos, não da ausência de Flutter ou E2E.

### Telas, subtelas e ações Supabase

| Tela / ação backend | Feito na Etapa 2 | Pendente / primeiro próximo passo | Estado |
| --- | --- | --- | --- |
| Auth — login/logout/recovery/reset | Lifecycle descartável e pgTAP 29/29; Catalog recovery fail-closed corrigido/revisado em `5e8d2655`. | Integrar; 17 migrations intermediárias, clone/squash forward-only, DNS/hosting/SMTP/identity e E2E. | `local-green`/`not-deployed` |
| Chat — listar/abrir/enviar/editar/anexar/receipts/revogar | `68d1217d` implementou gateway interno v2 local (migration, adapter, capabilities, MFA, tenant/IDOR, revogação e auditoria); Flutter relacionado 54/54. O harness canônico de replay foi corrigido em `1fca68b8` com 3/3 Pester, e o Docker voltou a responder. | Rodar o pgTAP local do gateway, validar replay limpo, wiring auth scope, anexos/Realtime, tenant A/B e persistência/reload; remoto permanece ausente e sem mutação. | `local-green` técnico / `blocked-supabase` para integração |
| Convites — listar/detalhe/criar/reenviar/revogar | Produção permanece corretamente `UnavailableInviteRepository`; auditoria 10/10. Migration histórica foi rejeitada por realm people-based/backfill especulativo/issuer person. | Decidir OQ-039: capabilities Owner+AAL2, issuer interno separado sem backfill, evolução aditiva, legado read-only e Superadmin RPC-only; depois token/outbox/RLS/audit/E2E. | `blocked-decision` |
| Avisos — lista/criar/editar/agendar/publicar/arquivar | Adapter produtivo composto; `c5085746` fail-closed; worker 2/2. SQL `20260827222500` auditado estaticamente: ACL revogada, FORCE RLS e RPCs SECURITY DEFINER com capability/AAL/grants específicos. | Replay pgTAP travou no Docker sem resíduos; OQ-038, OQ-041, Supabase Storage privado, tenant A/B, persistência/reload e remoto. R2 não é bloqueio do MVP. | `blocked-supabase` |
| Instituições — list/options/detail/edit | Seis gateways internos v2 protegidos por pgTAP declarado de 20 asserts; Flutter composto em `d864f19a`. Remoto read-only confirma ausência de grants CRUD diretos de tabela. | Docker/replay/pgTAP real, hardening de EXECUTE privado remoto, Advisors, tenant A/B, reload e E2E. | `static-reviewed`; não local-green |
| Instituições — create/status | Ausência explícita preservada; nenhum RPC legacy usado. | Contrato/gateway interno, capability, RLS/audit, replay e E2E. | `fail-closed` |
| Unidades — list/options/create/edit/status | Drift `institution_type_id` local × `unit_type_id` remoto inventariado. | OQ-032/spec044, gateway interno nominal, replay/remoto/E2E. | `blocked-decision`/fail-closed |
| Turmas — list/options/create/edit/status | RPCs legacy recusadas para ator interno. | OQ-031/OQ-043/spec045, gateway interno nominal, replay/remoto/E2E. | `blocked-decision`/fail-closed |
| Atividades/Modelos por Unidade | Migration candidata e 31 asserts apenas escritos. | Replay/pgTAP real, gateway nominal, remoto e E2E. | `static-review` |
| Avaliações — configurar/lançar/diário/fechar/reabrir | Schema/RPC/RLS em execução local. | Doze RPCs/tabelas ausentes, replay, concorrência, audit, remoto e E2E. | `fail-closed` |
| Planos | Auditoria read-only. | Schema/CRUD/RPC/RLS completos, composition root e E2E. | `blocked-supabase` |
| Cardápios/Modelos | Schema/RPCs locais históricos inventariados. | Reconciliar drift, SECURITY DEFINER, composição produtiva, cleanup e E2E. | `blocked-supabase` |
| Formulários — monitor/respostas/detalhe/arquivos | Projeções/RPCs de leitura compostas no Flutter em `236f12cd`: monitor, listagem, detalhe e jobs de arquivo. | Sessão/remoto autorizado, RLS/negativos, reload e E2E. | backend-read composto; não `remote-green` |
| Formulários — criar/editar/publicar/testar/responder | Backend/DTO de comando incompletos. | Contexto `institution_id` autorizado, versão/request ID, occurrence/participation, segredo anônimo, RLS/audit e E2E. | `fail-closed` |
| Importações | Nenhum backend adicional é exigido no MVP; o legado observado não autoriza expansão. | Nenhuma implementação agora. No encerramento formal do MVP, perguntar ao Owner se deseja implementar arquivos, parser, jobs, RPC/Edge, auditoria e integração. | `deferred-post-mvp`; não bloqueia Supabase/MVP |
| Agenda — eventos/solicitações/aprovações | Nenhum backend produtivo comprovado. | Schema, RLS, RPCs, perguntas/respostas, notificações, mapa/privacy e E2E. | `blocked-supabase` |
| Pessoas — detalhe/vínculos/reload | `superadmin_person_detail_v2` foi composto no Flutter em `d4a87af8`; contrato/envelope e falhas foram testados no cliente. | Replay pgTAP fresco, daemon Docker, negativos de sessão/permissão/MFA, remoto, persistência/reload real e E2E. | composição local; backend não promovido |
| Pessoas — lista/criar/editar | Contratos legados inventariados. | Spec/gateway interno nominal de escrita, mutações/vínculos, RLS/audit, negativos, reload e E2E. | `fail-closed` |
| Segurança da criança — lifecycle | Repository/RPC histórico inventariado. | AAL2/capability, ownership, suspend/revoke, evidência privada, audit e tenant A/B. | `audited` |
| Usuários internos — listar/convidar/editar/suspender/MFA | Rotas Flutter falham fechadas. | Identidade interna, Auth/Convites, RPCs, sessão/realm, MFA e auditoria. | `blocked-decision` |
| Perfis e permissões | RPCs antigos usam realm people-based. | Gateway interno nominal, atribuição/deleção, anti-escalation, OQ-044, replay e E2E. | P0/bloqueado |
| Modelos de perfil | Dez wrappers/18 capabilities escritos sobre quatro tabelas herdadas; FORCE RLS/ACL revisados estaticamente. | P0 realm; autorização antes de lookup; anti-escalation cross-app; motivo obrigatório; replay/pgTAP/Advisors. | `static-reviewed` |
| Perfis de cuidado | Fixtures Flutter somente. | OQ-003/OQ-040, schema/RLS/CRUD, dados sensíveis, audit e E2E. | `fail-closed` |
| Medicação | Fixtures Flutter somente. | Base legal, prescrição/dose/evidência/retenção, RLS/CRUD/audit e E2E. | `blocked-decision` |
| Acontece/Agora/Momentos/Perfil/publicadores | Nenhuma mutação backend. | Contratos, audiência, metadata Postgres, mídia em Supabase Storage privado, retenção/remoção, audit e prova de camada. R2 está fora do MVP. | `blocked-decision` pelos demais contratos |
| Circulares | RPCs/RLS remotos históricos observados read-only; Flutter `/dev` agora cobre diretório e CRUD/publicação local em `5e714c16`. | Adapter produtivo, ator/capability, tenant A/B, persistência/reload e E2E; nenhuma promoção remota. | `audited` |

### Macroajustes Supabase da Etapa 2

| Macroajuste | Feito | Pendente |
| --- | --- | --- |
| RLS e grants | FORCE RLS/ACL de alguns pacotes revisados; inventário apontou 34 avisos em `app_private`. | Classificar exposição/grants, negar por padrão, testar IDOR/BOLA e cross-tenant; sem correção cega. |
| Auth/realm interno | Lifecycle Auth local e contrato de sessão existem. | Eliminar gateways people-based para Superadmin; revalidar `session_id`, realm, membership e ator interno. |
| Migrations/ledger | Remoto read-only termina em `20260821200000`; drift catalogado. | Replay integral compatível; não aplicar cauda em lote; OQ-041 antes de remoto. |
| Auditoria/idempotência | Alguns wrappers têm versão, soft-delete, receipt e advisory lock. | Motivo obrigatório, ator interno, append/negativos, replay divergente e cobertura de todas as ações. |
| Mídia/Supabase Storage | ADR 0030 define Supabase Storage privado para toda mídia do MVP. | Autorização server-side, bucket privado, URLs assinadas curtas, MIME/tamanho, retenção, remoção e cleanup. R2 não é pendência do MVP. |
| Advisors/performance | Alertas inventariados. | Rodar Advisors pós-DDL autorizado, revisar SECURITY DEFINER e índices sem correção global cega. |

### Estruturas — Instituições v2 e hardening remoto

- Commits `bd611d02`/`d864f19a`: pgTAP declarado de 20 asserts para seis
  gateways internos e composição Flutter list/options/detail/edit.
- Docker não responde: plan/count e diff-check verdes são apenas evidência
  estática. Sem promoção local-green/remota.
- Remoto read-only não concede CRUD de tabelas `app_private` a anon/
  authenticated/PUBLIC, mas funções privadas antigas ainda têm EXECUTE para
  authenticated e algumas PUBLIC; hardening existe somente na cadeia local não
  aplicada. OQ-041 bloqueia deploy.
- Create/status Instituição, CRUD Unidade e CRUD Turma continuam bloqueados pelas
  decisões/specs registradas e não serão mascarados por RPC legacy.

### Primeiro próximo passo Supabase da Etapa 2

1. Não aplicar a cauda de migrations no remoto.
2. Classificar o ambiente da OQ-041 e reconciliar ledger/schema em replay local.
3. Revisar e testar as migrations de Modelos de perfil e Estruturas.
4. Escolher uma ação vertical cujo Flutter e contrato backend estejam aprovados;
   só então provar permitido, negado, revogado, tenant A/B, persistência, reload
   e auditoria.

**Bloqueio P0 descoberto no review:** as RPCs candidatas de Modelos autorizam
por `app_private.current_person_id()` e `has_platform_permission()`, dependentes
de `people`, `person_auth_links` e `platform_memberships`. Isso conflita com ADR
0019/spec 039: Usuário Interno Superadmin exige contexto interno nominal,
revalidação de `auth.sessions/session_id`, realm e ator/auditoria internos. No
estado atual, a conta interna legítima pode ser negada e um principal legado
people-based pode ser aceito; a leitura também não aplica corretamente a regra
Owner=AAL2. Os commits DB não são integráveis como produção antes da correção,
auditoria interna e negativos cross-app/cross-realm.

Achados adicionais do mesmo review:

- detalhe/update/delete/duplicate consultam ou bloqueiam o modelo antes do gate,
  criando oracle de existência/UUID;
- create/update/import validam posse/delegação de capability somente para o
  domínio `platform`, deixando Admin/Principal sem anti-escalation suficiente;
- create/update/duplicate aceitam motivo ausente e geram texto padrão, apesar
  da exigência canônica de motivo em toda mutação;
- os arquivos pgTAP somente declaram planos 35 e 10; nenhum assert foi executado
  e faltam negativos AAL1, sessão/vínculo revogado, cross-app/tenant, replay,
  auditoria append e cobertura das 18 ações;
- o full replay permanece RED e as migrations dependem de
  `20260811215451_access_profile_management_v2.sql`; FoundationOnly termina
  antes dessas migrations. As quatro tabelas são herdadas dessa migration
  anterior, não criadas por `e7520192`.

**Tempo usado:** não calculável com precisão. **ETA geral Supabase revisado:**
152–253 h líquidas sequenciais, com parcela de **38–64 h no caminho crítico de
calendário** no modelo de cinco worktrees verticais, subagentes locais e cutover
serial pelo coordenador. Sem isolamento/ownership estritos, usar 70–115 h como
teto operacional. Famílias bloqueadas por decisão pausam sem acrescentar horas
de espera.

## 1. Finalidade e leitura obrigatória

Este é o rastreador operacional vivo do backend Supabase do Coelo: Auth,
Postgres, RLS, grants, RPCs, Edge Functions, Storage, Realtime, migrations,
segurança de dados e contratos backend exigidos por cada tela e ação.

Ele não substitui os rastreadores Flutter ou integrado. Um item pode ficar
`done` aqui e continuar pendente na interface ou no fluxo ponta a ponta.

### Passagem em andamento — Operações — 2026-09-01

- O projeto remoto `coelo` (`evvbomzejfijozbtgvpt`) foi identificado como
  `ACTIVE_HEALTHY`; a passagem consultou somente documentação oficial e
  inventário read-only.
- Nenhuma migration, policy, grant, RPC, Edge Function ou dado remoto foi
  alterado nesta fatia. Logo, Planos, Cardápios, Formulários, Importações e
  Agenda continuam abertos no backend e não recebem `local-green`,
  `remote-green` ou `done`.
- A próxima fatia Supabase deve inventariar os objetos existentes por ação,
  reconciliar o ledger e então implementar RLS deny-by-default, grants mínimos,
  idempotência, auditoria e negativos cross-tenant antes de habilitar CRUD real.
- O inventário remoto read-only confirmou tabelas com RLS para Planos,
  Cardápios, Formulários e Importações. Nenhuma tabela nominal de Agenda,
  Eventos, Solicitações ou Aprovações apareceu em `public`; a lacuna segue em
  auditoria e bloqueia CRUD produtivo da Agenda até migration/policies próprias.

Ele não substitui Product Vision, PRDs, ADRs ou specs aprovadas. Em conflito, a
fonte canônica de maior prioridade prevalece e a divergência deve ser registrada
em `docs/open-questions.md`.

Antes de iniciar trabalho relacionado, o agente deve:

1. ler este arquivo por completo;
2. ler `AGENTS.md` e a skill `coelo-supabase` vigente;
3. acionar o plugin oficial `@Supabase` e usar as skills `supabase`,
   `supabase-postgres-best-practices` e `rtk`;
4. fazer uma leitura leve de `coelo-flutter-supabase-review`, aplicando o fluxo
   integrado apenas quando Flutter estiver no escopo;
5. consultar a spec, ADR e perguntas abertas da superfície;
6. verificar o código, as migrations e as definições realmente instaladas;
7. atualizar este arquivo depois de cada fatia concluída ou bloqueada.

O acionamento obrigatório do plugin não autoriza mutação remota. Antes da
confirmação do pacote, usar documentação e inspeção somente leitura. Se o plugin
estiver indisponível, registrar o bloqueio e não declarar `remote-green` nem
`done`. Usar RTK nos comandos de terminal compatíveis; cmdlets nativos sem
wrapper podem ser executados diretamente com a exceção registrada.

### Como ler termos, estados e números

Na primeira ocorrência em um relatório ao usuário, usar o termo técnico junto da
explicação cotidiana:

- Auth: entrada, identidade e sessão da pessoa;
- RLS (`Row Level Security`): segurança por linha do banco;
- RPC: função do banco chamada pelo aplicativo;
- Edge Function: função executada no servidor;
- migration: alteração versionada da estrutura ou regra do banco;
- ledger: lista de migrations registradas como aplicadas;
- Advisor: verificador automático de segurança ou desempenho;
- IDOR/BOLA: tentativa de acessar o registro de outra pessoa ou tenant trocando
  um identificador;
- `fail-closed`: acesso negado e recurso indisponível por segurança;
- `local-green`: passou somente no ambiente local;
- `remote-green`: passou no backend remoto autorizado;
- `done`: todos os gates Supabase do item foram comprovados e registrados.

Toda contagem ou percentual precisa de frase interpretativa. Exemplo: em vez de
somente `54/54` ou `100%`, escrever “54 testes executados; todos os 54 passaram”.
Não presumir que a pessoa usuária conhece a sigla ou entende o impacto do número.

### Protocolo obrigatório de abertura da atividade

Toda atividade de code review, revisão, correção ou auditoria deve começar antes
de qualquer edição com um contrato de execução visível ao usuário contendo:

1. lista das pendências gerais, telas, subtelas e ações já conhecidas;
2. objetivo que o usuário quer alcançar nesta atividade;
3. recorte incluído e explicitamente fora de escopo;
4. ordem de execução e critério de parada;
5. evidências exigidas para cada item e ETA inicial por fatia e total.

O recorte deve ser classificado em uma destas modalidades, ou combinação
explicitamente registrada delas:

- `todas as pendências`;
- `todas as telas`;
- `macrotema`, como RLS, Auth, migrations ou segurança;
- `macrotema + X telas`;
- `X telas na ordem obrigatória`;
- `X ações específicas`, como criar e editar instituição, publicar aviso ou
  enviar mensagem no chat.

Se o usuário já informou o recorte, o agente deve confirmá-lo no contrato e
começar; não deve perguntar novamente. Se não informou, deve apresentar as
pendências e solicitar a escolha do recorte antes de alterar código. O relatório
final deve separar o que foi concluído dentro do contrato de tudo que continua
pendente fora dele. Nunca interpretar “concluído nesta atividade” como “produto
inteiro concluído”.

### Orçamento de tempo e níveis de correção

Antes de escolher telas ou ações, perguntar quanto tempo total o usuário quer
investir, em minutos, horas ou dias. Se já informou, não perguntar novamente:
inventariar em modo somente leitura e recomendar o pacote que cabe sem retirar
gates de segurança.

| Nível | O que corrige | O que pode continuar pendente | Estimativa inicial | Quando aconselhar |
| --- | --- | --- | ---: | --- |
| Básica | Uma falha pequena, reprodução do problema e teste local mínimo. | Remoto, regressão, demais ações da tela e autorização ampla. | 30–90 min | Apenas para item trivial e não sensível. |
| Intermediária | Tudo da Básica, contrato backend, autorização e testes negativos aplicáveis. | Outras ações, testes amplos entre instituições, remoto e regressão completa. | 2–6 h | Mínimo aconselhado para correção relevante. |
| Avançada | Tudo da Intermediária, ações relacionadas, testes entre instituições e remoto autorizado. | Fechamento global, limpeza e itens fora do recorte. | 1–2 dias | Mínimo para Auth, RLS, grants, migrations, segurança e dados sensíveis. |
| Completa | Tudo da Avançada, todas as pendências do recorte, regressão, Advisors, auditoria e limpeza. | Somente bloqueios externos e itens fora do recorte. | 2–5 dias | Obrigatória para declarar o item Supabase concluído. |

As faixas são estimativas, não promessas. Recalcular depois do inventário
conforme quantidade de ações, dependências, risco, drift local/remoto e decisões
bloqueadas. Se o tempo não comportar o nível seguro, reduzir o recorte; nunca
retirar teste, autorização, RLS ou evidência para fazer a estimativa caber.

#### Nível mínimo por tema geral

| Tema | Mínimo aconselhado | Faixa inicial | Motivo |
| --- | --- | --- | --- |
| Inventário somente leitura | `Básica` | 30–90 min por domínio | Não altera o sistema; apenas produz baseline. |
| Segredos, configuração e Advisors | `Intermediária` | 2–6 h por tema | Exige classificação e evidência, mas pode ser isolado. |
| RPC/Edge não sensível | `Intermediária` | 2–6 h por ação | Precisa contrato, autorização e negativas. |
| Migrations e reconciliação de ledger | `Avançada` | 1–3 dias | Drift pode alterar schema e histórico aplicado. |
| RLS, grants e `SECURITY DEFINER` | `Avançada` | 1–3 dias por domínio | Falha pode permitir acesso indevido entre tenants. |
| Auth, MFA e revogação | `Avançada` | 2–5 dias | Afeta identidade, sessão e comandos privilegiados. |
| Storage privado e URLs assinadas | `Avançada` | 1–3 dias por domínio | Envolve ownership, expiração e dados privados. |
| Saúde, segurança infantil e medicação | `Completa`; Perfis de cuidado liberado para trabalho local | 3–7 dias por domínio | Perfis de cuidado pode avançar com dados sintéticos e gates técnicos; produção com dados reais e os demais domínios conservam seus gates próprios. |
| Declaração de backend concluído | `Completa` | Recalcular pelo recorte | Exige regressão, remoto, auditoria e cleanup. |

## 2. Regra de conclusão

Uma rota, tabela, policy, RPC ou Edge Function existente não está concluída só
por compilar ou falhar fechada. `Fail-closed` significa que o acesso foi negado
com segurança, mas a funcionalidade continua indisponível.

Uma ação recebe `done` **neste rastreador Supabase** somente quando a cadeia de
backend foi comprovada:

`requisição não confiável -> Auth/contexto -> RPC/Edge/Data API -> autorização/RLS -> Postgres ou Storage remoto -> auditoria -> resposta estável -> regressão remota`

Para cada ação, são obrigatórias evidências de:

- contrato e regra canônica identificados;
- input, IDs, claims e filtros do cliente tratados como não confiáveis;
- pessoa ativa, tenant, membership, capability, vínculo, ownership e hierarquia
  revalidados no backend;
- MFA/AAL2 quando exigido pela regra do domínio;
- RLS deny-by-default e policies/grants mínimos, ou RPC privilegiada privada com
  wrapper estritamente autorizado;
- `SECURITY DEFINER` justificado, `search_path = ''`, `PUBLIC` e grants
  desnecessários revogados;
- idempotência, concorrência/versão, rate limit e auditoria quando aplicáveis;
- tentativa cross-tenant e IDOR/BOLA negada com erro estável;
- testes positivos, negativos, revogação dinâmica e ator suspenso;
- migration canônica presente e reconciliada com ledger e definição instalada;
- Advisors executados e achados novos resolvidos ou classificados;
- pgTAP e Deno/Edge proporcionais ao risco aprovados;
- dado sintético, cleanup e ausência de segredo ou PII em evidências.

Não aceitar como prova final:

- mock que não preserva SQLSTATE ou comportamento remoto;
- migration fora do ledger ou definição apenas local quando o alvo é remoto;
- RLS apenas habilitada, `TO authenticated` sem ownership ou botão oculto;
- URL assinada criada antes da reautorização;
- sucesso do cliente sem persistência comprovada no backend;
- `local-green`, `remote-green` parcial ou `fail-closed` descrito como `done`;
- tela ponta a ponta declarada pronta apenas porque o backend ficou verde.
## 3. Estados permitidos

| Estado | Significado |
| --- | --- |
| `not-audited` | A cadeia Supabase ainda não foi inventariada. |
| `audited` | Evidências e lacunas foram identificadas, sem conclusão funcional. |
| `in-progress` | Existe ownership explícito e implementação/teste em andamento. |
| `fail-closed` | Operação segura e indisponível; não equivale a concluída. |
| `blocked-decision` | Depende de decisão canônica, jurídica, ambiental ou autorização externa. |
| `local-green` | Local aprovado; remoto e implantação ainda não comprovados. |
| `remote-green` | Backend remoto aprovado no recorte, aguardando regressão/registro final. |
| `done` | Todos os gates Supabase da seção 2 foram comprovados e registrados. |
| `regressed` | Uma evidência anteriormente verde deixou de passar. |

## 4. Snapshot inicial conhecido — 2026-08-26

Este snapshot deve ser atualizado com data e evidência; não deve ser tratado
como verdade permanente.

- Projeto remoto conectado `coelo`: 103 migrations registradas no ledger; a
  última versão observada foi `20260821200000`.
- Ledger local observado: 148 migrations registradas, com versão máxima
  `20260825180500`; esse número não deve ser confundido com filesystem ou remoto.
- Repositório: 156 migrations canônicas e 156 migrations no espelho, contadas
  novamente no filesystem em 2026-08-26; o último arquivo observado foi
  `20260825193131_final_review_profile_about_lint_hardening`. Isso representa 53
  arquivos a mais no repositório do que registros observados no remoto; a
  diferença exige reconciliação e não prova, sozinha, quais estão ausentes.
- Security Advisor remoto: 207 achados no total — 50 informativos de RLS sem
  policy, 156 alertas de `SECURITY DEFINER` executável por `authenticated` e 1
  configuração de proteção contra senhas vazadas desabilitada. A soma é
  50 + 156 + 1 = 207; cada grupo ainda precisa ser classificado/corrigido.
- Tabelas `public` observadas estavam com RLS habilitada; isso não prova policy,
  grant ou autorização corretos.
- A auditoria anterior trabalhou majoritariamente em modo somente leitura e
  instalou definições no banco local fora do ledger durante testes. O handoff da
  Final Higienização classifica esse banco local como contaminado para fins de
  reprodutibilidade; não usar seu estado como prova de reset limpo.
- Access Profile Files, Auth/MFA, retenção, Edge/Storage e diversos E2E
  permaneceram abertos.
- O consolidado dos handoffs registrou zero fluxo ponta a ponta (`verified-e2e`)
  comprovado; teste local ou handler endurecido sem deploy não altera esse total.
- A revisão anterior inventariou 175 rotas Flutter: 79 produtivas e 96 marcadas
  `/dev`; 66 formavam pares equivalentes entre rota normal e `/dev`. Entre as 96
  rotas `/dev`, 42 podiam alcançar Supabase naquele snapshot.

### 4.1. Autoridade e camadas de evidência

| Camada | Evidência datada | Interpretação conservadora | Gate de retomada |
| --- | --- | --- | --- |
| Repositório | 156 migrations canônicas e 156 espelhadas foram contadas no filesystem em 2026-08-26; em um baseline anterior eram 147 + 147 com hashes iguais. | A igualdade de contagem atual não prova igualdade de nomes/hashes; o baseline antigo não cobre os nove pares posteriores. | Comparar nomes e SHA-256 de todos os 156 pares e registrar HEAD. |
| Ledger local | 148 migrations registradas, com máximo `20260825180500`; definições `202608251931xx` foram observadas instaladas durante testes. | O banco está contaminado para reprodutibilidade; definição instalada fora do ledger não é migration aplicada nem prova de reset limpo. | Comparar fonte, ledger e catálogo em stack descartável autorizada. |
| Supabase local | Postgres estava saudável e o container `vector` reiniciava; o stack era compartilhado e reset foi evitado. | Estado histórico, não garantia do estado vivo nem autorização para reutilizar fixtures. | Inventariar processos, portas, containers, dados sintéticos e owners antes de qualquer mutação. |
| Remoto `coelo` | Somente leitura; ledger observado com 103 versões até `20260821200000`; nenhuma migration, repair, deploy ou escrita foi executada nesta revisão. | Ambiente não classificado formalmente e sem autorização de escrita; nenhuma ação pode ser `remote-green` por inferência. | Classificar ambiente e obter autorização explícita por operação. |
| Advisors remotos | 207 achados de segurança e 505 de desempenho observados em 2026-08-26. | Baseline não triado: 50 RLS sem policy, 156 `SECURITY DEFINER` executáveis por `authenticated`, 1 proteção de senha vazada desabilitada; 128 FKs sem índice e 377 índices não usados. | Reexecutar, deduplicar e classificar por objeto, risco e owner. |
| Rotas | Baseline de 175 `GoRoute`, 1 `ShellRoute`, 79 rotas normais, 96 `/dev`, 66 pares; 42 caminhos `/dev` podiam alcançar Supabase. | Inventário histórico; composição mudou durante revisões concorrentes. | Reextrair por arquivo/linha e executar tripwires de zero chamada. |
| Evolução após baseline | O handoff Senior inspecionou 19 commits posteriores a `9e3c` e não identificou alteração de backend neles. | Isso limita o delta daquele recorte, mas não confirma o HEAD vivo nem substitui reconciliação de ledger/remoto. | Registrar HEAD atual e repetir diff dirigido a `packages/coelo_database`, Edge e configuração antes de retomar. |

### 4.2. Evidência histórica resolvida ou parcialmente verde

Estes registros preservam trabalho útil, mas não fecham a dívida atual:

- o baseline de 147 migrations canônicas e 147 espelhadas não tinha divergência
  de hash; a contagem posterior de 156 e o ledger remoto de 103 reabriram a
  reconciliação;
- nove migrations forward-only de lint foram produzidas nas versões
  `20260825193102`, `20260825193105`, `20260825193109`, `20260825193112`,
  `20260825193116`, `20260825193120`, `20260825193123`, `20260825193128` e
  `20260825193131`; fonte, espelho e definições locais foram inspecionados, mas
  a ausência no ledger local impede classificá-las como aplicadas;
- a revalidação S1 focada executou 19 arquivos pgTAP e aprovou 402 testes; o
  `supabase db lint` local terminou com zero erro naquele estado. O banco estava
  contaminado, não houve push/deploy e nenhum gate remoto foi executado, portanto
  o resultado permanece evidência local e não `remote-green` ou `done`;
- no par `20260825193109_final_review_access_profiles_lint_hardening.sql`, o
  SHA-256 canônico/espelho observado foi
  `062A4643256A63F491730CABB2C13C837A1E27AA5B025044C2C60BA18494640D`;
- o gateway local de importação/exportação de Unidades passou testes focados de
  upload binário, `job_id`, MIME e limite de 5 MiB; deploy e E2E remoto ficaram
  bloqueados;
- o pacote local de `circular-media` passou 15 testes focados e verificações de
  configuração, sem deploy; isso não libera superfícies consumidoras;
- correções locais de Forms F3/F4 e download protegido foram revalidadas em
  código/testes, mas F5, Storage real, deploy e E2E permaneceram abertos;
- nenhuma escrita, deploy, repair ou migration foi feita no remoto durante a
  revisão.

### 4.3. Resíduos conhecidos que precisam permanecer visíveis

- definições locais instaladas fora do ledger e possível fixture/sessão de
  testes compartilhados;
- arquivos untracked e mudanças concorrentes em Flutter, SQL, Edge e
  documentação; este rastreador não concede ownership sobre eles;
- Access Profile Files com bloqueadores de assinatura, revogação, expiração e
  exposição de localização interna de Storage;
- Forms F5 ausente e dez targets de aplicação/rotas sem closure produtivo;
- adapters stale ou reprovados de Units Directory, Student Tracking,
  Routine, Groups e Invites; produção deve continuar `fail-closed`;
- reset de senha, MFA completo, downgrade de AAL e membership revogada sem E2E;
- exportação de Assiduidade sem worker/materializador/status/download completo;
- secret scan, cleanup, advisors e matriz cross-tenant ainda não reexecutados
  sobre o estado integrado atual.

## 5. Ordem obrigatória de execução

O trabalho deve seguir esta ordem. Não iniciar uma tela posterior enquanto
existir um bloqueador P0 não classificado na etapa atual. Trabalho paralelo só é
permitido em arquivos e dependências comprovadamente independentes.

### Fase 0 — congelamento e inventário

1. Registrar HEAD, status, operações Git, processos e ambientes disponíveis.
2. Classificar o projeto remoto como desenvolvimento, staging ou produção.
3. Inventariar alterações concorrentes e reservar ownership por path.
4. Capturar baseline de migrations, schemas, policies, grants, funções, Edge,
   buckets e Advisors sem mutação.
5. Atualizar o snapshot deste documento.

### Fase 1 — fundação Supabase geral

1. Reconciliar migrations canônicas, espelhos, ledger local e ledger remoto.
2. Corrigir lint/compilação e provar instalação limpa por reset local.
3. Classificar RLS, grants, views, `SECURITY DEFINER`, `search_path` e Advisors.
4. Corrigir segredos/configuração, `verify_jwt`, CORS, limites e rate limits.
5. Definir e provar contratos comuns de idempotência, auditoria, erros e
   concorrência.
6. Provar isolamento absoluto entre `/dev` e repositories/serviços Supabase.

### Fase 2 — identidade e autorização transversal

1. Auth: login, sessão, refresh, logout, recuperação e reset.
2. MFA do Owner: enrollment, challenge, AAL2 e downgrade/revogação.
3. Pessoa global, membership ativa, contexto e troca de tenant.
4. Capabilities, negações, hierarquia e revogação dinâmica.
5. Matriz cross-tenant A/B reutilizável para todas as telas.

### Fase 3 — cadastros estruturais

1. Instituições.
2. Unidades.
3. Grupos/turmas.
4. Pessoas.
5. Perfis e modelos de acesso.
6. Convites.

### Fase 4 — operação escolar

1. Atividades.
2. Avaliações.
3. Alunos.
4. Assiduidade.
5. Rotina diária.
6. Agenda, quando existir spec produtiva aprovada.

### Fase 5 — comunicação e conteúdo

1. Conversas/chat.
2. Avisos e publicação.
3. Formulários, respostas, monitoramento, arquivos e mídia.
4. Acontece.
5. Agora.
6. Momentos.
7. Para Você.

### Fase 6 — cuidado e dados sensíveis

1. Segurança infantil.
2. Perfis de saúde/cuidado.
3. Planos de medicação somente após aprovação dos gates jurídicos vigentes.

### Fase 7 — operações de plataforma

1. Importações e exportações genéricas.
2. Arquivos de Perfis de Acesso/Access17.
3. Auditoria.
4. Suporte, apenas quando houver backend produtivo aprovado.
5. Perfil e configurações.
6. Planos, cardápios e usuários internos quando ganharem rota/spec produtiva.

### Fase 8 — fechamento

1. Reexecutar Advisors, pgTAP e testes Deno/Edge.
2. Executar matriz completa de ações e cross-tenant no ambiente autorizado.
3. Provar read-after-write, revogação, expiração, cleanup e ausência de órfãos.
4. Reconciliar migrations e definições instaladas pela última vez.
5. Executar secrets scan e diff-check dos artefatos Supabase.
6. Atualizar todas as linhas deste documento; nenhuma pode permanecer
   `in-progress` sem owner, próximo passo e ETA.

## 6. Pendências gerais

| ID | Prioridade | Estado | Pendência | Evidência de saída |
| --- | --- | --- | --- | --- |
| SUP-GEN-001 | P0 | `audited` | Classificar formalmente os ambientes e a autoridade para migrations, deploy e testes remotos. | Ambiente nomeado, owner e operações permitidas documentados. |
| SUP-GEN-002 | P0 | `audited` | Reconciliar 156 migrations do repositório com o ledger remoto observado de 103. | `migration list`, diff de schema e reset limpo sem drift. |
| SUP-GEN-003 | P0 | `audited` | Triar 156 warnings remotos de `SECURITY DEFINER` executáveis por `authenticated`. | Cada função: remover, tornar invoker ou justificar e testar autorização interna. |
| SUP-GEN-004 | P0 | `audited` | Classificar as 50 tabelas com RLS sem policy e provar deny-by-default intencional ou criar policy mínima. | Matriz tabela/operação/grant/policy aprovada. |
| SUP-GEN-005 | P0 | `audited` | Ativar e testar proteção contra senhas vazadas e política de senha. | Configuração Auth e teste de comportamento. |
| SUP-GEN-006 | P0 | `audited` | Corrigir MFA do Owner e bloquear comandos após downgrade de AAL ou membership revogada. | Auth + SQL/RPC com revogação dinâmica no backend. |
| SUP-GEN-007 | P0 | `audited` | Eliminar acesso de rotas `/dev` a Supabase produtivo. | Sentinelas provam zero chamadas produtivas nas 96 rotas `/dev`. |
| SUP-GEN-008 | P0 | `audited` | Padronizar RPCs privilegiadas, ACLs, `search_path`, idempotência, rate limit e auditoria. | Teste estrutural e comportamental por função. |
| SUP-GEN-009 | P0 | `audited` | Fechar lifecycle comum de arquivos: upload, checksum, preview, confirmação, status, download, expiração, retenção e cleanup. | pgTAP + Deno + arquivo real sintético + cleanup. |
| SUP-GEN-010 | P0 | `audited` | Impedir exposição de bucket/path e remint de URL após revogação/expiração. | DTO sanitizado e zero assinatura em casos negativos. |
| SUP-GEN-011 | P1 | `audited` | Reexecutar matriz cross-tenant, IDOR/BOLA e grants com SQLSTATE real em todos os domínios. | Ator A/B, sem capability, suspenso, revogado e IDs adulterados. |
| SUP-GEN-012 | P1 | `audited` | Corrigir harness pgTAP e impedir mocks que escondam falhas de runtime. | Suíte global não aborta e apresenta plano completo. |
| SUP-GEN-013 | P1 | `audited` | Definir retenção, jobs agendados, DLQ, retry e observabilidade de Edge/Storage. | Worker idempotente, métricas, logs minimizados e teste de falha. |
| SUP-GEN-014 | P1 | `audited` | Provar ausência de segredo em Flutter, web, assets, logs, URLs e Git. | Secrets scan no diff e bundles. |
| SUP-GEN-015 | P0 | `audited` | Reexecutar `supabase db lint` global depois de instalar migrations somente pelo ledger. | Zero erro real; warnings classificados separadamente. |
| SUP-GEN-016 | P0 | `audited` | Remover ou reconciliar definições locais `202608251931xx` instaladas fora do ledger sem resetar stack compartilhado indevidamente. | Fonte, hash, ledger e catálogo convergem em ambiente descartável autorizado. |
| SUP-GEN-017 | P0 | `blocked-decision` | Fechar reset de senha, callback, sessão de recovery, redirects/SMTP e política por papel. | Fluxo real válido/inválido, uso único, expiração e ausência de enumeração. |
| SUP-GEN-018 | P0 | `fail-closed` | Fechar Access Profile Files sem usar o hub genérico de Units nem expor `storage_path`. | Gateway worker-only aprovado; status assina apenas export autorizado, não expirado e ainda autorizado. |
| SUP-GEN-019 | P0 | `fail-closed` | Fechar Forms F5 e os contratos de resposta, autosave, mídia e download antes de recolocar rotas na composição. | Closure reprodutível, pgTAP/Deno/Dart, Storage privado e E2E. |
| SUP-GEN-020 | P1 | `audited` | Inventariar e limpar apenas fixtures, sessões, jobs e objetos do ledger sintético da execução. | Ledger de IDs/paths, cleanup seletivo e consulta final sem órfãos. |
| SUP-GEN-021 | P1 | `audited` | Revalidar `verify_jwt`, CORS, métodos, limites, headers e mensagens públicas de todas as Edge Functions expostas. | Teste de configuração e handler por função, sem segredo ou detalhe interno. |
| SUP-GEN-022 | P1 | `audited` | Provar persistência e reload/read-after-write em cada ação mutável no ambiente autorizado. | Tela/cliente, banco e nova sessão convergem com auditoria. |

## 7. Matriz Supabase por telas e ações

Cada linha deve ser expandida em subtarefas por ação. O estado registrado é o
snapshot inicial deste rastreador, não uma conclusão definitiva.

| Ordem | Tela/subtelas | Contratos Supabase que precisam de prova | Estado | Pendência Supabase principal |
| ---: | --- | --- | --- | --- |
| 1 | Auth: login, esqueci senha, reset | entrar, persistir/renovar sessão, sair, recuperar, redefinir, MFA | `audited` | MFA/downgrade, revogação de sessão e membership revogada não estão provados no backend remoto. |
| 2 | Home/shell/contexto | carregar, trocar contexto, bloquear rota, logout | `audited` | Provar que nenhuma resposta/dado chega antes da autorização e que troca de tenant limpa estado/cache. |
| 3 | Instituições: lista, criar, editar | listar, filtrar, criar, editar, status, plano, branding, representantes, reload | `local-green` | Revalidar definições instaladas, grants, policies e CRUD remoto cross-tenant. |
| 4 | Unidades: lista, criar, editar | CRUD, identidade/mídia, status, tipo, import/export, reload | `audited` | Edge/Storage, autorização e testes remotos ainda precisam fechamento. |
| 5 | Grupos/turmas: lista, criar, editar | CRUD, vínculos, participantes, import/export | `fail-closed` | Produção/repository e lifecycle de arquivos precisam ser provados no remoto. |
| 6 | Pessoas: lista, criar, editar | diretório, identidade global, contatos, endereços, vínculos, reload | `fail-closed` | RPCs, policies e vínculos de identidade ainda não foram provados no backend remoto. |
| 7 | Perfis de acesso: lista, criar, detalhe, editar | CRUD, capabilities, assignments, escopo, duplicar, excluir/reatribuir | `fail-closed` | Acesso básico/estendido, delegação e testes remotos continuam incompletos. |
| 8 | Modelos de acesso: lista, criar, detalhe, editar, duplicar | CRUD, catálogo, validação de escopo, versão | `fail-closed` | Closure estendido e arquivos permanecem parciais/untracked. |
| 9 | Convites: lista, criar, detalhe | criar, aceitar, revogar, reenviar, expirar, reload | `fail-closed` | Produção isolada com segurança, mas envio/aceite real não foi comprovado. |
| 10 | Atividades: lista, criar/publicar, detalhe, editar | CRUD, rascunho, publicar, templates, locais, assignments | `local-green` | Revalidar contratos instalados, backend remoto e cross-tenant. |
| 11 | Avaliações: lançamento, gradebook, fechamento, detalhe | criar/editar configuração, lançar, fechar, reabrir, ler | `audited` | Migrations e integração ainda não possuem gate remoto completo. |
| 12 | Alunos: lista, gerenciar | listar, vincular, transferir, atualizar, revogar | `fail-closed` | Leitura, comandos, mudanças de contexto e RPCs precisam revalidação remota. |
| 13 | Assiduidade: dashboard, nova chamada, chamada | listar, criar chamada, marcar, corrigir, concluir, exportar, reload | `local-green` | Operações Supabase completas, concorrência e export worker ainda não foram provados. |
| 14 | Rotina diária: lista, criar, editar | modelos, aplicações, lançamentos, publicar, versionar | `fail-closed` | Isolamento foi melhorado, mas produção completa continua sem prova remota. |
| 15 | Agenda: timeline, eventos, criar, detalhe, editar, solicitações, permissões | CRUD, recorrência, aprovar/rejeitar, permissões | `blocked-decision` | Hoje é superfície `/dev`; requer spec produtiva antes de Supabase. |
| 16 | Conversas/chat | listar, abrir, enviar, editar, recibos, anexar, revogar acesso | `audited` | Contratos possuem testes locais, mas remoto, revogação dinâmica e cross-tenant não foram provados. |
| 17 | Avisos: lista, criar/publicar, editar | CRUD, audiência, agendar/publicar, mídia, recibos | `audited` | Contrato backend produtivo, publicação e testes remotos estão pendentes. |
| 18 | Formulários: lista, criar, overview, editar/publicar, testar | CRUD, versionar, publicar, distribuir, agendar | `fail-closed` | F5 e contratos de lifecycle/remoto não foram integrados de forma reprodutível. |
| 19 | Formulários: monitor, responder, respostas, detalhe | responder, autosave, anônimo, editar resposta, métricas, exportar | `fail-closed` | Triggers, capabilities, tenant e fluxo completo ainda apresentaram REDs. |
| 20 | Formulários: arquivos e mídia | upload, resolver, baixar, expirar, excluir | `fail-closed` | Rotas foram removidas da composição até backend/Storage aprovados. |
| 21 | Acontece | listar feed, criar/publicar, audiência, mídia, remover | `blocked-decision` | Contrato backend produtivo entre Supabase Storage privado e metadados Postgres precisa aprovação e implementação; R2 está fora do MVP. |
| 22 | Agora | listar, criar/publicar, audiência, mídia, expiração | `blocked-decision` | Contrato produtivo de publicação, audiência, Supabase Storage privado e metadados Postgres não foi aprovado/provado; R2 está fora do MVP. |
| 23 | Momentos | listar, visualizar, criar/publicar, mídia, audiência, remover | `blocked-decision` | Contrato backend de publicação, mídia, audiência e remoção continua protótipo. |
| 24 | Para Você/perfil Principal | ler, filtrar contexto, editar dados permitidos | `blocked-decision` | Superfície de preview sem contrato produtivo completo. |
| 25 | Segurança infantil: lista, criança, criar/editar autorização | CRUD, capabilities, suspensão, evidências, notificar | `audited` | Backend/Storage sensível e ownership precisam gate completo. |
| 26 | Saúde/cuidado: perfis, criar, detalhe, editar | CRUD, ownership, mídia, histórico, auditoria | `fail-closed` | Gates canônicos de saúde e integração produtiva continuam incompletos. |
| 27 | Planos de medicação: lista, criar, detalhe, editar | CRUD, prescrição, dose, evidência, retenção | `blocked-decision` | OQ-040/base legal e retenção precisam aprovação antes de acesso produtivo. |
| 28 | Importações: hub, criar, upload, preview, confirmar, status | lifecycle completo, erro por linha, retry, download | `fail-closed` | Apenas domínios com handler aprovado podem operar; contrato remoto está divergente. |
| 29 | Access17/arquivos de perfis | importar/exportar, preview, confirmar, status, download | `audited` | CSV de import pode ser assinado; AAL/capability/expiração e DTO de Storage estão abertos. |
| 30 | Auditoria | listar, filtrar, paginar, exportar autorizado | `audited` | Provar leitura minimizada, imutabilidade, retenção e cross-tenant. |
| 31 | Suporte | criar ticket, listar, kanban, detalhe, responder, encerrar | `fail-closed` | UI acessível não substitui backend produtivo aprovado. |
| 32 | Perfil/configurações | ler/editar perfil, senha, MFA, preferências, sessões | `fail-closed` | Perfil/senha/backend incompletos; preferências locais não cobrem conta. |
| 33 | Catálogo de governança | listar componentes, sincronizar, publicar contrato | `audited` | Catálogo é ferramenta de engenharia; não possui contrato Supabase produtivo aprovado. |
| 34 | Planos e assinaturas | listar, criar, editar, ativar, vincular instituição | `blocked-decision` | Rotas atuais são `/dev`; definir spec e autorização produtivas. |
| 35 | Cardápios e modelos | listar, criar, editar, publicar, imagem, audiência | `blocked-decision` | Rotas atuais são `/dev`; repository parcial não torna superfície produtiva. |
| 36 | Usuários internos | listar, criar/convidar, editar, suspender, MFA | `blocked-decision` | Superfície `/dev`; exige modelo produtivo e política privilegiada. |
| 37 | Erros 403/404/409/500/503 | renderizar, recuperar, retry seguro, correlação | `audited` | Garantir mapeamento uniforme de SQLSTATE/PostgREST/Edge sem vazar detalhes. |

### Recomendação inicial por tela/família

As faixas abaixo são do backend Supabase por família, não do Flutter nem do
produto inteiro. Recalcular após abrir as ações reais da linha.

| Ordem | Tela/família | Mínimo aconselhado | ETA inicial | Motivo principal |
| ---: | --- | --- | --- | --- |
| 1 | Auth | `Avançada` | 2–5 dias | Sessão, MFA e revogação são segurança transversal. |
| 2 | Home/shell/contexto | `Avançada` | 1–2 dias | Troca de tenant e cache exigem negativas remotas. |
| 3 | Instituições | `Avançada` | 1–2 dias | CRUD privilegiado e isolamento cross-tenant. |
| 4 | Unidades | `Avançada` | 1–2 dias | CRUD, mídia e import/export. |
| 5 | Grupos/turmas | `Avançada` | 1–2 dias | Vínculos, participantes e arquivos. |
| 6 | Pessoas | `Avançada` | 2–4 dias | Identidade global, contatos e vínculos sensíveis. |
| 7 | Perfis de acesso | `Completa` | 2–5 dias | Capabilities e delegação controlam outras superfícies. |
| 8 | Modelos de acesso | `Completa` | 2–5 dias | Escopo, versão e arquivos de autorização. |
| 9 | Convites | `Avançada` | 1–2 dias | Emissão, expiração, aceite e revogação. |
| 10 | Atividades | `Avançada` | 1–2 dias | Publicação, audiência e assignments. |
| 11 | Avaliações | `Avançada` | 1–3 dias | Lançamento, fechamento e reabertura concorrentes. |
| 12 | Alunos | `Avançada` | 1–3 dias | Vínculos, transferência e revogação. |
| 13 | Assiduidade | `Avançada` | 1–3 dias | Chamada, correção, fechamento e exportação. |
| 14 | Rotina diária | `Avançada` | 1–3 dias | Modelos, lançamentos, publicação e versão. |
| 15 | Agenda | `Avançada` após decisão | Recalcular após spec | Ainda não existe contrato produtivo aprovado. |
| 16 | Conversas/chat | `Completa` | 3–7 dias | Mensagens, anexos, recibos, Realtime e revogação. |
| 17 | Avisos | `Avançada` | 1–3 dias | Publicação, audiência, agendamento e recibos. |
| 18 | Formulários — editor/publicação | `Completa` | 3–7 dias | Versão, distribuição, agenda e lifecycle. |
| 19 | Formulários — respostas/monitor | `Completa` | 3–7 dias | Autosave, anonimato, métricas e exportação. |
| 20 | Formulários — arquivos/mídia | `Completa` | 2–5 dias | Storage privado, expiração e exclusão. |
| 21 | Acontece | `Avançada` após decisão | Recalcular após contrato | Integração Supabase Storage/metadados ainda bloqueada; R2 está fora do MVP. |
| 22 | Agora | `Avançada` após decisão | Recalcular após contrato | Publicação, audiência e expiração não aprovadas. |
| 23 | Momentos | `Avançada` após decisão | Recalcular após contrato | Publicação, mídia e remoção ainda protótipo. |
| 24 | Para Você/perfil Principal | `Avançada` após decisão | Recalcular após contrato | Superfície produtiva ainda não definida. |
| 25 | Segurança infantil | `Completa` | 3–7 dias | Dados sensíveis, evidências e suspensão. |
| 26 | Saúde/cuidado | `Completa` | 3–7 dias | Dados sensíveis, mídia, histórico e auditoria. |
| 27 | Medicação | `Completa` após decisões | Recalcular após OQ-040 | Base legal e retenção bloqueiam correção. |
| 28 | Importações | `Completa` | 2–5 dias | Upload, preview, confirmação, retry e download. |
| 29 | Access17/arquivos de perfis | `Completa` | 2–5 dias | AAL, capability, assinatura e expiração. |
| 30 | Auditoria | `Avançada` | 1–3 dias | Imutabilidade, retenção e cross-tenant. |
| 31 | Suporte | `Avançada` após decisão | Recalcular após backend | Backend produtivo ainda não aprovado. |
| 32 | Perfil/configurações | `Avançada` | 1–3 dias | Senha, MFA, sessões e dados de conta. |
| 33 | Catálogo de governança | `Intermediária` | 2–6 h | Ferramenta de engenharia sem contrato produtivo. |
| 34 | Planos/assinaturas | `Avançada` após decisão | Recalcular após spec | Rota produtiva e autorização indefinidas. |
| 35 | Cardápios/modelos | `Avançada` após decisão | Recalcular após spec | Publicação, imagem e audiência indefinidas. |
| 36 | Usuários internos | `Completa` após decisão | Recalcular após spec | Operação privilegiada e MFA. |
| 37 | Erros backend | `Intermediária` | 2–6 h | Mapeamento seguro e consistente de erros. |

### 7.1. Matriz detalhada obrigatória por tela e ação

Cada linha abaixo representa uma ação independente. As colunas de nível são
cumulativas e descrevem o pacote possível; somente a coluna **Nível
aconselhado** é a recomendação atual. A estimativa é por ação e deve ser
somada à da família; espera por decisão externa não está incluída.

| Ordem | Tela/subtela | Ação | Pendência Supabase | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 1 | `auth` | `auth.login` | Login, restauração, refresh e bootstrap interno vinculado ao `session_id` passaram no replay Auth-only descartável; produção não recebeu o pacote. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | replay produtivo 1–2 d | GoTrue real local, sessão/contexto pelo mesmo `session_id`, membership/capability/tenant e revogação; depois pacote transacional compatível com ledger e E2E remoto. |
| 1 | `auth` | `auth.logout` | Logout, rotação e recusa de refresh/access token revogados passaram no lifecycle local real; produção não recebeu o pacote. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | replay produtivo 1–2 d | Logout real, tokens revogados negados, bootstrap sensível bloqueado, pacote transacional e E2E remoto. |
| 1 | `auth` | `auth.mfa` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 6–12 h | Sessão válida/inválida; pessoa e vínculo ativos; revogação/downgrade; tenant A/B; nenhum dado antes da autorização. |
| 1 | `auth` | `auth.recover` | Solicitação neutra, Mailpit, redirect e callback recovery passaram no replay Auth-only descartável; produção/SMTP permanecem abertos. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | replay produtivo 1–2 d + SMTP/E2E | Conta existente/desconhecida indistinguíveis, callback válido/inválido, link real e nenhum segredo/PII em evidência; Flutter guard continua em correção separada. |
| 1 | `auth` | `auth.reset` | Reset sem MFA foi aprovado neste pacote e troca, expiração/reuso, logout e senha antiga recusada passaram localmente; produção não recebeu o pacote. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | replay produtivo 1–2 d + E2E | Sessão recovery real, uso único, senha antiga/nova e logout; Flutter guard continua em correção separada. |
| 2 | `shell` | `shell.load` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Sessão válida/inválida; pessoa e vínculo ativos; revogação/downgrade; tenant A/B; nenhum dado antes da autorização. |
| 2 | `shell` | `shell.navigate` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Sessão válida/inválida; pessoa e vínculo ativos; revogação/downgrade; tenant A/B; nenhum dado antes da autorização. |
| 2 | `shell` | `shell.reload` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Sessão válida/inválida; pessoa e vínculo ativos; revogação/downgrade; tenant A/B; nenhum dado antes da autorização. |
| 2 | `shell` | `shell.switch-context` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Sessão válida/inválida; pessoa e vínculo ativos; revogação/downgrade; tenant A/B; nenhum dado antes da autorização. |
| 2 | `shell` | `shell.unauthorized` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Sessão válida/inválida; pessoa e vínculo ativos; revogação/downgrade; tenant A/B; nenhum dado antes da autorização. |
| 3 | `institutions` | `institutions.access-denied` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 3 | `institutions` | `institutions.create` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 3 | `institutions` | `institutions.detail` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 3 | `institutions` | `institutions.edit` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 3 | `institutions` | `institutions.error` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 3 | `institutions` | `institutions.export` | O wrapper remoto executável por `authenticated` alcança `app_private.superadmin_request_institution_export`, cuja query referencia `institution_directory.slug` e `updated_at`, colunas ausentes da view remota; runtime/lint falha com SQLSTATE `42703`. Cliente deve permanecer fail-closed. | `fail-closed` | Reproduzir `42703` e manter integração indisponível; não fecha ação. | Básica + corrigir projeção/contrato sem confiar em filtros, com autorização e negativas locais. | Intermediária + tenant A/B, vínculo revogado, limites, arquivo real, expiração e remoto autorizado. | Avançada + regressão, Advisors, auditoria, cleanup e E2E; pode fechar ação. | `Avançada` | 6–12 h | RED/GREEN do runtime; view e função compatíveis; ator/tenant/ownership; filtros/IDs adulterados; arquivo real; DTO sem path; expiração/revogação; cleanup sem órfão; remoto autorizado e E2E. |
| 3 | `institutions` | `institutions.files` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 3 | `institutions` | `institutions.filter` | Filtros/opções v2 internos passaram 35/35: allowlists, escopo visible-only, limites 8.192/240, NULL/duplicados/UUIDs adulterados, Support/Content negados e audit fail-closed. | `local-green` | Backend focal fechado localmente; não fecha ação sem remoto, Flutter e E2E. | Básica + contrato, autorização e negativas locais. | Intermediária + cutover Flutter, tenant A/B integrado e remoto autorizado. | Avançada + regressão integrada, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h de integração + remoto/E2E separado | Migration 20260827235500; mirror 108/108; regressões Auth 29/29 e detalhe 26/26. |
| 3 | `institutions` | `institutions.import` | O wrapper remoto executável por `authenticated` alcança `app_private.superadmin_confirm_institution_import`, cujo update usa `created_count` e `rejected_count` de forma ambígua; runtime/lint falha com SQLSTATE `42702`. Cliente deve permanecer fail-closed. | `fail-closed` | Reproduzir `42702` e manter integração indisponível; não fecha ação. | Básica + qualificar variáveis/colunas, contrato, autorização e negativas locais. | Intermediária + tenant A/B, vínculo revogado, idempotência, arquivo real e remoto autorizado. | Avançada + regressão, Advisors, auditoria, cleanup e E2E; pode fechar ação. | `Avançada` | 6–12 h | RED/GREEN do runtime; contagens persistidas sem ambiguidade; ator/tenant/ownership; negações; replay; arquivo real; reload; auditoria; remoto autorizado e E2E. |
| 3 | `institutions` | `institutions.list` | Diretório v2 interno passou 35/35: paginação 1–100, offset até 10.000, 17 sorts NULLS LAST/id, output estrito, busca literal e escopo platform/institution. | `local-green` | Backend focal fechado localmente; não fecha ação sem remoto, Flutter e E2E. | Básica + contrato, autorização e negativas locais. | Intermediária + cutover Flutter, tenant A/B integrado e remoto autorizado. | Avançada + regressão integrada, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h de integração + remoto/E2E separado | Owner/Operations/Auditor positivos; Owner AAL2; ACL mínima e audit v2/v3. |
| 3 | `institutions` | `institutions.reload` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 3 | `institutions` | `institutions.status` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 4 | `units` | `units.create` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 4 | `units` | `units.edit` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 4 | `units` | `units.error` | Contrato backend de falha foi inventariado, mas o estado de erro produtivo e sua recuperação não possuem E2E. | `audited` | Reproduzir uma falha + teste local mínimo; não fecha ação. | Básica + erro tipado, autorização e ausência de dados antes da permissão. | Intermediária + tenant A/B, sessão revogada, ID adulterado e retry seguro. | Avançada + Flutter/E2E, regressão, remoto autorizado, auditoria e cleanup. | `Avançada` | 2–4 h | Erro backend tipado e minimizado; nenhum dado pré-autorização; tenant A/B; sessão revogada; ID adulterado; retry sem duplicação ou vazamento. |
| 4 | `units` | `units.export` | D3a Edge local fechou validação/allowlists e limites do hub, DTO público, teto pré-upload de 5 MiB, neutralização CSV, path canônico, reautorização pré-upload/pré-conclusão e export vazio auditável. O gateway Flutter consome `request_export` → `status` → `download`, a UI rejeita snapshot obsoleto, o worker reutiliza replay `SUCESSO`, preserva artefato pós-conclusão, reautoriza antes da URL e exige segredo interno dedicado do hub antes de qualquer RPC. A ação permanece `audited`: grants legados, escopo/capability institucional, retenção/remint, cleanup/purge, configuração/deploy remoto e E2E continuam RED ou bloqueados. O contrato de escopo está `blocked-decision` por OQ-032, ADR 0019 e OQ-034; produção segue fail-closed. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, tenant A/B, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–15 h locais + remoto/E2E separado | Flutter 45/45. Unit-export 41/47; 6 REDs preservados: purge, retention/remint, cleanup órfão e 3 grants legados. Chamada direta do worker: 403/zero RPC. |
| 4 | `units` | `units.filter` | Filtros server-side foram inventariados no contrato de listagem, mas noResults e integração produtiva não possuem E2E. | `audited` | RED de filtro/noResults + teste local mínimo; não fecha ação. | Básica + allowlist, escopo backend, autorização e negativas locais. | Intermediária + tenant A/B, filtros/IDs adulterados, paginação e minimização. | Avançada + Flutter/E2E, regressão, remoto autorizado, auditoria e cleanup. | `Avançada` | 2–4 h | Busca/filtros autorizados e allowlisted; noResults sem vazamento; tenant A/B; filtros/IDs adulterados; paginação/minimização e reload. |
| 4 | `units` | `units.import` | D3b testou CSV/XLSX reais, identidades/memberships, tenant A+B, cross-actor, adulteração, replay, concorrência Edge e falhas parciais. D3c-EDGE fechou o path adulterado. D3d provou create/upload/preview/confirm/retry em conexões Postgres reais num banco descartável, com replay convergente e payload divergente negado; o RED explícito de cleanup confirma que falha do delete mantém job auditável, mas deixa órfão sem retry/purge. Permanecem também os REDs de membership revogada e `request_id` nulo. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 4 | `units` | `units.list` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 4 | `units` | `units.reload` | Contrato backend de releitura foi inventariado, mas retry/reload produtivo e persistência após recarregar não possuem E2E. | `audited` | RED de retry/reload + teste local mínimo; não fecha ação. | Básica + contrato de releitura, autorização e negativa local. | Intermediária + tenant A/B, sessão revogada, idempotência e persistência. | Avançada + Flutter/E2E, regressão, remoto autorizado, auditoria e cleanup. | `Avançada` | 2–4 h | Retry autorizado; reload reflete estado persistido; tenant A/B; sessão revogada; sem duplicação, cache cruzado ou dados obsoletos. |
| 4 | `units` | `units.status` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 4 | `units` | `units.access-denied` | A negação backend foi inventariada; a superfície produtiva permanece explicitamente fail-closed e sem E2E. | `audited` / `fail-closed` | RED de acesso negado + teste local mínimo; não fecha ação. | Básica + autorização backend, resposta uniforme e nenhum dado pré-autorização. | Intermediária + capability/sessão revogada, tenant A/B e ID adulterado. | Avançada + Flutter/E2E, acesso direto, remoto autorizado, regressão e auditoria. | `Avançada` | 2–4 h | Sem capability, revogado, tenant diferente e ID adulterado recebem negação uniforme; nenhum dado antes da autorização; UI fail-closed comprovada. |
| 4 | `units` | `units.people-export` | Não existe capability, snapshot, job ou worker para exportar Pessoas por unidade. `superadmin_people_list` não serve para arquivo porque pode agregar contextos externos da pessoa; `units.export` exporta Unidades; o hub aceita somente `units`. A superfície Flutter foi ocultada e deve permanecer fail-closed. | `blocked-decision` / `fail-closed` | Inventário/RED de ausência; não fecha ação. | Básica + decidir capability, unidade, colunas e modelo 1 linha/pessoa ou vínculo. | Intermediária + snapshot/job/worker, AAL2, tenant A/B, revogação, replay e arquivos locais. | Avançada + remoto autorizado, auditoria, retenção/cleanup e E2E; pode fechar ação. | `Completa` | 8–14 h backend local; 18–32 h vertical total após decisões | Capability `people.export` + `unit_id` server-derived; sem contextos A+B; colunas minimizadas; CSV/XLSX formula-safe; Storage privado ≤5 MiB, URL 5 min, retenção ≤24 h; cross-tenant, ID adulterado, revogado, concorrência, reload e E2E. |
| 5 | `groups` | `groups.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 5 | `groups` | `groups.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 5 | `groups` | `groups.export` | Flutter ocultou o falso controle de exportação, mas adapter produtivo, repository, job, Storage, status e download permanecem indisponíveis. Nenhuma prova Supabase nova foi produzida. | `fail-closed` | RED + teste backend local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + tenant A/B, vínculo revogado, job/arquivo/status e remoto autorizado. | Avançada + regressão, Advisors, auditoria, retenção/cleanup e E2E; pode fechar ação. | `Avançada` | 6–12 h | Request/status/download; arquivo real; ator/tenant/ownership; negações; replay; URL expirada/revogação; DTO sem path; cleanup sem órfão; reload e E2E. |
| 5 | `groups` | `groups.import` | Flutter ocultou o falso controle de importação, mas adapter produtivo, repository, picker, upload, preview e job permanecem indisponíveis. Nenhuma prova Supabase nova foi produzida. | `fail-closed` | RED + teste backend local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + tenant A/B, vínculo revogado, upload/preview/confirm/retry e remoto autorizado. | Avançada + regressão, Advisors, auditoria, cleanup e E2E; pode fechar ação. | `Avançada` | 6–12 h | Seleção/upload/preview/validação/confirm/retry; arquivo real; ator/tenant/ownership; negações; replay; cleanup sem órfão; reload e E2E. |
| 5 | `groups` | `groups.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 5 | `groups` | `groups.members` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 6 | `people` | `people.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 6 | `people` | `people.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 6 | `people` | `people.links` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 6 | `people` | `people.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 6 | `people` | `people.reload` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 7 | `access_profiles` | `access-profiles.assign` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 7 | `access_profiles` | `access-profiles.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 7 | `access_profiles` | `access-profiles.delete` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 7 | `access_profiles` | `access-profiles.detail` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 7 | `access_profiles` | `access-profiles.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 7 | `access_profiles` | `access-profiles.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 8 | `access_models` | `access-models.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 8 | `access_models` | `access-models.detail` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 8 | `access_models` | `access-models.duplicate` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 8 | `access_models` | `access-models.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 8 | `access_models` | `access-models.filter` | O contrato de filtros e escopo no repository estendido não está comprovado ponta a ponta; filtros e IDs enviados pelo cliente são não confiáveis. | `fail-closed` | RED da busca/troca de domínio ou status + teste local mínimo; não fecha ação. | Básica + allowlist de filtros, escopo backend, autorização e negativas locais. | Intermediária + tenant A/B, paginação, minimização, IDs adulterados e reload. | Avançada + E2E Flutter–Supabase, regressão, Advisors, auditoria e cleanup; pode fechar ação após decisão. | `Completa após decisão` | 2–4 h | Busca, domínio/status, vazio e reload; allowlist e escopo no backend; tenant A/B; filtros/IDs adulterados negados; paginação/minimização sem vazamento. |
| 8 | `access_models` | `access-models.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 9 | `invites` | `invites.create` | Backend local aprovado; entrega real, aceite Auth, Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | Sucesso persistido; token único não persistido em claro; sem capability/AAL2; tenant A/B; target/profile/ID adulterado; idempotência, reload e auditoria. |
| 9 | `invites` | `invites.detail` | Backend local aprovado; Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada e minimizada; acesso negado; capability revogada; tenant A/B; ID existente/desconhecido sem oracle; reload sem vazamento. |
| 9 | `invites` | `invites.list` | Backend local aprovado; Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Listagem autorizada, filtros server-side e paginação; acesso negado; tenant A/B; SQL/ID/filtro adulterado; minimização e ausência de vazamento. |
| 9 | `invites` | `invites.resend` | Backend local aprovado; entrega real, Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | Rotação de token, versão/send count, outbox único e idempotência; sem capability/AAL2; expirado/revogado; tenant A/B; reload e auditoria. |
| 9 | `invites` | `invites.revoke` | Backend local aprovado; cancelamento real de entrega, Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | Transição pending→revoked, cancelamento de outbox, versão/idempotência; sem capability/AAL2; tenant A/B; reenvio negado; reload e auditoria. |
| 10 | `activities` | `activities.assessment` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 10 | `activities` | `activities.create` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 10 | `activities` | `activities.detail` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 10 | `activities` | `activities.edit` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 10 | `activities` | `activities.list` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 10 | `activities` | `activities.publish` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 11 | `assessments` | `assessments.close` | Backend local aprovado; fluxo Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | Transição versionada; pendências impedem publicação; capability; concorrência; tenant A/B; reload, histórico imutável e auditoria. |
| 11 | `assessments` | `assessments.detail` | Backend local aprovado; fluxo Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada e canais família/interno separados; acesso negado; tenant A/B; ID adulterado; versão e ausência de vazamento. |
| 11 | `assessments` | `assessments.entry` | Backend local aprovado; fluxo Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Valor validado por escala/taxonomia; normalização server-side; capability; tenant A/B; ID adulterado; idempotência e revisão imutável. |
| 11 | `assessments` | `assessments.gradebook` | Backend local aprovado; fluxo Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Configuração/versionamento, pesos, escala, recovery e receipts; sem grants diretos; tenant A/B; concorrência e reload. |
| 11 | `assessments` | `assessments.reopen` | Backend local aprovado; fluxo Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | Correção exige justificativa, versão e capability; tenant A/B; ID adulterado; revisão/histórico imutável, reload e auditoria. |
| 12 | `students` | `students.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 12 | `students` | `students.link` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 12 | `students` | `students.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 12 | `students` | `students.revoke` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 12 | `students` | `students.transfer` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 13 | `attendance` | `attendance.correct` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 13 | `attendance` | `attendance.create` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 13 | `attendance` | `attendance.dashboard` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 13 | `attendance` | `attendance.export` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 13 | `attendance` | `attendance.finish` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 13 | `attendance` | `attendance.mark` | Revalidar em stack limpa, ledger e remoto autorizado; faltam regressão e fechamento. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 14 | `daily_routine` | `daily-routine.apply` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 14 | `daily_routine` | `daily-routine.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 14 | `daily_routine` | `daily-routine.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 14 | `daily_routine` | `daily-routine.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 14 | `daily_routine` | `daily-routine.publish` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 15 | `agenda` | `agenda.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 15 | `agenda` | `agenda.detail` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 15 | `agenda` | `agenda.edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 15 | `agenda` | `agenda.permissions` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 15 | `agenda` | `agenda.request` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 15 | `agenda` | `agenda.view` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 16 | `chat` | `chat.attach` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 16 | `chat` | `chat.edit` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 16 | `chat` | `chat.list` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 16 | `chat` | `chat.open` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 16 | `chat` | `chat.receipts` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 16 | `chat` | `chat.revoke` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 16 | `chat` | `chat.send` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 17 | `notices` | `notices.archive` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 17 | `notices` | `notices.create` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 17 | `notices` | `notices.edit` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 17 | `notices` | `notices.list` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 17 | `notices` | `notices.publish` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 17 | `notices` | `notices.schedule` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 18 | `forms_authoring` | `forms.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 18 | `forms_authoring` | `forms.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 18 | `forms_authoring` | `forms.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 18 | `forms_authoring` | `forms.overview` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 18 | `forms_authoring` | `forms.publish` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 18 | `forms_authoring` | `forms.test` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 19 | `forms_responses` | `forms.export` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 19 | `forms_responses` | `forms.monitor` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 19 | `forms_responses` | `forms.respond` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 19 | `forms_responses` | `forms.response-detail` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 19 | `forms_responses` | `forms.responses` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 20 | `forms_files` | `forms.delete-file` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 20 | `forms_files` | `forms.download` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 20 | `forms_files` | `forms.expire-file` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 20 | `forms_files` | `forms.resolve-file` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 20 | `forms_files` | `forms.upload` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 21 | `acontece` | `acontece.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 21 | `acontece` | `acontece.feed` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 21 | `acontece` | `acontece.publish` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 21 | `acontece` | `acontece.remove` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 22 | `agora` | `agora.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 22 | `agora` | `agora.expire` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 22 | `agora` | `agora.publish` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 22 | `agora` | `agora.view` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 23 | `momentos` | `momentos.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 23 | `momentos` | `momentos.publish` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 23 | `momentos` | `momentos.remove` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 23 | `momentos` | `momentos.view` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 24 | `principal_profile` | `principal.for-you` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 24 | `principal_profile` | `principal.profile-edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 24 | `principal_profile` | `principal.profile-view` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 25 | `child_safety` | `child-safety.child` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 25 | `child_safety` | `child-safety.create` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 25 | `child_safety` | `child-safety.edit` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 25 | `child_safety` | `child-safety.list` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 25 | `child_safety` | `child-safety.suspend` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 26 | `health_care` | `health-care.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 26 | `health_care` | `health-care.detail` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 26 | `health_care` | `health-care.edit` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 26 | `health_care` | `health-care.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 27 | `medication` | `medication.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 27 | `medication` | `medication.detail` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 27 | `medication` | `medication.edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 27 | `medication` | `medication.evidence` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 27 | `medication` | `medication.list` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 28 | `imports` | `imports.confirm` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 28 | `imports` | `imports.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 28 | `imports` | `imports.download` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 28 | `imports` | `imports.list` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 28 | `imports` | `imports.preview` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 28 | `imports` | `imports.status` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 28 | `imports` | `imports.upload` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 29 | `profile_files` | `profile-files.confirm` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 29 | `profile_files` | `profile-files.download` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 29 | `profile_files` | `profile-files.export` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 29 | `profile_files` | `profile-files.import` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 6–12 h | Arquivo sintético real; ator/tenant/ownership; negações; expiração/revogação; DTO sem path; cleanup sem órfão. |
| 29 | `profile_files` | `profile-files.preview` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 29 | `profile_files` | `profile-files.status` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 30 | `audit` | `audit.detail` | Backend local aprovado; Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Detalhe autorizado e minimizado; acesso negado; tenant A/B; ID desconhecido/cross-scope sem oracle; ator histórico/sistema estável. |
| 30 | `audit` | `audit.export` | Backend local aprovado; geração/arquivo real, Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 6–12 h | MFA/capability; snapshot A/B; revogação; worker autenticado; lease/CAS; PII classificada; fórmula neutralizada; expiração/cleanup e arquivo real. |
| 30 | `audit` | `audit.filter` | Backend local aprovado; Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Filtros/cursor server-side; query hostil e cursor parcial negados; tenant A/B; IDs/filtros adulterados; minimização sem vazamento. |
| 30 | `audit` | `audit.list` | Backend local aprovado; Flutter/E2E, reset limpo e remoto continuam pendentes. | `local-green` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Listagem autorizada e minimizada; sem before/after; capability/deny; tenant A/B; cursor cross-scope; imutabilidade/hash e paginação. |
| 31 | `support` | `support.close` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 31 | `support` | `support.create` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 31 | `support` | `support.detail` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 31 | `support` | `support.kanban` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 31 | `support` | `support.reply` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 31 | `support` | `support.table` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 32 | `account` | `account.logout` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 32 | `account` | `account.mfa` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 32 | `account` | `account.profile` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 32 | `account` | `account.sessions` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 32 | `account` | `account.settings` | Acesso está seguro, porém a ação produtiva permanece indisponível. | `fail-closed` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada` | 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 32 | `account` | `account.theme` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Básica` | 1–2 h | Confirmar que é preferência local e que nenhuma persistência Supabase é alegada. |
| 33 | `catalog` | `catalog.list` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 33 | `catalog` | `catalog.publish` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 33 | `catalog` | `catalog.sync` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 33 | `catalog` | `catalog.validate` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 34 | `plans` | `plans.activate` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 34 | `plans` | `plans.assign` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 34 | `plans` | `plans.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 34 | `plans` | `plans.edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 34 | `plans` | `plans.list` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 35 | `meal_plans` | `meal-plans.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 35 | `meal_plans` | `meal-plans.edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 35 | `meal_plans` | `meal-plans.list` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 35 | `meal_plans` | `meal-plans.model-create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 35 | `meal_plans` | `meal-plans.model-edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 35 | `meal_plans` | `meal-plans.publish` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Avançada após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 36 | `internal_users` | `internal-users.create` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 36 | `internal_users` | `internal-users.edit` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 36 | `internal_users` | `internal-users.list` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 36 | `internal_users` | `internal-users.mfa` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 36 | `internal_users` | `internal-users.suspend` | Ação depende de decisão canônica antes de implementação produtiva. | `blocked-decision` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Completa após decisão` | decisão + 4–8 h | RED; sucesso persistido; sem capability; suspenso/revogado; tenant A/B; ID adulterado; reload e auditoria. |
| 37 | `error_pages` | `errors.403` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Intermediária` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 37 | `error_pages` | `errors.404` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Intermediária` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 37 | `error_pages` | `errors.409` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Intermediária` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 37 | `error_pages` | `errors.500` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Intermediária` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 37 | `error_pages` | `errors.503` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Intermediária` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |
| 37 | `error_pages` | `errors.retry` | Contrato inventariado, mas a ação ainda não possui prova completa local/remota. | `audited` | RED + teste local mínimo; não fecha ação. | Básica + contrato, autorização e negativas locais. | Intermediária + ações relacionadas, tenant A/B e remoto autorizado. | Avançada + regressão, Advisors, auditoria e cleanup; pode fechar ação. | `Intermediária` | 2–4 h | Leitura autorizada; acesso negado; tenant A/B; ID/filtro adulterado; paginação/minimização e ausência de vazamento. |

#### Estimativa consolidada por família após abrir as ações

As somas abaixo são esforço técnico bruto se cada ação for tratada como unidade
independente. A execução conjunta pode compartilhar setup e reduzir repetição, mas
não autoriza remover nenhum gate de segurança ou evidência.

| Ordem | Tela/família | Quantidade de ações | Soma por ação |
| ---: | --- | ---: | ---: |
| 1 | `auth` | 5 | 30–60 h |
| 2 | `shell` | 5 | 30–60 h |
| 3 | `institutions` | 12 | 38–76 h |
| 4 | `units` | 10 | 34–68 h |
| 5 | `groups` | 6 | 24–48 h |
| 6 | `people` | 5 | 14–28 h |
| 7 | `access_profiles` | 6 | 20–40 h |
| 8 | `access_models` | 6 | 16–32 h |
| 9 | `invites` | 5 | 16–32 h |
| 10 | `activities` | 6 | 18–36 h |
| 11 | `assessments` | 5 | 14–28 h |
| 12 | `students` | 5 | 18–36 h |
| 13 | `attendance` | 6 | 24–48 h |
| 14 | `daily_routine` | 5 | 18–36 h |
| 15 | `agenda` | 6 | 18–36 h |
| 16 | `chat` | 7 | 22–44 h |
| 17 | `notices` | 6 | 22–44 h |
| 18 | `forms_authoring` | 6 | 18–36 h |
| 19 | `forms_responses` | 5 | 16–32 h |
| 20 | `forms_files` | 5 | 30–60 h |
| 21 | `acontece` | 4 | 14–28 h |
| 22 | `agora` | 4 | 12–24 h |
| 23 | `momentos` | 4 | 14–28 h |
| 24 | `principal_profile` | 3 | 6–12 h |
| 25 | `child_safety` | 5 | 16–32 h |
| 26 | `health_care` | 4 | 12–24 h |
| 27 | `medication` | 5 | 18–36 h |
| 28 | `imports` | 7 | 28–56 h |
| 29 | `profile_files` | 6 | 28–56 h |
| 30 | `audit` | 4 | 12–24 h |
| 31 | `support` | 6 | 18–36 h |
| 32 | `account` | 6 | 17–34 h |
| 33 | `catalog` | 4 | 14–28 h |
| 34 | `plans` | 5 | 18–36 h |
| 35 | `meal_plans` | 6 | 18–36 h |
| 36 | `internal_users` | 5 | 18–36 h |
| 37 | `error_pages` | 6 | 12–24 h |
| — | **Backlog conhecido** | **207** | **715–1430 h** |

O total bruto não é promessa de calendário: itens `blocked-decision` somam espera
externa, e migrations, RLS, Auth, dados sensíveis e remoto exigem pacotes
Avançados ou Completos. O recorte deve ser reduzido por ações quando o orçamento
for Intermediário.

## 8. Manifesto retomável por `screen_id` e `action_id`

Data da consolidação: 2026-08-26. `Local` significa fonte, catálogo ou testes no
stack local; `ledger` indica se a migration estava registrada; `remoto` significa
somente evidência lida no projeto `coelo`. Nenhuma linha abaixo possui prova
remota completa, portanto não há estado `remote-green` ou `done`.

O ETA é esforço técnico estimado após ownership, ambiente e decisões liberados;
não inclui espera externa. Ações mutáveis incluem no GREEN esperado persistência,
reload/read-after-write, auditoria, revogação e cross-tenant mesmo quando o nome
do `action_id` não contém `reload`.

| # | `screen_id` | `action_id` por estado | Evidência comprovada — ambiente/data | Bloqueio e próximo passo exato | ETA da família |
| ---: | --- | --- | --- | --- | --- |
| 1 | `auth` | `local-green`: `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`; `blocked-decision`: `auth.mfa` | Replay Auth-only passou pgTAP 29/29 e lifecycle real local em GoTrue/PostgREST/Postgres/Mailpit; produção classificada permaneceu sem mutação. | Reproduzir pacote transacional contra ledger produtivo, revisar forward-only, configurar URL/SMTP e executar E2E; MFA continua fora/fail-closed. | replay produtivo 1–2 d + E2E 0,5–1 d |
| 2 | `shell` | `audited`: `shell.load`, `shell.navigate`, `shell.switch-context`, `shell.unauthorized`, `shell.reload` | Composição/rotas auditadas localmente em 2026-08-26; baseline tinha 79 rotas normais e 96 `/dev`. | Reextrair grafo vivo; provar nenhum dado pré-autorização, limpeza de cache/contexto e zero Supabase em `/dev`. | 1 d |
| 3 | `institutions` | `local-green`: `institutions.list`, `institutions.filter`, `institutions.detail`, `institutions.create`, `institutions.edit`, `institutions.status`, `institutions.files`, `institutions.error`, `institutions.access-denied`, `institutions.reload`; `fail-closed`: `institutions.import`, `institutions.export` | Contratos gerais tiveram evidência local anterior, mas o plugin oficial confirmou dois wrappers remotos executáveis por `authenticated` com falhas runtime: import `42702` e export `42703`. Nenhuma ação de arquivo está E2E ou concluída. | Manter import/export indisponíveis; corrigir primeiro a história reproduzível das migrations e os dois REDs; depois provar autorização, tenant A/B, vínculo revogado, IDs/filtros adulterados, arquivos reais, reload, cleanup, remoto autorizado e E2E. | 1–2 d local + remoto/E2E separado |
| 4 | `units` | `audited`: `units.list`, `units.filter`, `units.error`, `units.reload`, `units.create`, `units.edit`, `units.status`, `units.import`, `units.export`; `audited`/`fail-closed`: `units.access-denied`; `blocked-decision`/`fail-closed`: `units.people-export` | UI confirmou filter/noResults, erro, retry/reload e acesso negado; a ação falsa people-export foi ocultada. Contratos backend correspondentes foram inventariados, mas Unit Directory produtivo segue reprovado, people-export não tem capability/job próprio e não há E2E. | Manter diretório `Unavailable`; decidir capability/escopo/colunas de people-export; provar filtros, erro/retry, reload/persistência e negação uniforme com tenant A/B; reconciliar RPC/Edge/Storage e executar arquivos reais. | 2–4 d + 18–32 h vertical de people-export após decisões |
| 5 | `groups` | `fail-closed`: `groups.list`, `groups.create`, `groups.edit`, `groups.members`, `groups.import`, `groups.export` | Flutter ocultou os falsos controles import/export; adapter produtivo stale/reprovado e nenhum backend/arquivo foi promovido. | Integrar somente contrato canônico após comparar RPC/ACL; manter produção Unavailable e `/dev` fake local até pgTAP, jobs/Storage, arquivos e E2E. | 2–3 d |
| 6 | `people` | `fail-closed`: `people.list`, `people.create`, `people.edit`, `people.links`, `people.reload` | Identity repository/RPC/ACL auditados localmente; decisão produtiva e E2E ausentes. | Fechar lookup canônico OQ-038, minimização de PII, AAL2/capabilities, vínculos A/B e reload; só então substituir Unavailable. | 2–4 d |
| 7 | `access_profiles` | `fail-closed`: `access-profiles.list`, `access-profiles.create`, `access-profiles.detail`, `access-profiles.edit`, `access-profiles.assign`, `access-profiles.delete` | Migrations de lint e ACL locais inspecionadas; definição observada fora do ledger; extended repository removido da composição. | Reconciliar ledger, validar delegação/escopo/versionamento e testar atribuição/exclusão com reatribuição, AAL2 e revogação. | 2–3 d |
| 8 | `access_models` | `fail-closed`: `access-models.list`, `access-models.filter`, `access-models.create`, `access-models.detail`, `access-models.edit`, `access-models.duplicate` | Closure estendido/arquivos parcial e não reprodutível em clean HEAD; a UI real de busca, domínio/status, vazio e reload confirmou `access-models.filter` em 2026-08-26. | Aprovar contrato de catálogo/modelo e filtros/escopo; implementar menor backend versionado e executar allowlist, tenant A/B, paginação/minimização, IDs adulterados, capability/AAL2, idempotência e reload. | 2–3 d |
| 9 | `invites` | `local-green`: `invites.list`, `invites.create`, `invites.detail`, `invites.resend`, `invites.revoke` | Migration aplicada no ledger local e suíte dedicada com 60/60 asserts verdes em 2026-08-26: grants/RLS, MFA, tenant A/B, filtros, issue/resend/revoke, replay, versão, outbox e auditoria; a versão não consta no ledger remoto lido pelo plugin oficial. | Preservar migration+teste removidos por reorganização; manter UI produtiva fail-closed até alinhar contrato, delivery/expiry, executar aceite Auth/E2E, reset limpo e remoto explicitamente autorizado. | 1–3 d restantes |
| 10 | `activities` | `local-green`: `activities.list`, `activities.create`, `activities.detail`, `activities.edit`, `activities.publish`, `activities.assessment` | Testes e contratos locais prévios; OQ-038 mantém lookup sensível fail-closed; remoto não provado. | Reconciliar ledger/catálogo; CRUD/publicação A/B, AAL2, templates/assignments, lookup permitido e reload remoto autorizado. | 2 d |
| 11 | `assessments` | `local-green`: `assessments.entry`, `assessments.gradebook`, `assessments.close`, `assessments.reopen`, `assessments.detail` | Quatro migrations aplicadas no ledger local e suíte dedicada 85/85 verde em 2026-08-26: schema/RLS/grants, 17 RPCs, escalas, taxonomia, pesos, receipts, versionamento, recovery, publicação e visibilidade. Nenhuma das versões consta no remoto. | Executar fixtures comportamentais amplas tenant A/B, Flutter/E2E, reload, reset limpo e remoto autorizado antes de fechar ações. | 1–2 d restantes |
| 12 | `students` | `fail-closed`: `students.list`, `students.link`, `students.transfer`, `students.edit`, `students.revoke` | Fundação de Student Tracking passou 43/43 localmente, mas não equivale às cinco ações de diretório/vínculo; repository produtivo e files continuam reprovados/Unavailable. | Não promover as ações pelo GREEN estrutural; integrar somente leitura após provar E2E e redesenhar commands/files em pacotes separados com RLS, Storage, AAL/capability e tenant A/B. | 3–5 d |
| 13 | `attendance` | `local-green`: `attendance.dashboard`, `attendance.create`, `attendance.mark`, `attendance.correct`, `attendance.finish`; `fail-closed`: `attendance.export` | RPCs/testes locais focados previamente verdes; export sem worker/materializador/status/download aprovado. | Revalidar closure clean HEAD, concorrência e A/B; implementar pipeline de export real antes de remover fail-closed. | 2–3 d |
| 14 | `daily_routine` | `fail-closed`: `daily-routine.list`, `daily-routine.create`, `daily-routine.edit`, `daily-routine.apply`, `daily-routine.publish` | Contratos auditados; adapter produtivo stale e composição Unavailable recomendada. | Comparar RPC instalada/fonte, corrigir closure canônico e testar modelos/aplicações/revisões, capability, A/B e reload. | 2–3 d |
| 15 | `agenda` | `blocked-decision`: `agenda.view`, `agenda.create`, `agenda.detail`, `agenda.edit`, `agenda.request`, `agenda.permissions` | Superfície conhecida como `/dev`; nenhum contrato Supabase produtivo aprovado. | Aprovar spec de recorrência, solicitações e permissões; depois modelar RLS/RPC e testes. | decisão 1 d + 3–5 d |
| 16 | `chat` | `audited`: `chat.list`, `chat.open`, `chat.send`, `chat.edit`, `chat.attach`, `chat.receipts`, `chat.revoke` | Contratos/testes locais históricos; paginação real, revogação e remoto ainda sem prova consolidada. | Revalidar paginação/unread, membership dinâmica, anexo privado, receipts, A/B e reload no ambiente autorizado. | 2–3 d |
| 17 | `notices` | `audited`: `notices.list`, `notices.create`, `notices.edit`, `notices.schedule`, `notices.publish`, `notices.archive` | Threat model e fontes existentes; publicação/Edge/mídia remota não fechadas. | Provar audiência, agendamento, publicação idempotente, mídia, revogação, receipts e A/B. | 2–3 d |
| 18 | `forms_authoring` | `fail-closed`: `forms.list`, `forms.create`, `forms.overview`, `forms.edit`, `forms.publish`, `forms.test` | F3/F4 locais revalidados; F5 route-context migration/repository e pages closure ausentes. | Integrar F5 apenas com migration/RPC/pgTAP canônicos; depois recompor authoring e testar versão/publicação/distribuição. | 3–5 d |
| 19 | `forms_responses` | `fail-closed`: `forms.monitor`, `forms.respond`, `forms.responses`, `forms.response-detail`, `forms.export` | Dez targets de aplicação/rotas sem closure produtivo; REDs em triggers/capabilities registrados. | Manter rotas estáticas/Unavailable; fechar eligibility, autosave/anônimo, edição, métricas, export e tenant A/B. | 4–6 d |
| 20 | `forms_files` | `fail-closed`: `forms.upload`, `forms.resolve-file`, `forms.download`, `forms.expire-file`, `forms.delete-file` | Resolvers removidos da composição; download protegido local não teve deploy/E2E. | Implementar Storage privado, resolver HTTPS por ticket após reautorização, TTL/expiry/delete/cleanup e zero `storage_path` no cliente. | 2–4 d |
| 21 | `acontece` | `blocked-decision`: `acontece.feed`, `acontece.create`, `acontece.publish`, `acontece.remove` | Separação R2/Supabase prevista por ADR, sem contrato produtivo aprovado nesta revisão. | Aprovar ownership/audiência/retention e worker R2; implementar metadados/RLS/auditoria e E2E. | decisão 1–2 d + 4–6 d |
| 22 | `agora` | `blocked-decision`: `agora.view`, `agora.create`, `agora.publish`, `agora.expire` | UI/preview não constitui backend; nenhuma prova remota registrada. | Aprovar contrato temporal, audiência, expiração e mídia R2; implementar e testar A/B. | decisão 1–2 d + 3–5 d |
| 23 | `momentos` | `blocked-decision`: `momentos.view`, `momentos.create`, `momentos.publish`, `momentos.remove` | UI/preview não constitui backend; nenhuma prova remota registrada. | Aprovar publicação, audiência, mídia, remoção/retenção e auditoria; implementar e testar A/B. | decisão 1–2 d + 3–5 d |
| 24 | `principal_profile` | `blocked-decision`: `principal.for-you`, `principal.profile-view`, `principal.profile-edit` | Superfície de preview sem contrato produtivo completo. | Definir dados permitidos por contexto, ownership e campos editáveis; implementar leitura/escrita minimizada com RLS. | decisão 1 d + 2–4 d |
| 25 | `child_safety` | `audited`: `child-safety.list`, `child-safety.child`, `child-safety.create`, `child-safety.edit`, `child-safety.suspend` | Migração de lint local inspecionada; sem ledger/remoto/E2E sensível. | Reconciliar enum/status e ledger; testar ownership, AAL2, capability, evidência privada, suspensão, notificação e A/B. | 2–4 d |
| 26 | `health_care` | `fail-closed`: `health-care.list`, `health-care.create`, `health-care.detail`, `health-care.edit` | Contratos e UI auditados; repository/file actions produtivos ainda não implementados. O Owner liberou o trabalho Supabase local em 2026-08-28 sem esperar a etapa jurídica posterior. | Especificar e implementar backend interno com minimização, histórico, mídia privada, auditoria, tenant A/B e dados sintéticos; manter retenção jurídica e produção com dados reais como gates separados. | 4–6 d locais + remoto/E2E separado |
| 27 | `medication` | `blocked-decision`: `medication.list`, `medication.create`, `medication.detail`, `medication.edit`, `medication.evidence` | Repository/contrato produtivo ausente ou stale; OQ-040 jurídica/retenção aberta. | Decidir base legal, prescrição, dose, evidência, retenção e responsabilidade; só então especificar backend. | decisão externa + 5–8 d |
| 28 | `imports` | `fail-closed`: `imports.list`, `imports.create`, `imports.upload`, `imports.preview`, `imports.confirm`, `imports.status`, `imports.download` | Hub genérico real atende Units; facade histórica diverge em endpoints e não suporta Access Profiles. | Publicar catálogo allowlist por domínio; testar create-only, MIME/encoding/limites, replay, partial failure, URL/expiry e cleanup. | 3–5 d |
| 29 | `profile_files` | `fail-closed`: `profile-files.import`, `profile-files.preview`, `profile-files.confirm`, `profile-files.status`, `profile-files.export`, `profile-files.download` | RPCs locais auditadas: bucket privado e ACLs restritas; P0 em `file_complete`, `file_job`, assinatura de import e vazamento bucket/path. | Aprovar gateway worker-only; permitir conclusão só de export com AAL2/capability/membership/expiry revalidados; sanitizar DTO e testar revogação/reuso. | decisão 1 d + 3–5 d |
| 30 | `audit` | `local-green`: `audit.list`, `audit.filter`, `audit.detail`, `audit.export` | Suíte dedicada 78/78 verde em 2026-08-26 após atualizar somente harness/fixtures: imutabilidade/hash, minimização, paginação, capability/MFA, tenant A/B, worker, lease/CAS, revogação, expiração e cleanup. | Preservar migration concorrente; executar reset limpo, arquivo CSV real, Flutter/E2E e remoto autorizado; validar retenção conforme decisão formal. | 1–2 d restantes |
| 31 | `support` | `fail-closed`: `support.create`, `support.table`, `support.kanban`, `support.detail`, `support.reply`, `support.close` | UI/protótipo não possui backend produtivo aprovado. | Aprovar modelo, escopo interno, motivo, least privilege, auditoria e retenção; implementar antes de habilitar. | decisão 1–2 d + 4–6 d |
| 32 | `account` | `audited`: `account.theme`, `account.logout`; `fail-closed`: `account.profile`, `account.settings`; `blocked-decision`: `account.mfa`, `account.sessions` | Preferência de tema é local; logout wiring auditado; perfil/senha/sessões/MFA produtivos incompletos. | Fechar Auth da família 1; definir campos editáveis, listar/revogar sessões e MFA por papel; testar reload e revogação. | 2–4 d após Auth |
| 33 | `catalog` | `blocked-decision`: `catalog.list`, `catalog.validate`, `catalog.sync`, `catalog.publish` | Ferramenta de engenharia, sem contrato Supabase produtivo aprovado. | Decidir se permanece tooling local; se produtivo, especificar atores, assinatura/versionamento, auditoria e rollback. | decisão 1 d + 3–5 d |
| 34 | `plans` | `blocked-decision`: `plans.list`, `plans.create`, `plans.edit`, `plans.activate`, `plans.assign` | Rotas `/dev`; nenhuma autoridade de cobrança/assinatura aprovada. | Aprovar spec, ownership institucional, estados, idempotência e auditoria; depois backend e A/B. | decisão 2–3 d + 5–8 d |
| 35 | `meal_plans` | `blocked-decision`: `meal-plans.list`, `meal-plans.create`, `meal-plans.edit`, `meal-plans.model-create`, `meal-plans.model-edit`, `meal-plans.publish` | Rotas `/dev` e repository parcial não liberam produção. | Aprovar domínio, audiência, alergias/dados sensíveis, mídia, versionamento/publicação e retenção. | decisão 2 d + 5–8 d |
| 36 | `internal_users` | `blocked-decision`: `internal-users.list`, `internal-users.create`, `internal-users.edit`, `internal-users.suspend`, `internal-users.mfa` | Superfície `/dev`; política privilegiada além do Owner permanece aberta. | Decidir papéis/capabilities/MFA, convite, suspensão e auditoria; implementar com least privilege e E2E. | decisão 2–3 d + 5–8 d |
| 37 | `error_pages` | `audited`: `errors.403`, `errors.404`, `errors.409`, `errors.500`, `errors.503`, `errors.retry` | Mapeamentos foram inspecionados em revisões locais; nenhuma linha representa persistência. | Criar matriz SQLSTATE/PostgREST/Edge, mensagens sem leak, correlation ID seguro e retry somente idempotente. | 0,5–1 d |

### 8.1. Handoff para o rastreador integrado

O consumidor de integração deve copiar os estados abaixo para a coluna Supabase
de cada `screen_id/action_id`, sem promover o estado por evidência Flutter:

| Estado Supabase | `screen_id/action_id` |
| --- | --- |
| `local-green` | `auth.login`; `auth.recover`; `auth.reset`; `auth.logout`; `institutions/*`; `activities/*`; `attendance.dashboard`; `attendance.create`; `attendance.mark`; `attendance.correct`; `attendance.finish` |
| `audited` | `shell/*`; `units/*`; `assessments/*`; `chat/*`; `notices/*`; `child-safety/*`; `audit/*`; `account.theme`; `account.logout`; `error_pages/*` |
| `fail-closed` | `groups/*`; `people/*`; `access_profiles/*`; `access_models/*`; `invites/*`; `students/*`; `attendance.export`; `daily_routine/*`; `forms_authoring/*`; `forms_responses/*`; `forms_files/*`; `health_care/*`; `imports/*`; `profile_files/*`; `support/*`; `account.profile`; `account.settings` |
| `blocked-decision` | `auth.mfa`; `agenda/*`; `acontece/*`; `agora/*`; `momentos/*`; `principal_profile/*`; `medication/*`; `account.mfa`; `account.sessions`; `catalog/*`; `plans/*`; `meal_plans/*`; `internal_users/*` |
| `remote-green` ou `done` | nenhum item em 2026-08-26 |

Os curingas `*` significam exatamente todos os `action_id` enumerados na linha
correspondente da tabela principal, não ações futuras ou implícitas.

### 8.2. Modelo para novas evidências

Ao iniciar um domínio, tela ou ação, acrescentar uma subseção seguindo este
modelo. Não apagar histórico; mover evidências antigas para uma lista datada
curta.

```md
### SUP-SCREEN-NNN — Nome da tela / ação

- Estado:
- Owner:
- Início:
- Última atualização:
- ETA:
- Tela/cliente consumidor:
- Contrato de entrada/saída:
- RPC/Edge/Data API:
- Tabelas/views/buckets:
- Migration(s):
- Capabilities e escopo:
- MFA/AAL:
- RLS/grants/ACL:
- Auditoria/notificações:
- RED inicial:
- Correção implementada:
- pgTAP:
- Deno/Edge:
- Cross-tenant/IDOR:
- Definição instalada verificada:
- Teste remoto/read-after-write:
- Cleanup:
- Bloqueio/decisão:
- Próximo passo exato:
- Evidência de conclusão:
```

## 9. Protocolo de pausa e retomada

Antes de pausar:

1. Atualizar estado, owner, último comando/teste, RED/GREEN e próximo passo.
2. Registrar HEAD, paths reservados e se há processo, migration ou transação.
3. Informar o que está apenas local, o que está no ledger e o que está remoto.
4. Não escrever “quase pronto”; listar exatamente os gates faltantes.
5. Preservar dados/artefatos recuperáveis sem copiar PII ou segredos para este
   documento.

Ao retomar:

1. Reler este arquivo integralmente.
2. Confirmar se HEAD, remoto, ledger, Advisors e ownership mudaram.
3. Reproduzir o último RED ou último GREEN antes de editar.
4. Continuar do primeiro gate incompleto da ordem obrigatória.
5. Atualizar este documento no mesmo turno da correção.

## 10. Formato obrigatório de relatório ao usuário

Todo checkpoint deve informar, nesta ordem:

1. contrato da atividade e modalidade de recorte escolhida;
2. pendências totais conhecidas e pendências incluídas no recorte;
3. fase e item atual da ordem obrigatória;
4. tela/subtela e ação em execução;
5. o que ficou `done` desde o último checkpoint;
6. evidências e testes;
7. itens restantes da tela atual e fora do recorte;
8. bloqueios e decisão necessária;
9. próxima tela somente se a atual estiver concluída ou formalmente bloqueada;
10. ETA da ação, da tela, da fase e do total conhecido;
11. paths sob ownership e estado local/ledger/remoto.

## 11. Prompt mestre — revisão e finalização Supabase

Copie o texto abaixo para a tarefa responsável pelo backend Supabase.

```text
NOME DA MISSÃO: Revisão e finalização Coelo Supabase

OBJETIVO

Auditar ou concluir o recorte autorizado de Auth, Postgres, RLS, grants, RPCs,
Edge Functions, Storage, Realtime e migrations sem confundir artefato local,
fail-closed ou backend parcial com conclusão.

ABERTURA OBRIGATÓRIA

Se o usuário ainda não informou, comece perguntando: “Quanto tempo total você
quer investir nesta atividade? Responda em minutos, horas ou dias.” Na mesma
resposta, liste as pendências conhecidas e não edite nada. Se o tempo já foi
informado, não pergunte novamente.

Faça inventário read-only, compare o orçamento com as faixas do rastreador e
recomende `Básica`, `Intermediária`, `Avançada` ou `Completa` por tema/tela/ação.
Recomende no mínimo Intermediária para correção relevante, Avançada para Auth,
RLS, grants, migrations com drift e segurança, e Completa para declarar `done`.
Mostre o que será incluído e tudo que continuará pendente. Se o tempo for
insuficiente, reduza o recorte; nunca retire gates para caber.

Depois registre objetivo, modalidade, incluído, fora de escopo, ordem, critério
de parada, evidências e ETA recalculado. Modalidades: todas as pendências; todas
as telas; macrotema; macrotema + X telas; X telas; ou X ações. Peça confirmação
do pacote recomendado antes de iniciar correções. Se o usuário já escolheu tempo,
recorte e nível, apenas confirme o contrato e execute o que estiver autorizado.

COMUNICAÇÃO CLARA

Na primeira ocorrência, traduza siglas e estados para linguagem cotidiana: Auth
(entrada e sessão), RLS (segurança por linha), RPC (função do banco chamada pelo
app), Edge Function (função executada no servidor), fail-closed (negado com
segurança, mas indisponível), local-green (passou só localmente) e remote-green
(passou no backend remoto). Explique contagens e percentuais: “54 testes
executados; todos os 54 passaram”, não apenas “54/54” ou “100%”.

LEITURA OBRIGATÓRIA

1. AGENTS.md.
2. Skill coelo-supabase vigente.
3. Plugin oficial @Supabase e skills supabase,
   supabase-postgres-best-practices e rtk.
4. Leitura leve da skill coelo-flutter-supabase-review; usar o fluxo integrado
   apenas se Flutter estiver no escopo.
5. docs/reviews/coelo-supabase-pendencias.md integralmente.
6. docs/reviews/2026-08-25-coelo-supabase-screen-integration.md.
7. Specs, ADRs e open questions do recorte.
8. Estado real do código, migrations, ledger e ambiente remoto autorizado.

Acione ao menos uma ferramenta apropriada do plugin @Supabase em cada
atividade: documentação atual para planejamento/revisão e, havendo projeto e
autoridade, inventário remoto somente leitura. Isso não autoriza executar SQL,
aplicar migration, publicar função, criar branch ou fazer deploy. Se o plugin
estiver indisponível, registre o bloqueio e não declare remote-green nem done.
Use RTK para busca, leitura, Git, testes e lint quando houver wrapper compatível.

AUTORIDADE

Review, revisão, auditoria, diagnóstico e relatório são read-only. Não corrigir,
aplicar migration, alterar remoto, publicar Edge Function, usar privilégio elevado
ou fazer deploy sem autorização compatível para a operação e o ambiente.

ORDEM

Siga as Fases 0 a 8 deste rastreador:
0. ambiente, inventário, baseline e ownership;
1. migrations, RLS, grants, RPCs, Edge, Storage e fundação;
2. Auth, MFA, tenant, membership, capabilities e cross-tenant;
3. Instituições -> Unidades -> Grupos -> Pessoas -> Perfis -> Convites;
4. Atividades -> Avaliações -> Alunos -> Assiduidade -> Rotina -> Agenda;
5. Chat -> Avisos -> Formulários -> Acontece -> Agora -> Momentos -> Para Você;
6. Segurança infantil -> Saúde -> Medicação após gates jurídicos;
7. Import/export -> Access17 -> Auditoria -> Suporte -> Perfil/Configurações;
8. regressão remota, advisors, reconciliação, secrets scan e cleanup.

Não pule item aberto. Avance após done Supabase ou blocked-decision documentado.

MÉTODO POR DOMÍNIO/TELA/AÇÃO

1. Inventarie contratos backend de listar, criar, editar, publicar/ativar,
   excluir/revogar, importar/exportar, anexar, enviar, responder e recarregar.
2. Registre uma entrada SUP-SCREEN para cada ação do recorte.
3. Trace Data API/RPC/Edge até tabelas, views, buckets, policies e migrations.
4. Compare definição instalada, ledger e arquivo canônico.
5. Produza RED reproduzível sem esconder SQLSTATE.
6. Implemente a menor fatia backend autorizada.
7. Teste auth, pessoa, tenant, membership, capability, vínculo, ownership,
   hierarquia, MFA/AAL2, rate limit, idempotência e revogação dinâmica.
8. Teste autorizado, sem capability, suspenso, revogado, tenant A/B e IDs
   adulterados. Toda tentativa indevida falha no backend.
9. Para arquivos, teste ownership, URL curta após reautorização, expiração,
   remoção, órfãos e retenção.
10. Execute pgTAP, Deno/Edge, Advisors e teste remoto no ambiente autorizado.
11. Confirme read-after-write, concorrência, auditoria e cleanup.
12. Atualize estado local/ledger/remoto, evidências, pendências e ETA.

SEGURANÇA

- Nunca expor service_role, secret key, segredo ou PII.
- Nunca confiar em IDs, filtros, claims, rotas ou payloads do cliente.
- Nunca usar user_metadata para autorização.
- RLS deny-by-default; grants mínimos; UPDATE com SELECT, USING e WITH CHECK.
- TO authenticated sem ownership/escopo não é autorização.
- SECURITY DEFINER exige justificativa, search_path vazio, grants revogados e
  autorização interna testada.
- Não criar URL assinada antes de revalidar sessão, AAL, capability e ownership.
- Não inventar regra jurídica, retenção, papel ou capability ausente.

DONE SUPABASE

Use a seção Regra de conclusão. Local-green não é remote-green. Remote-green
parcial e fail-closed não são done. Done neste arquivo prova somente o backend;
não autoriza declarar a tela Flutter ou a integração ponta a ponta concluída.

CHECKPOINTS

Informe contrato, posição, evidências, estado local/ledger/remoto, restante no
recorte, pendências fora dele, bloqueios, próximo passo e ETA atualizado.

ENCERRAMENTO

Prove classificação de todas as linhas do recorte, ledger/definições
reconciliados, advisors triados, testes positivos/negativos/cross-tenant verdes,
cleanup e secrets scan. Diferencie atividade concluída, item Supabase done e
produto ainda pendente.
```

## 12. Estado da atividade de organização — 2026-08-26

> **Nota de supersessão:** esta seção preserva o contrato histórico anterior à
> confirmação do usuário. A Opção B (`Avançada`) foi confirmada e executada
> parcialmente. O estado operacional vigente está na seção 14 e no Checkpoint
> seguro 23; as expressões “não confirmada” e “não iniciada” abaixo não descrevem
> mais o estado atual.

### Contrato ainda não confirmado para correções

- **Tempo disponível:** o usuário indicou `Intermediária` como preferência
  teórica, equivalente a 2–6 horas, mas pediu primeiro o inventário para decidir.
- **Nível realmente executado até aqui:** somente planejamento e inventário
  read-only; nenhum pacote de correção Básica, Intermediária, Avançada ou
  Completa foi iniciado.
- **Posição atual na ordem:** Fase 0, congelamento e inventário. O baseline local
  e remoto foi recapturado; a próxima ação depende da confirmação do recorte.
- **Ações Supabase concluídas nesta atividade:** nenhuma. A atividade de
  organização abriu 202 ações independentes; as sincronizações Flutter de
  2026-08-26 confirmaram `access-models.filter` e quatro ações de Units, elevando
  o inventário total, incluindo shell, a 207.
- **Ações restantes no recorte global:** 207 ações, além das 22 pendências gerais
  SUP-GEN. A estimativa bruta das ações é 715–1430 horas antes de espera por
  decisões externas; não é um pacote aconselhado para execução contínua.
- **Pendências fora de qualquer pacote ainda não confirmado:** todo código,
  migration, configuração local, teste mutável, deploy, SQL e alteração remota.
- **Bloqueios:** ambiente remoto ainda não classificado como desenvolvimento,
  staging ou produção; worktree contém alterações concorrentes extensas; há
  migrations removidas, modificadas e não rastreadas que não pertencem a esta
  atividade; banco local histórico foi classificado como contaminado.
- **Próximo passo seguro:** escolher e confirmar uma das recomendações da seção
  12.1; depois reservar ownership dos paths e reproduzir o primeiro RED sem
  tocar no remoto.
- **Tempo restante:** não mensurável até o usuário escolher o pacote. A janela
  Intermediária de referência permanece 2–6 horas.

### Estado por camada

| Camada | Estado em 2026-08-26 | Interpretação |
| --- | --- | --- |
| Repositório/HEAD | `447ac02c6c75617a8233f141dd0b2c8dc6c228d1`; 156 migrations canônicas e 156 no espelho; último nome `20260825193131_final_review_profile_about_lint_hardening.sql`. | Contagem igual não prova hashes iguais; o worktree concorrente impede assumir baseline limpo. |
| Ledger local | Histórico observado de 148 registros, com definições instaladas fora do ledger. | Estado local não é prova reprodutível; reset compartilhado não está autorizado. |
| Projeto remoto `coelo` | `ACTIVE_HEALTHY`, Postgres 17; 103 migrations, última `20260821200000`; nenhuma escrita feita. | Inventário remoto somente leitura; ambiente ainda não classificado e não está `remote-green`. |
| Advisors remotos | 207 achados de segurança: 50 RLS sem policy, 156 funções `SECURITY DEFINER` executáveis por `authenticated` e 1 proteção contra senha vazada desabilitada. 505 achados de desempenho: 128 FKs sem índice e 377 índices não usados. | Baseline atual confirmado pelo plugin oficial Supabase; cada objeto ainda requer classificação antes de correção. |
| Edge Functions remotas | 10 ativas; `form-operations` e `circular-media` aparecem com `verify_jwt=false`. | Exige confirmar autenticação interna; a configuração isolada não prova vulnerabilidade. |
| Flutter–Supabase | Zero fluxo ponta a ponta comprovado no consolidado vigente. | Backend verde, quando existir, não concluirá a tela Flutter automaticamente. |

### 12.1. Pacotes para decisão

| Opção | Nível | Recorte proposto | ETA | Resultado honesto |
| --- | --- | --- | ---: | --- |
| A | `Intermediária` | Fase 0: reconciliar nomes/hashes/ledger em read-only; classificar o ambiente; triagem dirigida das duas Edge Functions sem `verify_jwt` e dos Advisors P0 alcançáveis. | 4–6 h | Produz baseline confiável e um plano de correção por objeto; não corrige segurança nem fecha ação Supabase. |
| B | `Avançada` | Tudo da Opção A + corrigir localmente a primeira fatia P0 comprovada, com grants/RLS/autorização, negativos, tenant A/B e preparar validação remota separadamente autorizada. | 1–2 dias | **Recomendação para extrema importância.** Pode concluir o pacote contratado, mas não toda a fundação nem uma tela. |
| C | `Completa` | Uma unidade fechada da fundação, começando por um grupo coerente de `SECURITY DEFINER` ou por uma família de RLS, com regressão, Advisors, auditoria e cleanup. | 2–5 dias por unidade | Única opção que pode levar a unidade escolhida a `done`; não fecha as 207 ações do produto. |

**Conselho registrado:** não usar a preferência Intermediária para alterar Auth,
RLS, grants, migrations ou segurança. Se a prioridade é corrigir o que tem
extrema importância, escolher a Opção B (`Avançada`) por 1–2 dias. Se o limite
real for 2–6 horas, escolher a Opção A e encerrar com diagnóstico confiável,
sem alegar correção de segurança.

### 12.2. Critério de parada e evidências do primeiro pacote de correção

O primeiro pacote de correção, se confirmado, para no primeiro destes eventos:

1. término do tempo contratado;
2. primeiro bloqueio de decisão, ambiente ou ownership que impeça prova segura;
3. primeira fatia P0 classificada e corrigida com todos os testes do nível;
4. necessidade de qualquer mutação remota não autorizada explicitamente.

Evidências mínimas: RED reproduzível; objeto e migration canônica identificados;
grants/policies/função instalada comparados; ator permitido, sem capability,
suspenso, revogado, tenant A/B e ID adulterado; pgTAP/Deno aplicável; Advisors
reexecutados; estado local/ledger/remoto separado; diff sem segredo ou PII;
cleanup seletivo. Validação remota continua dependendo de autorização específica.

### Distinção de conclusão na pausa atual

- **Atividade de organização:** concluída após validação deste Markdown.
- **Atividade contratada de correção:** não confirmada e não iniciada.
- **Ação Supabase concluída:** nenhuma nesta atividade.
- **Tela Supabase concluída:** nenhuma.
- **Integração Flutter–Supabase concluída:** nenhuma.
- **Produto:** permanece pendente.

## 13. Histórico de atualização

- 2026-08-26: `groups.import`/`groups.export` permaneceram `fail-closed` após o
  Flutter ocultar os falsos botões/SnackBars. Nenhuma prova Supabase, repository,
  job, Storage, remoto ou E2E foi acrescentada; fluxos reais exigem pacote
  próprio de autorização, tenant A/B, revogação, replay, reload e cleanup.
- 2026-08-26: `units.people-export` foi separado de `units.export` e
  `people.export`. Backend não possui capability/job/worker utilizável;
  listagem de Pessoas pode misturar contextos e não pode ser exportada
  diretamente. Cliente ficou oculto/fail-closed; ação permanece
  `blocked-decision`, sem remoto/E2E.
- 2026-08-26: adicionados orçamento de tempo, níveis `Básica`, `Intermediária`,
  `Avançada` e `Completa`, recomendações por tema/tela e uso obrigatório do
  plugin `@Supabase`, das skills Supabase/Postgres/RTK e da leitura integrada.
- 2026-08-26: o plugin oficial Supabase confirmou em modo somente leitura 103
  migrations, 207 achados de segurança, 505 de desempenho e 10 Edge Functions;
  o rastreador foi expandido para 201 linhas independentes de ação, com alcance
  por nível, conselho, estimativa e evidência, sem correção de código ou remoto.
- 2026-08-26: separado como rastreador exclusivo do backend Supabase; conclusão
  Flutter e ponta a ponta passou a depender dos rastreadores próprios.
- 2026-08-26: criado o rastreador vivo após constatação de que a revisão anterior
  produziu auditoria e vários estados fail-closed, mas não concluiu todas as
  ações Flutter + Supabase de ponta a ponta.
- 2026-08-26: consolidadas as 37 famílias e todos os `action_id` oficiais com
  estado conservador, evidência por ambiente, bloqueio, próximo passo e ETA;
  separados histórico parcialmente verde, dívida atual, resíduos, autoridade
  local/ledger/remoto e handoff nominal para o rastreador integrado.

## 14. Execução Avançada SUP-GEN-002/SUP-GEN-016 — 2026-08-26

### Contrato confirmado e posição atual

- **Confirmação do usuário:** executar a Opção B (`Avançada`) sem interromper a
  atividade por ordens de outras conversas, mantendo feedback por etapa e
  checkpoints seguros.
- **Tempo contratado:** 1–2 dias de trabalho focado. Após a confirmação dos P0
  de Instituições, a estimativa mínima restante foi recalculada para 9–17 horas
  locais; validação remota autorizada e E2E formam pacote separado.
- **Macrotema:** Fundação Supabase.
- **Tela/subtela/família:** infraestrutura transversal de migrations e ledger;
  nenhuma tela de produto será declarada concluída por este pacote.
- **Ações em execução:** `SUP-GEN-002` (reconciliar migrations), `SUP-GEN-016`
  (consolidar resíduos concorrentes), com os primeiros P0 confirmados em
  `institutions.import` e `institutions.export`.
- **Posição na ordem:** Fase 1, antes do reparo de compatibilidade de replay da
  migration `20260811220646_institution_import_export.sql`; depois vêm as
  correções forward-only dos SQLSTATE `42702` e `42703`, uma por vez.
- **Estado do pacote:** `in-progress`; nenhuma ação Supabase está `done` ainda.

### Etapas, estimativas e evidência

| Etapa | Objeto exato | ETA | Estado | Evidência/saída |
| --- | --- | ---: | --- | --- |
| 1 | Instruções, HEAD, worktree e ownership | 20–40 min | concluída | HEAD `447ac02c6c75617a8233f141dd0b2c8dc6c228d1`; worktree concorrente preservado. |
| 2 | 156 migrations canônicas, 156 do mirror e 103 do ledger remoto | 60–90 min | concluída | Canônico e mirror sem arquivo ausente ou hash divergente; plugin oficial usado somente para leitura. |
| 3 | Classificar drift, resíduos e primeiro P0 | 45–90 min | parcial | As 103 versões remotas estão cobertas; há 173 migrations canônicas, 173 no mirror e 70 versões somente locais. O inventário por pacotes foi produzido, mas a história ainda não é reprodutível a partir do HEAD. |
| 4 | Reproduzir a primeira divergência P0 | 60–120 min | concluída para Unidades | RED determinístico: o teste falhou porque o canônico não continha `20260811215621_unit_performance_hardening.sql`. Nenhuma alteração remota. |
| 5 | Aplicar a menor correção local segura | 2–4 h | concluída para Unidades | Três timestamps implantados restaurados; guards da ordem histórica preservados; nenhuma regra de autorização alterada. |
| 6 | Testes positivos, negativos, cross-tenant e regressão aplicável | 2–4 h | parcial | Pacotes locais focados foram executados, mas a tentativa de clean-stack expôs a ordem incompatível da migration `11220646`, os P0 `42702`/`42703` e o incidente local. Não há prova válida de replay limpo nem E2E. |
| 7 | Reconciliar evidências e preparar handoff | 30–60 min | em execução | Checkpoints registram estado local/remoto e limites de conclusão. O Checkpoint 23 consolida o recorte, a sequência restante e o handoff sem promover ação a `done`. |

### Checkpoint seguro 1 — triagem de reparos históricos isolados

Os commits `bde38460`/`3d50ddf6` corrigem o alias reservado `authorization`
em `20260813161500_child_safety_operational_detail.sql`; `f090de99` corrige
delimitadores `$` incompletos em
`20260813172000_people_aggregate_identity_commands.sql`; `8ac84b18` documenta
o primeiro reparo. Os diffs são sintáticos e pequenos, porém as duas migrations
não existem no canônico atual nem no ledger remoto de 103 registros. Portanto,
esses commits foram classificados como **trabalho local válido de outra linha,
fora da divergência compartilhada atual**, e não serão integrados isoladamente.

- **Ação concluída com evidência:** apenas a classificação dos quatro commits;
  `SUP-GEN-002` e `SUP-GEN-016` continuam abertas.
- **Estado local:** nenhuma migration alterada por esta execução; tracker é o
  único path atualizado neste checkpoint.
- **Estado remoto:** somente leitura; nenhuma migration, SQL, Advisor, função ou
  configuração alterada.
- **Flutter–Supabase:** não validado neste pacote transversal.
- **Bloqueio evitado:** integrar commits de uma sequência não presente no
  canônico/remoto criaria uma terceira história de migrations.
- **Próximo passo exato:** comparar conteúdo e ancestralidade dos oito pares de
  mesmo nome/timestamp diferente, começando por
  `unit_performance_hardening`, `unit_contract_security_hardening` e
  `unit_export_snapshot_fk_index`; selecionar o primeiro delta sem ownership
  concorrente e produzir RED.
- **Ponto de retomada:** iniciar pela comparação histórica do par
  `unit_contract_security_hardening`, o único dos três primeiros cujo blob
  implantado conhecido diverge do arquivo local renumerado.

### Checkpoint seguro 2 — aliases de Unidades corrigidos localmente

#### Atividade/tela/ação exata

- **Macrotema:** Fundação Supabase / reconciliação de migrations.
- **Família:** Unidades.
- **Ações afetadas:** `units.import` e `units.export`, especificamente a
  capacidade de aplicar a sequência de migrations e manter grants mínimos dos
  gateways de preview, paginação e conclusão de arquivo.
- **Causa confirmada:** três migrations presentes no ledger remoto foram
  renumeradas no canônico local. Isso faria o CLI interpretar as versões locais
  como novas, com risco de reaplicar objetos já implantados. O primeiro RED que
  tratava apenas `REVOKE` como defeito foi descartado após confirmar que a ordem
  renumerada era diferente; o RED definitivo modela os timestamps implantados.

#### Correção local

| Nome implantado restaurado | Alias local removido | Tratamento |
| --- | --- | --- |
| `20260811215621_unit_performance_hardening.sql` | `20260811225100_unit_performance_hardening.sql` | Conteúdo SQL preservado; somente nome/ordem reconciliados. |
| `20260811222209_unit_contract_security_hardening.sql` | `20260811225200_unit_contract_security_hardening.sql` | Restaurados guards para wrappers que só existem após `20260811223000`. |
| `20260811235155_unit_export_snapshot_fk_index.sql` | `20260811230300_unit_export_snapshot_fk_index.sql` | Conteúdo SQL preservado; somente nome/ordem reconciliados. |

O mirror foi regenerado e verificado pelo fluxo oficial:
`Sync-SupabaseCliMigrations.ps1 -Mode Prepare` e `-Mode Verify`, ambos com
`Verified 156 canonical migrations.`

#### RED/GREEN e grants

- **RED:** `migration_order_contract_test.ts` falhou por ausência de
  `20260811215621_unit_performance_hardening.sql` no canônico.
- **GREEN:** o mesmo teste passou após a reconciliação e também impede retorno
  dos três aliases ou `REVOKE` incondicional na ordem histórica.
- **Deno focado:** 3/3 em `unit-import` e 2/2 em `unit-export`.
- **pgTAP focado:** 48/48 em
  `unit_contract_security_hardening_test.sql` e
  `unit_import_export_security_test.sql`.
- **Grants comprovados no banco local instalado:** preview de linhas e wrapper
  legado de paginação não são executáveis por `authenticated`; conclusão/falha
  de arquivo permanecem restritas a `service_role`; gateways públicos mantêm
  `search_path` endurecido conforme os testes existentes.
- **RLS:** nenhuma policy foi alterada neste checkpoint; os pgTAP focados
  confirmaram a policy de leitura de identidade e ausência das policies diretas
  de insert/delete já previstas, mas não constituem regressão RLS completa.

#### Estado e retomada

- **Drift após a correção:** 156 canônicas, 103 remotas; 76 versões só locais,
  23 só remotas e 5 aliases de mesmo nome/timestamp diferente, todos em
  Cardápios.
- **Estado remoto:** plugin oficial usado somente para listar migrations;
  nenhuma migration, SQL, Advisor, função, configuração ou deploy alterado.
- **Ação Supabase concluída:** a correção local dos três aliases de Unidades e
  seu contrato de regressão; `units.import`/`units.export` como ações ponta a
  ponta continuam `audited`, não `done`.
- **Flutter–Supabase:** não validado nem concluído.
- **Arquivos tocados:** as seis entradas canônico/mirror correspondentes, este
  rastreador e
  `supabase/functions/unit-import/migration_order_contract_test.ts`.
- **Tempo restante estimado no pacote:** 6–12 horas focadas.
- **Próximo passo seguro:** repetir a reconciliação, um par por vez, nos cinco
  aliases de Cardápios, começando por `meal_plans_superadmin`; antes de mover,
  localizar a fonte histórica e comparar conteúdo, dependências e ledger.
- **Ponto de retomada exato:** comparar
  `20260813181952_meal_plans_superadmin` remoto com
  `20260813120000_meal_plans_superadmin.sql` local; não mover se o conteúdo
  implantado não puder ser comprovado.

### Checkpoint seguro 3 — aliases de Cardápios corrigidos localmente

#### Atividade/tela/ação exata

- **Macrotema:** Fundação Supabase / reconciliação de migrations.
- **Família:** Cardápios.
- **Ações afetadas:** listar/detalhar, criar/editar rascunho, submeter, publicar,
  arquivar, enviar/excluir imagem e cleanup; o checkpoint corrige a história de
  migrations e seus testes, não comprova esses fluxos no Flutter.
- **Causa confirmada:** cinco migrations implantadas foram renumeradas
  localmente. A migration base também havia incorporado, fora da ordem, partes
  das migrations posteriores de policies e grants.

#### Correção local e prova remota somente leitura

| Nome implantado restaurado | Alias local removido | Fingerprint normalizado |
| --- | --- | --- |
| `20260813181952_meal_plans_superadmin.sql` | `20260813120000_meal_plans_superadmin.sql` | `b7b7044a05cdf2e55faea76e126730eb` |
| `20260813182036_meal_plans_policy_hardening.sql` | `20260813123000_meal_plans_policy_hardening.sql` | `7656747e5265525b33cffa2329200201` |
| `20260813182115_meal_plans_rpc_grants_hardening.sql` | `20260813124500_meal_plans_rpc_grants_hardening.sql` | `9d7b8dae534447beaffafee595fce486` |
| `20260820154917_meal_plans_model_audience_availability_v2.sql` | `20260820160000_meal_plans_model_audience_availability.sql` | `845aef2961c182d1552022bd424adc26` |
| `20260820173350_meal_plan_private_images.sql` | `20260820171000_meal_plan_private_images.sql` | `a5b41da1c3aeb1672d81cfa4cf203893` |
| `20260820174445_meal_plan_fk_indexes.sql` | `20260820171100_meal_plan_fk_indexes.sql` | `2de5850007f9ad26d6febfa8f28ea18e` |

Os seis fingerprints locais coincidem exatamente com o SQL normalizado do
ledger remoto após remover somente quebras finais. O acesso remoto foi
`SELECT` somente leitura em `supabase_migrations.schema_migrations`; nenhuma
função, migration, policy, grant, configuração ou dado foi alterado.

#### RED/GREEN e autorização

- **RED de ledger:** faltavam os cinco nomes implantados no canônico.
- **GREEN de ledger:** 1/1 Deno; impede retorno dos aliases e duplicação do
  hardening dentro da migration base.
- **Deno cleanup:** 3/3.
- **pgTAP inicial:** revelou quatro asserts desatualizados em lifecycle e uma
  fixture de mídia sem capability válida; a correção não enfraqueceu backend.
- **Causa dos asserts:** o desenho vigente usa leituras `SECURITY INVOKER` e
  gateways de comando receipted `SECURITY DEFINER` com `search_path=''`,
  autorização interna e funções `*_unreceipted` sem grants ao cliente. A policy
  de INSERT valida escopo em `WITH CHECK`, não em `USING`.
- **Causa da fixture:** `has_platform_permission` só considera membership de
  plataforma; o teste usava apenas membership institucional e revisão esperada
  `0`, embora o default vigente seja `1`.
- **GREEN pgTAP:** 21/21 em segurança/lifecycle e 30/30 em mídia/receipts.
- **Cross-tenant:** ator institucional B continua negado ao recurso de A antes
  de receber membership de plataforma para o cenário separado de idempotência;
  o teste não transforma membership global em isolamento institucional.

#### Estado e retomada

- **Drift após a correção:** 156 canônicas, 103 remotas; 70 versões só locais,
  17 só remotas e zero aliases de mesmo nome com timestamp divergente.
- **Correção de fundação concluída localmente:** reconciliação de seis aliases
  de Cardápios e atualização dos testes para o contrato vigente.
- **Estado das seis ações `meal-plans.*`:** permanece `blocked-decision`, como
  registrado nas linhas por ação e no manifesto. Os 55 testes tornam somente
  o subsistema backend/migrations `audited`/local-green; não removem decisões
  de domínio, audiência, alergias/dados sensíveis, mídia, publicação, retenção,
  rota `/dev` ou integração Flutter.
- **Pendência de dados identificada:** a migration histórica contém rótulos com
  mojibake já implantados. A correção futura deve ser forward-only; não será
  escondida reescrevendo migration aplicada.
- **Arquivos tocados:** doze entradas canônico/mirror correspondentes,
  `migration_ledger_contract_test.ts`, dois pgTAP de Cardápios e este rastreador.
- **Tempo restante estimado no pacote:** 4–10 horas focadas.
- **Próximo passo seguro:** classificar as 17 migrations remotas sem versão
  canônica, comparando fingerprints do ledger com os 70 arquivos só locais;
  restaurar apenas correspondências exatas ou diferenças explicadas.
- **Ponto de retomada exato:** começar por
  `20260811220631_institution_identity_storage_and_handles`,
  `20260811220646_institution_import_export` e
  `20260811221002_institution_storage_rls_hardening`; calcular fingerprint
  normalizado e procurar conteúdo idêntico antes de criar ou mover arquivo.

### Checkpoint seguro 4 — cobertura integral do ledger remoto no canônico

#### Atividade/tela/ação exata

- **Macrotema:** Fundação Supabase / reconciliação de migrations.
- **Famílias alcançadas:** Instituições/importação-exportação, Unidades,
  Formulários, Cardápios e Perfil/Sobre.
- **Ação corrigida neste checkpoint:** recuperar no canônico e no mirror as
  versões já presentes no ledger remoto que ainda não possuíam arquivo local.
  Esta correção não declara nenhuma tela, ação de produto ou integração Flutter
  concluída.
- **Fonte remota:** plugin oficial Supabase, somente leitura, no projeto
  identificado `evvbomzejfijozbtgvpt`. A documentação oficial confirma que o
  CLI compara a história local/remota pelos timestamps e que `migration repair`
  altera o ledger; portanto nenhum repair foi executado neste pacote.

#### Migrations remotas recuperadas

Além dos aliases de Unidades e Cardápios registrados nos checkpoints anteriores,
foram restauradas as seguintes versões implantadas:

- **Formulários/Perfil:** `20260820124500`, `20260820171018`,
  `20260820171200`, `20260820172043`, `20260820182229`, `20260820183250` e
  `20260821200000`;
- **Instituições/lint/Unidades/Cardápios:** `20260811220631`,
  `20260811220646`, `20260811221002`, `20260811230000`, `20260811230100`,
  `20260811230200`, `20260812131952`, `20260820114916` e `20260820121005`.

As nove versões do segundo grupo foram reconstruídas a partir dos statements do
ledger remoto somente leitura e tiveram comprimento e fingerprint normalizado
comparados 9/9. As sete versões do primeiro grupo foram recuperadas de blobs
históricos do Git e comparadas com o ledger. Canônico e mirror possuem os mesmos
171 nomes; a verificação por hash permanece como gate antes de fechamento.

#### Inventário reconciliado

| Fonte | Versões | Relação atual |
| --- | ---: | --- |
| Canônico `packages/coelo_database/migrations` | 171 | 103 implantadas + 68 somente locais |
| Mirror `packages/coelo_database/supabase/migrations` | 171 | mesmos nomes do canônico; hash integral é gate de fechamento |
| Ledger remoto | 103 | 103/103 versões presentes no canônico; zero somente remotas |

Isto encerra a lacuna **remote-only**, mas não prova que as 68 migrations locais
são todas aplicáveis, ordenadas ou necessárias. `SUP-GEN-002` e `SUP-GEN-016`
continuam `audited`/`in-progress`, não `done`.

#### RED/GREEN e regressão local

- **Contratos de ledger:** os testes de Unidades, Cardápios e
  Formulários/runtime falharam antes das versões implantadas serem restauradas e
  passaram depois; execução atual 3/3 Deno, com `deno fmt --check` aprovado.
- **Formulários:** 9 arquivos, 169 asserts pgTAP, todos verdes.
- **Instituições/importação-exportação:** o primeiro ciclo encontrou 1 RED em
  131 asserts. A expectativa antiga exigia sete policies
  `*_scoped_platform_read`, embora migrations posteriores tenham substituído as
  policies de `units` e `groups` por `units_authorized_read` e
  `groups_authorized_read`. O teste passou a exigir as cinco policies vigentes e
  as duas sucessoras; nenhuma policy, função ou grant foi enfraquecido. Segundo
  ciclo: 131/131 verdes.
- **Perfil, Unidades e Cardápios:** 138/138 asserts pgTAP verdes.
- **Total atual deste checkpoint:** 438 asserts pgTAP e 3 contratos Deno verdes.
  Os testes usam o banco local e rollback; não constituem reset do catálogo nem
  validação remota de comportamento.

#### Estado, limites e retomada

- **Ações de Cardápios:** `meal-plans.list`, `meal-plans.create`,
  `meal-plans.edit`, `meal-plans.model-create`, `meal-plans.model-edit` e
  `meal-plans.publish` permanecem `blocked-decision`. Somente o subsistema
  backend/migrations está `audited`/local-green.
- **Ações de Unidades, Formulários, Instituições e Perfil:** não foram elevadas
  para `done`; os testes de fundação não substituem E2E, persistência/reload ou
  integração Flutter–Supabase.
- **Estado remoto:** somente leitura; nenhum SQL de mutação, migration repair,
  deploy, Edge Function, configuração Auth, Advisor ou dado alterado.
- **Estado Git:** nenhum stage ou commit realizado por esta atividade.
- **Tempo restante estimado no pacote:** 2–8 horas focadas, dependendo de
  quantas das 68 versões locais forem duplicadas, concorrentes ou bloqueadas.
- **Próximo passo seguro:** comparar canônico e mirror por hash; depois
  classificar as 68 versões somente locais por dependência e família, sem apagar
  nenhuma, começando pela primeira versão local posterior/intercalada ao ledger
  que ainda não possua evidência de implantação.
- **Ponto de retomada exato:** gerar o manifesto ordenado das 68 versões
  local-only com nome, família, predecessor remoto/local, status Git e teste
  relacionado; selecionar o primeiro conflito real para novo RED antes de
  qualquer alteração.

### Checkpoint seguro 5 — fonte e revogação do Chat Realtime corrigidas

#### Atividade/tela/ação exata

- **Macrotema:** Fundação Supabase / ledger local e autorização dinâmica.
- **Família:** Conversas/Chat.
- **Ações afetadas:** `chat.send`, `chat.receipts`, `chat.attach` e
  `chat.revoke`, somente no subsistema de invalidação privada Realtime. As ações
  permanecem `audited`, não `done`; Flutter, anexo real R2, reload e E2E não
  foram executados.
- **Divergência reproduzida:** o ledger do banco local continha a versão aplicada
  `20260824210000`, mas o canônico e o mirror não continham sua fonte. A versão
  era `chat_private_broadcast_invalidation`, preservada em commits Git não
  ancestrais do HEAD. Um contrato Deno falhou deterministamente pela ausência do
  arquivo.

#### Correção de fonte e defeitos encontrados

1. A migration histórica
   `20260824210000_chat_private_broadcast_invalidation.sql` foi restaurada
   byte a byte do commit preservado `9fddea45`, no canônico e no mirror. Ela não
   foi reescrita, porque já consta como aplicada no ledger local.
2. O pgTAP histórico revelou que o emissor acessava
   `chat_attachment_metadata.conversation_id`, coluna ausente no contrato
   canônico, e falhava no update de lifecycle do anexo.
3. O mesmo teste provou que revogar `institution_memberships` não invalidava o
   caminho de participante ativo em `can_access_chat_conversation`.
4. A migration forward-only
   `20260826120000_chat_private_broadcast_attachment_hardening.sql` passa a:
   derivar a conversa do anexo por `message_id`; exigir membership ativa, não
   revogada, da mesma pessoa e instituição quando o participante possui
   `membership_id`; preservar `SECURITY DEFINER`, `search_path=''` e execução
   apenas por `service_role` nas funções privadas.

O Supabase Realtime local atual materializa o payload solicitado como `{}` em
um objeto privado contendo somente um `id` opaco. O teste foi atualizado para
provar ausência de dados de domínio, um único campo `id` e `private=true`, sem
afrouxar isolamento ou grants.

#### RED/GREEN e ambiente

- **RED de fonte:** 1/2 contratos Deno falhou por ausência de
  `20260824210000`; após restauração, 2/2 verdes e `deno fmt --check` aprovado.
- **RED comportamental:** o pgTAP histórico abortou na coluna inexistente; após
  alinhar a fixture ao schema canônico, expôs três falhas: anexo, payload antigo
  e membership revogada.
- **GREEN comportamental:** 43/43 asserts verdes, incluindo tenant A/B,
  tópico adulterado, anon/authenticated sem INSERT, anexo, receipt, revogação,
  grants e triggers.
- **Isolamento do teste:** migration nova e pgTAP foram executados no mesmo
  processo `psql`, sob transação externa; `ROLLBACK` confirmou nenhuma aplicação
  persistente no banco local compartilhado.
- **Estado remoto:** nenhuma mutação, migration, repair, SQL, deploy, função,
  policy, grant, Auth ou configuração aplicada.
- **Estado Git:** nenhum stage ou commit realizado.

#### Inventário e retomada

- **Canônico/mirror atuais:** 173 versões cada; 103/103 versões remotas
  cobertas; zero remote-only; 70 versões não remotas.
- **Composição das 70 não remotas:** 37 versionadas e limpas no HEAD, 4
  versionadas/modificadas e 29 não versionadas, incluindo a fonte histórica
  recuperada e a correção forward-only deste checkpoint.
- **Ledger local após correção de fonte:** 148 versões aplicadas; 137 possuem
  fonte com o mesmo timestamp; as 11 versões aplicadas sem fonte são aliases já
  explicados de Unidades/Cardápios. A migration forward-only não foi instalada
  persistentemente.
- **Ação Supabase concluída:** correção local versionável do emissor de anexo e
  da revogação dinâmica, com teste transacional. A implantação local permanente,
  remota e o fluxo ponta a ponta continuam pendentes.
- **Tempo restante estimado no pacote:** 1,5–6 horas focadas.
- **Próximo passo seguro:** produzir o manifesto das 70 versões não remotas e
  separar as 37 do HEAD das 33 com trabalho concorrente; depois selecionar a
  próxima divergência aplicada-sem-fonte somente se não for um dos 11 aliases
  já comprovados.
- **Ponto de retomada exato:** recontar canônico/mirror/ledger local e remoto;
  confirmar `173/173/148/103`, hash canônico-mirror zero e, em seguida,
  classificar as 33 versões não remotas com worktree sujo sem apagar arquivos.

#### Manifesto das 33 migrations não remotas com worktree sujo

| Ordem | Família | Estado físico | Versões/ações | Classificação e próximo passo |
| ---: | --- | --- | --- | --- |
| 1 | Chat | 2 novas | `20260824210000`, `20260826120000` | Ownership desta atividade; fonte aplicada recuperada e hardening forward-only 43/43 verde. Preservar para integração coordenada. |
| 2 | Unidades | 3 novas | `20260820140933`–`20140935` | Confirmadas no commit preservado `7bc79256` e no ledger local: índice redundante, revoke da paginação legada e fail-job preso ao request/Edge scope. Regressão ampliada 180/180 verde; preservar e integrar com os testes, sem renumerar. |
| 3 | Access Profiles | 6 novas | `20260811223419`, `11224435`, `11225339`, `11234954`, `12134000`, `12135220` | Cadeia preservada `4496cb3a`, aplicada localmente e `audited`/local-green: harness `like/unlike` reparado e 162/162 asserts verdes. Preservar/integrar como pacote; Flutter/E2E/remoto continuam pendentes. |
| 4 | Rotina diária/Assiduidade | 10 novas | `20260811231000`–`12150100` | Cadeia aplicada localmente e `audited`/local-green: sintaxe do harness reparada e 95/95 asserts verdes. Preservar como pacote; Flutter/E2E/remoto continuam pendentes. |
| 5 | Convites | 1 nova | `20260811233609` | Backend local-green: provenance `33087e25`→remoção `f71b6a9c`, ledger local aplicado, canônico/mirror iguais e 60/60 pgTAP verdes. A versão não consta no ledger remoto somente leitura; preservar migration+teste, sem deploy implícito. |
| 6 | Segurança infantil | 3 modificadas | `20260812002000`–`12002200` | Conteúdo versionado alterado por outra linha. Preservar; reconciliar diffs e decisões sensíveis antes de tocar. |
| 7 | Avisos | 1 modificada | `20260812003000` | Migration versionada alterada por outra linha. Preservar e comparar com worker/receipts antes de consolidar. |
| 8 | Medicação | 1 nova | `20260812115016` | `blocked-decision` por OQ-040/base legal/retenção; não implantar apenas por existir SQL local. |
| 9 | Care Profiles | 2 novas | `20260812123500`, `12124000` | Fundação global + ownership são inseparáveis; requer gate de dados sensíveis e cross-tenant. |
| 10 | Avaliações | 2 novas | `20260824223000`, `24232000` | Ledger local aplicado, canônico/mirror iguais e 85/85 pgTAP verdes; remoto não contém as versões. Preservar com Student Tracking, sem declarar Flutter/E2E. |
| 11 | Student Tracking | 2 novas | `20260824230000`, `24231000` | Ledger local aplicado, canônico/mirror iguais e fundação 43/43 verde; remoto não contém as versões. Isso não promove `students.*`, cujo repository produtivo segue Unavailable. |
| 12 | Auditoria | 1 modificada | `20260812000847` | Migration concorrente preservada: rótulos e rename de variável reservada; ledger local aplicado e canônico/mirror iguais. Apenas o harness/fixtures foi atualizado; 78/78 pgTAP verdes. |

**Resultado da classificação:** nenhuma das 31 migrations concorrentes restantes
foi apagada, renumerada ou editada. Elas representam 10 pacotes dependentes, não
31 defeitos independentes. A próxima análise deve começar pelas três migrations
de Unidades, porque já pertencem à família validada neste pacote; Segurança
infantil, Avisos, Medicação e os pacotes acadêmicos permanecem fora do próximo
recorte seguro sem ownership/decisão adicional.

**Fechamento do pacote de Unidades:** as três versões `20260820140933`–`20140935`
não são a próxima divergência. Elas já estão aplicadas no ledger local, possuem
fonte idêntica no canônico/mirror e vieram de uma cadeia preservada ainda não
ancestral do HEAD. Sete arquivos pgTAP de tipo/plano, performance, management,
identidade/Storage, contrato, import/export e retenção somaram 180/180 asserts
verdes. O pacote continua sem E2E Flutter porque o auth scope produtivo injeta
`UnavailableUnitBackendCommandsGateway`; `units.import` e `units.export`
permanecem `audited`, não `done`.

**Novo ponto de retomada:** retirar Unidades da fila de suspeitos e classificar o
pacote Access Profiles de seis migrations como uma unidade, começando por
proveniência, ledger local e dependências entre `worker_runtime_closure`,
`fail_closed_delegation` e `file_idempotency_closure`. Não aplicar, renumerar ou
separar migrations antes dessa cadeia estar comprovada.

**RED de Access Profiles:** as seis migrations nasceram juntas em `4496cb3a`,
receberam correções posteriores de compilação/ordem e constam aplicadas no ledger
local. A regressão de seis pgTAP não passou: autorização negativa ficou verde;
`security_review_closure` falhou nos asserts 13, 17, 18 e 23; `model_commands`
falhou no assert 19; `management_v2`, `management_v2_security_closure` e
`import_models_rate_limit` abortaram antes do plano completo porque o harness não
resolveu as assinaturas `like/unlike(text, unknown, unknown)`. Nenhum backend,
grant ou migration foi alterado em resposta ao RED.

**Próxima ação segura de Access Profiles:** reproduzir cada aborto isoladamente,
comparar o uso de `like/unlike` com a assinatura pgTAP instalada e corrigir apenas
casts/expectativas do harness quando comprovadamente obsoletos. Só então
reexecutar os seis arquivos e diagnosticar as cinco falhas comportamentais por
contrato, uma a uma. ETA revisada deste pacote: 2–6 horas; ele não cabe como
correção apressada dentro do fechamento atual de ledger.

### Checkpoint seguro 6 — Access Profiles local-green

#### Escopo e action_ids

- **Família:** Access Profiles e Access Models.
- **Migrations preservadas:** `20260811223419`, `20260811224435`,
  `20260811225339`, `20260811234954`, `20260812134000` e `20260812135220`.
- **Action_ids validados:** `access-profiles.list`,
  `access-profiles.create-from-model`, `access-profiles.assign`,
  `access-profiles.capability-catalog`, `access-models.duplicate`,
  `access-models.list-system` e `access-models.import-preview`.
- **Estado funcional:** `audited`/local-green. Nenhuma ação, tela ou integração
  Flutter–Supabase foi promovida a `done`.

#### Causa e correção do harness

O pgTAP instalado expõe `extensions.ok(boolean[,text])`, mas não os helpers
históricos `like/unlike(text,text,text)`. O PostgreSQL tentava resolver apenas
`pg_catalog.like(text,text)` e três arquivos abortavam antes do plano completo.
Cada teste recebeu helpers transacionais `public.like/unlike` que delegam para
`extensions.ok`; o `ROLLBACK` remove os helpers ao final, sem alterar o banco.

Depois do harness completar os planos, oito REDs foram tratados um por vez:

| Action_id | RED | Classificação | GREEN |
| --- | --- | --- | --- |
| `access-profiles.list` | tokens do cursor em ordem diferente | assert estrutural frágil | requisitos `definition_kind/profile/principal` independentes |
| `access-profiles.create-from-model` | nomes do helper ausentes no wrapper e ordem diferente | falso positivo; wrapper passa `source.id/source.version` ao helper e força inativo | snapshot/version/lock comprovados sem depender da formatação |
| `access-profiles.assign` | `definition_kind/profile/principal` em ordem diferente | assert estrutural frágil | os três requisitos continuam obrigatórios |
| `access-profiles.capability-catalog` | `NULL` e espaços esperados literalmente | serialização normalizada por `pg_get_functiondef` | `inherited_effect=null` e ausência de `none` comprovadas |
| `access-models.duplicate` | espaços esperados entre `'status','inactive'` | formatação, não regra | duplicata inativa comprovada |
| `access-models.list-system` | conjunto esperado não seguia `ORDER BY code` | ordem incorreta do teste | seis modelos exatos na ordem lexical |
| `access-models.import-preview` | tokens esperados em sequência textual | assert estrutural frágil | mass assignment, duplicata e scope tipado exigidos separadamente |

Nenhuma migration, função, RLS, grant, RPC ou regra backend foi modificada para
obter o GREEN.

#### Evidências e retomada

- **Regressão final conjunta:** 6 arquivos, 162/162 asserts pgTAP verdes.
- **Negativas cobertas:** autorização negativa, fail-closed, delegação,
  importação sem PII/assignments, limites, rate limit, modelos inativos e
  separação profile/model.
- **Estado remoto:** não consultado para comportamento e não alterado.
- **Estado Git:** nenhum stage ou commit desta atividade.
- **Pendências:** integração Flutter, fluxo real de arquivo, persistência/reload,
  banco descartável/reset e validação remota autorizada.
- **Tempo restante estimado no pacote Avançado:** 1–4 horas para classificar o
  próximo pacote de migrations sujas; Access Profiles local não consome mais a
  estimativa de correção backend.
- **Próximo passo seguro:** sair de Access Profiles e inventariar como uma cadeia
  única as 10 migrations de Rotina diária/Assiduidade, começando por ledger
  local, proveniência e suíte existente, sem editar schema antes de um RED real.

### Checkpoint seguro 7 — Rotina diária/Assiduidade local-green

#### Escopo, origem e action_ids

- **Famílias:** Assiduidade e Rotina diária.
- **Migrations:** `20260811231000`, `20260811231500`, `20260811231600`,
  `20260811231700`, `20260812120000`, `20260812143000`, `20260812143500`,
  `20260812144000`, `20260812150000` e `20260812150100`.
- **Origem:** nove versões nasceram juntas em `62364121`; a segurança de
  Assiduidade veio em `b6cbf4fc`. Houve exclusão posterior durante reorganização
  de menu (`f71b6a9c`) e reconciliações posteriores. As dez constam aplicadas no
  ledger local e devem ser preservadas como cadeia, não apagadas isoladamente.
- **Action_ids revalidados:** `attendance.create`, `attendance.set-participant`,
  `attendance.complete`, `attendance.idempotency` e `daily-routine.scope`, além
  dos contratos estruturais de model/version/application/remap.

#### RED/GREEN

O primeiro ciclo teve cinco arquivos verdes e um aborto em
`attendance_routine_security_test.sql`. O harness possuía um `select ok` sem
fechamento entre os asserts de concorrência e data futura. Após reparar somente
a sintaxe, três REDs completaram o plano:

| Action_id | RED | Causa confirmada | GREEN |
| --- | --- | --- | --- |
| `attendance.create` | teste procurava a tabela de receipts dentro da função | a função delega replay/store para helpers privados e mantém advisory lock | lock + `attendance_command_replay/store` comprovados |
| `attendance.set-participant` / `attendance.complete` | teste procurava acesso direto à tabela | ambas delegam replay e store aos helpers únicos | idempotência completa comprovada nas duas mutações |
| `daily-routine.scope` | teste procurava `has_context_permission` no wrapper | `require_routine_scope` delega para `routine_scope_allowed`, que aplica a permissão contextual | cadeia de autorização em duas camadas comprovada |

Nenhuma migration, RPC, função, RLS, grant ou regra backend foi alterada.

#### Evidências e retomada

- **Regressão final:** 6 arquivos, 95/95 asserts pgTAP verdes.
- **Cobertura:** schema, RLS/segurança, idempotência, optimistic concurrency,
  hierarchy/scope, application scope e remap versionado.
- **Estado funcional:** backend `audited`/local-green; ações/telas não estão
  `done`, e persistência/reload Flutter não foi validada.
- **Estado remoto:** nenhuma consulta comportamental ou mutação realizada.
- **Estado Git:** nenhum stage ou commit realizado.
- **Tempo restante estimado no pacote Avançado:** 0,5–3 horas para classificar
  os pacotes menores ainda sujos; bloqueios de decisão não serão comprimidos.
- **Próximo passo seguro:** preservar Segurança infantil/Avisos como trabalho
  modificado por outras linhas e classificar Convites como o próximo pacote
  isolado de uma migration, começando por proveniência e pgTAP/Auth local.

### Checkpoint seguro 8 — sincronização de `access-models.filter`

- **Origem:** a revisão Flutter integrada confirmou em 2026-08-26 uma superfície
  real de busca, troca de domínio/status, estado vazio e reload em Access Models.
- **Action_id adicionado:** `access-models.filter`; `access-models.delete` não foi
  criado porque existe apenas no repository, sem superfície de UI confirmada.
- **Estado:** `fail-closed`. A sincronização não promove Access Models, Access
  Profiles, tela ou integração Flutter–Supabase a `done`.
- **Pendência backend/E2E:** decidir e implementar o contrato de filtros e escopo
  no repository estendido, tratar filtros e IDs como não confiáveis e provar
  tenant A/B, paginação/minimização, vazio e reload sem vazamento.
- **Nível mínimo aconselhado:** `Completa após decisão`; estimativa proporcional
  da ação: 2–4 h de backend/E2E, sem reduzir autorização, negativas ou evidências.
- **Contagem sincronizada:** 202 action_ids; Access Models passa a 6 ações e
  16–32 h brutas; backlog global passa a 707–1414 h brutas.
- **Estado remoto:** não consultado nem alterado nesta sincronização.
- **Estado Git:** nenhum stage ou commit realizado.
- **Próximo passo seguro:** retomar Convites exatamente no ponto registrado no
  Checkpoint 7: proveniência da migration `20260811233609`, suíte pgTAP/Auth local
  e primeiro RED real antes de qualquer alteração de schema.

### Checkpoint seguro 9 — Convites backend local-green

#### Escopo, proveniência e action_ids

- **Família:** Convites.
- **Action_ids:** `invites.list`, `invites.create`, `invites.detail`,
  `invites.resend` e `invites.revoke`.
- **Migration:** `20260811233609_superadmin_invites_production.sql`, criada com
  a suíte dedicada no commit `33087e25` e removida junto da reorganização de menu
  em `f71b6a9c`; o par foi recuperado no worktree e deve ser preservado.
- **Integridade:** versão presente no ledger local; canônico e mirror possuem o
  mesmo SHA-256 `D387F117DDE47462787F89D94026464FAA0956FFB6D7CF576D89A1CD888B1077`.

#### RED/GREEN e evidências

Não houve RED nesta cadeia: a suíte transacional existente completou 60/60
asserts pgTAP verdes sem alterar migration, RPC, RLS, grant ou regra backend.
Ela prova localmente:

- capabilities separadas de leitura/gestão, MFA AAL2 para mutações e
  reautorização a cada comando;
- RLS forçada e leitura direta mínima apenas pelo destinatário, sem token,
  contato ou identificadores do emissor;
- directory/detail server-side, filtros parametrizados, paginação e resposta
  uniforme para ID existente/desconhecido sem autorização;
- issue/resend/revoke versionados e idempotentes, advisory lock, receipts,
  rotação do token hash, outbox privado e cancelamento após revogação;
- hierarquia e tenant A/B para unidade, grupo e perfil, canais allowlisted,
  auditoria do ator recalculado e rejeição após capability revogada.

#### Estado e retomada

- **Estado Supabase:** cinco ações `local-green`; nenhuma ação/tela/integração foi
  promovida a `done`.
- **O que continua pendente:** entrega real de e-mail, aceite via Auth, adapter
  Flutter produtivo, persistência/reload E2E, reset/stack limpa e remoto
  autorizado.
- **Estado remoto:** plugin oficial consultado somente para listar migrations; a
  versão `20260811233609` não consta nas 103 versões remotas observadas. Nenhuma
  consulta comportamental, migration, SQL, deploy ou outra mutação foi feita.
- **Estado Git:** nenhum stage ou commit realizado.
- **Tempo restante estimado no pacote Avançado:** 0,25–2,5 h; trabalho sensível
  bloqueado por decisão ou E2E não será comprimido.
- **Próximo passo seguro:** executar a verificação consolidada dos checkpoints
  6–9 e classificar o próximo pacote pequeno que não esteja modificado por outro
  owner; Segurança infantil, Avisos e dados sensíveis permanecem preservados ou
  bloqueados até reconciliação/decisão.

### Checkpoint seguro 10 — regressão consolidada dos pacotes 6–9

- **Execução transacional local:** 13 arquivos pgTAP, 317/317 asserts verdes e
  zero arquivo abortado ou com `not ok`.
- **Access Profiles/Models:** 6 arquivos, 162/162.
- **Rotina diária/Assiduidade:** 6 arquivos, 95/95.
- **Convites:** 1 arquivo, 60/60.
- **Interpretação:** as migrations recuperadas e os reparos estritamente no
  harness coexistem no catálogo local atual sem regressão focada. Isso não prova
  reset limpo, Flutter, E2E, entrega externa ou comportamento remoto.
- **Persistência do teste:** todas as suítes encerraram em `ROLLBACK`; nenhuma
  fixture ou mutação de teste deve permanecer no banco local.
- **Estado remoto:** somente o ledger de migrations foi lido pelo plugin oficial
  no pacote de Convites; nenhuma mutação remota foi executada.
- **Estado Git:** nenhum stage ou commit realizado.
- **Próximo passo seguro:** triagem somente leitura de Audit
  (`20260812000847_audit_production.sql`), pois é fundação de segurança e está
  modificado por outra linha; confirmar proveniência, ledger e testes antes de
  solicitar qualquer ownership ou tocar no arquivo.

### Checkpoint seguro 11 — sincronização das ações UI de Units

- **Origem:** handoff Flutter confirmou quatro superfícies reais agregadas
  anteriormente em `units.list`: filtro/noResults, erro, retry/reload e acesso
  negado.
- **Action_ids adicionados:** `units.filter`, `units.error`, `units.reload` e
  `units.access-denied`.
- **Estado backend:** `audited` para filtro, erro e reload porque os contratos
  backend correspondentes já foram inventariados; `units.access-denied` fica
  explicitamente `audited`/`fail-closed`.
- **Limite da evidência:** o patch informado é UI local/fail-closed. Nenhuma das
  quatro ações é `remote-green`, `done` ou E2E; Unit Directory produtivo continua
  indisponível.
- **Contagem sincronizada:** 206 action_ids únicos; Units passa a 10 ações e
  34–68 h brutas; backlog global passa a 715–1430 h brutas.
- **Alterações backend:** nenhuma por causa desses IDs; código, migrations,
  grants, RLS, RPCs e ambiente remoto não foram tocados.
- **Gate de conhecimento:** nenhuma regra durável de produto, domínio ou permissão
  foi decidida; não há atualização canônica de `docs/knowledge/` neste checkpoint.
- **Próximo passo seguro:** aguardar o handoff Flutter final e ownership estável
  antes de qualquer promoção de estado; preservar o RED read-only de Audit para
  classificação separada, sem editar o arquivo concorrente.

### Checkpoint seguro 12 — Auditoria backend local-green

#### Escopo e proveniência

- **Action_ids:** `audit.list`, `audit.filter`, `audit.detail` e `audit.export`.
- **Migration:** `20260812000847_audit_production.sql`, originada em `298c4bc4`
  e ajustada depois por `b83e5495`, `e23d9462` e `5dea64a9`.
- **Alteração concorrente preservada:** 18 adições/16 deleções adicionam rótulos
  das permissions e renomeiam a variável reservada `authorization`; canônico e
  mirror continuam iguais e a versão consta no ledger local. A migration não foi
  editada por esta atividade.

#### REDs classificados e correções

Todos os REDs estavam no harness/fixtures históricos, não no comportamento
backend:

1. nove asserts pgTAP de schema usavam três argumentos; o pgTAP instalado exige
   quatro quando o schema é explícito;
2. fixtures de Units não forneciam `unit_type_id`, descrição de `other` e handle
   normalizado, hoje obrigatórios;
3. o teste confundia `object_id` com ID do audit log e `request_id` com `job_id`;
4. workers sob `service_role` tentavam consultar tabelas produtivas ou temporárias
   sem grants; os IDs agora vêm dos RPCs e apenas temporárias recebem `SELECT`.

Nenhum grant produtivo foi ampliado. Não houve alteração em função, RLS, RPC,
schema ou regra de auditoria para obter o GREEN.

#### Evidências e retomada

- **Regressão final:** 78/78 asserts pgTAP verdes, com `ROLLBACK`.
- **Regressão consolidada:** 14 arquivos e 395/395 asserts verdes somando Audit,
  Access Profiles/Models, Rotina/Assiduidade e Convites.
- **Cobertura:** append-only/hash chain, minimização, filtros/cursor, detalhes,
  capability/MFA, deny explícito, tenant A/B, export idempotente, rate limit,
  worker server-only, reautorização/revogação, lease/CAS, PII, fórmula, expiração
  e cleanup.
- **Estado funcional:** quatro ações Supabase `local-green`; tela, Flutter/E2E,
  arquivo CSV real, reset limpo e remoto não estão concluídos.
- **Estado remoto:** não consultado para Audit e não alterado.
- **Plugin oficial Supabase:** documentação atual de `SECURITY DEFINER`, revoke e
  RLS foi consultada; confirma preservar EXECUTE mínimo e não conceder leitura
  direta às tabelas apenas para acomodar o harness.
- **Estado Git:** nenhum stage ou commit realizado.
- **Próximo passo seguro:** reexecutar a regressão consolidada dos checkpoints
  6–12; depois preservar os pacotes bloqueados/concorrentes e selecionar apenas
  um pacote sem decisão sensível para a janela restante.

### Checkpoint seguro 13 — Avaliações e Student Tracking

#### Cadeia e evidências locais

- **Migrations Avaliações:** `20260824223000` e `20260824232000`.
- **Migrations Student Tracking:** `20260824230000` e `20260824231000`.
- **Integridade:** as quatro constam no ledger local e possuem canônico/mirror
  idênticos; nasceram nos pacotes preservados `1e485dc6`/`75d923e1`, com ajustes
  posteriores de integração pedagógica.
- **Avaliações:** 85/85 asserts pgTAP verdes.
- **Student Tracking:** 43/43 asserts pgTAP verdes.
- **Regressão consolidada da janela:** 16 arquivos e 523/523 asserts verdes,
  somando Access Profiles/Models, Rotina/Assiduidade, Convites, Audit,
  Avaliações e Student Tracking.

#### Classificação por action_id

- `assessments.entry`, `assessments.gradebook`, `assessments.close`,
  `assessments.reopen` e `assessments.detail` passam a backend `local-green`.
- `students.list`, `students.link`, `students.transfer`, `students.edit` e
  `students.revoke` permanecem `fail-closed`: a suíte de Student Tracking prova
  read models, normalização, RLS/grants e comandos acadêmicos, mas não essas cinco
  ações de diretório/vínculo nem o repository Flutter produtivo.

#### Limites e retomada

- **Remoto:** o plugin oficial listou as migrations somente em leitura; nenhuma
  das quatro versões consta nas 103 versões remotas. Nenhuma mutação foi feita.
- **Não concluído:** Flutter/E2E, fixtures comportamentais completas tenant A/B,
  sessão/vínculo revogado, reload, arquivos privados, reset limpo e remoto.
- **Estado Git:** nenhum stage ou commit realizado.
- **Próximo passo seguro:** executar regressão consolidada incluindo os dois
  arquivos acadêmicos; depois pausar novos pacotes sensíveis e preservar o ponto
  para coordenação, pois Medicação/Care Profiles exigem decisão e Child
  Safety/Avisos possuem alterações concorrentes.

### Checkpoint seguro 14 — `units.import` D1+D2, boundary e REDs

#### Contrato D1 congelado

- **Action_id:** somente `units.import`; `units.export` não foi iniciado.
- **Boundary canônico:** Edge `import-export-jobs`, conforme spec 033 e o cliente
  Flutter atual.
- **Chamadas com JWT do ator:**
  `superadmin_create_import_export_job`,
  `superadmin_import_export_upload_contract`,
  `superadmin_confirm_import_export_job`,
  `superadmin_retry_import_export_job` e
  `superadmin_get_import_export_job`.
- **Chamadas server-only:**
  `superadmin_preview_unit_import_from_edge` para atestar e persistir a prévia e
  `superadmin_fail_unit_file_job` com `expected_request_id` para falha escopada.
- **Persistência:** tabelas `import_jobs`, `import_files`, `import_mappings`,
  `import_rows`, `import_errors` e `import_results`, sem escrita direta pelo
  Flutter. O arquivo usa bucket privado `coelo-operations` e path derivado no
  servidor `imports/units/<job_id>/source.<csv|xlsx>`.
- **Legado a retirar/substituir em D3:** a Edge `unit-import` ainda chama
  `superadmin_create_unit_import_job`, embora a migration
  `20260825173938_close_legacy_unit_import_export_gateways.sql` revogue esse
  gateway. O hub já delega internamente à implementação privada correta.

#### REDs D2 executados isoladamente

- **Deno boundary:** 5 casos, 2 verdes e 3 REDs esperados.
  Arquivo:
  `supabase/functions/import-export-jobs/units_import_boundary_red_test.ts`.
- **pgTAP comportamental:** 11 casos, 10 verdes e 1 RED esperado.
  Arquivo:
  `supabase/tests/unit_import_hub_negative_authorization_red_test.sql`.
- **RED 1 — configuração:** `config.toml` não registra
  `[functions.import-export-jobs]` com `verify_jwt = true`.
- **RED 2 — paridade/legado:** `unit-import/index.ts` ainda referencia o RPC
  público `superadmin_create_unit_import_job`, fechado pela migration local.
- **RED 3 — falha parcial:** depois de upload bem-sucedido, erro de parse ou
  preview marca o job em best effort, mas não remove o objeto privado recém
  gravado.
- **RED 4 — request adulterado:**
  `superadmin_retry_import_export_job(job_id, null)` não rejeita o request nulo;
  a implementação Unit grava `retry_request_id: null` e altera o estado.

#### Negativas já comprovadas no novo harness

- AAL1 e ausência de `units.import` falham com `42501`.
- ator de tenant B não obtém o upload contract do job criado pelo ator A;
- vínculo do ator removido entre create e upload falha fechado;
- capability revogada entre preview e confirm é revalidada;
- UUID de job adulterado não revela nem autoriza outro job;
- path de upload é derivado no servidor;
- replay com a mesma chave e contrato diferente é rejeitado;
- create e preview possuem advisory locks para serialização.

#### Causa, menor D3 e parada segura

- **Causa-raiz:** coexistem o boundary canônico novo e a Edge Unit legada; o
  boundary novo não está registrado na configuração local versionada; duas
  validações de transição/compensação ainda não foram fechadas.
- **Menor patch D3 estimado (não iniciado):** 4–7 h para registrar a Edge com
  JWT, retirar/redirecionar a chamada legada, validar request não nulo no hub e
  implementação Unit e compensar somente o objeto autorizado desta tentativa
  antes de marcar falha. Purge agendado/retention global permanece fora deste
  D3 e exige pacote próprio.
- **Estado real:** `units.import` continua `audited`, com D1 concluído e D2 em
  RED; não é `local-green`, remoto, E2E nem concluído.
- **Persistência dos testes:** pgTAP terminou em `ROLLBACK`; nenhuma fixture
  ficou no banco local. Os 180/180 anteriores não foram repetidos.
- **Estado remoto/Git:** nenhuma consulta mutante, migration, deploy, stage ou
  commit; `units.export` e arquivos de produção não foram alterados.
- **Próximo passo seguro:** aguardar grant nominal para D3 e corrigir um RED por
  vez, começando pelo registro JWT/paridade da Edge; depois reexecutar somente
  estes 16 casos antes de ampliar regressão.

#### Revalidação final e matriz de cobertura D2

- **Revalidação focada:** os hashes dos dois testes permaneceram iguais ao
  handoff. Deno executou 5 casos: 2 passaram e os mesmos 3 REDs falharam pelo
  motivo esperado. pgTAP executou 11 casos: 10 passaram e o mesmo RED de
  `request_id` nulo falhou porque nenhuma exceção foi lançada. Não há falha de
  coletor ou sintaxe. O pgTAP encerrou em `ROLLBACK`.

| Tema D2 | Cobertura comprovada agora | Cobertura ainda ausente antes de conclusão |
| --- | --- | --- |
| AAL/capability | AAL1 nega create; ausência de `units.import` nega create; capability revogada nega confirm. | Executar com identidades, roles, memberships e claims reais, sem substituir helpers; chamar também a Edge por HTTP autenticado. |
| Tenant A/B | Ator B não obtém upload contract do job do ator A. | Duas Instituições e memberships reais; CSV/XLSX com linhas A+B; provar preview/confirm sem leitura, criação ou erro revelador cross-tenant. |
| Vínculo revogado por transição | `current_person_id` nulo entre create→upload nega; capability retirada entre preview→confirm nega. | Revogar registros reais em create→upload, upload→preview, preview→confirm e erro→retry; cobrir sessão ainda portando JWT válido. |
| IDs/job/request/path adulterados | Job inexistente/trocado é negado; path vem do servidor; `request_id` nulo em retry é RED confirmado. | UUID malformado no handler HTTP; job/request pertencentes a atores diferentes; Storage path/object/checksum/MIME trocados no worker real; resposta uniforme sem enumeração. |
| Replay/idempotência/concorrência | Mesma chave com payload diferente é negada; advisory locks de create e preview existem. | Replay idêntico retorna o mesmo job; duas sessões simultâneas para create/upload/preview/confirm/retry; mesmos bytes aceitos e bytes divergentes rejeitados sem duplicação. |
| Falhas parciais | Worker de falha só recebe job previamente autorizado; o RED prova ausência de compensação pós-upload. | Upload real seguido de erro de CSV/XLSX ou preview; falha ao remover objeto; estado/auditoria coerentes; ausência de objeto órfão e nenhuma transição no job estrangeiro. |
| Edge↔RPC↔grants/config | Boundary do hub chama apenas os RPCs canônicos esperados; migration contém grants do hub e revoke do create legado. | Fechar os 3 REDs Deno; clean-stack focado; comparar artefato a implantar com grants efetivos. Remoto permanece fora deste D2. |

#### Patch mínimo D3 proposto, ainda não autorizado nem iniciado

1. registrar `[functions.import-export-jobs]` com `verify_jwt = true` em
   `supabase/config.toml`;
2. retirar a chamada pública legada de `unit-import` ou transformar essa Edge
   em delegação explícita ao hub, sem reabrir o grant revogado;
3. persistir em memória somente o path devolvido pelo upload contract autorizado
   e removê-lo em best effort após falha de parse/preview, antes da transição de
   falha do job; nunca aceitar path do cliente;
4. rejeitar `p_request_id is null` no hub retry e na implementação Unit antes de
   lock ou mudança de estado;
5. tornar verdes somente estes 16 casos e então adicionar as lacunas
   comportamentais acima em lotes pequenos, sem iniciar `units.export`.

- **ETA mínimo D3:** 4–7 h para os quatro REDs atuais; 4–8 h adicionais para as
  fixtures reais e concorrência ausentes. Cleanup/purge agendado, remoto e E2E
  continuam pacotes separados.
- **Classificação final D2:** atividade D2 concluída; ação Supabase
  `units.import` continua `audited`/RED, não `local-green`, `remote-green`, E2E
  ou `done`.

### Checkpoint seguro 15 — `units.import` D3a local, sem migration

#### Recorte executado e sequência RED→GREEN

- **Action_id:** somente `units.import`; `units.export` não foi iniciado.
- **Nível realmente executado:** pacote Intermediário D3a local. A atividade
  contratada D3a foi concluída, mas a ação Supabase, a tela, a integração
  Flutter–Supabase e o produto permanecem pendentes.
- **RED 1 — autenticação do boundary:** registrado
  `[functions.import-export-jobs]` com `verify_jwt = true` no `config.toml`
  canônico. O teste focado evoluiu de 2/5 para 3/5 verdes.
- **RED 2 — gateway legado fechado:** `unit-import` deixou de chamar os RPCs
  públicos Unit de create/status/confirm/retry e passou a usar os RPCs
  canônicos do hub, com `p_domain = 'units'`, sem reabrir grant. O teste focado
  evoluiu de 3/5 para 4/5 verdes.
- **RED 3 — falha parcial pós-upload:** o hub registra em memória somente o path
  devolvido pelo upload contract autorizado, marca se o objeto foi criado pela
  própria tentativa e, em erro posterior de parse/contagem/preview, tenta
  remover esse objeto privado antes de registrar a falha escopada do job. Um
  objeto preexistente aceito por idempotência não é removido. O teste focado
  evoluiu de 4/5 para 5/5 verdes.

#### Evidências locais

- `units_import_boundary_red_test.ts`: 5/5 testes Deno verdes.
- `bridge_test.ts` + `xlsx_guard_test.ts`: 7/7 testes verdes.
- `unit-import/failure_scope_test.ts`: 2/2 testes verdes.
- **Regressão proporcional:** 14/14 testes verdes; `deno check` verde para as
  duas Edge Functions e `deno fmt --check` verde para os arquivos do recorte.
- A primeira tentativa de executar as suítes de duas funções a partir da raiz
  falhou apenas porque o Deno não aplicou os `deno.json` por diretório; a
  reexecução em cada diretório canônico passou. Nenhuma dependência foi alterada.
- Documentação atual do plugin oficial Supabase confirmou configuração
  individual de função no `config.toml`, verificação JWT no gateway e uso
  server-side de Storage. Nenhuma ferramenta mutante foi acionada.
- **Gate de conhecimento:** `no-op`, pois nenhuma regra durável nova de produto
  foi aprovada; o comportamento já deriva da spec 033 e ficou registrado na
  fonte operacional. Os scripts `Search-CoeloKnowledge.ps1` e
  `Test-CoeloKnowledge.ps1` referidos pela skill não existem neste checkout, de
  modo que a validação automatizada da projeção ficou indisponível.

#### RED preservado, lacunas e classificação

- **RED SQL deliberadamente preservado:**
  `superadmin_retry_import_export_job(job_id, null)` ainda aceita `request_id`
  nulo. O pgTAP D2 permanece 10/11 e está bloqueado até grant nominal de
  migration; nenhum SQL, RPC ou arquivo de migration foi tocado no D3a.
- **Ainda ausente:** CSV e XLSX reais; HTTP autenticado com identidades reais;
  tenant A/B por linha; sessão/vínculo revogado em todas as transições;
  job/request/path/checksum/MIME adulterados no worker real; replay idêntico;
  concorrência de create/upload/preview/confirm/retry; falha real de remoção;
  ausência comprovada de órfão; clean-stack focado; Flutter/E2E e remoto.
- **Estado da ação:** `units.import` continua `audited`, não `local-green`,
  `remote-green`, E2E ou `done`. Nenhuma tela Supabase foi declarada concluída.
- **Estado Flutter:** o contrato do cliente aponta ao hub, mas a integração
  produtiva e o E2E continuam não comprovados; este pacote não alterou Flutter.
- **Estado remoto:** não consultado nem alterado neste pacote; sem deploy,
  migration, SQL, Advisors mutantes ou configuração remota.
- **Estado Git/operações:** nenhum stage ou commit; nenhum processo persistente;
  nenhuma migration, RPC, RLS, grant, fixture, secret ou dependência alterada.

#### Próximo passo seguro e ETA D3b

1. obter grant nominal para uma migration mínima que rejeite `request_id` nulo
   antes de lock ou transição e executar o pgTAP 10/11→11/11 (1–2 h);
2. adicionar fixtures reais CSV/XLSX e provar upload→parse/preview→compensação,
   incluindo falha da remoção e ausência de órfão (2–4 h);
3. fechar tenant A/B, revogação entre transições, adulteração e
   replay/concorrência em lotes RED→GREEN (2–3 h).

- **ETA D3b local:** 5–9 h. Remoto autorizado, deploy e Flutter/E2E são pacotes
  posteriores e não estão incluídos nessa estimativa.
- **Posição atual na ordem:** D3a encerrado após o terceiro GREEN; retomar pelo
  RED SQL de `request_id` nulo, sem iniciar `units.export`.
- **Tempo restante do pacote D3a:** 0; pacote contratado concluído dentro da
  janela, sem ampliar o escopo.

### Checkpoint seguro 16 — `units.import` D3b comportamental, sem migration

#### Recorte e artefatos de teste

- **Action_id:** somente `units.import`; `units.export` não foi iniciado.
- **Modalidade e nível:** uma ação, pacote Intermediário local de testes e
  fixtures. Nenhum arquivo de produção, Edge Function, `config.toml`, migration,
  RPC, RLS, grant, purge ou dependência foi alterado.
- **Harness Deno:**
  `supabase/functions/import-export-jobs/units_import_d3b_behavior_test.ts`.
  Gera em memória um CSV real e um XLSX binário real, ambos com linhas das
  Instituições A e B, e executa o `handler` de produção contra um Supabase local
  simulado pelo teste.
- **Harness pgTAP:**
  `supabase/tests/unit_import_d3b_real_identity_behavior_test.sql`. Cria pessoas,
  usuários Auth, links, roles, memberships e Instituições reais dentro de uma
  transação; helpers exclusivos ficam em `pg_temp`. Tudo termina em `ROLLBACK`,
  sem ampliar grants produtivos ou persistir fixtures.

#### Resultado por gate

| Gate | Evidência local | Estado |
| --- | --- | --- |
| CSV real A+B | Parser de produção enviou as duas linhas corretas à prévia. | `GREEN` |
| XLSX real A+B | Guardas ZIP/workbook e parser de produção enviaram as duas linhas corretas. | `GREEN` |
| AAL1 | Usuário Auth, link e membership reais foram negados sem AAL2. | `GREEN` |
| Capability ausente | Membership real sem `units.import` foi negada no create. | `GREEN` |
| Link Auth revogado | JWT ainda válido não superou `person_auth_links` inativo. | `GREEN` |
| Membership revogada no upload | JWT AAL2 e link ativo ainda obtiveram o upload contract após revogar a membership. | `RED` |
| Membership revogada no confirm | A confirmação revalidou capability e foi negada. | `GREEN` |
| Cross-actor | Ator B não obteve upload contract nem confirmou o job do ator A. | `GREEN` |
| UUID HTTP malformado | Rejeitado antes de qualquer chamada ao backend. | `GREEN` |
| Path adulterado na Edge | Path divergente devolvido pelo contrato foi aceito e alcançou Storage. | `RED` |
| Path canônico no banco | Worker server-only ignorou objeto estrangeiro e exigiu o path derivado do job. | `GREEN` |
| MIME/tamanho/checksum | MIME HTTP, metadata Storage e checksum de replay adulterados foram negados. | `GREEN` |
| Replay idêntico | Create persistiu um job; attestation persistiu uma linha. | `GREEN` |
| Duas sessões Edge | Duas chamadas concorrentes com os mesmos bytes reutilizaram o objeto sem divergência. | `GREEN local simulado` |
| Falha de parse/preview | Objeto novo foi removido antes do registro de falha do job. | `GREEN` |
| Falha do delete | A falha do job continuou auditável, mas o objeto permaneceu órfão. | `GAP` |
| Retry sem request | `superadmin_retry_import_export_job(job_id, null)` continuou sem exceção. | `RED bloqueado por migration` |

#### Contagens e regressão

- **D3b novo:** 33 casos executados; 31 passaram e 2 REDs comportamentais
  permaneceram (path Edge e membership revogada no upload contract).
- **RED D2 revalidado:** 11 casos pgTAP; 10 passaram e o mesmo RED de
  `request_id` nulo permaneceu. O arquivo e o SQL de produção ficaram intactos.
- **Regressão Deno existente:** 14 testes executados; todos os 14 passaram.
- **Regressão pgTAP existente:** 58 testes executados; todos os 58 passaram
  (`import_export_hub_security`, lifecycle closure e Unit import/export).
- **Matriz final:** 116 casos considerados; 113 passaram e 3 REDs conhecidos
  permaneceram. Todas as execuções SQL terminaram em `ROLLBACK`.
- `deno check` e `deno fmt --check` passaram no novo harness Deno.

#### Causas confirmadas e limites

1. `import-export-jobs` usa o path retornado pelo upload contract sem conferir
   novamente `imports/units/<job_id>/source.<formato>`. O RPC gera corretamente
   o path, mas a Edge não aplica defesa em profundidade contra resposta
   divergente.
2. `app_private.assert_import_export_hub_actor()` valida identidade e AAL2, mas
   não exige membership ativa ou `units.import`; por isso o upload contract
   continua acessível após revogar a membership. Preview/confirm revalidam mais
   tarde, porém o upload privado desnecessário ainda pode ocorrer.
3. O retry com `request_id` nulo continua exigindo mudança de migration/RPC, fora
   do grant D3b.
4. Se o Storage falhar ao remover o objeto, o job fica auditável como falha, mas
   não existe retry/purge autorizado neste recorte para garantir ausência de
   órfão.
5. Concorrência real entre duas conexões Postgres não cabe numa transação pgTAP
   isolada sem fixtures visíveis entre sessões. A Edge foi exercitada com duas
   promises concorrentes e o banco mantém advisory locks comprovados; o teste
   multi-conexão continua pendente.

#### Estado, parada e retomada

- **Atividade contratada D3b sem migration:** concluída; os testes e fixtures
  autorizados foram entregues e os REDs foram preservados, não mascarados.
- **Ação Supabase:** `units.import` continua `audited`, não `local-green`,
  `remote-green` ou `done`.
- **Tela e integração:** Unidades e Flutter–Supabase não estão concluídos; não
  houve alteração nem execução Flutter/E2E.
- **Estado remoto:** não consultado nem alterado; sem deploy ou Advisors remotos.
- **Estado Git:** nenhum stage ou commit. Nenhum processo novo persistente.
- **Próximo passo seguro:** D3c com grant nominal para produção/migration, nesta
  ordem: validar path na Edge (0,5–1,5 h), reautorizar membership/capability no
  upload contract (1–2 h), rejeitar `request_id` nulo (1–2 h), definir retry ou
  purge de cleanup e teste multi-conexão (2–4 h).
- **ETA D3c local:** 4,5–9,5 h; remoto/deploy/Flutter E2E continuam pacotes
  posteriores.
- **Tempo restante do D3b contratado:** 0; parada segura após a matriz final e
  antes de qualquer alteração de produção.

### Checkpoint seguro 17 — `units.import` D3c-EDGE, path canônico

#### Recorte e correção

- **Action_id:** somente `units.import`; `units.export` não foi iniciado.
- **Nível realmente executado:** pacote Intermediário local e focado em um RED.
  A atividade D3c-EDGE foi concluída; a ação Supabase continua `audited`.
- **Correção:** após obter o upload contract, a Edge deriva exclusivamente
  `imports/units/<job_id>/source.<csv|xlsx>` a partir do `job_id` solicitado e do
  MIME permitido. `upload.job_id` e `upload.path` precisam coincidir exatamente
  com esse valor antes que qualquer chamada ao Storage ou compensação seja
  autorizada.
- **Falha fechada:** contrato adulterado recebe `422` com erro uniforme
  `invalid_upload_contract`, sem consulta ao objeto e sem revelar sua existência.
  O path não confiável também não entra no caminho de cleanup.

#### RED→GREEN e regressão proporcional

| Gate | Antes | Depois |
| --- | ---: | ---: |
| Path adulterado antes do Storage | 0/1, resposta `200` | 1/1, resposta `422` |
| Harness D3b Deno completo | 9/10 | 10/10 |
| Regressão Deno existente do hub e legado | — | 14/14 |
| `deno check` | — | 2 arquivos aprovados |
| `deno fmt --check` | — | 2 arquivos aprovados |

- O primeiro `fmt --check` detectou apenas a expressão MIME recém-editada; o
  formatador canônico foi aplicado ao mesmo arquivo e o gate repetido passou.
- Nenhum teste SQL foi repetido neste pacote e nenhum resultado anterior foi
  promovido: o RED de `request_id` nulo e o RED de membership revogada continuam
  preservados.

#### Estado, lacunas e retomada

- **Ainda pendente em `units.import`:** reautorizar membership/capability no
  upload contract; rejeitar `request_id` nulo; definir retry/purge para falha de
  remoção e provar ausência de órfão; executar concorrência Postgres real entre
  conexões; validar Flutter/E2E e, quando autorizado, o ambiente remoto.
- **Fora do recorte e intacto:** SQL, migrations, RPCs, RLS, grants,
  `config.toml`, purge/retry, `units.export` e Flutter.
- **Estado remoto:** não consultado nem alterado; nenhum deploy, SQL, migration
  ou Advisor mutante.
- **Estado Git/operações:** nenhum stage ou commit; nenhum processo persistente
  iniciado. Secrets e operações Git destrutivas não foram adicionados.
- **Próximo passo seguro:** somente com novo grant nominal, corrigir a
  reautorização do upload contract (1–2 h), depois o `request_id` nulo via
  migration (1–2 h), e por fim cleanup/concorrência (2–4 h). Total local restante
  estimado: 4–8 h, sem remoto nem Flutter/E2E.
- **Tempo restante do D3c-EDGE contratado:** 0; parada segura após o GREEN e os
  gates locais.

### Checkpoint seguro 18 — `units.import` D3d concorrência e cleanup RED

#### Recorte e ambiente isolado

- **Action_id:** somente `units.import`; `units.export` não foi iniciado.
- **Nível executado:** pacote Intermediário local de teste/harness. Nenhum
  arquivo Edge de produção, configuração, SQL, migration, RPC, RLS, grant, cron,
  retry ou purge foi alterado.
- **Concorrência real:** o harness Deno abriu processos `psql` independentes
  contra um banco local descartável `coelo_d3d_multiconnection`. O banco recebeu
  o schema e somente os catálogos mínimos necessários; foi removido em `finally`.
  O banco compartilhado não foi resetado nem usado como prova reprodutível.

#### Resultado por gate

| Gate D3d | Evidência | Estado |
| --- | --- | --- |
| Create, replay idêntico | Duas conexões com a mesma chave retornaram o mesmo `job_id`; uma linha persistiu no banco descartável. | `GREEN` |
| Create, payload divergente | A conexão concorrente com nome diferente e mesma chave recebeu `idempotency key replay mismatch`; uma linha persistiu. | `GREEN` |
| Upload contract | Duas conexões receberam o mesmo path server-owned. | `GREEN` |
| Preview idêntico | Duas conexões convergiram para um job, uma attestation e uma linha de preview. | `GREEN` |
| Preview divergente | Checksum/payload divergente recebeu `unit import source replay mismatch`. | `GREEN` |
| Confirm | Duas conexões retornaram o mesmo job; uma transição/auditoria de confirmação foi registrada. A fixture mínima terminou `REJEICAO`, sem unidade criada, e não foi promovida como sucesso funcional. | `GREEN de serialização` |
| Retry | Duas conexões com o mesmo request convergiram para `PENDENTE` e um único `retry_request_id`. | `GREEN` |
| Falha de delete pós-upload | Resposta permaneceu `422` e `superadmin_fail_unit_file_job` registrou a falha; o objeto privado continuou presente. | `RED cleanup` |

- **Teste de concorrência:** um teste Deno executado; o teste passou e removeu o
  banco descartável, dumps e processos.
- **Matriz Edge/cleanup:** onze testes executados; dez passaram e o único RED
  deliberadamente preservado exige que não exista órfão depois de falha do
  delete.
- **Correções do harness:** o primeiro cleanup tentou `DELETE` protegido de
  Storage e o segundo encontrou a trilha append-only. As fixtures dessa tentativa
  foram removidas e a consulta final no banco compartilhado retornou zero. O
  harness final não repete esses bypasses: usa banco descartável e o derruba.
- **Contrato corrigido no teste:** o payload canônico usa `job_id`; uma asserção
  pgTAP anterior comparava `id` nulo com `id` nulo e não provava o identificador.

#### Estado, bloqueios e próximo patch mínimo

- **Atividade contratada D3d:** concluída. A ação `units.import` permanece
  `audited`, não `local-green`, `remote-green`, E2E ou `done`.
- **REDs restantes:** membership revogada ainda obtém upload contract;
  `request_id` nulo ainda é aceito no retry; delete indisponível deixa órfão.
- **Menor patch futuro de cleanup:** persistir uma solicitação de limpeza
  idempotente, ligada a `job_id`, bucket e path server-owned, quando `remove`
  falhar; worker server-only com lock/claim, retry limitado, auditoria de cada
  tentativa e conclusão; purge de retenção remove objeto antes dos metadados e
  mantém falha observável/DLQ. Exige grant nominal para SQL/migration, Edge e
  cron; não foi iniciado neste pacote.
- **Estimativa futura:** contrato/migration de cleanup 1–2 h; worker e negativas
  2–4 h; concorrência/replay e ausência de órfão 1–2 h. Total local 4–8 h,
  seguido de remoto e Flutter/E2E em pacotes separados.
- **Cleanup final D3d:** zero banco descartável, zero dump, zero fixture D3d no
  banco compartilhado e nenhum processo persistente.
- **Estado remoto/Git:** remoto não consultado nem alterado; nenhum deploy,
  stage ou commit.
- **Tempo restante do D3d contratado:** 0; parada segura antes de qualquer patch
  de produção.

### Checkpoint seguro 19 — `units.export` D1+D2 local, contrato e REDs

#### Recorte, nível e boundary

- **Action_id:** somente `units.export`. `units.import`, o checkpoint D3d e os
  paths Flutter permaneceram imutáveis.
- **Nível realmente executado:** Intermediário local de inventário, reprodução
  e testes RED. A atividade D1/D2 foi concluída; a ação Supabase continua
  `audited`, não `local-green`, `remote-green`, E2E ou `done`.
- **Boundary canônico inventariado:** cliente → Edge `import-export-jobs` →
  worker `unit-export` → RPCs de request/status/materialização/
  `superadmin_unit_export_page_v2`/conclusão → bucket privado
  `coelo-operations`.
- **Limites atuais:** importação usa 5.000 linhas; exportação local usa 50.000
  linhas e páginas keyset de até 500; o artefato é limitado a 5 MiB no bucket e
  na conclusão; URLs assinadas declaram 300 segundos. Os limites propostos de
  body/arrays Edge ainda não são decisão aprovada.

#### Evidência executada

| Suíte | Resultado | Classificação |
| --- | ---: | --- |
| `failure_scope_test.ts` | 2 GREEN / 0 RED | Regressão estrutural existente. |
| `units_export_boundary_red_test.ts` | 1 GREEN / 2 RED | Contratos estáticos de reautorização final e purge. |
| `units_export_artifact_storage_red_test.ts` | 1 GREEN / 3 RED | Fixture CSV/XLSX real; demais gates são contratos estáticos, não E2E de Storage. |
| `units_export_hub_boundary_red_test.ts` | 1 GREEN / 11 RED | Handler mockado e ledger de grants; inclui UUID de instituição adulterado. |
| `unit_export_d2_behavior_test.sql` | 12 GREEN / 1 RED | Comportamento SQL local transacional, com rollback e zero fixture persistida. |

- **Deno combinado após deduplicação:** 21 testes, 5 GREEN e 16 RED. `fmt
  --check` e `deno check` passaram nos quatro arquivos Deno.
- **SQL comportamental:** AAL1 e capability ausente negaram; replay idêntico
  convergiu no mesmo job; payload divergente e cross-actor negaram; `page_v2`
  permaneceu estável sobre snapshot sem gaps; membership revogada negou a
  paginação. Os atores A/B são owners globais distintos: esta suíte não prova
  isolamento institucional tenant A/B, materialização concorrente nem os
  limites 50.000/50.001.
- **Artefatos:** CSV e XLSX sintéticos com linhas de duas instituições foram
  gerados/abertos e o CSV neutralizou fórmula. Isso não prova upload real,
  download real, MIME remoto ou expiração temporal.

#### REDs e causa corrente

1. `request_export` aceita UUID idempotente, domínio, formato e UUID de filtro
   adulterados antes do primeiro RPC; o materializador descarta UUID inválido e
   pode ampliar silenciosamente o conjunto. Body e arrays também não têm limite
   Edge explícito; 64 KiB/100 itens permanecem apenas proposta a decidir.
2. O DTO de status retransmite `storage_path` e checksum quando recebidos do
   backend, em vez de usar allowlist pública.
3. `unit-export` aceita JWT de navegador sem prova de delegação server-owned.
   `superadmin_request_unit_export`, `superadmin_unit_export_page_v2` e
   `superadmin_get_unit_file_job` seguem executáveis por `authenticated`.
   Revogá-los só é seguro no mesmo pacote que introduzir e provar o replacement
   hub → worker; isoladamente quebraria o worker atual.
4. Após request válido e revogação da membership, o materializador privilegiado
   ainda cria/reutiliza o snapshot. Também falta reautorização depois da última
   página e antes de upload/conclusão/assinatura.
5. O worker não barra `generated.bytes.length` acima de 5 MiB antes do upload;
   depende das barreiras posteriores do Storage/RPC.
6. Remint/download não prova em conjunto job, path server-owned, ownership,
   vínculo/capability vigentes, retenção e objeto não deletado antes de assinar.
7. Falha de `remove` é best effort sem receipt/queue durável. Não há claim,
   retry e complete auditáveis para purge; export vazio e falha de assinatura
   após completion também não têm prova comportamental terminal.

#### Paridade, bloqueios e próximo passo

- **Local:** hub, worker, RPCs, snapshot e `page_v2` existem. Snapshot
  concorrente/idempotente, filtros institucionais A+B, 50.000/50.001,
  persistência de checksum/retenção e ausência de órfão ainda não foram
  comprovados comportamentalmente.
- **Remoto:** não foi consultado nem alterado nesta rodada. A evidência histórica
  registra `unit-export` ACTIVE v8/`verify_jwt=true`, limite remoto de 5.000,
  `import-export-jobs` ausente e contrato/grants incompatíveis com o local; não
  há `remote-green`.
- **Flutter:** equipe separada trabalha HARDEN-EXPORT A+B em cliente/gateway/UI
  e mantém a composição `Unavailable`. Este pacote não tocou Flutter nem prova
  integração Flutter–Supabase ou E2E.
- **D3a proposto, não autorizado — hub/autoridade (3–5 h):** decidir limites;
  validar tipos/UUIDs/arrays antes da RPC; DTO allowlist; delegação worker-only;
  teste positivo hub → worker; só então revogar os três gateways legados.
- **D3b proposto, não autorizado — worker/artefato (3–6 h):** reautorizar ator
  em materialização e conclusão; limite pré-upload; path/MIME/checksum;
  retenção, expiração e remint fail-closed.
- **D3c proposto, não autorizado — lifecycle (4–8 h):** concorrência e snapshot
  real; 50.000/50.001; filtros A+B; estados de falha; cleanup idempotente e
  purge claim/complete sem órfão.
- **Estimativa local restante:** 10–19 h. Remoto/deploy/Advisors e Flutter E2E
  exigem autorização e pacotes separados.
- **Parada segura:** primeiro gate ainda não iniciado é a decisão/autorização de
  D3a. Nenhum arquivo de produção, Edge, config, SQL, migration, RPC, RLS,
  grant ou Storage foi alterado; nenhum remoto, deploy, stage ou commit ocorreu.
  Nenhuma fixture permaneceu e nenhum processo iniciado pela atividade ficou
  ativo.
- **Classificação final:** atividade D1/D2 concluída; ação `units.export`, tela
  Units, integração Flutter–Supabase e produto continuam pendentes.

### Checkpoint seguro 20 — `units.export` D3a Edge local

#### Recorte, nível e estado

- **Action_id:** somente `units.export`; nenhum path Flutter, SQL, migration,
  RPC, RLS, grant, cron ou configuração foi alterado neste pacote.
- **Nível realmente executado:** Avançado local parcial, restrito a Edge e
  testes. A atividade D3a foi concluída; a ação permanece `audited`, não
  `local-green`, `remote-green`, E2E ou `done`.
- **Produção:** continua fail-closed. O cliente produtivo segue com gateway
  indisponível e este pacote não autoriza habilitar a integração.
- **Tempo do pacote D3a:** encerrado, com zero etapa autorizada restante.

#### Correções e evidências por grupo

| Grupo | Correção local | RED → GREEN / evidência |
| --- | --- | ---: |
| 1. Hub e DTO | Body real limitado a 64 KiB; `action/domain/format`, UUIDs, tipos, chaves, arrays e allowlists são validados antes do primeiro RPC. `plan_ids` aceita código limitado já suportado pelo diretório. DTO público usa allowlist e omite `summary.storage_path`, checksum, `result` e `errors` não confiáveis. | 7 gates GREEN, mais regressão positiva de plan code. |
| 2. Artefato | Teto exato de 5 MiB é aplicado antes do Storage. CSV neutraliza `=`, `+`, `-` e `@` mesmo após espaço, tab, CR ou LF. CSV/XLSX reais preservaram linhas. | 2 gates GREEN. |
| 3. Reautorização | O ator é reautorizado com o JWT do cliente depois da última página, imediatamente antes do upload e novamente antes da conclusão. | 1 gate GREEN; o RED SQL de revogação antes da materialização permanece. |
| 4. Status/download | Assinatura exige estado `SUCESSO`, `job_id` exato e path server-owned `exports/units/<job>/<uuid>.<csv|xlsx>`. Payload de outro job recebe resposta fail-closed. | 2 gates GREEN; retenção canônica permanece RED. |
| 5. Vazio | Export sem linhas registra falha autorizada/auditável e retorna 409 sem alcançar Storage ou conclusão. | 1 gate GREEN. |

- **Matriz Deno final:** 29 testes focados, 18 GREEN e 11 RED deliberadamente
  preservados. Os quatro REDs novos materializam riscos já existentes de replay
  e pós-conclusão; não são regressões introduzidas pelo D3a.
- **Regressão proporcional do hub de importação:** `bridge_test.ts` e
  `xlsx_guard_test.ts`, 7/7 GREEN.
- **Gates estáticos:** `deno check` passou para os dois handlers e seis arquivos
  focados; `deno fmt --check` passou após formatação canônica.
- **Lint proporcional:** o handler `unit-export` passou. O handler do hub ainda
  acusa somente `MAX_BYTES` não usado, débito preexistente fora do recorte; os
  testes focados também têm avisos `require-await`/`prefer-const` de harness, sem
  erro de tipo ou mudança de comportamento.
- **SQL D2:** permanece 12 GREEN / 1 RED e não foi repetido, pois este pacote não
  alterou SQL. O RED é materialização privilegiada após revogação do vínculo.

#### REDs preservados e bloqueios

1. O worker `unit-export` ainda aceita Bearer do navegador sem delegação
   server-owned; três RPCs legados continuam concedidos a `authenticated`.
2. Revogação depois do request ainda permite que a materialização privilegiada
   processe dados antes da reautorização Edge.
3. Remint não dispõe de evidência canônica de retenção viva; a expectativa de
   objeto temporário de 24 h da spec 018 não prova expiração física no runtime.
4. Falha de delete continua sem receipt/queue durável; purge não possui
   claim/retry/complete auditáveis.
5. Replay de job já `SUCESSO` rematerializa e pode enviar outro path; duas
   execuções concorrentes ainda não possuem lease/CAS server-side.
6. Resposta perdida após completion pode apagar um objeto que já se tornou
   canônico; falha de signed URL depois do completion também tenta apagar o
   objeto e demover o job.
7. Falta reautorização depois do commit de completion e imediatamente antes de
   emitir a URL assinada.
8. Tenant A/B, IDs/path adulterados em runtime, remoto e Flutter E2E continuam
   sem prova ponta a ponta.

#### Decisão de escopo e contrato futuro

- `global-only` não é regra de produto aprovada. Owner global + AAL2 é o único
  baseline transitório inequívoco; Operations não deve ser promovido.
- OQ-032, ADR 0019 e OQ-034 bloqueiam o contrato: o runtime atual exige vínculo
  platform/global para pedir export, mas materializa por `units.read`
  institucional, e `platform_memberships/person_id` diverge do modelo de
  identidade aprovado.
- Filtros enviados pelo cliente nunca definem alcance. O contrato futuro deve
  persistir escopo autoritativo derivado do vínculo, exigir instituição
  explícita, reautorizar request/materialize/complete/sign/remint e materializar
  pela capability `units.export`.
- Desenho futuro recomendado, **não autorizado nesta rodada:** M1 expand com
  runtime privado por job, actor/session/state/version, lease/CAS e cleanup
  queue; Edge switch; depois M2 contract revogando os RPCs legados. Backfill não
  fabrica sessão/checksum: item legado não atestável fica não baixável e entra
  em cleanup.

#### Signed URL e cache — documentação oficial Supabase

- URL assinada de bucket privado continua utilizável até sua expiração mesmo se
  Auth for revogado ou rotacionado; remint/download deve reautorizar.
- Com Smart CDN, resposta já cacheada pode continuar disponível até o TTL do
  cache mesmo depois de expirar o token. Excluir o objeto invalida os caches,
  com propagação documentada de até aproximadamente 60 segundos.
- Portanto, estado local `expired` não prova indisponibilidade física imediata.
  TTL e `cacheControl` conservadores, cleanup por objeto e teste específico
  permanecem gates futuros.
- Fontes: [Storage downloads](https://supabase.com/docs/guides/storage/serving/downloads)
  e [Smart CDN](https://supabase.com/docs/guides/storage/cdn/smart-cdn).

#### Próximo passo seguro e estimativa

- **Próximo grant necessário:** decisão de escopo e migration em duas fases.
  M1 + Edge switch deve provar runtime privado, sessão/vínculo/capability,
  ownership, lease/CAS, retention e cleanup; M2 só revoga grants depois do fluxo
  hub → worker estar provado.
- **ETA release-blocker futuro:** 11–18 h locais para M1 + Edges + M2 + gates;
  remoto autorizado exige mais 6–10 h. SQL isolado sem Edge não é liberável.
- **Estado local:** D3a Edge implementado e testado; 11 REDs preservam os
  bloqueios fora do grant. Nenhuma fixture ou processo persistente é esperado.
- **Estado remoto:** não consultado nem alterado; nenhum deploy ou Advisors.
- **Git:** nenhum stage ou commit.
- **Classificação final:** atividade D3a concluída; ação Supabase
  `units.export`, tela Units, integração Flutter–Supabase e produto continuam
  pendentes.

### Checkpoint seguro 21 — correção pós-D3a do contrato DTO

#### Regressão confirmada e correção

- A revisão pós-D3a confirmou que o `status` genérico aplicava o sanitizer de
  exportação também aos jobs de importação. Isso removia `result` e `errors`
  necessários ao contrato de status/import e não estava coberto pela regressão
  anterior de 7/7.
- O hub agora separa DTO de import e export. Import preserva somente
  `result.{created_count,updated_count,linked_count,ignored_count,
  rejected_count,completed_at}` e
  `errors[].{row_number,field,code,message}`; IDs internos, path, checksum e
  chaves arbitrárias são removidos.
- Export normaliza as três ações para `domain=units`, `direction=export`,
  `job_id`, `format`, `state`, timestamps e summary público. Valores aninhados
  sob chaves permitidas são descartados por tipo, impedindo vazamento recursivo.
- `request_export` compara o job retornado pelo worker com o job criado pelo
  hub; `status` e `download` comparam com o `job_id` solicitado. Estado, formato,
  origem e timestamps inválidos falham fechado.
- `status` e `download` agora rejeitam chaves raiz extras antes do primeiro RPC.
  Na ação `download`, o DTO só expõe URL HTTPS em `SUCESSO` e declara
  `expires_in=300`. O teste usa resposta mockada: não comprova a expiração real
  da URL, o host de origem nem o comportamento remoto; o hub aceita qualquer
  host HTTPS sintaticamente válido.

#### Evidência e estado

- **Hub DTO:** 31 testes, 27 GREEN e quatro RED externos preservados: worker
  direto e três grants legados.
- **Matriz Deno focada total:** 47 testes, 36 GREEN e os mesmos 11 REDs já
  catalogados. Nenhum RED novo permanece dentro do sanitizer.
- **Regressão import do hub:** `bridge_test.ts` + `xlsx_guard_test.ts`, 7/7
  GREEN. O teste novo de status/import prova agora o conteúdo allowlisted, não
  somente presença de rota.
- **Gates:** `deno fmt --check` e `deno check` passaram nos dois handlers e nos
  arquivos focados.
- **Worker direto, RED explícito:** resposta atual ainda é HTTP 200 e vaza
  `institution_id`, `summary.storage_path`, checksum, `result` e `errors` quando
  chamado com Bearer do navegador. A correção depende de delegação server-owned
  e revogação coordenada dos grants; continua fora deste gate.
- **Flutter:** o gateway local atualmente espera URL já em `request_export`,
  enquanto este contrato restringe emissão a `download`. Como a composição
  produtiva permanece `Unavailable`, não houve regressão produtiva habilitada,
  mas a integração Flutter–Supabase está explicitamente bloqueada até alinhar o
  fluxo request → status → download.
- **Estado remoto/Git:** nenhum remoto, migration, deploy, stage ou commit.
- **Classificação:** correção DTO pós-D3a concluída; `units.export` continua
  `audited` e fail-closed; tela, integração e produto continuam pendentes.
- **Próximo passo seguro:** alinhar o contrato Flutter request/status/download
  e, em grant separado com migration, introduzir delegação server-owned antes de
  revogar os três RPCs legados.

### Checkpoint seguro 22 — Instituições import/export runtime-broken

#### Recorte e classificação

- **Action_ids afetados:** `institutions.import` e `institutions.export`.
- **Estado corrigido:** ambas passam de `local-green` para `fail-closed`.
- **Limite de conclusão:** atividade de auditoria somente leitura concluída;
  ações Supabase, tela, integração Flutter–Supabase e produto continuam
  pendentes.

#### Evidência local e remota

- O clean-stack reproduziu que a história atual não é diretamente instalável:
  `20260811215451_access_profile_management_v2.sql` torna `module_label`,
  `screen_label` e `action_label` obrigatórios antes de
  `20260811220646_institution_import_export.sql` inserir permissões sem esses
  campos. A cronologia histórica de aplicação diverge da ordenação atual dos
  filenames; não reescrever migration implantada sem decisão explícita.
- Após compatibilidade exclusivamente diagnóstica fora do repositório,
  `supabase db lint` encontrou:
  - `app_private.superadmin_confirm_institution_import`: referências ambíguas a
    `created_count`/`rejected_count`, SQLSTATE `42702`;
  - `app_private.superadmin_request_institution_export`: referências a
    `institution_directory.slug` e `updated_at`, ausentes da view, SQLSTATE
    `42703`.
- O plugin oficial `@Supabase`, em leitura somente, confirmou que os wrappers
  públicos correspondentes estão implantados e possuem `EXECUTE` para
  `authenticated`. A view remota também não expõe `slug` nem `updated_at`.
- Advisors remotos permaneceram no baseline: 207 de segurança e 505 de
  desempenho. Nenhuma mutation, migration, repair, deploy ou configuração
  remota foi executada.

#### Incidente e limites do ambiente local

- O comando diagnóstico com `db reset --db-url` reiniciou inesperadamente o
  stack compartilhado e deixou o banco local principal sem seed, com zero
  usuários, sessões, instituições, unidades, pessoas, jobs e objetos. O remoto
  não foi afetado.
- O ledger local pós-incidente contém 173 versões, mas não constitui prova de
  localhost limpo nem é reproduzível pelo HEAD atual. O estado anterior não deve
  ser inferido ou reconstruído sem backup.
- Nenhum stage ou commit foi realizado pela atividade Supabase que produziu
  esta evidência.

#### Ordem e próximo passo seguro

1. decidir a estratégia de história reproduzível das migrations sem mascarar a
   cronologia implantada;
2. escrever REDs focados para `42702` e `42703`;
3. corrigir uma função por vez em migration forward-only autorizada;
4. provar autorização, AAL2, vínculo revogado, tenant A/B, IDs/filtros
   adulterados, replay e arquivos reais;
5. repetir clean-stack em ambiente realmente isolado, lint, regressão e somente
   então remoto autorizado/E2E.

- **ETA local:** 4–8 h para história + dois RED/GREEN + regressão proporcional.
- **Remoto/E2E:** pacote separado, autorizado e estimado depois do GREEN local.

### Checkpoint seguro 23 — estado do recorte contratado e retomada

#### Resposta objetiva

- **A atividade contratada Opção B (`Avançada`) não está concluída.** O
  inventário, a consolidação e vários pacotes locais foram executados, mas a
  história de migrations ainda não é reproduzível pelo HEAD e os dois primeiros
  P0 confirmados de Instituições ainda não receberam RED/GREEN forward-only.
- **Recorte contratado vigente:** fundação `SUP-GEN-002`/`SUP-GEN-016` e a
  primeira fatia P0 comprovada, atualmente `institutions.import` e
  `institutions.export`.
- **Nível realmente executado:** Avançada parcial. Pacotes menores podem estar
  concluídos como atividades, mas nenhuma das quatro ações deste recorte está
  `done`, nenhuma tela Supabase foi concluída e não há integração E2E concluída.

#### O que foi executado e sua evidência

| Atividade/pacote | Estado da atividade | Evidência disponível | Limite de conclusão |
| --- | --- | --- | --- |
| Organização por tela, subtela e ação | concluída | 207 `action_id` únicos em 37 famílias, com nível, ETA, dependência, evidência e próximo passo | Não corrige automaticamente nenhuma ação. |
| Inventário canônico/mirror/remoto | concluído em leitura | 173 migrations canônicas, 173 no mirror, 103 remotas cobertas e 70 versões somente locais | A cronologia de aplicação não foi recuperada integralmente; replay do HEAD continua vermelho. |
| Inventário remoto e Advisors | concluído em leitura | Projeto ativo; 103 migrations; 207 Advisors de segurança e 505 de desempenho | Nenhuma validação remota mutável, SQL, migration, repair ou deploy foi autorizada/executada. |
| Pacotes locais de migrations e autorização anteriores | concluídos apenas nos respectivos grants | Checkpoints 1–19 registram pgTAP, Deno, negativos, tenant A/B, grants e REDs preservados | Cada ação mantém o estado conservador da tabela; teste local não prova remoto nem Flutter E2E. |
| `units.import` D1–D3d | pacote local concluído até o grant concedido | Contrato, RED/GREEN Edge, fixtures e concorrência focada; RED de `request_id` nulo e lacunas de retry/purge preservados | `units.import` continua `audited`/fail-closed, sem migration final, remoto ou E2E. |
| `units.export` D1–D3a e DTO | pacote local concluído até o grant concedido | Checkpoints 20–21: 47 testes Deno, 36 GREEN e 11 RED externos catalogados; DTO do hub endurecido | Worker direto, grants legados, revogação, retenção, cleanup, replay e Flutter continuam bloqueados; ação não está `done`. |
| `institutions.import`/`institutions.export` | auditoria P0 concluída | SQLSTATE `42702` e `42703` reproduzidos/classificados; remoto confirma wrappers/grants e forma da view | Ambas continuam fail-closed; nenhuma correção de produção foi aplicada. |

#### Pendências na ordem obrigatória

| Ordem | Ação/objeto | Trabalho restante | Nível mínimo | ETA local | Evidência de parada/conclusão |
| ---: | --- | --- | --- | ---: | --- |
| 1 | `SUP-GEN-002`/`SUP-GEN-016` — replay da migration `20260811220646` | Recuperar o artefato/log exato aplicado. Se não existir, obter autorização explícita para reparo histórico documentado de compatibilidade, adicionando os labels obrigatórios no canônico e mirror sem alegar identidade byte a byte com o remoto. | Avançada | 4–8 h | Proveniência registrada; canônico/mirror idênticos; teste estático do insert; reset em ambiente realmente isolado e reproduzível. |
| 2 | `institutions.import` — SQLSTATE `42702` | Criar migration forward-only com variáveis PL/pgSQL não ambíguas; RED/GREEN para sucesso, contagens, replay, AAL1, capability ausente, vínculo revogado, ator/tenant B, job/ID adulterado e ACL. | Avançada | 3–5,5 h | pgTAP focado e regressão verdes; replay divergente permanece explicitamente RED se exigir decisão adicional. |
| 3 | `institutions.export` — SQLSTATE `42703` | Criar migration forward-only que obtenha `slug`/`updated_at` da tabela canônica `public.institutions`, sem ampliar silenciosamente a view. | Avançada | 2–3,5 h | RED/GREEN runtime, autorização e regressão verdes; ação permanece fail-closed até fechar contrato e worker. |
| 4 | `institutions.export` — fechamento funcional | Decidir e implementar filtros, sort, snapshot, idempotência/replay, auditoria, worker/Storage, revogação, retenção e cleanup. | Completa | +8–14 h | Matriz positiva/negativa/cross-tenant, arquivos reais, persistência/reload e integração cliente comprovadas. |
| 5 | Remoto autorizado e Flutter E2E | Aplicar somente migrations aprovadas em ambiente classificado; repetir Advisors, runtime e fluxo Flutter request/status/download. | Avançada/Completa | estimar após GREEN local | Ledger, logs redigidos, Advisors comparados e E2E sem mock; nenhuma tela é promovida antes disso. |

O mínimo local restante do recorte Avançado atual é **9–17 horas** para as três
primeiras ordens. O fechamento funcional de `institutions.export` acrescenta
**8–14 horas locais** e pertence a um pacote Completo; remoto autorizado e E2E
são estimados separadamente. A ampliação decorre de defeitos P0 confirmados, não
da simples soma das 207 ações.

#### Dependências, bloqueios e critério de parada

- A cronologia factual indica, por histórico Git, que a migration de
  Instituições nasceu antes da migration de Access Profiles, embora os nomes
  atuais imponham a ordem inversa. Isso é evidência de provável ordem histórica,
  não substitui artefato ou log de deploy.
- Sem recuperar essa proveniência, qualquer edição da migration histórica exige
  decisão explícita e registro como reparo de compatibilidade de replay. Não
  renomear, fazer `migration repair`, squash ou fabricar equivalência remota.
- O próximo pacote para antes de mutation remota, mudança de escopo, conflito de
  ownership ou necessidade de decisão de produto. Nunca se retiram testes,
  autorização, RLS ou evidências para fazê-lo caber no tempo.
- A documentação oficial Supabase confirma que migrations são aplicadas na
  ordem dos timestamps e que `db reset` recria o banco e destrói os dados locais;
  o próximo reset deve usar ambiente comprovadamente isolado. Referências:
  [Managing migrations](https://supabase.com/docs/guides/deployment/database-migrations)
  e [Local development and database migrations](https://supabase.com/docs/guides/local-development/overview).

#### Estado para retomada e handoff

- **Posição atual:** parada segura imediatamente antes de qualquer edição de
  migration. Primeiro recuperar a origem exata de `11220646`; na ausência dela,
  solicitar o grant do reparo de compatibilidade descrito na ordem 1.
- **Estado local:** o incidente do Checkpoint 22 deixou o stack compartilhado sem
  fixtures e com ledger de 173 versões; esse estado não vale como clean-stack e
  não é reprodutível a partir do HEAD. Nenhuma nova mutation local foi feita
  neste checkpoint.
- **Estado remoto:** última leitura permanece em 103 migrations, 207 Advisors de
  segurança e 505 de desempenho; remoto não foi alterado.
- **Flutter–Supabase:** composição produtiva de Units permanece fail-closed; os
  contratos de import/export ainda não têm E2E. Instituições também permanece
  sem fluxo ponta a ponta concluído.
- **Pendências globais:** o catálogo conserva 207 ações e zero ação/tela/E2E
  promovida a conclusão global por este checkpoint. Itens fora do recorte
  permanecem com o estado individual da tabela da seção 7.
- **Git e entrega:** somente este rastreador foi atualizado neste checkpoint;
  nenhum stage, commit ou deploy foi criado. O delta deve ser revisado e
  integrado pela atividade Final Higenização a partir do worktree compartilhado.
- **Memória de conhecimento:** nenhuma regra durável de produto foi aprovada;
  portanto, não há projeção `docs/knowledge` a atualizar.

### Checkpoint seguro 24 — `units.export` replay pós-sucesso

- **Action_id:** somente `units.export`; alteração local em
  `supabase/functions/unit-export/index.ts`, sem migration, deploy ou mutação
  remota.
- **RED reproduzido:** replay de job `SUCESSO` chamava novamente
  `superadmin_materialize_unit_export_from_edge` e tentava novo upload.
- **Causa raiz:** após `superadmin_request_unit_export`, o worker ignorava o
  estado e o `summary.storage_path` canônico já retornados.
- **Correção mínima:** `successfulReplayArtifactPath` aceita somente mesmo
  `job_id`, domínio `units_export`, estado `SUCESSO`, formato permitido e path
  canônico; o ator é reautorizado e o job é devolvido sem materializar, subir
  arquivo ou assinar URL. A assinatura continua pertencendo ao passo
  `download` do hub.
- **Provas:** RED isolado 0/1 → GREEN 1/1; matriz Deno 34/44, com 10 REDs
  restantes nominalmente preservados; `deno check` GREEN.
- **Estado:** gate local `local-green`; item Supabase permanece `audited`, ação
  integrada `blocked-supabase`, zero remoto mutável e zero E2E.
- **Próximo gate:** tratar resposta de conclusão perdida sem apagar artefato
  possivelmente canônico.

### Checkpoint seguro 25 — `units.export` fronteira pós-conclusão

- **Action_id:** somente `units.export`; mudança local no worker, sem migration,
  deploy, configuração ou mutação remota.
- **REDs reproduzidos:** resposta perdida de
  `superadmin_complete_unit_file_job` apagava artefato possivelmente confirmado;
  falha de signed URL após conclusão também apagava o objeto e tentava demotion.
- **Causa raiz:** o `catch` não distinguia falha compensável pré-commit de falha
  ambígua ou posterior ao commit.
- **Correção mínima:** `completionAttempted` é marcado imediatamente antes da
  RPC de conclusão; depois dessa fronteira, não se executa cleanup nem
  `superadmin_fail_unit_file_job`. O status/download posterior reconcilia o job.
- **Provas:** pós-sucesso 3/4, matriz Deno 36/44, `deno check` GREEN e Flutter
  45/45. Os oito REDs restantes continuam visíveis.
- **Estado:** os dois gates estão `local-green`; a ação Supabase permanece
  `audited`, integrada `blocked-supabase`, sem remoto mutável nem E2E.
- **Próximo gate:** reautorizar após conclusão e antes de mintar signed URL.

### Checkpoint seguro 26 — `units.export` reautorização pós-conclusão

- **Action_id:** somente `units.export`; alteração local no worker, sem migration,
  deploy ou mutação remota.
- **RED reproduzido:** a terceira consulta autorizadora, depois da conclusão,
  não existia; vínculo revogado ainda alcançava Storage.
- **Correção mínima:** nova `reauthorizeExportJob` após conclusão e antes da
  signed URL. Falha fica após a fronteira de commit e, portanto, não apaga nem
  rebaixa o job.
- **Provas:** pós-sucesso 4/4, matriz Deno 37/44, `deno check` GREEN e Flutter
  45/45.
- **Estado:** gate `local-green`; ação Supabase `audited`, integrada
  `blocked-supabase`; sete REDs, remoto e E2E permanecem.
- **Próximo gate:** negar acesso direto ao worker sem delegação server-owned.

### Checkpoint seguro 27 — `units.export` delegação server-owned

- **Action_id:** somente `units.export`; alterações locais no hub, worker,
  fixtures e README, sem migration, deploy, segredo real ou mutação remota.
- **RED reproduzido:** JWT de navegador alcançava o worker e uma RPC privada,
  retornando 200 com campos internos.
- **Correção mínima:** `import-export-jobs` exige
  `COELO_UNIT_EXPORT_WORKER_SECRET` e o envia no header interno; `unit-export`
  compara o mesmo segredo antes de ler Authorization ou chamar Supabase.
  Ausência/divergência retorna 403. Nenhum valor de segredo foi gravado.
- **Provas:** negativo direto 403 e zero RPC; testes do hub verificam o header;
  pós-sucesso 4/4; unit-export 41/47; import-export-jobs 22/23, com o RED de
  cleanup de import já conhecido; Flutter 45/45.
- **Resíduos nominais:** purge expirado, retenção/remint, cleanup órfão e três
  grants legados. A configuração remota coordenada do segredo e o deploy das
  duas Functions exigem autorização específica.
- **Estado:** pacote principal local 7/7 concluído; item Supabase permanece
  `audited`, ação integrada `blocked-supabase`, zero `remote-green` e zero E2E.
- **Encerramento medido:** recorte 100,00% (7/7), restante 0,00% (0/7);
  backlog integrado 0,00% (0/207), restante 100,00% (207/207). Tempo mensurável
  de 28 min entre o marcador 16:44 e 17:12 BRT; inventário anterior ao marcador
  não calculável com segurança.

### Checkpoint seguro 28 — baseline reconciliável e contrato Auth interno

- **Lote:** baseline/reconciliação read-only e contrato de Auth, sessão e
  contexto interno; nenhuma ação da matriz foi promovida. O inventário corrigiu
  a contagem geral para 207 `action_id` + 22 gates `SUP-GEN` = 229 unidades
  estritas, mantendo ações e gates como conjuntos separados.
- **Ações tratadas:** fundação de `auth.login`, `auth.logout`, `auth.mfa` e
  `shell.load`/`shell.switch-context` apenas no contrato. Recovery/reset,
  convite e qualquer alteração Flutter permanecem fora deste lote.
- **Migrations, RPCs ou Functions alteradas:** nenhuma. A spec 039 definiu para
  implementação futura identidade, `auth_link` e membership privados,
  `session_id` validado em `auth.sessions`, `platform.read` escopado, Owner AAL2
  e envelopes auditáveis; nenhuma definição SQL foi criada ou aplicada.
- **Evidências:** worktree `codex/supabase-foundation` em base `b81923dc`;
  commits `d6366d491f272070c43c703c6daf57f2c8071dd8` e
  `64308b19bb6de2e9b579293f54cda46d55b270d1`. Manifesto v2 portátil
  `3eb7f9dd1c8ae55529d34cb8e1d59de7381cf74fcd9ee46f4224b3d9f38e61e5`:
  100 canônicas, 175 recovery, 103 remotas, 186 versões e 378 linhas. CSV com
  142.534 bytes e SHA-256
  `22d6268119fe9af9d8a009f5790cfc7dbd64e86f9218ab57929fb7bc27be253e`;
  o sidecar confere o payload e não contém path absoluto.
- **Testes executados:** geração dupla determinística; payload SHA/bytes/rows;
  nomes remotos; EOL normalizado; rejeição de reparse/escape; parser PowerShell;
  `git diff --check`; scan de segredos; validadores e testes da memória Coelo.
  Três ciclos de review fecharam capability inexistente, semântica HTTP do
  PostgREST, auditoria negativa, portabilidade e autointegridade.
- **Estado local/remoto:** documentação e evidência `local-green`; branch limpa
  após os dois commits. O projeto remoto `coelo` (`evvbomzejfijozbtgvpt`) foi
  consultado somente por `SELECT` de ledger/metadata e permaneceu com 103
  migrations; zero DDL, DML operacional, Auth, Storage, Edge ou deploy.
- **Bloqueios:** seis versões têm conflito textual e não entram em promoção
  automática; `20260812000847` e `20260813155005` também pertencem ao ledger
  remoto. Nenhum dos seis será sobrescrito. O replay Docker isolado ainda não
  foi executado.
- **Pendências:** para as 55 candidatas remotas, provar equivalência ou
  proveniência por versão antes de restaurar qualquer arquivo; somente
  `20260811220646` possui fingerprint do statement remoto neste checkpoint. As
  31 migrations apenas locais exigem triagem e gates por pacote/decisão — não
  promoção em lote —, incluindo os bloqueios já registrados de Medicação e Care
  Profiles. Depois, regenerar o mirror, classificar os seis conflitos e executar
  replay/reset isolado antes de escrever o RED Auth.
- **Tempo usado:** aproximadamente 1 h até o checkpoint; tempo de reviews e
  commits posteriores incluído nesta mesma janela operacional. **Tempo restante
  estimado:** 8–17 dias focados para Auth/contexto + Instituições, Unidades,
  Grupos e Pessoas; backlog integral não calculável ainda.

### Checkpoint seguro 29 — restauração comprovada de Auditoria e próximo RED

- **Lote:** reconciliação individual da migration remota
  `20260812000847_audit_production.sql`; nenhuma ação da matriz foi promovida.
- **Ações tratadas:** somente os gates gerais `SUP-GEN-002` e `SUP-GEN-016`.
  Auth, Instituições e as demais migrations recovery-only não foram alterados.
- **Migrations, RPCs ou Functions alteradas:** a migration canônica
  `20260812000847` foi restaurada ao blob histórico
  `268467fd0efadcc11f2c5914b2e67b72de790f84` do commit
  `5dea64a9a2e24b66f40b302d222b3ae0b5bc6391`; nenhum objeto remoto foi escrito.
- **Evidências:** o primeiro replay isolado reproduziu SQLSTATE `42601` no
  identificador reservado `authorization`. O ledger remoto, consultado por
  `SELECT`, contém exatamente 12 ocorrências de `v_authorization`, zero do
  identificador reservado e zero da variante recovery
  `authorization_scope_value`, além dos labels de capability. O arquivo
  restaurado possui zero diferenças contra `5dea64a9`; canônico e mirror têm
  66.923 bytes, SHA-256 raw
  `546127f251867629ee4110348d2aedd7af5003d28a8a3c5c0fd298c067b66b5c`
  e SHA-256 LF-normalized
  `8562df833a09ba3a79d972bbe0b6a533bd76647eb0d338698eecdb0ce8625b30`.
  Manifesto v2 regenerado: id
  `953681023d3ed4f24c5d0c74c43aecbba2095e3d927ced3363887279e7a2b4f8`,
  CSV 142.936 bytes/SHA-256
  `82951d24ba3518c7232f35185e971526ce03787dda3723ef43d63b492d913568`
  e meta 1.128 bytes/SHA-256
  `339cf0566086c66d2a88a39860dabb04d8a6d08a76dde857169c07e651e4e6fd`.
- **Testes executados:** replay RED inicial; restauração mínima; replay afetado
  uma vez; `Sync-SupabaseCliMigrations.ps1` Prepare e Verify, ambos 100/100;
  igualdade contra o blob histórico; `git diff --check`; teardown nominal.
- **Estado local/remoto:** a sintaxe reservada foi removida, mas o replay segue
  RED na mesma migration porque `platform_permissions.module_label` ainda não
  existe no baseline canônico. A dependência é a candidata
  `20260811215451_access_profile_management_v2.sql` e não foi promovida sem sua
  própria prova. O remoto permaneceu somente leitura: zero DDL, DML operacional,
  Auth, Storage, Edge, migration aplicada ou deploy.
- **Bloqueios:** ledger canônico incompleto antes de `20260812000847`; as outras
  54 candidatas remotas continuam sem fingerprint integral. As 31 local-only,
  inclusive Medicação e Perfis de cuidado, permanecem em pacotes individuais.
- **Cleanup:** projetos Docker `coelo_auth_baseline_20260827_01` e
  `coelo_replay_20260827_02`, redes e diretórios temporários foram removidos;
  zero container/volume/rede residual desses projetos. Os três volumes antigos
  `coelo_database` foram apenas observados e permaneceram intactos.
- **Pendências:** fechar a proveniência de `20260811215451`, repetir somente o
  replay afetado e continuar a reconciliação por dependência; Auth SQL permanece
  bloqueado até ledger/replay reconciliados.
- **Tempo usado:** aproximadamente 1 h 45 min acumulados. **Tempo restante
  estimado:** 8–17 dias focados para Auth/contexto + Instituições, Unidades,
  Grupos e Pessoas; backlog integral não calculável ainda.

### Checkpoint seguro 30 — dependência Access Profiles comprovada

- **Lote:** reconciliação individual de
  `20260811215451_access_profile_management_v2.sql`; nenhuma ação funcional foi
  promovida.
- **Ações tratadas:** somente `SUP-GEN-002` e `SUP-GEN-016`. A migration Auth,
  Flutter e as outras 84 candidatas não foram alterados.
- **Migrations, RPCs ou Functions alteradas:** adicionada à fonte canônica a
  versão remota `20260811215451` a partir do blob Git único
  `ac2b2b023d55607204b95a5d4ca391146b68698e`, presente nos commits equivalentes
  `10bad552bd70b33e7ba2333a8290403dafe68a0f` e
  `849b867fc7073580e5b021954754131c41b1940c`. A recovery posterior
  `99322aa83f0f2c0b1d67edb8d70377f3cb3cb1d6` foi rejeitada.
- **Evidências:** ledger remoto read-only: 115 statements, 117.154 bytes no join
  e SHA-256
  `b8d3dfc1764fdfa9320c8f8c398198986a057a2fa1b05e42df130fe9c91486c3`.
  O vetor estrutural remoto — 22 funções públicas de perfil, 19 gateways com
  parâmetros posicionais, três wrappers nomeados, zero drops tardios e zero
  patch de labels Units — seleciona somente `ac2b2b...` entre cinco blobs. O
  arquivo canônico/mirror tem 117.682 bytes, SHA-256 raw
  `04c1bedd194b812ea753243dd95e400d39e0257f985506a8b703e68329d90208`
  e LF-normalized
  `cf774bdd403025673ba385c7234cea1527e4a6b0204a7afad4d980f575745462`.
- **Manifesto:** gerador passou a exigir contagem canônica esperada explícita;
  `-ExpectedCanonicalCount 100` nega e `101` gera deterministicamente. Sidecar
  id `59d218305d76653e1f1dd16d345d2ae451beb9b40fe7c7a34cbfec7091e6f859`;
  CSV 143.738 bytes/SHA-256
  `33f5ef6d0c3bf79cd6b428a4e9b7b6b60eef9ccd55edc2f2bda20d38ed45dbd9`;
  meta 1.128 bytes/SHA-256
  `0cc28d855108e82acaac136a1b06771d82146f5ee5b78880f64a85ff8663677b`.
- **Testes executados:** review de proveniência independente; parser SQL dos
  cinco blobs; mirror Prepare/Verify 101/101; replay isolado afetado uma vez;
  negativo/positivo do gerador; geração determinística dupla; teardown nominal.
  O `diff --check` padrão sinaliza somente a linha vazia histórica no EOF do
  blob remoto; com `core.whitespace=-blank-at-eof`, os demais gates de whitespace
  passam. A linha foi preservada para manter o blob Git exato.
- **Estado local/remoto:** `20260811215451` e `20260812000847` passaram no
  replay. O próximo RED é SQLSTATE `42703` em
  `20260812001000_import_export_hub_security.sql`: a coluna
  `public.import_jobs.processing_state` ainda não existe no baseline. O remoto
  recebeu apenas SELECTs de ledger; zero migration, DDL, DML operacional, Auth,
  Storage, Edge ou deploy.
- **Cleanup:** projeto/rede/diretório temporário
  `coelo_replay_20260827_03` removido; zero container, volume ou rede residual.
- **Bloqueios e pendências:** identificar por proveniência individual a migration
  que cria `processing_state`; não reconstruir as oito versões órfãs descritas
  pelo rastreador. Auth SQL permanece bloqueado até o replay reconciliar.
- **Tempo usado:** aproximadamente 2 h 20 min acumulados. **Tempo restante
  estimado:** 8–17 dias focados para Auth/contexto + Instituições, Unidades,
  Grupos e Pessoas; backlog integral não calculável ainda.

### Checkpoint seguro 31 — dependência de Grupos comprovada

- **Lote:** reconciliação individual de
  `20260811151254_group_management_security.sql`; nenhuma ação funcional foi
  promovida.
- **Ações tratadas:** somente `SUP-GEN-002` e `SUP-GEN-016`. Auth, Flutter e as
  outras 83 candidatas não foram alterados.
- **Migrations, RPCs ou Functions alteradas:** adicionada à fonte canônica a
  versão remota `20260811151254` a partir do único blob Git/recovery
  `f5bd2182b05bec2ee58cc00e9d5360b463c5faf8`, proveniente do commit
  `4496cb3a27da37413cf978ab9600fca560b829b2`. Nenhuma outra recovery foi
  promovida.
- **Evidências:** o ledger remoto foi consultado somente por `SELECT` e contém
  140 statements. A canonicalização SQL-aware por statement produziu, no
  remoto e no arquivo local, o mesmo SHA-256 agregado
  `204b839b9b570ed82283f8b1de1ff567d49acd54cfbc17991558f0993da67322`;
  os 140 tokens ordenados e as extremidades também coincidem. O arquivo tem
  80.959 bytes, SHA-256 raw
  `8666c997a8a04e13a404c20f46bfbcaae0cb12b8b5dbb64623fbfff4cfcd993f`
  e LF-normalized
  `507a70ad88f595088c6ce9146e31e27f4c9bf9e86e63f8e093ee5066638c3ef3`.
- **Manifesto:** canônico e mirror foram verificados 102/102. O gerador negou
  contagem 101, gerou duas vezes o mesmo sidecar id
  `71a32a4e03b07f8729a6c5fa31c253c28b9790834cb0c35c4bd2da92d07bbd90`;
  CSV com 144.572 bytes, 380 linhas e SHA-256
  `09f6708208c59bc56c8c2bb55e343acfcd9236e79a665cedda9c65097328dcb1`;
  meta com 1.128 bytes e SHA-256
  `f5953f574924118eec0bb68c31dfc2b9ee76278af0cc9fb65d3934f8cefb15d3`.
- **Testes executados:** prova de proveniência independente; comparação por
  statement remoto/local; mirror Prepare/Verify 102/102; negativo/positivo do
  gerador; geração determinística dupla; replay Docker isolado afetado uma vez;
  teardown nominal.
- **Estado local/remoto:** o replay aplicou `20260811151254`,
  `20260811215451`, `20260812000847` e todo o bloco Import/Export até
  `20260812001975`. O próximo RED é SQLSTATE `23502` em
  `20260812002000_child_safety_schema.sql`: três inserts em
  `platform_permissions` não fornecem `module_label`. No projeto remoto
  `evvbomzejfijozbtgvpt` houve somente leitura; zero migration, DDL, DML
  operacional, Auth, Storage, Edge ou deploy.
- **Cleanup:** projeto Docker `coelo_replay_20260827_05`, rede dedicada e
  diretório temporário foram removidos; zero container, volume ou rede residual.
- **Bloqueios e pendências:** Auth SQL permanece bloqueado até o replay
  reconciliar. O próximo pacote deve identificar individualmente a migration
  remota que satisfaz `platform_permissions.module_label`; não reconstruir
  versões órfãs nem promover recovery em lote.
- **Tempo usado:** aproximadamente 3 h acumuladas. **Tempo restante estimado:**
  8–17 dias focados para Auth/contexto + Instituições, Unidades, Grupos e
  Pessoas; backlog integral não calculável ainda.

### Checkpoint seguro 32 — ACL default de funções fail-closed

- **Lote:** fechamento do P1 encontrado na revisão independente do pacote de
  Grupos; nenhuma ação funcional foi promovida.
- **Ações tratadas:** `SUP-GEN-002`, `SUP-GEN-003`, `SUP-GEN-008` e
  `SUP-GEN-016`, somente no
  ambiente local testado.
- **Migrations, RPCs ou Functions alteradas:** adicionada a migration
  forward-only `20260827214000_harden_default_function_execute_privileges.sql`.
  Ela exige execução como `postgres`, revoga `EXECUTE` por default para
  globalmente e nas camadas por schema `public`/`app_private` para objetos
  criados por `postgres`, tornando `PUBLIC`, `anon`, `authenticated` e
  `service_role` opt-in; também remove grants explícitos fora da allowlist e
  reaplica os ACLs mínimos das oito funções pós-`COMMIT` de import/export de
  Grupos. O blob remoto histórico
  `20260811151254` não foi reescrito.
- **RED:** um projeto Docker mínimo executado com Supabase CLI 2.116.0 criou
  uma função `SECURITY DEFINER` depois de `COMMIT` e falhou antes do `REVOKE`.
  Após o erro, tabela pré-commit e função persistiram e
  `has_function_privilege('public', ..., 'EXECUTE')` retornou verdadeiro. Isso
  confirmou exposição parcial real no runner, não apenas risco estático.
  Uma contraprova posterior ficou 10/12: a camada `IN SCHEMA` não revogava o
  grant global padrão de `PUBLIC`. A revisão remota read-only também comprovou
  defaults aditivos por schema para `anon`, `authenticated` e `service_role`.
  A correção final neutraliza as camadas global e por schema antes de reaplicar
  somente os grants explícitos necessários.
- **GREEN:** replay isolado das 29 migrations até `20260811151254` mais a nova
  hardening aplicou sem erro. O teste
  `default_function_execute_privileges_test.sql` passou 12/12: executor e
  owners `postgres`, `anon` negado,
  gateway autenticado preservado, complete/fail negados a `authenticated`,
  permitidos a `service_role`, defaults global e por schema de `postgres` sem
  `PUBLIC EXECUTE`, probes sintéticos negados aos três client/server roles e
  allowlist exata das oito ACLs.
  Um grant sintético indevido a `anon` em helper privado foi removido pela
  reaplicação idempotente e os 12 asserts permaneceram verdes. Execução sob
  `authenticated` foi negada pelo guard antes de alterar defaults ou ACLs.
- **Replay seguro:** o forward posterior não consegue proteger sozinho uma
  falha depois do `COMMIT` interno da migration histórica. O wrapper local
  `Invoke-SafeLocalMigrationReplay.ps1` cria projeto, identidade Docker e portas
  descartáveis fora do repositório, rejeita reparse points, usa somente
  `db reset --local`, injeta um preflight SHA-256
  `AB4AE8E35B26926963A2D4D741709E582BF2058E6402E00C661A136FC7E12027`
  imediatamente antes de Grupos e remove o staging no teardown. O replay
  DB-only aplicou 104 arquivos até `20260812001975`; staging final 0 e zero
  containers.
- **Manifesto:** canônico/mirror verificados 103/103, incluindo a migration
  final com 3.760 bytes e SHA-256 idêntico
  `8C49FFF6E6037F46021CD78ED88169415C9630E1DCD47BF33F85F0CCA07C830D`;
  geração dupla determinística com sidecar id
  `3de0f6f438dda51de0089077348e2333da299fe9ba17b779adfd714d2590b237`.
  CSV com 144.973 bytes, 381 linhas e SHA-256
  `0d410467c23d9a66061792c86061890521d66c192809ed3f101576d218d844a1`;
  meta SHA-256
  `d85880339d7ea64b6f317d2c160b9ddad8bb4f60e68d286947b858e7a3daa8a3`.
- **Estado local/remoto:** `local-green` somente para o endurecimento focal. A
  migration nova não existe no remoto e não foi aplicada; portanto o pacote
  não é `remote-green` nem `done`. O remoto permaneceu sem DDL, DML operacional,
  Auth, Storage, Edge ou deploy.
- **Cleanup:** projetos `coelo_cli_atomicity_20260827_06`,
  `coelo_group_acl_20260827_07`, `coelo_group_acl_20260827_08` e
  `coelo_group_acl_20260827_10`–`12`, redes e volumes foram removidos
  nominalmente. O replay final DB-only deixou zero migration no staging e zero
  container; os diretórios descartáveis sem dados continuam fora do Git.
- **Bloqueios e pendências:** o replay amplo continua no RED de Child Safety do
  checkpoint 31. `groups.export` é exigida por RPCs, mas o permission code não é
  criado por migration canônica/recovery; permanece `fail-closed`. A nova
  migration precisa de integração e futura aplicação remota autorizada antes de
  qualquer conclusão. Auth/contexto permanece bloqueado pela reconciliação.
- **Tempo usado:** aproximadamente 3 h 45 min acumulados. **Tempo restante
  estimado:** 8–17 dias focados para Auth/contexto + Instituições, Unidades,
  Grupos e Pessoas; backlog integral não calculável ainda.

### Checkpoint seguro 33 — proveniência de Child Safety bloqueada

- **Lote:** investigação individual do primeiro RED de Child Safety; nenhuma
  migration foi promovida e nenhuma ação funcional mudou de estado.
- **Ações tratadas:** `SUP-GEN-002`/`SUP-GEN-016` apenas como reconciliação do
  replay. Child Safety, Auth e Flutter não foram implementados.
- **Evidências e testes:** a versão `20260812002000` não existe no ledger remoto
  e o remoto não possui rows `child_safety.%`, portanto não há equivalência
  remota possível. O blob histórico mínimo `d4ef6d0f...` resolve o primeiro
  `23502` de labels, mas encontra SQLSTATE `42703` no mesmo arquivo porque tenta
  atualizar `platform_role_permissions.updated_at`, coluna inexistente. Busca
  em 129 blobs SQL Git e 168 recoveries não encontrou migration anterior que
  crie a coluna.
- **Bloqueio:** o candidato posterior `a27d7823...` remove a referência inválida,
  mas também altera regras de produto e grants legados. Não foi promovido. O
  arquivo canônico foi mantido no baseline; a decisão deve ser tratada em pacote
  próprio, sem reconstrução ou promoção em lote.
- **Estado local/remoto:** apenas investigação/replay local e consultas remotas
  read-only já registradas; zero DDL, DML operacional, Auth, Storage, Edge ou
  deploy remoto. Próximo lote independente seguro: inventário Auth/contexto.
- **Tempo usado:** aproximadamente 4 h 30 min acumulados. **Tempo restante
  estimado:** 8–17 dias focados; backlog integral não calculável ainda.

### Checkpoint seguro 34 — isolamento destrutivo do replay e `groups.export`

- **Lote:** correção do harness local após re-review adversarial e fechamento
  read-only da proveniência de `groups.export`; nenhuma ação foi promovida.
- **Ações tratadas:** `SUP-GEN-002`, `SUP-GEN-003`, `SUP-GEN-016` e
  `groups.export`, que continua `fail-closed`.
- **Arquivos alterados:** `Invoke-SafeLocalMigrationReplay.ps1` e README. O
  wrapper agora gera identidade `coelo_safe_<GUID>` e portas próprias, fixa
  Supabase CLI 2.116.0, rejeita TEMP no repositório e reparse points, serializa
  a sessão com mutex recuperável, preserva erro primário junto de falhas de
  teardown e exige zero diretório, container, volume e rede residuais. SHA do
  script: `B745A1DCB274B179E2CE23C3FE294E859089CD07A70882650EC6FAC6C3738FDF`.
- **Evidências e testes:** parser, diff-check e secret scan verdes. Caminho GREEN
  aplicou 104 migrations até `20260812001975`; caminho RED reproduziu o `23502`
  esperado em Child Safety. Testes adversariais provaram rejeição de TEMP dentro
  do repo sem criar/remover path, concorrência negada, recuperação de mutex
  abandonado e `AggregateException` contendo simultaneamente o RED de reset e a
  falha de stop. Todos terminaram com zero `coelo_safe_*` e zero containers.
  Dois reviews independentes: zero P0/P1.
- **Proveniência `groups.export`:** o remoto possui somente `groups.read/manage`;
  a migration de Grupos apenas referencia `groups.export`. O blob histórico
  `bb7de4d8...` da versão local-only `20260813183644` cria a capability, mas
  também cria bridge/worker e depende de `20260813122643`, igualmente ausente
  do remoto. Não foi restaurado nem separado artificialmente. A capability deve
  permanecer inativa até aprovação do fluxo completo, worker, Storage e testes.
- **Estado local/remoto:** harness `local-green`; migration ACL ainda não
  implantada. A investigação remota foi somente `SELECT`; zero DDL/DML/Auth/
  Storage/Edge/deploy. Não é `remote-green` nem `done`.
- **Bloqueios e pendências:** Child Safety continua bloqueada conforme checkpoint
  33. Residuais P2 do harness: corrida externa entre descoberta/uso de porta,
  mutex limitado à sessão Windows e janela local check-then-delete; falham de
  forma segura no fluxo contratado e não ampliam autoridade remota.
- **Tempo usado:** aproximadamente 5 h acumuladas. **Tempo restante estimado:**
  8–17 dias focados; backlog integral não calculável ainda.

### Checkpoint seguro 35 — RED contratual da fundação Auth

- **Lote:** Auth, sessão e contexto institucional; migration e pgTAP permanecem
  em elaboração, sem commit e sem promoção de ação.
- **Ações tratadas:** fundação privada, exclusão simétrica dos realms, sessão
  revalidada, lifecycle terminal, Owner AAL2, escopo, audit v1/v2, bootstrap e
  resolução institucional. Nenhuma das 207 ações recebeu estado E2E.
- **Migrations/RPCs alteradas:** draft local
  `20260827233000_superadmin_internal_auth_context.sql`; wrappers
  `superadmin_auth_bootstrap_context()` e
  `superadmin_auth_resolve_institution_context(uuid)`; teste
  `superadmin_internal_auth_context_test.sql`. Canônico/mirror foram preparados
  e verificados em 104/104 somente para o replay local.
- **Evidências e testes:** stage descartável explícito até `20260812001975`,
  seguido por `20260827214000` e pelo draft Auth, aplicou sem erro. O pgTAP
  mínimo sem JWT passou 13/13: envelope exato, duas chamadas, correlações
  distintas, zero mutação/audit pré-sessão, ACLs, tabelas privadas, RLS forçada
  e zero policies. O teardown deixou zero recurso Docker e removeu o projeto
  temporário.
- **Compatibilidade audit:** o detalhe, a lista e a materialização de export
  foram substituídos forward-only para preservar atores v1 e representar ator
  interno v2 por `kind`, ID opaco e rótulo genérico. O replay após esse ajuste
  aplicou novamente sem erro e manteve 13/13; falta um pgTAP comportamental de
  cadeia mista que prove nome/kind/ID/filtro e row de export, portanto esse P1
  continua aberto e não foi promovido.
- **Estado local/remoto:** `RED contratual`; não é `local-green`,
  `remote-green` nem `done`. Não houve DDL, DML operacional, Auth, Storage,
  Edge ou deploy remoto.
- **Bloqueio:** OQ-037. Uma sessão válida sem link interno, ou uma identidade
  sem membership, deve ser negada e auditada pela spec 039, mas não possui os
  três IDs obrigatórios do ator audit v2. Não foi criado ator `system`, pessoa
  sintética, `service_role` ou ID falso. Faltam ainda testes com sessão real,
  AAL1/AAL2, cross-app, cross-tenant, lifecycle, concorrência e cadeia mista.
- **Tempo usado:** aproximadamente 6 h acumuladas. **Tempo restante estimado:**
  8–17 dias focados, sujeito à decisão OQ-037; backlog integral não calculável.

### Checkpoint seguro 36 — proveniência individual 12002010/02020/02110

- **Lote:** investigação read-only de três migrations locais posteriores ao RED
  de Child Safety; nenhuma migration foi promovida.
- **20260812002010:** origem única no commit `3f2e97ba`, blob
  `0ba4e6b3...`, SHA-256 LF `2fb32c1b...`. Depende da tabela
  `unit_import_source_attestations`, criada pela órfã `20260811222209`, que
  consta no ledger remoto. A contraprova read-only associou o remoto ao blob
  original `feeb4bcc...` por marcadores e tamanho normalizado; os blobs
  `1f94...`/`39dab...` são hardenings posteriores, não o conteúdo aplicado.
  O remoto não possui `public.import_files.retention_expires_at`, nem a
  função/trigger de `12002010`; a coluna nasce somente na local-only
  `20260812001000`, e Child Safety bloqueia a ordem antes de `12002010`.
  Aplicação isolada não é segura. O pgTAP histórico tem somente três asserts
  estruturais: não prova checksum/24 h; o `coalesce` preserva retenção anterior
  e o trigger não cobre update isolado do checksum.
- **20260812002020:** mesma origem `3f2e97ba`, blob `aa6b8f2e...`, SHA-256 LF
  `14d6b988...`. Revisão remota estritamente read-only confirmou que
  `superadmin_preview_unit_import_from_edge`,
  `superadmin_materialize_unit_export_from_edge` e
  `superadmin_unit_export_page_v2` existem como `SECURITY DEFINER`, owner
  `postgres`, `search_path=''`, com `EXECUTE` efetivo para `PUBLIC`, `anon`,
  `authenticated` e `service_role`; `authenticated` também possui `USAGE` em
  `app_private`. Preview/materialize recebem `job_id`, carregam
  `job.created_by` e instalam claims desse ator/AAL2 sem validar o caller,
  formando risco P0 de impersonação/BOLA por UUID se alcançáveis pela Data API.
  A reachability HTTP ainda não foi provada. A migration histórica não corrige
  o remoto: seus dois primeiros `REVOKE` citam helpers inexistentes lá e
  abortam antes das três funções expostas. Também é incompleta localmente:
  `12001000` cria oito helpers privados e `12002020` revoga somente dois,
  deixando inclusive payload/list/get e guards fora da closure. O hardening
  `20260827214000` é prospectivo e não remove ACLs existentes. Classificação:
  **P0 remoto pendente de correção/deploy autorizado; BLOQUEAR a migration
  histórica**. Próximo pacote local deve ser forward-only, com inventário e
  allowlist por assinatura, revogação completa de papéis clientes/servidor e
  pgTAP de ACL/chamadas negativas; nenhum remoto foi alterado.
- **20260812002110:** origem única no commit `ceebc9ef`, blob `c47861fe...`,
  SHA-256 LF `c10e315f...` e CRLF `88d1b96b...`. O ledger remoto não contém a
  versão nem qualquer overload da RPC. A coluna `processing_state` existe no
  remoto, mas os quatro helpers exigidos vêm somente da local-only
  `20260812001000`, então a migration isolada não aplica. Mesmo no replay ela
  preserva o overload de cinco argumentos, aceita `page_size` nulo como limite
  ilimitado, não exige cursor pareado e não limita cardinalidade dos arrays; o
  pgTAP histórico é somente estrutural. Classificação: BLOQUEAR/preservar.
- **Estado:** as três permanecem `local-only-head`, dependentes e sem
  equivalência remota. Não promover isoladamente nem em lote. Próximo gate
  seguro: proveniência/fingerprint individual de `20260811222209` e de sua
  cadeia, antes de qualquer replay integral Import/Export.
- **Ambiente/cleanup:** somente Git, manifests e recoveries locais; zero Docker,
  DDL/DML/Auth/Storage/Edge/deploy remoto. Conhecimento: `no-op`.
- **Tempo usado:** aproximadamente 6 h 30 min acumulados. **Tempo restante:**
  8–17 dias focados para o recorte principal; backlog integral não calculável.

### Checkpoint seguro 37 — closure forward-only de ACL Import/Export

- **Lote:** correção local mínima do P0 remoto identificado no checkpoint 36;
  nenhuma ação funcional, importação/exportação ou E2E foi promovida.
- **Migration e teste:** adicionada
  `20260827222000_unit_import_export_private_acl_closure.sql`, sem restaurar a
  histórica bloqueada `20260812002020`. A função privada de reconciliação exige
  owner `postgres`, valida `search_path=''`, revoga `PUBLIC`, `anon`,
  `authenticated` e `service_role` de toda implementação privada presente e
  reaplica somente a allowlist pública comprovada: sete gateways para
  `authenticated`, quatro workers para `service_role` e dois gateways legados
  sem papel cliente. O overload legado `fail(uuid,text)`, o helper de trigger e
  a attestation local-only permanecem apenas em deny condicional.
- **Evidências:** inventário remoto estritamente read-only confirmou igualdade
  funcional de 15 assinaturas `app_private` e 13 `public`, owner `postgres` e
  `search_path=''`. O pgTAP cria o perfil remoto de forma transacional, injeta
  grants adversariais, executa a reconciliação duas vezes e compara o catálogo
  real com o manifesto nos dois sentidos, rejeitando overloads extras. Também
  prova ACL para os quatro papéis, metadata das privadas e três chamadas por
  UUID negadas a `authenticated`.
- **Testes executados:** stage Docker isolado até `20260812001975`, com
  preflight de Grupos, `20260827214000` e a nova migration. Um RED intermediário
  revelou que `regprocedure` omitia o schema `public` e que o harness não
  convertia `not ok` em falha; ambos foram corrigidos. Replay final: 73/73
  asserts verdes, rollback das fixtures, teardown completo e zero container,
  volume, rede ou diretório `coelo_acl_*` residual.
- **Manifesto:** 105 migrations canônicas verificadas contra o mirror. Migration
  e mirror SHA-256 idêntico
  `AB34496EE66A0D848AAAA9B2C22147E3F09958CE4F0E534C273CA7FE3CFCD107`;
  pgTAP SHA-256
  `61B61F280E03AB1F14236B146989E8874279601C6B8C2488414D09CC68AC79A9`.
  `git diff --check` e secret scan focal verdes.
- **Estado local/remoto:** `local-green` somente para a closure ACL. O remoto
  não foi alterado e ainda mantém o P0 nas três implementações privadas e no
  helper de branding até aplicação forward-only explicitamente autorizada.
  Portanto não é `remote-green`, `done` nem prova comportamental de
  importação/exportação.
- **Bloqueios e pendências:** revisão independente final e integração seletiva
  do commit ainda são gates. Auth permanece RED por OQ-037. As migrations
  `12002010`, `12002020` e `12002110` permanecem BLOQUEADAS; import/export
  continua fora do recorte funcional e fail-closed.
- **Tempo usado:** aproximadamente 7 h 15 min acumulados. **Tempo restante:**
  8–17 dias focados para o recorte principal, sujeito à OQ-037; backlog
  integral não calculável.

### Checkpoint seguro 38 — Notices 12002900 bloqueada e ACL remota excessiva

- **Lote:** proveniência e segurança read-only de
  `20260812002900_notices_status_values.sql`; nenhuma migration ou ação de
  Avisos foi promovida.
- **Proveniência:** único blob Git
  `2310e04d135659d4bb3eb9571d8d57ec949f52dc`, commit `ca550887`, pai
  `3f2e97ba`. Git/LF e recovery têm 286 bytes e SHA-256
  `D21D79D7D40A24EF063E9903BF7C560C1F0D61C4AA6C2E7B2911B67A00128F23`;
  checkout CRLF tem 290 bytes e SHA-256
  `C2416311DC7CDF259990B68D795F486D3FDBB61E86285ED23C7676942DCE390C`.
  As cópias são EOL-equivalentes, sem variante semântica.
- **Remoto read-only:** o ledger não contém `12002900` nem `12003000`; o enum
  contém exatamente `draft`, `scheduled`, `published`, `expired`, `archived`,
  `platform_notices` tem zero rows e nenhuma função remota consome a tabela. A
  ACL SQL raw concede ALL a `anon`, `authenticated` e `service_role`; RLS está
  habilitada, não forçada, com uma policy SELECT para `authenticated` por
  `platform.read`. `has_table_privilege` confirmou `TRUNCATE` para
  `anon`/`authenticated` e `INSERT` para `anon`. Isso prova privilégio SQL
  efetivo excessivo, não reachability HTTP/PostgREST de `TRUNCATE`.
- **Classificação:** BLOQUEAR/preservar `12002900`. Ela só acrescenta três
  labels por `ALTER TYPE ... ADD VALUE`, operação sem rollback simples, e não
  corrige grants/RLS. A closure nasce somente na local-only/text-conflict
  `12003000`; aplicá-la isoladamente contornaria o RED anterior de Child Safety
  e criaria falsa aparência de avanço seguro.
- **Contrato/testes:** OQ-038 registra o conflito entre o ciclo de seis estados
  da spec técnica e os cinco estados legados da spec de banco. Acrescentar os
  labels produziria oito valores, sem mapping para `published`/`archived` e em
  ordem física inadequada. Não existe pgTAP focal de enum exato, transições de
  pausa/retomada/inativação ou matriz ACL completa.
- **Próximo pacote seguro:** primeiro, hardening forward-only independente de
  ACL/RLS das tabelas Notice, sem ativar o domínio; depois, somente após decisão
  OQ-038, migrations coordenadas para expansão/migração do enum e contrato
  produtivo, com testes de transição, negativos e autorização.
- **Ambiente/estado:** somente Git e SELECT remoto redigido; zero Docker,
  DDL/DML/Auth/Storage/Edge/deploy remoto. Não é `local-green`, `remote-green`
  nem `done`. Conhecimento atualizado somente em `docs/open-questions.md`.
- **Tempo usado:** aproximadamente 7 h 45 min acumulados. **Tempo restante:**
  8–17 dias focados, sujeito às OQ-037/OQ-038; backlog integral não calculável.

### Checkpoint seguro 39 — hardening local das tabelas Platform Notice

- **Lote:** fechamento forward-only da superfície SQL excessiva encontrada no
  checkpoint 38, sem ativar enum, RPC, worker ou ação de Avisos.
- **Migration/teste:** adicionada
  `20260827222500_harden_platform_notice_table_access.sql` e o pgTAP
  `platform_notice_table_access_hardening_test.sql`. O preflight exige owner
  `postgres` e as cinco relações exatas: `public.platform_notices`,
  `notice_rules`, `notice_media`, `notice_receipts` e
  `analytics.notice_events`. A migration revoga ALL somente de `PUBLIC`, `anon`
  e `authenticated`, habilita e força RLS; preserva `service_role`, as cinco
  policies SELECT existentes, schemas, enum e objetos de Assiduidade.
- **RED:** stage truncado sem a migration reprovou FORCE RLS nas cinco tabelas
  e ACL nas quatro tabelas `public`; confirmou a mesma causa do inventário
  remoto. Um erro de tipo `name[]` no assert do enum foi corrigido antes do
  GREEN e não foi contado como prova funcional.
- **GREEN:** stage Docker isolado até `20260812001975`, seguido por preflight de
  Grupos, hardening default ACL `20260827214000`, closure Import/Export
  `20260827222000` e a nova migration, passou 35/35 asserts. Foram provados
  owner/RLS, zero privilégio de `PUBLIC`/`anon`/`authenticated` por
  `aclexplode` e pela matriz efetiva dos sete privilégios de tabela,
  compatibilidade deliberada de `service_role` nos mesmos sete privilégios,
  preservação das cinco policies esperadas, enum legado inalterado e
  SELECT/TRUNCATE negados a `anon`/`authenticated`. Rollback das
  fixtures e teardown deixaram zero container, volume, rede ou temp.
- **Manifesto:** 106 migrations canônicas verificadas contra o mirror.
  Migration/mirror com 1.682 bytes e SHA-256
  `939BE71754D85151C4773507E0256C7E6FA7787F7CFC6839A186871FB2B1FF7F`;
  pgTAP com 4.071 bytes e SHA-256
  `0653A4F8652868B2231381E8F81453BB8C78352FAE490644A9C76DE11B69C8BF`.
  Diff-check e secret scan focal verdes.
- **Estado local/remoto:** `local-green` somente para o hardening focal. O
  remoto não recebeu a migration e continua com grants excessivos até deploy
  explicitamente autorizado; não é `remote-green`, `done` nem integração de
  Avisos. A histórica `12002900` continua BLOQUEADA e OQ-038 aberta.
- **Bloqueios/pendências:** review independente do snapshot final concluiu
  P0=0/P1=0; falta integração seletiva. Depois do hardening remoto autorizado,
  qualquer funcionalidade
  Notice ainda exige decisão do enum, contrato consolidado, RPC/worker,
  autorização, transições, persistência/reload e E2E.
- **Tempo usado:** aproximadamente 8 h 15 min acumulados. **Tempo restante:**
  8–17 dias focados, sujeito às OQ-037/OQ-038; backlog integral não calculável.
### Checkpoint seguro 40 — fundação Auth, sessão e contexto interno

- **Lote:** implementação local da opção A aprovada para Auth/Sessão do
  Superadmin, sem alterar Flutter e sem criar, alterar ou consultar dados de
  usuários remotos. OQ-037 foi fechada na fonte canônica antes do SQL.
- **Contrato implementado:** principal, vínculo Auth e membership internos
  vivem em `app_private`, separados de `people`, `person_auth_links` e
  `platform_memberships`. O contexto deriva somente de `auth.uid()` e do
  `session_id` revalidado contra `auth.sessions` do mesmo usuário e dentro de
  `not_after`; Owner exige AAL2 e os demais papéis seguem `requires_mfa`.
  Instituição e escopo vêm da membership privada, nunca de claims ou filtros do
  cliente. Os wrappers públicos de bootstrap e resolução retornam envelope JSON
  estável e são executáveis somente por `authenticated`.
- **Autorização e lifecycle:** tabelas privadas usam RLS habilitada e forçada,
  sem policies ou grants de cliente. Locks consultivos simétricos impedem corrida
  entre realms; vínculos e memberships revogados são terminais; escopo respeita
  `max_scope_kind`; a proteção do último Owner considera role, membership e
  auth_link ativos, AAL e escopo funcional. Helpers privilegiados são
  `SECURITY DEFINER`, owner `postgres`, `search_path=''` e sem EXECUTE para
  `PUBLIC`, `anon`, `authenticated` ou `service_role`.
- **Auditoria:** eventos históricos v1 permanecem verificáveis; v2 representa
  ator interno completo; v3 `auth_session` registra obrigatoriamente negações
  após sessão válida ainda sem vínculo/membership, apenas com hash de sessão de
  32 bytes e contexto minimizado. IDs pessoais/internos e role ficam nulos no
  v3. Falha do append aborta a RPC. Detalhe, lista, busca e export exibem
  “Sessão autenticada” sem expor o hash.
- **Migration/teste:** adicionada
  `20260827233000_superadmin_internal_auth_context.sql` e o pgTAP
  `superadmin_internal_auth_context_test.sql`. Migration e mirror têm 67.165
  bytes e SHA-256
  `B65E44866C7E148A06CE2C0A96D9C5B1CB377AB0947BA251EE795F103FF0A577`;
  teste tem 23.602 bytes e SHA-256
  `236651B5F76BEC2E6E955724F95EF65C9014ABA22B2764CB62E47D2A18B39832`.
- **Testes executados:** replay Docker DB-only e isolado no baseline até
  `20260812001975`, seguido por `20260827214000` e a migration Auth via
  `migration up --local`; o ledger local confirmou as duas versões. Um RED de
  harness e um parêntese excedente no pgTAP foram corrigidos. Gate final:
  29/29 testes passaram, incluindo envelope, ACL/RLS, sessões ausente/expirada,
  ator incompleto v3, correlação 1:1, digest/cadeia v1-v2-v3, append fail-closed,
  leitores sem hash e metadata dos definers. Teardown terminou com zero
  container, volume, rede ou diretório temporário residual.
- **Estado local/remoto:** `local-green` para o recorte testado; 106 migrations
  canônicas e mirror reconciliadas. O remoto não recebeu migration, Auth, DDL,
  DML, Storage, Edge ou deploy; logo não é `remote-green`, `done` nem prova E2E.
- **Pendências:** ainda faltam integração GoTrue/PostgREST com login, refresh,
  logout, revogação e AAL2 reais; fixtures completas de Owner e memberships para
  bootstrap/resolução positivos, cross-tenant e concorrência multi-conexão;
  integração posterior com Flutter. OQ-038 de Notices continua aberta.
- **Revisão independente:** Eng Sup confirmou P0=0/P1=0 nos hashes finais e
  recomendou commit após staging explícito dos blobs corrigidos.
- **Tempo usado:** aproximadamente 1 h 30 min neste lote. **Tempo restante:**
  cerca de 8 h 30 min do orçamento adicional corrente; ETA do recorte principal
  continua 8–17 dias focados e o backlog integral não é calculável.

### Checkpoint seguro 41 — Instituições: detalhe e reload v2 internos

- **Lote/ações tratadas:** leitura de detalhe e reload de Instituições pelo
  principal interno da spec 039. Listagem, opções de filtro, criação, edição,
  status, arquivos, importação/exportação e cutover Flutter permanecem fora
  deste pacote.
- **Contrato/migration:** a spec técnica
  040-superadmin-internal-institution-read-v2.md foi aprovada documentalmente
  pela coordenação, derivada estritamente das specs 011/039. A migration aditiva
  20260827234500_superadmin_internal_institution_detail.sql cria helper privado
  e wrapper público v2 sem alterar o helper compartilhado ou revogar contratos
  legados. Somente owner, operations e auditor podem ler; support e content
  ficam fail-closed; Owner exige AAL2.
- **Autorização/evidências:** a chamada revalida Auth, session_id,
  auth.sessions.not_after, link, membership, role, capability, MFA e escopo
  antes de interpretar o ID. Membership institucional lê somente sua FK;
  membership de plataforma autorizada lê A/B. ID inexistente, adulterado e
  cross-scope são indistinguíveis. O helper não tem EXECUTE de cliente; o
  wrapper é SECURITY DEFINER, owner postgres, search_path vazio e executável
  somente por authenticated.
- **Auditoria/persistência:** sucesso grava evento v2 minimizado por Instituição;
  negativas após sessão válida gravam v2/v3 correlacionado fora da
  subtransação. Falha do append aborta a RPC. O teste alterou o nome sintético
  entre duas chamadas e o reload observou o valor persistido; todas as fixtures
  foram revertidas por transação.
- **Testes executados:** replay Docker DB-only isolado no baseline até
  20260812001975, seguido por hardening ACL 20260827214000, Auth 20260827233000
  e a migration do domínio. O pgTAP passou 26/26 cobrindo envelopes exatos,
  reload, cross-tenant, cross-app, sessão expirada sem audit, membership
  suspensa, Support/Content, Owner AAL1/AAL2, Auditor, escopo platform, não enumeração,
  ACL e append fail-closed. Teardown terminou com zero container. Dois reviews
  independentes concluíram P0=0/P1=0.
- **Manifesto:** 107 migrations canônicas e mirror reconciliadas. Migration e
  mirror: 3.951 bytes, SHA-256
  EBFFF6AAE8614494A1C3FFDC35AB0BCA8E2AD0BCC28EB8C0062FBB242AAFDC98;
  pgTAP: 21.039 bytes, SHA-256
  20D47C0A2D1E23C103E231D99A93A7C3D9890662E218ADBA4FDCEAFFA941C2DD;
  spec aprovada: 7.116 bytes, SHA-256
  4A7481D7A569CF61AE1A448AF893281C5F334CFA5A5991A8D975CC6899C61EF9.
  Diff-check verde e nenhuma credencial real foi usada.
- **Estado local/remoto:** local-green somente para detalhe/reload v2. Zero
  mutação remota, deploy, Flutter ou E2E; não é remote-green nem done.
- **Bloqueios/pendências:** list/filter v2 já está em RED independente; escrita
  ainda depende de recibo/autoria internos sem reutilizar people. Contratos
  legados permanecem até cutover e regressão integrada.
- **Tempo usado:** aproximadamente 2 h 45 min do orçamento adicional.
  **Tempo restante:** aproximadamente 7 h 15 min; ETA do recorte principal
  permanece 8–17 dias focados e o backlog integral não é calculável.
### Checkpoint seguro 42 — Instituições: listagem e filtros v2 internos

- **Lote/ações tratadas:** `institutions.list` e `institutions.filter` no
  backend interno. A tela de Instituições passa a ter contrato local real para
  listar, buscar literalmente, filtrar, paginar, ordenar e carregar opções.
  Flutter, criação, edição, ativação, arquivos, importação/exportação e E2E não
  foram alterados.
- **Contrato/migration:** a spec 041 aprovada substitui somente as seções de
  diretório/opções da spec 040; detalhe/reload permanece canônico. A migration
  aditiva `20260827235500_superadmin_internal_institution_list_filter.sql`
  cria dois wrappers autenticados e helpers privados, sem alterar a view/RLS
  legada nem o helper compartilhado de autorização.
- **Autorização:** Auth, sessão, `not_after`, link, membership, role,
  `platform.read`, MFA e escopo são revalidados antes dos filtros. Somente
  Owner, Operations e Auditor entram; Owner exige AAL2. Membership institution
  enxerga apenas sua FK; Support e Content permanecem fail-closed.
- **Contrato comportamental:** limite 1–100, offset 0–10.000, 17 sorts com
  `NULLS LAST` e desempate `id ASC`; busca trata `%`, `_` e barra como
  literais. Filtros têm allowlist, teto JSON 8.192 bytes, textos 240 bytes,
  cardinalidade, UUID canônico e duplicidade normalizada. Outputs e opções usam
  chaves estritas e somente valores visíveis ao escopo.
- **Erros/auditoria:** `SAI_INVALID_ARGUMENT` foi acrescentado forward-only ao
  envelope interno com status semântico 400, preservando todos os códigos
  anteriores. Falhas desconhecidas viram erro interno; sucessos e negativas
  identificadas geram audit v2/v3 correlacionado e minimizado; falha de append
  aborta a RPC.
- **Testes executados:** stage Docker DB-only isolado até `20260812001975`,
  seguido por ACL `20260827214000`, Auth `20260827233000`, detalhe
  `20260827234500` e list/filter `20260827235500`. PgTAP list/filter passou
  35/35; regressões afetadas Auth 29/29 e detalhe 26/26 também passaram.
  Teardown terminou com zero recursos. Dois reviews independentes concluíram
  P0=0/P1=0.
- **Manifesto:** 108 migrations canônicas e mirror verificados. Migration e
  mirror: 23.552 bytes, SHA-256
  `0DB7F95A064242F3DB1D7D8A4D2B0631C5573CB55B0DEC19519047DD7ADBE604`;
  pgTAP: 27.817 bytes, SHA-256
  `D793F5B846BE62E5C5647068922BD7D04282B96B3CB613C701BFCC5BE91A4BC6`;
  spec 041: 6.807 bytes, SHA-256
  `65E260D24C7745800D82D151A5066C466843959947D701F4B93DB0C36CB6E66E`.
- **Estado local/remoto:** `local-green` somente. Zero mutação remota, deploy,
  Flutter ou E2E; não é `remote-green` nem `done`.
- **Bloqueios/pendências:** futura integração Flutter deve remover/desabilitar
  page size 500 e fazer cutover das APIs legadas. O preflight de shape da view é
  hardening P2. Escrita interna não pode reutilizar o realm `people`; edição
  core exige spec/receipt tipado e criação/ativação completa depende do contrato
  de Owner, convite e admin.
- **Tempo usado:** aproximadamente 4 h 30 min do orçamento adicional.
  **Tempo restante:** aproximadamente 5 h 30 min. ETA do recorte principal
  permanece 8–17 dias focados; backlog integral não calculável.

### Checkpoint seguro 43 — Instituições: EDIT CORE v2 ROOT+ADDRESS

- **Lote/ação tratada:** primeira fatia local de `institutions.edit`, limitada
  à raiz da Instituição e ao endereço. A spec canônica
  `042-superadmin-internal-institution-edit-core-v2.md` tem SHA-256
  `273578B535516638FC7C8B339C9AB80F05C361C2C9802B0859B99763553A0FC0`.
  O slice não promove a ação inteira nem a tela.
- **Migration/teste:** a migration forward-only
  `20260828000500_superadmin_internal_institution_edit_core.sql`, canônica e
  mirror, tem SHA-256
  `87996FEE97069C5B9B1C7A687E9A8CECC6C9A69A97029641A26357A7F7ACBD59`.
  O pgTAP `superadmin_internal_institution_edit_core_test.sql` tem plano 47 e
  SHA-256
  `8167B71B80C529B65409AC72A8CCD6CE8A21D516AC1E89ADEF5355CC74573A4A`.
  O manifesto terminou com 109 migrations canônicas e 109 mirrors idênticos.
- **Provas locais:** o replay isolado executou 47 testes EDIT CORE e todos os
  47 passaram. As regressões Auth 29/29, detalhe 26/26 e listagem/filtros 35/35
  também passaram: 137 testes executados no conjunto e todos os 137 verdes.
  Persistência na raiz/endereço e reload pelo detalhe v2 foram observados.
- **Concorrência/idempotência:** a corrida real com requests distintos produziu
  exatamente um sucesso e uma resposta `concurrent`; a corrida com request
  duplicado produziu exatamente uma mutação e um replay. Receipt privado,
  manifesto/hash, correlação, versões e auditoria 1:1 foram exercitados.
  Falha de receipt ou append de auditoria aborta a operação (`fail-closed`).
- **Ambiente/estado:** o teardown terminou sem container, volume, rede ou
  diretório Docker residual. Houve zero mutação remota, deploy, Flutter ou E2E;
  portanto o máximo comprovado é `local-green`, nunca `remote-green` ou `done`.
  O progresso geral de produto/E2E permanece 0/207 ações verificadas.
- **Fora de escopo/bloqueado:** contacts, criação/ativação, plano, branding,
  representantes/admins, status, domínio e documento. Contacts exigem um
  protocolo comum e versionado com os demais writers antes de entrar neste
  comando; não se deve contornar a concorrência reescrevendo o fluxo vigente.
- **Tempo adicional:** aproximadamente 7 h 30 min de um orçamento de cerca de
  10 h; restante aproximado de 2 h 30 min. São referências operacionais, não
  medição exata nem ETA do backlog integral.
- **Gate de conhecimento:** `no-op`. Nenhuma regra durável nova foi derivada
  para `docs/knowledge`; a fonte canônica permanece a spec 042.

### Checkpoint seguro 44 — Unidades: detalhe/reload v2 interno

- **Recorte/ações tratadas:** backend interno aditivo de detalhe da Unidade,
  com suporte ao reload de `units.reload`. A spec canônica
  `043-superadmin-internal-unit-detail-v2.md` está
  `approved-for-implementation`. Ela usa `platform.read` somente por
  compatibilidade, com allowlist Owner/Operations/Auditor; Owner exige AAL2,
  Support/Content permanecem `fail-closed` e o escopo platform/institution é
  validado no servidor. O slice não cria, aprova nem restaura
  `units.read`/`units.create`/`units.update`; OQ-032 continua aberta.
- **Output e regra física:** o JSON expõe somente `id`, `name`, `slug`,
  `status`, `institution {id,name,type {id,name}}`,
  `unit_type {id,name}`, `address`, `contact` e
  `effective_plan {id,code,name,inherited}`. Endereço ou contato sem linha
  não arquivada retorna `null`; linha `status='archived'` é tratada como
  ausente. O plano efetivo é determinístico: override vigente vence; sem
  override, usa a assinatura vigente mais recente por `created_at,id`; sem
  ambos, retorna `null`.
- **Migration/teste:** a migration forward-only
  `20260828002000_superadmin_internal_unit_detail.sql`, canônica e mirror, tem
  7.465 bytes e SHA-256
  `0943AF7A7D45B745A5C0651BF0D5E1CF85D84A32371CB6768E1222BD65FE1691`.
  O pgTAP `superadmin_internal_unit_detail_test.sql` tem 36.465 bytes, plano
  31 e SHA-256
  `B75159BB8F43F488926DF5BFA41D00956E0A01F8596CBBC9DA6FBE815EDC6C03`.
  O manifesto terminou com 110 migrations canônicas e 110 mirrors idênticos.
- **Provas locais:** replay isolado confirmou o RED específico do wrapper e
  helper antes da migration, depois passou UNIT 31/31 e as regressões Auth
  29/29, detalhe de Instituição 26/26, listagem/filtros 35/35 e EDIT CORE
  47/47: 168 testes executados e todos os 168 verdes. Persistência seguida de
  reload, auditoria v2/v3 1:1/minimizada/digest-valid e falha adversarial de
  append `fail-closed` foram exercitadas. Ledgers de dependências e alvo
  passaram; teardown terminou sem container, volume, rede ou diretório
  temporário residual.
- **Drift remoto separado:** a contraprova read-only mostrou que o remoto nao
  usa a policy global inicialmente inferida do HEAD. `unit_addresses` e
  `unit_contacts` estao FORCE RLS e usam `units.read` escopada a instituicao;
  a capability existe com grants Owner/Operations no realm legado. O acesso
  direto continua fora do gateway/audit interno, mas nao houve prova de
  cross-tenant fora do escopo. O slice permanece `local-green` e agora tambem
  `blocked-schema/provenance`: o remoto usa `unit_type_id/unit_types`, enquanto
  DETAIL v2 local usa `institution_type_id/institution_types`.

- **Ambiente/estado:** zero mutação remota, deploy, Flutter ou E2E. O máximo
  comprovado é `local-green` somente no backend; tela e integração não estão
  concluídas e o progresso geral de produto/E2E permanece 0/207 ações.
- **Tempo adicional:** aproximadamente 10 h consumidas neste pacote. O ETA do
  backlog integral permanece não calculável com os dados atuais.
- **Gate de conhecimento:** `no-op`. Os scripts `Search`/`Test` da memória não
  existem nesta checkout; nenhuma projeção foi inventada e a fonte canônica
  permanece a spec 043.

### Checkpoint seguro 45 - Units/Profile About: proveniencia e drift remotos

- **Lote/acoes tratadas:** somente inventario read-only de
  `20260811214000/11214500/11214600/11215451`,
  `20260821192000/21200000`, grants, policies, helpers e schema remoto. Nenhuma
  acao de produto foi promovida; 0/207 E2E permanece inalterado.
- **Proveniencia:** `11214000` equivale 140/140 ao blob original
  `c8f1f45e...`, `11214500` 50/50 ao blob `15a10f55...` e `11214600`
  4/4 ao blob `dca067c9...`. `11215451` e `text-conflict` e nao possui
  variante inspecionada equivalente. Profile/About `21192000` equivale 35/35
  ao hardened `4e3a89b3...`; `21200000` equivale 5/5 a `17096406...`.
  O original `e8c2086e...` e o local-only regressivo `25193131/a53cdc0f...`
  nao sao fontes implantadas validas.
- **Estado fisico remoto:** `units.read/create/update` e RPCs legadas existem;
  `units.read` esta ativa e concedida a Owner/Operations. As tabelas filhas
  estao FORCE RLS com `SELECT authenticated` e policies escopadas por
  `has_scoped_platform_permission('units.read', institution_id)`. O remoto usa
  `units.unit_type_id NOT NULL -> unit_types(id)`; ADR 0016/spec 017/spec 043 e
  DETAIL v2 local usam `institution_type_id/institution_types`.
- **Autoridade e risco:** helpers/RPCs Units e Profile/About derivam
  `current_person_id()` e memberships/atores people-based; nao validam o
  principal interno/sessao da spec 039. O acesso direto e alcancavel para ator
  legado valido, mas nao houve prova de exploracao HTTP ou BOLA/cross-tenant
  fora do escopo. `save_profile_about` escreve contato fora de
  `units.management_version`; `25193131` regride draft/publicacao/AAL2/erro
  seguro e permanece bloqueada.
- **Arquivos/migrations/RPCs alterados:** somente a spec 044, OQ-032 e
  rastreadores foram corrigidos documentalmente. Zero SQL, migration, funcao,
  grant, policy, Flutter ou mirror alterado.
- **Evidencias/testes:** comparacao individual por statement e SHA-256,
  catalogo/ledger remoto somente por SELECT e dois reviews Eng Sup P0/P1.
  Nenhum replay/Docker foi executado porque SQL esta RED e proibido neste lote.
- **Estado local/remoto:** DETAIL v2 continua `local-green +
  blocked-schema/provenance`; Design A esta `blocked-provenance/drift`.
  Nenhum estado e `remote-green`, deployable ou E2E. Zero mutacao remota.
- **Bloqueios/pendencias:** decidir sem inferencia
  `unit_types/unit_type_id` versus
  `institution_types/institution_type_id`; reconciliar dados, FKs, indices,
  capability/matriz e realms de forma forward-only; criar writer interno
  versionado para contato; nao restaurar recoveries ou `11215451` por nome.
- **Tempo usado:** nao mensurado com precisao neste inventario. **Tempo
  restante:** nao calculavel ate a decisao de schema/autoridade.
- **Gate de conhecimento:** `no-op`; a spec 044 bloqueada e OQ-032 registram a
  divergencia, sem projetar comportamento novo em `docs/knowledge`.

### Checkpoint seguro 46 - Grupos: detalhe/reload v2 interno

- **Lote/acoes tratadas:** contrato aditivo local para `groups.detail` e
  `groups.reload`, sem promover a tela ou a acao integrada. A spec 045 limita
  a leitura a Owner/Operations por `groups.read`; Owner exige AAL2 e
  Auditor/Support/Content permanecem `fail-closed`. O escopo
  platform/institution vem exclusivamente da membership interna da spec 039.
- **Contrato/output:** a RPC `superadmin_group_detail_v2(uuid)` retorna somente
  raiz fisica da Turma, Instituicao/Unidade, tipo textual, status, flags de
  heranca, versao e timestamps. Membros, convites, atividades, branding,
  acesso efetivo, contadores, arquivos e Auth ficam omitidos. ID inexistente ou
  cross-scope retorna o mesmo `SAI_PERMISSION_DENIED`, sem oracle.
- **Migration/teste:** `20260828003500_superadmin_internal_group_detail.sql`
  tem 8.587 bytes e SHA-256
  `F4F3CCACF25B28F0C1FD1BEF3F32FD25EBD572549FEBB04FDBA74DADF549C334`.
  O pgTAP `superadmin_internal_group_detail_test.sql` tem 41.649 bytes,
  plano 33 e SHA-256
  `CAFB534048A76658A626466F31740D5B8E87B49C2F96A1BA247DD3207301D609`.
  A spec 045 tem 11.572 bytes e SHA-256
  `11865CD1E85FADBF9F5103796F3D13B101D5532D7D4FD2EA47075B6BE0240880`.
- **Autorizacao/DDL:** o preflight exige owner `postgres`, Auth interno,
  `groups.unit_id NOT NULL`, FK composta validada, `groups.read` ativa sem MFA
  intrinseco e grants ativos exatos Owner/Operations. Nomes v2 preexistentes
  sao rejeitados para impedir overload residual. Helper privado nao tem EXECUTE
  de cliente/service e o wrapper publico concede somente a `authenticated`.
- **Provas locais:** o RED foi confirmado antes da migration. Depois, Groups
  passou 33/33; regressões Auth 29/29, Instituicao detalhe 26/26,
  listagem/filtros 35/35, EDIT CORE 47/47 e Unidade 31/31 tambem passaram:
  201 testes executados e todos os 201 verdes. Foram cobertos Owner/Operations,
  AAL, roles negados, sessoes invalidas, lifecycle, role/permission/grant
  inativos, grant revogado e efeito `deny`, cross-app/cross-tenant,
  persistencia/reload, shape, audit v2/v3 e append adversarial `fail-closed`.
  Fixtures ficaram em transacao com rollback.
- **Replay/mirror:** o stage final usou baseline ate `20260812001975` e somente
  as dependencies ACL/Auth/Instituicoes/Unidade allowlisted antes de Groups.
  A tentativa anterior pela cadeia completa parou no RED historico Child Safety
  `23502`; apos corrigir o staging, ela nao foi repetida. Prepare/Verify fechou
  111 migrations canonicas e 111 mirrors idênticos; teardown final deixou zero
  container, volume, rede ou diretorio temporario.
- **Proveniencia/remoto:** `20260811151254` permanece a unica base Groups com
  equivalencia formal 140/140. As seis migrations remotas posteriores ausentes
  do HEAD seguem apenas candidatas individuais, sem promocao/restauracao. Uma
  consulta remota agregada confirmou zero linhas Groups, sem PII; nenhuma
  migration, DDL, DML, Auth, Storage, Edge ou deploy remoto foi executado.
- **Estado/bloqueios:** maximo `local-green`. Nao e `remote-green`, deployable,
  `done` ou E2E. Flutter produtivo continua sem repository Supabase de Grupos.
  OQ-031, list/filter, create/edit/status/archive/delete, membros, convites,
  atividades, arquivos e import/export permanecem abertos; nenhuma das 207
  acoes integradas foi promovida.
- **Tempo usado:** nao mensurado com precisao neste lote. **Tempo restante:**
  nao calculavel para o backlog integral; depende de OQ-031, proveniencia das
  migrations remotas ausentes, Flutter e futura prova remota autorizada.
- **Gate de conhecimento:** `no-op`; a fonte canonica duravel e a spec 045 e
  nenhum comportamento remoto/integrado foi projetado em `docs/knowledge`.

### Checkpoint seguro 47 - Pessoas: detalhe/reload core v2 interno

- **Lote/acoes tratadas:** contrato aditivo local para `people.detail` e
  `people.reload`. A spec 046 limita a leitura ao Owner em AAL2 por
  `people.read`; Operations, Auditor, Support e Content permanecem
  `fail-closed`. O escopo platform/institution e derivado exclusivamente da
  membership interna da spec 039, sem usar `current_person_id()` ou
  `platform_memberships` como autoridade.
- **Contrato/output:** `superadmin_person_detail_v2(uuid)` retorna somente
  nomes essenciais, tipo/status, estado Auth coarse sem IDs, memberships e
  contextos infantis hierarquicos minimizados e `updated_at`. Nascimento,
  endereco, contato, documentos, e-mail, `auth_user_id`, sessao, guardian e
  summaries de plataforma ficam omitidos. ID ausente, apagado ou cross-scope
  converge em `SAI_PERMISSION_DENIED`, sem oracle.
- **Migration/spec/teste:** a spec 046 tem 17.575 bytes e SHA-256
  `E8BA681EF7FBE3A4AE72E0CDF3EBF7CE51A089DA9944D52E1472BF07AF63A355`.
  A migration `20260828005000_superadmin_internal_person_detail.sql` tem
  18.329 bytes e SHA-256
  `2076B1792A975A1328F6869984C1A01281B67DF84414B45E37DF92476329C7E3`.
  O pgTAP `superadmin_internal_person_detail_test.sql` tem 54.417 bytes,
  plano 42 e SHA-256
  `0B19FC78E5AC4378B62369CDB5A559E8CF7980FA2071A8B7A2B65DF71DAC2A95`.
- **Autorizacao e concorrencia:** sessao/Auth interno, capability/grant/role,
  AAL2, lifecycle e escopo sao revalidados no backend. A visibilidade,
  projecao e `FOR SHARE` da pessoa ocorrem na mesma instrucao/snapshot; nao ha
  promessa de versionamento de leitura ou lock de todas as linhas
  autorizadoras. Adulto, crianca e service usam ramos tipados; hierarquias e
  ciclos invalidos, expirados, revogados ou inativos sao excluidos.
- **Provas locais:** RED pre-migration confirmado. O replay final passou
  Pessoas 42/42 e regressao Auth 29/29, total focal 71/71. Foram cobertos
  Owner AAL2/AAL1, scope platform/institution, cross-app/cross-tenant,
  sessao divergente/expirada, role/capability/grant inativos ou revogados,
  efeito deny, lifecycle, hierarquia adulterada, multipath deterministico,
  minimizacao, persistencia/reload, audit v2/v3 correlacionado e append
  adversarial `fail-closed`. Fixtures ficaram em transacao com rollback.
- **Replay/mirror/cleanup:** projeto Docker descartavel com identidade e portas
  proprias; baseline ate `20260812001975`, depois ACL/Auth e Pessoas por
  `migration up --local`. Ledger local reconciliado; Prepare/Verify fechou
  112 migrations canonicas e 112 mirrors identicos. Teardown final deixou
  zero container, volume, rede ou diretorio temporario.
- **Estado local/remoto/integrado:** maximo `local-green`. Zero migration,
  DDL/DML, Auth, Storage, Edge ou deploy remoto; nao e `remote-green`,
  deployable, `done` ou E2E. O Flutter produtivo ainda chama gateways Pessoas
  legados people-based; cutover e regressao integrada permanecem P0 separado.
  Nenhuma das 207 acoes integradas foi promovida.
- **Bloqueios/pendencias:** list/filter/options, create/edit, vinculos,
  import/export e activity filter permanecem fora. Grants/RLS legados amplos
  exigem inventario e cutover compativel, sem revogacao neste pacote. OQ-033 e
  OQ-036 permanecem abertas nos respectivos recortes.
- **Tempo usado:** nao mensurado com precisao neste lote. **Tempo restante:**
  nao calculavel para o backlog integral; depende dos contratos Pessoas
  restantes, cutover Flutter, reconciliacao remota e prova autorizada.
- **Gate de conhecimento:** `no-op`; a fonte canonica duravel e a spec 046 e
  nenhum comportamento remoto/integrado foi projetado em `docs/knowledge`.

### Checkpoint seguro 48 - Convites draft/proveniencia e estado historico de Perfis de cuidado

- **Lote/acoes tratadas:** somente inventario read-only, spec 047
  `draft-for-review` e OQ-039 para Convites. Nenhuma acao de listar,
  detalhar/reload, criar, reenviar, revogar, aceitar ou entregar foi
  implementada ou promovida.
- **Proveniencia Convites:** `20260811233609` e recuperavel pelo blob
  `840e4cab50a3b37929822ca88ed3919ae7d2e8b2`, SHA-256 LF
  `D387F117DDE47462787F89D94026464FAA0956FFB6D7CF576D89A1CD888B1077`,
  mas foi removida do HEAD, esta ausente do ledger remoto e usa
  `current_person_id()`, People, receipts/outbox e audit v1. A prova historica
  60/60 pertence a cadeia composta com teste hardened e `20260813123901`,
  nao a migration isolada.
- **Decisoes Convites:** capability dedicada versus eventual `platform.read`,
  matriz/delegacao, scope platform/institution, dominio do convite, issuer
  interno nullable sem backfill, shape minimizada, `channels` legado
  `unknown` e ACL/cutover continuam abertas. A autoridade atual bloqueia RED
  executavel, migration/SQL, capability e backfill; `11233609` nao foi
  restaurada.
- **Risco legado separado:** o snapshot remoto SELECT-only tem RLS habilitada
  sem FORCE, self-read people-based e grants que alcancam colunas sensiveis.
  Isso exige inventario e cutover antes de hardening; nao foi alegada BOLA
  comportamental nem feita qualquer mutacao remota.
- **Perfis de cuidado:** inventario independente classificou todo o dominio
  `blocked-decision + blocked-provenance`. As recoveries local-only
  `20260812123500` e `20260812124000` lidam com saude infantil sensivel,
  autorizacao people-based e regras juridicas/retencao nao aprovadas. Nenhuma
  recovery, tabela, policy, RPC ou grant foi restaurado ou alterado.
- **Supercessao em 2026-08-28:** por decisao explicita posterior do Owner
  Coelo, a pendencia juridica deixou de bloquear o trabalho Supabase local de
  Perfis de cuidado. Permanece somente a necessidade tecnica de selecionar a
  proveniencia, substituir a autoridade people-based pelo principal interno,
  escrever a spec tecnica e provar RLS, tenant A/B, auditoria, persistencia e
  reload com dados sinteticos. A decisao nao autorizou dado real, deploy ou
  mutacao remota e nao definiu retencao.
- **Evidencias/testes:** revisoes read-only de proveniencia e contrato pelo Eng
  Sup e contraprova independente. Nenhum Docker ou pgTAP foi executado porque
  RED/SQL ficaram explicitamente bloqueados; o mirror permanece no baseline
  previamente verificado 112/112.
- **Estado:** documental/proveniencia apenas, nao `local-green`,
  `remote-green`, deployable, `done` ou E2E. Zero Flutter, Auth, Storage,
  Edge, migration, DDL/DML ou deploy remoto. Nenhuma das 207 acoes integradas
  foi promovida.
- **Tempo usado:** nao mensurado com precisao neste lote. **Tempo restante:**
  nao calculavel; Convites depende da OQ-039; Perfis de cuidado depende agora
  somente da spec tecnica, proveniencia, implementacao local, cutover e futura
  prova remota autorizada.
- **Gate de conhecimento:** `no-op`; a fonte canonica e a spec 047 draft mais
  OQ-039. Nenhum comportamento aprovado/implantado novo foi projetado em
  `docs/knowledge`.

### Checkpoint seguro 49 - Assiduidade draft/proveniencia

- **Lote/acoes tratadas:** inventario read-only, OQ-040 e spec 048
  `draft-for-review` para futuro detalhe/reload de chamada. Nenhuma acao de
  listar, detalhar, criar, marcar, concluir, reabrir, corrigir, cancelar,
  exportar ou agendar foi implementada ou promovida.
- **Fundacao:** `20260724152731` esta no ledger remoto; commit
  `b6c4095a85ea454ee9febc61a9b8aac2862d46d2`, blob
  `9539cb6a4fddd0d1d211497c2a95ef30ebdf07fe` e SHA-256
  `D8F99E587330EB4EC8F30525097A25667CC593B0CB03722DC89B1CDF47269AE6`.
  Sua autoridade e people-based e nao serve ao principal interno.
- **Dashboard/cadeia:** `20260825171221` e canônica local, mas ausente do
  ledger remoto; SHA-256
  `E3A93182083FE3EE80A500D1FB91DBEB7195E9C01A6D239C3D5EB4F0DA9C1128`.
  As RPCs de chamada esperadas pelo Flutter aparecem somente na cadeia
  local/recovery removida `11231000..12150100`, misturada com Rotina,
  people-based, receipts de Pessoa e audit v1. Nada foi restaurado.
- **P0 remoto de autorizacao:** Flutter injeta
  `SupabaseAttendanceRepository` e chama RPCs inexistentes no remoto. Separado
  desse gap, o snapshot SELECT-only provou que
  `can_access_attendance_child(..., require_manage)` aceita `platform.read`
  antes de diferenciar gestao. A permission tem grants ativos para os cinco
  papeis de plataforma e o helper alcanca confirmacao/reversao e a policy
  `ALL` de participantes esperados. Definicoes, ACLs e policies tornam a
  autorizacao SQL cross-tenant por ID factual; nenhum DML/HTTP foi executado e
  nenhum incidente foi afirmado. O hardening forward-only e pacote separado,
  ainda sem autorizacao de deploy.
- **Decisoes:** capability interna, matriz/AAL, scope platform/institution,
  shape infantil/DTO e cutover permanecem abertas. Dashboard/list/export,
  writes, schedule e cancel sao pacotes separados.
- **Evidencias/testes:** inventario e proveniencia read-only com contraprova
  independente concluida. O review confirmou o P0 SQL factual em helper,
  wrappers, policy e grants, sem executar DML/HTTP. Nenhum Docker/pgTAP foi
  executado porque RED e SQL/migration estao bloqueados; baseline mirror
  permanece 112/112.
- **Estado:** `blocked-contract/provenance`, apenas documental; nao
  `local-green`, `remote-green`, deployable, `done` ou E2E. Zero
  migration, DDL/DML, Auth, Storage, Edge, Flutter ou deploy remoto.
- **Tempo usado:** nao mensurado com precisao. **Tempo restante:** nao
  calculavel; depende da OQ-040, cutover e prova remota autorizada.
- **Gate de conhecimento:** `no-op`; spec 048 draft e OQ-040 sao as fontes
  canonicas desta investigacao, sem comportamento aprovado novo em
  `docs/knowledge`.

### Checkpoint seguro 50 - Perfis de cuidado B+C exclusivamente Superadmin

- **Decisao/recorte:** o Owner Coelo selecionou B+C apenas para o Superadmin:
  Owner interno com alcance global e diretorio tambem restritivo por
  instituicao/unidade. Admin e Principal nao recebem gateway, papel ou
  autoridade. A spec 049 foi redigida como `draft-for-review`; nenhum RED
  executavel, migration ou SQL de implementacao foi iniciado.
- **Capacidades:** o desenho usa `care_profiles.read`,
  `care_profiles.manage` e `care_profiles.archive`, todas criticas e com AAL2.
  Owner recebe grants explicitos iniciais e protecao da ultima cadeia global;
  nao existe bypass por nome. Os demais perfis futuros dependem do catalogo e
  grants de Perfis de Acesso; o comando produtivo de governanca permanece
  follow-up.
- **Escopo:** a membership da spec 039 continua somente
  `platform|institution`. Unidade e materializada por assignment privado Care
  `platform|institution|unit`, sempre como restricao adicional. Sem assignment
  ativo o acesso e negado; suspensao/revogacao nunca faz fallback para escopo
  mais amplo. FK composta valida unidade e instituicao.
- **Contrato proposto:** diretorio, detalhe/reload, create, edit e archive
  terminal; schema versionado, revisoes imutaveis, receipts privados,
  concorrencia por `expected_version`, auditoria v2/v3 e envelope seguro. A
  saida omite medicamentos, doses, alergias estruturadas, arquivos, contato,
  nascimento, Auth IDs e payload clinico em audit.
- **Seguranca:** autoridade exclusiva de
  `require_superadmin_internal_context`; `people`, memberships legadas,
  claims/filtros do cliente e `service_role` nao autorizam. Tabelas usam FORCE
  RLS, zero policies permissivas/grants; wrappers publicos somente
  `authenticated`; helpers privados sem EXECUTE de cliente.
- **Proveniencia:** as migrations historicas `20260812123500`,
  `20260812124000`, `20260813182000` e `20260813184051` nao serao restauradas:
  sao people-based, local-only e/ou ativam regras nao aprovadas. O pacote sera
  forward-only e reconstruido sob a spec 039.
- **Review:** Eng Sup classificou GREEN para a spec 049 e RED estrutural
  futuro desde que unit seja assignment privado; ampliar enum/membership Auth
  global dentro de Care e P0. A spec escrita ainda aguarda revisao do Owner
  antes do plano TDD e do SQL.
- **Estado e ambiente:** `draft-for-review`; nao `local-green`,
  `remote-green`, deployable, E2E ou `done`. Zero Docker, pgTAP, migration,
  DDL/DML, Auth, Storage, Edge, Flutter ou mutacao remota. O ledger e o mirror
  permanecem no ultimo baseline aceito 112/112.
- **Progresso:** geral estrito continua 0/228 unidades `done`; o rastreador
  integrado continua 0/207 E2E. O recorte Care concluiu somente desenho e
  proveniencia; implementacao, testes, consolidacao, cutover e remoto seguem
  pendentes.
- **Proximo passo seguro:** revisar/aprovar a spec 049; depois escrever plano,
  RED estrutural e migration forward-only em lote local isolado. Produção com
  dados reais e release gates continuam separados, sem inferir retencao.
- **Tempo usado:** nao mensurado com precisao. **Tempo restante:** estimativa
  inicial de 3-5 dias focados para schema+CRUD+pgTAP local completo; cutover
  Flutter, remoto e E2E sao estimados separadamente apos seus contratos.
- **Gate de conhecimento:** `no-op`; a fonte canonica nova e a spec 049 draft.
  Nenhum comportamento implantado ou integrado foi projetado em
  `docs/knowledge`.

### Checkpoint seguro 51 - abertura da fundacao cross-app e drift datado

- **Progresso obrigatorio:** projeto estrito `done` 0,00% (0/229), restante
  100,00% (229/229); Flutter local no baseline anterior 40,58% (84/207), sem
  recalcular a frente visual ativa; Flutter `verified` 0,00% (0/207);
  Supabase local no baseline aceito 8,11% (3/37 familias), Supabase `done`
  0,00% (0/37); integracao E2E 0,00% (0/202); backlog Supabase estrito
  `done` 0,00% (0/228), restante 100,00% (228/228). O gate operacional do
  Dia 1 concluiu 80,00% (4/5): worktree, inventario remoto, manifesto/mirror e
  plano persistente; falta o primeiro RED SQL executavel.
- **Objetivo e paths:** a branch `codex/supabase-cross-app-foundation` nasceu
  limpa de `dev` em `c9b7114b`, na worktree isolada
  `.worktrees/supabase-cross-app-foundation`. O recorte reserva somente banco,
  testes SQL, fontes canonicas e rastreadores autorizados. A worktree visual e
  seus arquivos dirty permaneceram intocados; nenhuma alteracao ocorreu em
  `apps/**` ou `packages/coelo_ui_*`.
- **Inventario local e drift:** 112 migrations canonicas e 112 mirrors foram
  regenerados/verificados com nomes e conteudo identicos. O manifesto datado
  classifica 112 locais e 103 registros remotos: 50 nomes/versoes exatos,
  oito versoes com nomes divergentes nos dois lados (16 linhas `unresolved`),
  54 `local-only` e 45 `remote-only`. Hash SHA-256 local e dependencias
  aproximadas foram registrados; o plugin nao fornece hash remoto, portanto
  nenhum nome igual ou parecido foi promovido a equivalencia textual sem
  prova.
- **Remoto read-only:** `coelo` (`evvbomzejfijozbtgvpt`) esta saudavel, mas
  permanece `blocked-environment` por falta de classificacao documental entre
  desenvolvimento, homologacao e producao. O catalogo vivo corrigiu o
  baseline para 180 tabelas `public`, 3 `audit` e 35 `app_private`; as 180
  publicas tem RLS, 87 tem FORCE RLS, e `audit.profile_about_commands` nao tem
  RLS. Ha 223 funcoes publicas, 205 `SECURITY DEFINER`, 174 executaveis por
  `authenticated` e 156 que combinam ambos. Edge Functions permanecem 10;
  `form-operations` e `circular-media` continuam `verify_jwt=false` apenas
  classificadas. Advisors seguem 207 de seguranca (50/156/1) e 505 de
  desempenho (128/377). Nenhuma mutacao remota foi feita ou proposta.
- **Migration/teste e RED/GREEN:** a fundacao aprovada continua materializada
  em `20260827233000_superadmin_internal_auth_context.sql`, com pgTAP
  `superadmin_internal_auth_context_test.sql`; nenhuma migration foi criada ou
  editada. O primeiro RED de comportamento nao pode ser executado porque o
  Docker Desktop falha ao iniciar ao remover o reparse point travado
  `dockerInference`. O unico GREEN fresco e estrutural: Prepare/Verify do
  mirror 112/112. Os 29/29 Auth e demais regressoes sao evidencia historica,
  nao foram reclassificados como prova desta execucao.
- **Diagnostico e seguranca local:** CLI Supabase 2.116.0, Docker CLI 29.7.2 e
  Docker Desktop 4.86.0 foram registrados. Tentativas distintas de remover o
  socket e iniciar o servico falharam por acesso do sistema; o loop foi
  encerrado. A ferramenta Docker exibiu fluxo de reset, mas nenhum reset de
  fabrica foi autorizado ou comandado. O PowerShell 5.1 exigiu importar
  explicitamente o modulo inbox `Microsoft.PowerShell.Utility` para restaurar
  `Get-FileHash`; isso resolveu apenas o verificador de mirrors.
- **Estado, tempo e ETA:** checkpoint documental/read-only, nao
  `local-green` fresco, `remote-green`, deployable, E2E ou `done`. Tempo medido
  desta abertura: aproximadamente 20 minutos ate 09:54 -03:00. O orcamento
  restante permanece dentro dos quatro dias focados, mas a ETA executavel
  depende de reinicio/reparo do Docker antes dos Dias 2-4.
- **Primeiro gate incompleto e proximo comando seguro:** restaurar o daemon
  Docker sem reset destrutivo e executar
  `& packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260827233000`.
  Ate isso ocorrer, nao ha autorizacao para usar o remoto como substituto.
- **Gate de conhecimento:** `no-op`; manifesto, plano e OQ-041 registram
  execucao/proveniencia e bloqueio, sem comportamento duravel novo para
  projetar em `docs/knowledge`.
- **Consolidacao segura apos o checkpoint:** o ledger commitado em `a1cc69f6`
  comprovou novamente os 41/41 patches da branch backend legada como
  equivalentes em `dev`. A worktree antiga, limpa, foi removida; sua branch e
  todos os commits foram preservados para a auditoria final.

### Checkpoint seguro 52 - Docker reparado e fundacao replay-green

- **Progresso:** projeto estrito `done` 0,00% (0/229); Supabase estrito
  `done` 0,00% (0/228); Supabase `done` 0,00% (0/37); Flutter e E2E
  permanecem inalterados. Dos quatro gates do macrotema, Dia 1 e Dia 2 estão
  fechados localmente: 50,00% (2/4), restante 50,00% (2/4). Dia 3 aguarda
  classificação/fechamento do lint histórico e Dia 4 aguarda regressão final,
  documentação e consolidação.
- **Docker:** o daemon foi recuperado sem apagar imagens/volumes. As pastas de
  runtime com sockets AF_UNIX corrompidos `dockerInference` e
  `docker-secrets-engine/engine.sock` foram movidas para backups reversíveis;
  Docker 29.7.2 voltou a responder. O próprio diálogo Docker registrou reset
  de aplicação durante uma falha anterior; nenhum comando desta tarefa pediu
  reset de fábrica. Imagens/volumes estavam vazios antes e depois.
- **REDs:** o replay integral reproduziu, em ordem, SQLSTATE `23502` por labels
  obrigatórios sem default, `42703` por `platform_role_permissions.updated_at`
  ausente, `42P01` por attestation de Unit Import removida e `42883` por
  funções Unit Import ausentes. Os dois últimos pertencem a Import/Export fora
  do recorte e não foram ocultados por stubs ou restauração de endpoints.
- **Correção mínima:** criado pelo CLI 2.116.0
  `20260831130726_reconcile_permission_labels_after_replay.sql`. Um bridge
  exclusivo de replay, imediatamente após `20260811215451`, fornece defaults
  sentinels e a coluna histórica `updated_at`; a migration atual normaliza os
  labels e remove os seis defaults. O perfil `FoundationOnly`, fechado por
  manifesto de nomes e SHA-256, seleciona exatamente 50 migrations canônicas
  revisadas e dois preflights; oito migrations de produto foram negadas e
  migrations futuras não entram automaticamente. O
  replay integral continua um gate RED separado em OQ-042.
- **GREEN e regressões:** replay focado instalou até `20260831130726`; nove
  arquivos pgTAP passaram inicialmente com 259 asserts e, após review
  adversarial, com 264 asserts. Incluem contrato fail-closed de drift,
  defaults/labels 9/9,
  default ACL, Auth 29/29, instituição detalhe/lista/edit, unidade, grupo e
  pessoa, cobrindo sessão, AAL, lifecycle, capability/grant, tenant A/B,
  sibling, cross-app, persistência/reload e auditoria. Cada execução terminou
  com zero container, volume, rede ou diretório temporário do replay.
- **Lint:** `supabase db lint --local --level warning --fail-on error`
  permaneceu RED por erros históricos já materializados em Activity,
  Import/Export e Access Profiles, além de warnings históricos de auditoria e
  domínio. O validator privado criado pelo delta não recebeu achado; nenhum
  erro foi atribuído silenciosamente a ele.
  O fechamento desses erros exige pacotes de proveniência próprios e mantém o
  Dia 3 incompleto.
- **Mirror/segredos/remoto:** canônico/mirror 113/113 verificado; `git diff
  --check` limpo e scan de JWT/service key zerado. Zero mutação remota; `coelo`
  continua `blocked-environment`, sem `remote-green`.
- **Tempo/ETA:** aproximadamente 1 h medida desde a abertura até este GREEN.
  Restam até três dias do orçamento para matriz/lint do recorte, regressão,
  rastreadores e consolidação, condicionados ao checkpoint visual.
- **Próximo passo:** revisar e commit-ar o pacote replay/labels, classificar os
  achados de lint relevantes à fundação e repetir pgTAP+lint. Flutter, UI,
  Import/Export funcional, mídia, Edge e remoto continuam fora.
- **Reconsulta remota pós-GREEN:** plugin oficial, somente leitura, confirmou
  ledger ainda em 103 migrations até `20260821200000`; Security Advisor ainda
  207 (50 RLS sem policy, 156 SECURITY DEFINER executáveis por authenticated e
  1 proteção de senha vazada) e Performance Advisor ainda 505 (128 FKs sem
  índice e 377 índices não usados). O delta local não existe no remoto.
- **Gate de conhecimento:** `no-op`; a mudança é infraestrutura de replay e
  reconciliação de schema, documentada nas fontes técnicas e OQ-042, sem novo
  comportamento de produto para `docs/knowledge`.

### Checkpoint seguro 53 - review adversarial fechado no replay da fundacao

- **Progresso:** os estados gerais permanecem: projeto estrito `done` 0,00%
  (0/229), Supabase estrito `done` 0,00% (0/228), Supabase `done` 0,00%
  (0/37), Flutter `verified` 0,00% (0/207) e E2E 0,00% (0/202). Gates do
  macrotema: 50,00% (2/4), restante 50,00% (2/4).
- **RED de review:** o filtro aberto admitia oito migrations de produto e
  qualquer migration futura; alvos parciais podiam encerrar antes da limpeza
  do bridge; defaults inesperados poderiam ser removidos sem preflight.
- **GREEN:** `foundation-migrations.sha256` fixa 50 nomes/hashes; o teste do
  perfil prova oito exclusões e todos os hashes. `FoundationOnly` aceita apenas
  o alvo final `20260831130726`, antes de iniciar Docker. Um bloco catalogal
  read-only roda antes de qualquer DDL e rejeita tabela/coluna/função inesperada;
  só depois a transação explícita cria o validator privado. Ele falha com
  SQLSTATE `55000` em owner, tipo, nullability ou default inesperado, tem EXECUTE
  revogado e é testado com drifts sintéticos revertidos por rollback.
- **Regressão:** nove arquivos pgTAP somam 265 asserts após a cobertura estrutural;
  o teste focal passou 10/10. Rejeições de alvo parcial,
  caminho fora da raiz e extensão não SQL ocorreram antes do Docker. O lint
  repetiu os erros históricos classificados e não apontou o validator novo.
  Todos os caminhos terminaram com zero container, volume e rede residual.
- **Estado local/remoto:** somente local; nenhum arquivo `apps/**` ou UI foi
  tocado. Remoto permanece `blocked-environment`, read-only, sem `remote-green`.
  Gate de conhecimento: `no-op`.
- **Próximo passo:** commit focado, nova revisão e então TDD dos erros de lint
  de Access Profiles que pertencem ao gate de capacidades/RLS. Activity e
  Import/Export continuam em pacotes de proveniência fora deste recorte.

### Checkpoint seguro 54 - nucleo de capacidades e RLS local-green

- **Progresso:** gates do macrotema concluídos 75,00% (3/4), restante 25,00%
  (1/4). Projeto estrito `done` 0,00% (0/229), Supabase estrito `done` 0,00%
  (0/228) e Supabase `done` 0,00% (0/37) permanecem inalterados.
- **RED:** o pgTAP novo falhou 4/5 no baseline: faltava unicidade canônica de
  override, o domínio Principal era ambíguo e o catálogo aninhava agregações.
  O lint confirmava SQLSTATE `42803`, `42702` e `42P10` no núcleo de Access
  Profiles.
- **GREEN:** migration CLI `20260831134407_harden_access_profile_capability_core`
  faz preflight fail-closed, rejeita duplicatas ativas e cria unicidade sem
  `effect`, impedindo allow+deny ativos simultâneos. Os helpers privados foram
  corrigidos, mantêm owner `postgres`, `search_path=''` e EXECUTE cliente
  revogado. O teste focal passou 5/5.
- **Regressão/lint:** replay fechado de 51 migrations canônicas + dois
  preflights passou dez arquivos/270 asserts e terminou sem recursos residuais.
  Os três erros de lint do núcleo desapareceram. Restam erros históricos de
  Activity/Import-Export e `superadmin_access_profile_import_stage`, fluxo de
  arquivo/importação explicitamente fora deste pacote; warnings foram mantidos
  classificados, não ocultados.
- **Mirror:** o primeiro cleanup expôs que 17 mirrors legados são rastreados
  apesar do ignore global; as deleções locais foram restauradas do HEAD antes
  de qualquer commit. O sync agora preserva arquivos rastreados, exige hash
  idêntico ao canônico e remove somente staging ignorado. Prepare/Verify passou
  114/114 e o Clean terminou com 17/17 rastreados, zero dirty.
- **Estado:** Dia 3 fechado localmente; remoto continua `blocked-environment` e
  read-only. Flutter/UI não foi tocado. Gate de conhecimento `no-op`.
- **Próximo passo:** executar fechamento do Dia 4: mirror/hash, secret scan,
  documentação final, revisão do novo delta e ledger de consolidação; aguardar
  checkpoint visual antes de avançar `dev`.

### Checkpoint seguro 55 - gateways, sibling scope e cleanup junction-safe

- **Review RED:** a primeira revisão pós-GREEN provou três falhas: wrappers
  `SECURITY INVOKER` perderam acesso aos helpers privados; overrides de sibling
  units eram agregados sem escopo exato; e `Clean` aceitava mirror em junction.
  O estado Dia 3 foi tratado como em correção até nova evidência.
- **GREEN comportamental:** os dois gateways públicos nominais agora são
  `SECURITY DEFINER`, owner `postgres`, `search_path=''`, EXECUTE somente para
  `authenticated` e alcançam a autorização backend; os helpers continuam sem
  EXECUTE cliente. O reducer privado usa membership + permission + scope kind +
  unit/group com `IS NOT DISTINCT FROM`. Fixture rollback-only com efeitos
  opostos em duas unidades provou isolamento. Teste focal 13/13; total do gate
  passa a 278 asserts em dez arquivos.
- **Unicidade:** o UUID zero usado somente como sentinel do índice foi proibido
  por constraint, eliminando colisão com escopo real; duplicatas allow+deny no
  mesmo escopo continuam fail-closed antes do DDL.
- **Filesystem:** o sync rejeita reparse point no mirror ou ancestrais antes de
  enumerar/deletar. Contraprova com junction externo foi rejeitada, preservou o
  `must-survive.sql`, restaurou os 17 mirrors rastreados e deixou zero dirty.
- **Remoto read-only:** ledger permanece 103 até `20260821200000`; Advisors
  permanecem segurança 207 (50/156/1) e desempenho 505 (128/377). Nenhuma
  migration local foi aplicada e o ambiente continua `blocked-environment`.
- **Estado:** Dia 3 volta a local-green somente após estas provas; macrotema
  75,00% (3/4), restante 25,00% (1/4). `done`, Flutter e E2E inalterados.
  Próximo passo: regressão completa, review final e consolidação após worktree
  visual limpa.

### Checkpoint seguro 56 - Dia 4 local-green e portátil

- **Progresso do macrotema:** 100,00% dos gates locais (4/4), restante 0,00%
  (0/4). Projeto estrito `done` permanece 0,00% (0/229), backlog Supabase
  estrito `done` 0,00% (0/228) e famílias Supabase `done` 0,00% (0/37).
- **RED de portabilidade:** o mesmo blob Git de uma migration produzia hash
  diferente em worktrees LF/CRLF e o replay recusava uma checkout válida.
- **GREEN:** scripts e manifesto calculam SHA-256 de texto UTF-8 normalizado em
  CRLF. O perfil aceitou 51 migrations revisadas, manteve oito exclusões e
  executou dois preflights + dez arquivos pgTAP/278 asserts até
  `20260831134407`.
- **Regressão:** mirror `Prepare`/`Verify` 114/114; lint repetiu somente erros
  históricos classificados de Activity/Import-Export; cleanup terminou sem
  container, volume ou rede `coelo_safe_*` residual. Nenhuma fixture, PII ou
  segredo foi persistido.
- **Estado:** fundação do recorte `local-green`, reproduzível; remoto continua
  `blocked-environment`, read-only, ledger 103 e sem `remote-green` ou `done`.
  Gate de conhecimento `no-op`. Próximo comando seguro remoto continua sendo
  apenas inventário SELECT; qualquer mutação exige autorização nominal.

### Checkpoint seguro 57 - retomada, Docker e regressão fresca

- **Progresso:** macrotema local permanece 100,00% (4/4), restante 0,00%
  (0/4). Projeto estrito `done` permanece 0,00% (0/229), backlog Supabase
  estrito `done` 0,00% (0/228) e famílias Supabase `done` 0,00% (0/37).
- **Worktree/Docker:** branch `codex/supabase-foundation-continuation` criada
  limpa de `dev` em `e0404638`. O primeiro replay evidenciou mirror ainda não
  preparado; após `Prepare` e `Verify` nativos, 114/114 hashes passaram. Docker
  executou o perfil isolado e terminou sem container, volume ou rede residual.
- **GREEN fresco:** replay de 51 migrations canônicas + dois preflights até
  `20260831134407`; Auth 29/29 e regressão completa dez arquivos/278 asserts,
  todos verdes. Nenhuma fixture, PII ou segredo foi persistido.
- **Lint visível:** os testes passaram antes de o lint encerrar em RED pelos
  quatro erros históricos já classificados: `42702` em imports Activity/Groups,
  `42804` no import de Access Profiles e `42703` no file job. Importação,
  exportação e arquivos continuam explicitamente fora do recorte; não houve
  migration corretiva sem contrato.
- **Remoto read-only:** plugin oficial confirmou projeto `ACTIVE_HEALTHY`, 103
  migrations, 10 Edge Functions, segurança 207 (50/156/1) e desempenho 505
  (128/377). Inventário SELECT confirmou 180 tabelas `public` com RLS, três em
  `audit` e `audit.profile_about_commands` ainda sem RLS. O ambiente permanece
  `blocked-environment`; nenhuma DDL/DML/Auth/Edge/configuração remota ocorreu.
- **Estado/tempo:** checkpoint medido nesta retomada de 12:55 a 13:08 BRT,
  aproximadamente 13 minutos. Fundação continua `local-green`; `remote-green`
  e `done` não foram promovidos. Gate de conhecimento `no-op`.
- **Próximo passo seguro:** preservar o recorte concluído e classificar a
  autoridade do ambiente remoto por evidência documental. Qualquer correção do
  lint histórico exige pacote próprio; qualquer mutação remota exige autorização
  nominal com migrations, hashes, objetos, risco e estratégia forward-only.

### Checkpoint seguro 58 - guard de proveniência e Docker restaurado

- **Progresso:** macrotema local permanece 100,00% (4/4), restante 0,00%
  (0/4). Projeto estrito `done` permanece 0,00% (0/229), backlog Supabase
  estrito `done` 0,00% (0/228) e famílias Supabase `done` 0,00% (0/37).
- **RED:** replay das 51 migrations anteriores chegou ao pgTAP novo, que falhou
  pela ausência de `app_private.assert_unit_hierarchy_contract()`. A primeira
  implementação também falhou corretamente antes do commit porque comparava a
  renderização textual da FK; o diagnóstico foi alterado para identidade
  catalogal de tabela/coluna e alvo.
- **GREEN:** migration CLI
  `20260831164937_assert_unit_hierarchy_contract.sql`, SHA-256 normalizado
  `34b22ee247857f56ac5c80d55694544a60c42fe3c373089ab37749aba47d6ca5`,
  cria guard privado invoker, `search_path=''` e sem EXECUTE cliente. O teste
  focal passou 7/7, incluindo a contraprova do formato remoto divergente;
  replay e regressão passaram 52 migrations + dois preflights, 11 arquivos
  pgTAP e 285 asserts. Mirror `Prepare`/`Verify`: 115/115.
- **Proveniência remota read-only:** `units.unit_type_id not null` referencia
  `unit_types(id)` e diverge do contrato local aprovado
  `institution_type_id -> institution_types`. O guard falharia antes de uma
  aplicação incompatível, mas não resolve OQ-032 e nenhuma mutação remota foi
  feita.
- **Docker:** o reset concluído na interface foi seguido da desativação de
  Docker AI, componente que recriava o socket AF_UNIX inválido. Engine 29.7.2
  voltou saudável; o wrapper terminou sem container, volume ou rede
  `coelo_safe_*` residual.
- **Lint/fora do pacote:** os 285 asserts passaram antes de o lint repetir dois
  `42702` em imports Activity/Groups, um `42804` no import de Access Profiles e
  um `42703` no file job. Importação, exportação, arquivos e mídia existentes
  foram preservados integralmente; não foram apagados, revertidos, desativados
  ou corrigidos neste lote.
- **Estado e próximo passo:** fundação permanece `local-green`; remoto continua
  `blocked-environment`, read-only, sem `remote-green` ou `done`. Primeiro gate
  incompleto é a decisão canônica OQ-032 e a classificação documental do
  ambiente remoto. Gate de conhecimento: `no-op`, pois não nasceu regra durável
  de produto nem comportamento implantado novo.

### Checkpoint seguro 59 - commits backend prontos para consolidação

- **Commits:** `04da0141` e `0f3b6ebf` são as duas únicas linhas `+` de
  `git cherry dev codex/supabase-cross-app-foundation`; ambos estão alcançáveis,
  testados e preservados em worktree limpa.
- **Gate local:** manifesto 52/52, mirror 115/115, regressão 11 arquivos/285
  asserts, secret scan sem ocorrência e cleanup Docker zero permanecem verdes.
- **Consolidação:** `dev` contém lote não commitado de Formulários/UI/docs
  visuais. Nenhum arquivo dessa frente foi alterado, staged ou commitado pelo
  backend. O fast-forward/cherry-pick fica condicionado ao status limpo para
  impedir mistura ou perda de trabalho.
- **Tempo restante local:** 30–60 minutos após a liberação limpa de `dev` para
  integrar, repetir gates, atualizar o ledger e remover somente a worktree e a
  branch backend. Remoto e OQ-032 continuam separados e sem ETA autorizado.

### Checkpoint seguro 60 - Auth real verde e Activities interno bloqueado

- **Progresso:** fundação Auth local permanece 100,00% (4/4 gates), restante
  0,00% (0/4). Projeto estrito `done` permanece 0,00% (0/229), backlog
  Supabase estrito `done` 0,00% (0/228) e famílias Supabase `done` 0,00%
  (0/37), pois não houve prova remota autorizada nem promoção de tela.
- **RED Auth:** o primeiro ciclo full-stack não encontrou o Postgres porque o
  Compose truncou a identidade Docker de 43 para 40 caracteres. Após corrigir
  a identidade na origem, o segundo ciclo chegou ao cleanup e confirmou a
  proteção append-only de membership; a fixture passou a ser limpa pela
  destruição integral do volume efêmero.
- **GREEN Auth:** GoTrue/PostgREST/Kong reais passaram cadastro sintético,
  bootstrap interno, logout, login por senha, refresh, novo bootstrap, logout,
  refresh recusado e `SAI_SESSION_INVALID` para o JWT revogado. O wrapper
  terminou em exit 0 com zero container, volume, rede ou staging residual e
  sem imprimir senha ou token.
- **RED Activities:** `activity_management_end_to_end_test.sql` passou 62/70.
  As oito falhas mostram que o teste integral mistura catálogo local-only e
  recursos de arquivo/import/export, além de envelopes people-based. O domínio
  legado tem RPCs reais no remoto read-only, mas não usa
  `require_superadmin_internal_context` e grava autoria em `people`.
- **Bloqueio canônico:** OQ-043 registra a necessidade de contrato v2 para ator
  interno nos comandos operacionais, coexistente com Admin people-based. Não
  foi criada pessoa sintética, migration especulativa ou adaptação de Flutter.
- **Estado remoto:** projeto continua `blocked-environment`, somente leitura;
  nenhuma configuração Auth, migration, DDL, DML ou função foi alterada.
- **Próximo passo seguro:** aprovar o contrato de ator interno v2; enquanto isso,
  revalidar apenas famílias legadas separadamente e nunca chamá-las de CRUD do
  Superadmin interno. Gate de conhecimento: `no-op`, pois o comportamento de
  produto não mudou; apenas a prova técnica e o conflito foram persistidos.

### Checkpoint seguro 61 - commits Auth preservados para consolidação

- **Commits exclusivos:** após persistir este checkpoint,
  `git cherry dev codex/supabase-cross-app-foundation` retorna seis linhas `+`:
  `04da0141`, `0f3b6ebf`, `5160e799`, `ed9d3b12`, `9980c681` e este commit
  documental. Todos estão alcançáveis pela branch; a worktree backend estava
  limpa antes deste checkpoint.
- **Regressão do wrapper:** modo database-only passou novamente 7/7 e terminou
  com zero recurso `coelo_safe_*`; modo Auth full-stack também terminou exit 0
  e cleanup zero. Manifesto 52/52, mirror 115/115, `git diff --check` e secret
  scan permanecem verdes.
- **Consolidação bloqueada com segurança:** `dev@f1aeacf6` mantém alterações
  dirty de Forms/UI/docs/knowledge da outra frente. Nenhum desses arquivos foi
  alterado ou staged pelo backend. Os seis commits ficam preservados na branch
  até `dev` estar limpa; não houve push, merge, cherry-pick ou remoção de
  worktree/branch.

### Checkpoint seguro 62 - Activities v2 interno local-green

- **Progresso geral conhecido:** projeto estrito `done` 0,00% (0/229),
  restante 100,00% (229/229); backlog Supabase estrito `done` 0,00% (0/228),
  restante 100,00% (228/228); famílias Supabase `done` 0,00% (0/37). A
  contagem local global permanece 8,11% (3/37 famílias), porque Activities já
  possuía evidência local e `activities.assessment` ficou fora deste pacote.
- **Progresso do recorte:** os quatro gates backend locais foram concluídos,
  100,00% (4/4), restante 0,00% (0/4). Os cinco `action_id`
  `activities.list`, `activities.create`, `activities.detail`,
  `activities.edit` e `activities.publish` receberam evidência v2 local
  fresca; nenhum dos cinco é `remote-green` ou `done`. Participantes,
  profissionais e permissões são subcontratos dessas ações, não novos
  denominadores.
- **Objetivo e paths:** fundação Activities cross-app para o Superadmin interno,
  com domínio compartilhado e gateways nominais, sem alterar `apps/**`, Flutter,
  UI, importação, exportação, arquivos ou mídia. Os paths mudados ficaram em
  migrations, mirror gerado, testes SQL, scripts de replay e documentação
  autorizada.
- **Migrations e SHA-256 dos arquivos canônicos:**
  `20260831192831_activities_v2_actor_attribution.sql`
  `6cde88d2d2c4d2c91d394b5152a6804fa18a609cec786f131ba29016ba17e37d`;
  `20260831195118_activities_v2_actor_provenance_hardening.sql`
  `3fd41204dc977b1d4bcb7e497d9b47e855c8b72b51a6f9feab437c0faae8204d`;
  `20260831195944_activities_v2_actor_provenance_semantics.sql`
  `7f06bc3df7f936f06bbc103cf732d83aa9c9724092aae768ac4aa530b8bf5a0c`;
  `20260831203645_activities_v2_permissions_receipts.sql`
  `1def96ddb74014af4ab04bb81a3063faf49d11988c507aacf0801ba5a219539a`;
  `20260831211945_activities_v2_internal_gateways.sql`
  `e627be30cc5f56b27a68f46b32ff17a1d64a304b1f8cb6e8ac648acfb3e4207d`;
  `20260831231645_activities_v2_rls_grants.sql`
  `0eb6efe209f594e0b4219c4764deded1f6604ad88c9e1a2a5a0d32d5f361376a`;
  `20260831234307_activities_v2_final_review_hardening.sql`
  `c1a221d67054dbfd401db7737df1126e137eaadf1df706bb7eff0dec0dd9e883`.
  Para a última migration, o manifesto registra o hash normalizado
  `01663a89c55e5de081aa97b808cec0329ae4af9dd6a24ef2d80c87d6c0ddc898`.
- **REDs:** o contrato inicial não representava autoria interna sem pessoa
  global. O review adversarial posterior rejeitou lookup antes da autorização,
  validação incompleta de publicação, ausência de auditoria negativa,
  precedência de permissões incompleta, rejeição indevida do no-op
  `belongs=false`, locks/referências insuficientes e matriz negativa incompleta.
  Cada achado permaneceu RED até correção e replay novos.
- **GREEN funcional:** as suítes Activities v2 executaram 199 asserts pgTAP;
  todos os 199 passaram, incluindo o teste focal final 25/25. As provas cobrem
  Auth e sessão vivas, AAL,
  lifecycle, role/capability/grant ativos, negação explícita, membership
  suspensa/revogada, tenant A/B, sibling scope, cross-app, UUID aleatório,
  list/detail, create/update/publish, snapshots de unidades/turmas,
  participantes, profissionais, permissões, replay e auditoria minimizada.
- **Segurança e concorrência:** onze relações têm RLS habilitada e forçada;
  somente onze wrappers nominais têm EXECUTE de `authenticated`; dezoito
  helpers permanecem sem EXECUTE cliente, owner `postgres` e
  `search_path=''`. Vinte e duas policies people-based foram preservadas sem
  bypass interno. Oito caminhos FK foram provados por catálogo; três índices
  novos fecharam os gaps reais. Duas sessões concorrentes produziram um único
  vencedor na versão 2 e um `SAI_CONCURRENT_CHANGE`, um receipt, uma auditoria
  de sucesso e uma negativa com a mesma correlação.
- **Regressões e ferramentas:** ciclo Auth nativo passou; concorrência real
  passou; contratos PowerShell passaram 11/11; perfil fechado passou 59/59 e
  canônico/mirror 122/122. O review final aprovou o delta em `1e921c47`. O
  lint repetiu apenas quatro erros históricos fora do recorte: dois `42702` em
  imports Activity/Groups, um `42804` no import de Access Profiles e um
  `42703` no file job. Secret scan focal e `git diff --check` ficaram limpos;
  cleanup terminou sem container, volume, rede, fixture, segredo ou staging
  `coelo_safe_*` residual.
- **Remoto read-only:** o projeto `coelo` está `ACTIVE_HEALTHY`, mas continua
  `blocked-environment`. O ledger mantém 103 migrations, até
  `20260821200000_profile_about_remote_context_compatibility`; existem dez Edge
  Functions, e `form-operations`/`circular-media` seguem com
  `verify_jwt=false`, apenas classificados. O Security Advisor mantém 207
  achados: 50 INFO de RLS sem policy, 156 WARN de `SECURITY DEFINER`
  executável por `authenticated` e um aviso de proteção contra senhas vazadas.
  O Performance Advisor mantém 505: 128 FKs sem índice e 377 índices não
  usados. Nenhuma migration, DDL, DML, configuração Auth, Edge Function ou
  deploy remoto ocorreu; logo o máximo comprovado é `local-green`.
- **Tempo e ETA:** a janela Git factual entre o primeiro commit do design
  `f793867d` às 16:05:55 BRT e o fechamento técnico `1e921c47` às 21:00:21 BRT
  foi de 4 h 54 min 26 s. O recorte backend local não tem trabalho funcional
  restante. ETA de remoto ou integração não é calculável sem classificação do
  ambiente, autorização nominal e contrato de cutover Flutter.
- **Primeiro gate incompleto e próximo passo seguro:** o review final já foi
  aprovado; resta persistir este checkpoint e preservar os commits na worktree
  isolada. Somente a tarefa de consolidação pode integrá-los em `dev` quando as
  frentes visuais estiverem em checkpoint seguro. No remoto, o próximo comando
  seguro continua sendo inventário somente leitura; qualquer mutação exige um
  pacote nominal com migrations, hashes, objetos, riscos e estratégia
  forward-only.
- **Gate de conhecimento:** atualizado
  `docs/knowledge/team/superadmin-activity-directory.md` com a regra durável de
  gateways nominais por realm e o limite local-only, sem PII nem log de
  atividade.

### Checkpoint seguro 63 - reconciliação documental pós-consolidação

- **Progresso geral:** projeto estrito `done` 0,00% (0/229), restante 100,00%
  (229/229); backlog Supabase estrito `done` 0,00% (0/228), restante 100,00%
  (228/228); famílias Supabase `done` 0,00% (0/37). O estado local permanece
  8,11% (3/37 famílias `local-green`). Esta reconciliação documental concluiu
  100,00% (1/1), restante 0,00% (0/1), sem promover Flutter, E2E ou remoto.
- **Git consolidado:** o estado vivo é `dev@cd1ea97c`. Os commits técnicos e
  documentais de Activities v2 citados no checkpoint 62 estão alcançáveis em
  `dev`: `1e921c47`, `03bf6734`, `65bae28c` e `32516e63`. A inspeção de
  worktrees anterior a esta atualização encontrou somente a checkout principal
  limpa; as worktrees backend e visual históricas já haviam sido consolidadas e
  removidas. A worktree `codex/tracker-supabase-refresh` existe apenas para este
  commit documental isolado.
- **Evidência local preservada:** o checkpoint 62 continua sendo a evidência
  funcional mais recente do recorte Activities v2: pgTAP 199/199, teste focal
  25/25, perfil 59/59, contrato PowerShell 11/11 e preparação/verificação
  canônico/mirror 122/122. Esses gates não foram reexecutados nesta correção de
  texto; nenhuma migration, teste SQL, script ou arquivo em `apps/**` mudou.
- **Remoto read-only:** o plugin oficial reconfirmou o projeto `coelo`
  `ACTIVE_HEALTHY` e o ledger com 103 migrations, terminando em
  `20260821200000_profile_about_remote_context_compatibility`. A saúde técnica
  não classifica o ambiente como desenvolvimento, homologação ou produção;
  portanto ele continua `blocked-environment`, sem `remote-green` e sem
  `done`. Os Advisors 207/505 e as dez Edge Functions permanecem como a última
  evidência classificada do checkpoint 62; não foram promovidos nem alterados.
- **Correção de histórico:** o próximo passo do checkpoint 62, que ainda dizia
  para preservar e consolidar os commits numa worktree backend, foi superado
  pela consolidação já materializada em `dev`. Ele permanece no registro apenas
  como fotografia daquele momento e não descreve mais o estado operacional.
- **Primeiro gate incompleto e próximo passo seguro:** no backend, o primeiro
  gate incompleto continua sendo a prova remota autorizada em ambiente
  documentalmente classificado. Até lá, somente inventário read-only é seguro.
  A adaptação Flutter e a prova E2E dos contratos Activities v2 pertencem às
  fases próprias dos rastreadores Flutter e integrado; esta atualização não
  altera seus denominadores nem estados.
- **Gate de conhecimento:** `no-op`. A atualização corrige estado operacional e
  proveniência Git; não cria regra durável nova de produto, domínio, permissão
  ou UX.

### Checkpoint seguro 67 — Auth-first local preservado, integração bloqueada pelo guard recovery

- **Backend local:** `auth.login`, `auth.logout`, `auth.recover` e
  `auth.reset` foram reconciliadas como `local-green` somente no Supabase
  descartável. O replay Auth-only passou pgTAP 29/29 e lifecycle local real em
  GoTrue/PostgREST/Postgres/Mailpit. MFA permanece `blocked-decision` e
  fail-closed.
- **Remoto:** produção classificada recebeu zero mutações. O pacote continua
  `not-deployed`: o ledger produtivo diverge do subconjunto local e exige
  replay transacional compatível, forward-only revisado, URL/SMTP e E2E. ETA
  técnico: 1–2 dias para replay/pacote, mais 0,5–1 dia para E2E após ambiente.
- **Bloqueio Flutter separado:** review independente de `36ae7c86` encontrou
  sessão recovery atravessando o guard para Home/rotas protegidas sem contexto
  interno. Isso não invalida o lifecycle backend local, mas impede qualquer
  promoção integrada e exige correção/testes negativos antes da integração.
- **Escopo:** o delta também alterou `apps/catalog`, fora do recorte exclusivo
  Superadmin. Deve preservar compatibilidade ou remover essa ampliação antes de
  unificar. Supabase geral permanece 3/37 famílias `local-green`, 0/37 `done`;
  remoto/E2E não foram promovidos.

## Checkpoint 2026-09-01 — Comunicações/Avisos após fechamento visual local

- O commit Flutter `ee8d3aff` não altera banco, Auth, Storage, Edge Functions,
  migrations ou composição produtiva. As 20 fixtures pertencem exclusivamente
  a `/dev`.
- A divergência remota permanece: as RPCs públicas de gestão de Avisos e
  `notice_events` esperadas pelo contrato local não foram encontradas na leitura
  do projeto. Portanto Avisos continua `blocked-supabase`; nenhuma ação foi
  promovida a `remote-green` ou `done`.
- O escopo da Etapa 2 está restrito ao Superadmin e backend indispensável; não
  autoriza materializar `apps/principal`, `apps/admin` ou `apps/site`.
- Próximo gate seguro: classificar formalmente o ambiente e aprovar nominalmente
  o pacote de migrations antes de qualquer mutação remota. Até lá, somente
  inventário read-only.

### Checkpoint seguro 68 — Estruturas locais, modelos por Unidade e Avaliações fail-closed

- **Unidades/Turmas:** adapters Flutter candidatos usam RPCs legados
  people-based. OQ-043 não os autoriza para o ator interno; composição produtiva
  permanece `fail-closed` até gateway nominal por realm, negativos e tenant A/B.
- **Modelos por Unidade:** `20260901165125_activity_template_unit_scope.sql`
  adiciona `unit_id`, hierarquia instituição/unidade, FK composta, índice, RLS,
  capability, AAL2, idempotência e auditoria. O teste contém 31 asserts
  estáticos; sem Docker/replay, estado é `in-progress/static-review`, nunca
  `local-green`.
- **Avaliações:** o adapter referencia 12 RPCs `superadmin_assessment_*` que não
  existem nas migrations canônicas. Não há CRUD produtivo; rotas permanecem
  fail-closed até backend v2 interno completo.
- **Ambiente:** remoto `evvbomzejfijozbtgvpt` recebeu zero mutações e continua
  condicionado à OQ-041. Supabase permanece 3/37 famílias `local-green`, 0/37
  `done`; replay, pgTAP, Advisors pós-DDL e E2E continuam pendentes.
- **Primeiro passo:** contratos nominais de Unidades/Turmas e Avaliações,
  Docker/replay dos 31 asserts e só então pacote remoto nominal. ETA técnica
  após desbloqueios: 8–16 h, sem contar espera externa.

## Checkpoint 2026-09-01 — Comunicação, adapters locais e drift remoto

- `supabase_chat_repository_test.dart` e `supabase_notice_repository_test.dart`
  passaram 10/10 para cursores, `request_id`, versão esperada e respostas
  proibidas. Isso é evidência local de adapter, não RLS/remoto/E2E.
- Leitura remota confirmou RLS nas tabelas principais de Chat/Avisos e RLS
  forçada em Circulares, mas não encontrou RPCs públicas `chat_*`/gestão de
  Avisos consumidas pelo Flutter, nem `chat_attachment_metadata` ou
  `notice_events`.
- RPCs autenticadas de Circulares (`load_circular_draft`,
  `save_circular_draft`, `publish_circular` e relacionadas) existem, mas não há
  ator autorizado, adapter final, tenant A/B, persistência/reload ou E2E.
- Chat/Avisos permanecem `blocked-supabase`; Circulares não avança para remoto.
  Nenhuma mutação foi executada e qualquer pacote continua condicionado à
  classificação/autorização nominal do ambiente.

### Avisos — hardening de status — `c5085746`

- Adapter produtivo falha fechado em status remoto não resolvido; Notices
  96/96, adapter 5/5, analyzer e worker Deno 2/2 verdes.
- Migration `20260827222500` passou auditoria estática de ACL/FORCE RLS/
  SECURITY DEFINER/capability/AAL/grants, mas replay pgTAP travou no Docker e foi
  interrompido sem resíduos. OQ-038/OQ-041/Storage×R2 permanecem bloqueios. Sem
  promoção a backend local-green, remoto ou done.

### Convites — contrato produtivo continua bloqueado por decisão

- Produção usa corretamente `UnavailableInviteRepository`; auditoria focada
  10/10. Não existe adapter Supabase/RPC canônico.
- Migration histórica `20260811233609` não deve ser restaurada: usa realm
  people-based, backfill especulativo e issuer person.
- Pacote proposto à OQ-039: `platform.invites.read/manage` inicialmente somente
  Owner+AAL2; issuer interno separado/nullable/sem backfill; evolução aditiva de
  `public.invitations`; emissor minimizado; legado read-only e Superadmin
  RPC-only. Aguardar decisão explícita; estado `blocked-decision`.

## Checkpoint 2026-09-01 — Operações backend, 0/40 E2E

- Auditoria estrita permanece 0/40 E2E: Agenda 6, Planos 5, Cardápios 6,
  Formulários 16 e Importações 7. Nenhuma mutação remota foi realizada.
- Remoto possui 103 migrations e objeto `plan_institution_availability` sem
  provenance local; migrations locais referenciam `agenda_events` e
  `agenda_audiences` inexistentes. Não aplicar a cauda em lote: reconciliar
  ledger/schema e replay primeiro.
- Planos carece de CRUD/RPC e RLS completa/forçada. Cardápios tem schema/RPCs,
  mas composition root produtivo não os usa e há 10 alertas SECURITY DEFINER.
- Forms possui backend RPC-only, porém create/edit/responses/files produtivos
  continuam desconectados e o hardening final não está remoto. Importações
  cobre somente units; RPCs genéricas/Edge estão ausentes. Agenda não possui
  schema/RLS/RPC/CRUD produtivos.
- Advisors: 207 alertas de segurança e 128 avisos de FKs sem índice exigem
  triagem, nunca correção cega. Primeiro passo é reconciliar drift/replay; ETA
  remota não é confiável antes disso.

## Checkpoint 2026-09-01 — Modelos de perfil, pacote somente `static-reviewed`

- As migrations candidatas `e7520192` e `5b3c01a3` operam sobre quatro tabelas
  herdadas de `20260811215451`, adicionando dez RPCs e 18 capabilities para
  Modelos de perfil nos contextos Superadmin, Admin e Principal. O escopo de
  aplicação continua somente o Superadmin; isso não autoriza mudanças nos três
  outros aplicativos.
- O handoff declara FORCE RLS com zero policies (deny-by-default), CRUD direto
  revogado de `public`/`anon`/`authenticated`, gateways somente para
  `authenticated`, helpers privados, AAL2 nas escritas, auditoria, versão e
  idempotência. Esses pontos estão sob revisão independente.
- Evidência atual é estritamente estática: planos pgTAP de 35 + 10 asserts e
  testes do adapter/repository Flutter. Docker não executou; não houve replay,
  Advisors pós-DDL, ledger compatível, tenant A/B, sessão revogada, remoto nem
  E2E. Portanto o estado não ultrapassa `in-progress/static-green` e nenhuma
  família Supabase é promovida.
- Pessoas, Segurança da criança, Usuários internos, Perfis de cuidado e Planos
  de medicação continuam nos estados backend anteriores (`fail-closed`,
  `audited` ou `blocked-decision`). Fixtures `/dev` não constituem dados nem
  persistência Supabase.
- Primeiro gate seguro: concluir review das migrations, executar replay limpo e
  pgTAP em ambiente descartável, Advisors e negativos; remoto continua
  bloqueado pela OQ-041 e Modelos também pela OQ-044.
- Review independente abriu P0: o principal de autorização das RPCs é
  people-based, incompatível com o usuário interno nominal exigido por ADR
  0019/spec 039. Corrigir contexto/sessão/realm/ator/auditoria e negativos antes
  de qualquer integração dos commits `e7520192`/`5b3c01a3`.
- O mesmo review bloqueou a ordem lookup→autorização, anti-escalation somente
  `platform`, motivos opcionais e a alegação 35/35+10/10: os testes nunca foram
  executados. O pacote permanece `static-reviewed`, não `static-green`.
