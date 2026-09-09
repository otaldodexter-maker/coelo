---
source: "R02 CONTRATO.md; assignments/D04.md r3; delegação D04; AGENTS.md; código e testes focais de Convites"
status: "local-corrections-verified; ready-for-parent-review; no-e2e-certification"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# R02 D04 Convites — revisão 2, 14:42 BRT

Subagente `/root/invites`; modelo não exposto pela sessão. Worktree real
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d04-acessos`, branch
`codex/e2-r02-d04-acessos`; baseline `56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`.
Início observado: 09/09/2026 14:19 BRT. Sem commits próprios; D04 serializa.
HEAD observado no fechamento local: `41d8398a5d3398e2e563eb2989ecb77c9096050a`
(commits independentes do pai/irmãos). Os quatro arquivos Dart de Convites
continuam delta local sobre a baseline; não reivindicar integração/publicação.

## Contrato e pendências

Etapa 2 → apps/superadmin → Comunicação → Convites → Lista, Criar, Detalhe,
Reenviar, Revogar → `invites.list/create/detail/resend/revoke`.
Família administrativa; Instituições e Criar/Editar Instituição são baselines.
Objetivo: corrigir aceites locais executáveis e informar dependências reais.
Incluído: exclusivamente `lib/features/invites/**` e `test/features/invites/**`.
Fora: rotas/bootstrap/globais, outros apps, migrations e mutações remotas.
Ordem: contratos, reprodução focal, correção, regressão pertinente, handoff.
Parada: aceites locais atingidos ou impedimento demonstrado; corte 16:30 BRT.
Estimativa após inspeção: cerca de 30 minutos para wizard/parser e testes,
mais espera de slot; não representa prazo BE/E2E.

Pendências conhecidas preservadas: SMTP/entrega efetiva, autorizações negativas
reais, tenant A/B, persistência/reload e auditoria remota. Sem nova exigência AAL2.
Nenhum convite enviado, conta criada ou backend alterado.

## Delta local

- `invites.create`: busca de destinatário não apaga perfil já selecionado quando
  a RPC filtra a lista de perfis pelo nome da pessoa. Pesquisa de perfil mantém
  formulário acessível no contexto escolhido mesmo sem contextos no resultado.
- `invites.create`: saltar para Revisão após invalidar contexto/perfil retorna à
  primeira etapa incompleta, sem desreferenciar valores nulos. Navegação aguarda
  opções em andamento.
- `invites.create/resend`: parser de link único nega userInfo e porta inesperada,
  preservando apenas HTTPS do host aprovado na porta 443.
- `invites.create`: nova busca invalida resposta anterior imediatamente, antes
  do debounce, e mantém seletores/navegação em carregamento. Início de uma
  consulta explícita cancela o debounce pendente.

## Provas e limites

Campanha FE `R02-D04-invites-r2`; Flutter test local, `--no-pub`, Windows,
baseline acima com quatro arquivos Dart de delta. Logs originais:
preservados em `../evidence/D04/invites/`: `wizard-parser-red.log`,
`wizard-parser-green.log`, `debounce-red.log`, `debounce-green.log`.

- RED: 13 P / 5 F; cinco falhas novas pela causa esperada.
- GREEN: 24 P / 0 F, nos arquivos `invite_form_context_test.dart`,
  `data/supabase_invite_repository_test.dart`, `invite_form_page_test.dart`.
  Debounce posterior RED 0 P/1 F pela causa esperada; GREEN 13 P/0 F em
  `invite_form_context_test.dart` e `invite_form_page_test.dart`, exit 0.
  Casos únicos atuais: P=25, F=0, B=0, S=0, U=0; N=25 (12 repository +13
  form/context; reruns não somados). Seis reproduções novas falharam antes das
  respectivas correções e passaram depois.
  Aprovados dos executados 25/25=100%; execução/plano aprovado 25/25=100%.
  Isso é cobertura do lote focal, não cobertura integral de Convites.
- `dart analyze` nos quatro arquivos alterados: sem issues.
- Shell dos dois lotes retornou 1 por warning do RTK no stderr interpretado como
  `NativeCommandError`; o runner GREEN concluiu `24: All tests passed!`.
  Não transformar o erro do wrapper em falha do produto. Lote debounce já
  preserva `RUNNER_EXIT=0` explicitamente; não precisou repetir testes anteriores.
- Validador visual com repo/allowlist corretos: bloqueado por
  `locations/presentation/location_schedule_section.dart:292`, uso cru de
  `DropdownButtonFormField`; nenhum bloqueio em Convites e allowlist preservada.
- Knowledge: consulta com `-Root` explícito; 54 artigos válidos, suite da
  ferramenta 12 P/0 F/1 S (symlink indisponível no host), separada do produto.
  Gate de memória no-op: nenhuma regra nova durável; correções cumprem contratos
  existentes. Fontes e projeções não foram alteradas.

## Contratos entregues ao pai

Repository produtivo usa somente RPCs internas
`superadmin_invite_{directory,options,detail,issue,resend,revoke}_v2`, envelopes
SAI e autorização autoritativa server-side. `p_search` filtra perfis e pessoas
na migration existente `20260901190432_superadmin_internal_invites_v2.sql`;
os resultados de busca de pessoa não representam revogação do perfil escolhido.

Dependência de composição: builder normal de `InviteDetailPage` em
`superadmin_router.dart:4210` omite `allowCommands`, default false, enquanto a
lista produtiva e detalhe `/dev` habilitam comandos. Pedido ao pai/D00:
passar `allowCommands: inviteRepository is! UnavailableInviteRepository` no
detalhe normal e testar composição. Reserva encaminhada por D04; nenhum edit
nos arquivos compartilhados feito por este filho.

## Estado por ação

| action_id | Avanço local | Primeiro gate aberto |
| --- | --- | --- |
| invites.list | Contrato existente inspecionado; sem delta nesta revisão | Reconciliar aceites da lista/negativas reais |
| invites.create | Wizard, busca e parser local-green parcial, seis reproduções corrigidas | Restante do aceite FE/composição; depois emissão real autorizada |
| invites.detail | Contrato existente inspecionado | Composição normal e prova FE |
| invites.resend | Parser local-green parcial | Composição normal, entrega/reload reais |
| invites.revoke | Contrato existente inspecionado | Composição normal, revogação/reload reais |

Certificação do recorte permanece FE 0/5, BE 0/5, E2E 0/5: não é percentual
implementado. Snapshot geral D00 de 09/09 14:12:40 BRT, comunicado em D04 r4:
FE 4/230, BE 0/223, E2E ativo 0/198. Supera o snapshot R01 2/219,0/212,0/187,
sem nova certificação por este filho. Critérios totais do
produto não reconciliados não recebem percentual.

Slot Flutter de ambos os lotes liberado ao pai. Sem processos persistentes,
localhost ou recurso remoto próprio. Próximo passo: revisão/commit pelo pai e
integração/composição D00; não executar novas suites sobrepostas sem delta.
Pacote operacional de personas entregue em `D04-personas.md`, com seis telas,
aliases e capabilities, helpers já existentes e gates People/Perfis/Safety/
Usuários internos; nenhuma criação de conta ou nova regra.

## Revisão 3 — proposta de composição, 14:54 BRT

Pedido adicional do pai: preparar, sem aplicar, patch nominal de roteamento.
Artefato próprio: `D04-invites-router-proposal.patch`. Inspeção confirmou que o
builder normal do detalhe ainda omite `allowCommands`; o diretório normal usa
`inviteRepository is! UnavailableInviteRepository`. O patch acrescenta somente
esse mesmo argumento ao detalhe normal. Mantém repository injetado, logout,
navegação, guard de sessão e autorização backend existentes. Não toca `/dev`
nem cria fallback, capability ou exigência AAL2.

`git apply --check` executado na worktree D04: exit 0. É apenas verificação de
aplicabilidade textual; patch não aplicado, roteador compartilhado não editado,
nenhum Flutter executado nesta proposta. D00 ainda é responsável pela reserva,
aplicação, teste e integração.

Teste mínimo de composição a executar após a reserva:

- Reutilizar o harness de `test/app/router/internal_user_detail_routes_test.dart`
  (sessão autorizada + `createSuperadminRouter` + `MaterialApp.router`) e os
  contratos HTTP sintéticos de `test/features/invites/data/` para navegar à rota
  normal `/invites/<id>` com `SupabaseInviteRepository` injetado. Convite pendente
  elegível permite revogar; convite expirado permite reenviar. Antes do patch,
  ambos os botões ficam ausentes. Confirmar ação em um único caso e verificar
  RPC nominal/id/version, sem SMTP ou efeitos remotos.
- Com `UnavailableInviteRepository`, verificar `InviteDetailPage.allowCommands`
  falso e nenhuma ação de mutação; com repository cujo RPC nega autorização,
  mostrar estado não autorizado e nenhum link/dado/comando remanescente.
- Reutilizar `test/app/router/invite_production_routes_test.dart` para regressão
  estrutural de repositório injetado e separação normal/preview. Seus asserts de
  texto isolados não substituem o caso de rota normal acima.

Estado da proposta: três cenários de composição U; fora do lote focal já verde
de 25 casos. Não somar a aplicabilidade do patch aos testes do produto nem
promover invites.detail/resend/revoke antes dessa verificação.
