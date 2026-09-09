---
title: "R02 D04 Perfis e Modelos — subagente"
source: "prompts/D04.md; assignment D04 r3; specs/018-profiles-permissions-superadmin.md; inspeção da base 56eb3f19"
status: "local-green-two-packages; runtime-and-remote-gates-open"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Rodada E2-R02-20260909; subagente `/root/profiles_models`; revisão 3;
instrução processada: pai D04, ownership exclusivo feature access_profiles e
testes; novos arquivos SQL nominais reservados via pai; sem commits próprios.
Início observado: 14:18 BRT. Modelo requerido: gpt-6-astra, medium; runtime
identifica GPT-6, variante/esforço não expostos por ferramenta.

Worktree real: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d04-acessos`.
Branch atribuída: `codex/e2-r02-d04-acessos`; HEAD/base observado
`56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`. Git/commit/push serializados pelo pai.

## Recorte e contrato

Etapa 2 → apps/superadmin → Acessos → Perfis de acesso → Perfis/Modelos.
IDs: access-profiles.list/create/detail/edit/assign/delete;
access-models.list/filter/create/detail/edit/duplicate. 12 IDs ativos.
Objetivo: corrigir aceites locais executáveis sem reabrir decisões, inventar
autorização ou certificar testes isolados como E2E. Família visual administrativa;
composição preservada. Fora: outros apps, produção, import/export, rotas/globais.
Ordem: contratos cedo → falhas reproduzíveis do adapter Modelos → pacote SQL
focal → provas autorizadas → delta por ID. Parada: 16:30 BRT implementação;
somente correções da consolidação até 17:15. ETA depende dos slots Flutter/SQL.

## Contratos entregues cedo ao pai

- Perfis usam RPCs raw `superadmin_access_profiles_list`,
  `superadmin_access_profile_detail`, `superadmin_access_profile_save`,
  `superadmin_access_profile_delete_and_reassign`.
- Perfis list tem diagnóstico histórico ACL42501 invoker→helper e pergunta
  específica sobre definições globais sem uso na instituição do ator, na
  proposta `2026-09-08-profiles-reader-proposal.md`. Não criar allow/deny por
  conveniência. Detail, writes e assign têm gates próprios.
- Modelos usam envelopes `ok/data/error`, catálogo e RPCs nominais
  `superadmin_access_profile_models_cursor`, detail/create/update/duplicate.
  READ exige capability `<domain>.role_models.read`; comando exige capability
  da ação. O helper também exige `platform_role_code=owner` e
  `scope_kind=platform`; capability isolada não basta. Sessão interna/AAL1,
  anti-escalation e auditoria permanecem.
- `child_context` é o valor de servidor do escopo Principal. O adapter exibe
  `group` no modelo UI e precisa convertê-lo de volta na fronteira RPC.

## Delta em execução

Falhas estáticas rastreadas, testes RED preparados:

1. `access-models.filter`: MultiSelectScope envia 2 seleções, adapter troca
   por null. Preparado teste cliente cursor e pgTAP servidor; proposta mantém
   assinatura text e estende scope scalar para CSV validado server-side.
2. `access-models.create/edit/duplicate`: adapter envia `group` em Principal,
   embora servidor aceite somente `child_context`.
3. **Corrigenda da hipótese inicial de contagem:** `access-models.detail/edit`
   reutilizam uma UI em que `membershipCount` significa vínculos de pessoas.
   Modelos não recebem atribuições diretamente (spec018). Portanto zero na
   lista estava correto; o defeito era converter capabilities do DETALHE em
   vínculos, exigindo realocação indevida e exibindo impacto fictício. A correção
   mantém `membershipCount=0` no adapter, sem converter `capability_count`.

## Pacote 1 apto local — 14:41 BRT

Arquivos funcionais aptos para commit do pai:

- `apps/superadmin/lib/features/access_profiles/data/access_profile_model_repository_adapter.dart`
- `apps/superadmin/test/features/access_profiles/data/d04_model_scope_contract_test.dart`
- `packages/coelo_database/migrations/20260909174500_d04_access_models_scope_filter.sql`
- `packages/coelo_database/supabase/tests/d04_access_models_scope_filter_test.sql`

RED Flutter final: 2 PASS, 6 FAIL pelas causas identificadas. Antes disso, duas
invocações ajudaram a corrigir exclusivamente o HTTP mock de RPC sem params
(`null` body), sem contar esses erros de fixture como defeito do produto.
GREEN Flutter: **37/37**, arquivos novo d04_model_scope_contract +
access_profile_model_repository_adapter + access_profile_model_context +
model_write_cache_epoch + presentation/model_command_consumer. Inclui criação,
edição, duplicação, exclusão, negativas, conflito/reload e contexto tardio com
double fiel; não HTTP real nem E2E. Analyzer dos dois Dart alterados: sem
problemas; warning raw Map do teste foi corrigido, sem mudança comportamental.

SQL RED: **7 PASS/8 FAIL de 15**; SQL GREEN: **15/15** após candidata.
Base exata: `ModelAal1PhasePolicy` 51 entradas validadas (49 canônicas + 2
preflights), through 20260908182839. GREEN aplicou candidata integral seguida
do teste por `TestPath` temporário; nenhum profile/script global foi alterado.
Pre/postflight da candidata preservam owner, ACL, SECURITY DEFINER, STABLE e
search_path. Script testado com Supabase CLI2.116.0, PostgreSQL local descartável.

Recursos: tentativa inicial com Tee/2>&1 em PowerShell5.1 falhou em stderr
normal do CLI antes do teste; cleanup confirmado. RED corrigido usou projeto
`coelo_safe_c56fa98c51c6494a97396487e58e7`. GREEN usou
`coelo_safe_711c2a2d8a0b4f018e8104299db12`, saída final confirma zero residual;
Docker vazio conferido. Temporário `d04_access_models_scope_filter_green_replay.sql`
removido por caminho literal após o teste. Flutter/SQL slots liberados.

Evidências nesta pasta: `D04-models-sql-red.log`, `D04-models-sql-green.log`,
`D04-models-flutter-red.log`, `D04-models-flutter-green.log`.
SHA256 candidata: `7151ff7653ff37ec80ba55fb35d894600d7bc674a865a586f548693574dfd8a1`;
pgTAP: `ce752b2c268b40b2110090c4c9d6d1d1dc95fef9e30f79215b6c45002867421e`;
SQL GREEN composto antes da remoção:
`6b995a936e8c0758d882d9b6d7147b0abeb3d9e4cc5af81783c22d5ad74ce261`.

**Dependência de implantação:** aplicar remotamente o pacote nominal scope_filter
após revisão/autorização e serialização D00 ANTES do deploy de FE que envia CSV.
Scalar/null seguem compatíveis; mapeamento Principal child_context já é o
contrato vigente. Commit/merge/push não são deploy. Produção não alterada.

FE/BE/E2E: nenhum certificado novo; 0/12 novos por camada. Estado histórico
pending-verification preservado. O recorte completo permanece aberto.
Plano focal executado: P52/F0/B0/S0/U0, 37 Flutter +15 pgTAP, sem somar RED ou
reruns. Taxa aprovação52/52, falha0/52; execução52/52 e plano52/52, somente do
pacote focal (não cobertura de toda a ação). Gate remoto e UI normal continuam.

## Primeiro gate seguinte e proposta de integração normal

`access-models.duplicate`: `superadmin_router.dart` ainda deixa rota normal
`profileModelDuplicate` em `_unavailableCompositionRootRoute` e lista Modelos
não encaminha `onDuplicate`. Proposta pontual ao D00 via pai:

1. No builder da lista normal `profileModels`, fornecer `onDuplicate` que abre
   `profileModelDuplicateName` com domain/modelId de seleção.
2. Builder normal usa `AccessProfileDuplicatePage` existente, repository e
   duplicator=`productionAccessProfileModelScreens`, keyed por pathParameters
   e `session.authorizationInvalidationRevision`, cancel→lista e retorno→lista
   após comando. `ListenableBuilder(session)` descarta contexto revogado.
3. Guard deve conferir contexto interno Owner/escopo platform e capabilities
   `<domain>.role_models.read` e `<domain>.role_models.create` para o domínio
   da rota, com negação antes de mostrar dados. Repository disponível não basta.
   Servidor revalida tudo pelo helper vigente, incluindo deny e sessão AAL1.
4. Provar entrada normal, submit/cancel/negado/revogado, sem herdar os testes
   de /dev ou de página isolada como certificado E2E.

## Pacote 2 apto local — 14:50:28 BRT

Corrigido editor de Modelos Principal: opções institution/unit não podem mais
ser escolhidas porque contrato desse domínio aceita somente child_context
(mapeado group no cliente). Os escopos Admin e Superadmin foram preservados.
Baseline: formulário Criar/Editar Instituições, componente
`CoeloAdminSingleSelectField` existente, sem novo estilo/componente/token.

Arquivos aptos:
- `apps/superadmin/lib/features/access_profiles/presentation/access_profile_form_page.dart`
- `apps/superadmin/test/features/access_profiles/presentation/d04_principal_model_scope_test.dart`

Teste RED1 comprovou opção indevida Instituição no menu aberto. GREEN8/8:
novo teste de menu +7 testes existentes em access_profile_form_context_test.
Analyzer2 limpo; format2 sem diferenças; git diff --check limpo.
SHA256 form: `76822e029639bc1e63436bad3576de8e86f9f1c37c40bc41932f2d744ea3d393`;
teste: `c09d62b758cf1f63ee5aaf8c9e685c2bd72eca5ab75cac3a44c834cc81c68821`.
Logs: `D04-models-scope-ui-red.log`, `D04-models-scope-ui-green.log`.

Validador obrigatório executado:
`dart apps/catalog/tool/validate_admin_visual_contracts.dart . apps/catalog/assets/admin-visual-contract-allowlist.json`.
Resultado FAIL em ocorrência preexistente fora D04:
`locations/presentation/location_schedule_section.dart:292`, DropdownButtonFormField cru.
Esse arquivo não tem diff contra56eb3f19; nenhum raw widget foi introduzido
no delta D04. Não ampliar allowlist nem editar Locais por conveniência.
Primeira invocação sem argumentos mostrou usage; invocação corrigida acima
é o resultado atual. Gate global visual permanece aberto, sem certificado FE.

Pacote1 commitado/publicado pelo pai em `c2209794b`; observado localmente,
confirmação de remoto recebida do pai. Review independente child_safety,
somente leitura, não encontrou bloqueante novo no SQL/ACL/cursor; não executou
lote duplicado. Pacote2 aguardando commit/push serializado pelo pai.

Total focal atual **P60/F0/B0/S0/U0 de testes de produto**:45 Flutter +15pgTAP,
sem somar RED/reruns. Validador documental/visual separado:1 falha baseline
fora do delta. Nenhum processo/recurso próprio permanece ativo; Flutter e SQL
slots liberados. Memória: nenhuma nova regra de produto; projeção antiga
reportada ao writer central. Não criar arquivo de conhecimento de atividade.

Aceites locais adicionados por ID: access-models.filter (CSV+cursor+UI scope),
access-models.create/edit/duplicate (Principal child_context),
access-models.detail/edit (capabilities não são vínculos). Demais IDs preservam
estado anterior. FE/BE/E2E certificados novos0/12; runtime normal/visuais por
ação e autorização/aplicação do pacote remoto ainda abertos. Perfis depende
da decisão de visibilidade e readers/writes/assign próprios. Duplicação normal
depende da reserva de rotas e guards descrita acima; não é bloqueio de SQL.

## Conhecimento

Skills exigidas consultadas, mais systematic-debugging e TDD. Busca knowledge
executada com -Root explícito. Projeção `team/superadmin-access-profiles.md`
ainda tem Principal somente catálogo e MFA obrigatório, superados pelo aditivo
spec018 de 2026-09-01 e política vigente AAL1. Pai informado; atualização por
writer central, sem nova regra de produto. Não criar artigo de atividade.
