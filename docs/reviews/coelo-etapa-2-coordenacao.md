---
title: "Coelo — Coordenação da Etapa 2"
source: "Conversa Coordenar Etapa 2 do Coelo; seis conversas delegadas; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
status: "active"
generated_at: "2026-09-01"
updated_at: "2026-09-01"
---

# Coelo — Coordenação da Etapa 2

## Finalidade

Este documento é o índice operacional da Etapa 2. Ele preserva propriedade,
proveniência, checkpoints e handoffs entre conversas. O recorte é exclusivo de
`apps/superadmin` e dos pacotes/backend indispensáveis ao Superadmin. Nenhuma
frente está autorizada a alterar `apps/admin`, `apps/site` ou `apps/principal`.
Não substitui os três rastreadores especializados e não promove `local-green`,
mock ou rota `/dev` para conclusão Flutter, Supabase ou ponta a ponta.

## Progresso estrito de referência

- Projeto estrito `done`: 0/229 unidades.
- Flutter `local-green`: 105/207 ações; Flutter `verified`: 0/207.
- Supabase `local-green`: 3/37 famílias; Supabase `done`: 0/37.
- Integração E2E: 0/202 ações.
- Tempo total usado e ETA geral: não calculáveis até os checkpoints finais das
  seis frentes e a confirmação do orçamento global de coordenação.

## Propriedade por frente

| Frente | Conversa | Propriedade exclusiva ou principal | Integrações compartilhadas |
| --- | --- | --- | --- |
| Comunicação | `01a05db6-b171-7a80-9e07-592e2e08dbe9` | Chat/Conversas, Convites e Comunicações/Avisos | Entrega o núcleo funcional de Chat à superfície Coelo (Principal) do Superadmin; recebe handoff histórico de Chat de Estruturas. |
| Operações | `01a05d88-3187-79a3-9443-218a0c5cb8ae` | Cardápios, Formulários, Agenda, Importações e Planos | Consome o shell Superadmin; não recria cabeçalho mobile. |
| Acessos e Saúde/Cuidado | `01a05d66-fdec-7f31-a4c3-fe7f7654e51b` | Pessoas, Usuários internos, Segurança da criança, Perfis/Modelos, Saúde e Medicação | Auth permanece transversal; não duplica Chat ou shell. |
| Auth | `01a05d37-a36d-7610-b9dc-f8259243ffcd` | Login, sessão, bootstrap, autorização transversal e produção Auth | Testes de rotas de outras features comprovam somente gates Auth. |
| Estruturas | `01a05d2b-d4e4-7a90-95a6-e9a401ab5836` | Instituições, Unidades, Turmas, Atividades, Avaliações e cabeçalho mobile global do Superadmin | Handoff de Chat para Comunicação; `SuperadminShell` é compartilhado por todas as telas Superadmin. |
| Coelo (Principal) | `01a05dce-96ed-7ca3-b3eb-e4701473510b` | Menu/superfícies Acontece, Para Você, Agora, Momentos, Perfil e Circulares dentro do Superadmin | Implementa o launcher e a superfície de Chat desse menu consumindo o núcleo de Comunicação; não altera `apps/principal`. |

## Contratos transversais

### Cabeçalho mobile do Superadmin

- Proprietário: Estruturas.
- Implementação compartilhada: `SuperadminShell`, com base no commit
  `d9232a94`.
- Abrangência: todo `apps/superadmin`.
- As outras frentes validam rotas representativas dentro do shell e registram
  incompatibilidades; não criam cabeçalhos locais concorrentes.
- O menu Coelo (Principal) permanece dentro de `apps/superadmin`; esta etapa não
  materializa nem altera o aplicativo `apps/principal`.

### Chat

- Comunicação mantém domínio, repository, backend, RLS, permissões e fluxo
  funcional compartilhável.
- Coelo (Principal) mantém somente a integração visual e a navegação dentro do
  menu homônimo do Superadmin.
- Estruturas não continua Chat; seu trabalho anterior deve chegar a
  Comunicação por checkpoint recuperável.
- Conclusão exige abrir, listar, enviar, negar acesso indevido, persistir e
  recarregar nos consumidores aplicáveis.

### Arquivos compartilhados e conflitos esperados

- `superadmin_router.dart`: Comunicação, Operações, Acessos, Auth e Estruturas.
- `superadmin_auth_scope.dart`: Auth, Acessos e Estruturas.
- testes de rotas de Chat: Comunicação, Auth e handoff histórico de Estruturas.
- navegação administrativa: Operações e Acessos.
- os três rastreadores: múltiplas frentes, sempre com atualização por
  `action_id`/checkpoint e reconciliação final pelo Coordenador.

## Snapshot recuperável das worktrees

Referência: 2026-09-01, após a redistribuição de Chat/Circulares.

| Frente | Branch | HEAD | Estado observado |
| --- | --- | --- | --- |
| Comunicação | `codex/finalizar-tela-comunicacao` | `1b7fd395` | Integração seletiva materializada em `dev` até `f516be71`; 301/301 testes pós-merge e analyzer global verdes. A branch permanece preservada porque contém históricos excluídos de Circulares e propostas documentais já reconciliadas. |
| Operações | `codex/finalizacao-telas-operacoes` | `84759675` | Worktree limpa; Flutter `/dev` das cinco áreas passou 344/344, mas backend permanece 0/40 E2E e bloqueado por drift/schema. |
| Acessos e Saúde | `codex/accessos-ponta-a-ponta` | `6e56d3e4` | Handoff final recebido; worktree limpa. Sete rotas `/dev`, 152/152 testes críticos e analyzer global verdes; models backend apenas `static-green`, remoto/E2E ausentes. Revisão independente em andamento antes da integração. |
| Auth | `codex/auth-first-local-green` | `36ae7c86` | Worktree limpa no snapshot; produção permanece condicionada aos gates registrados pela frente. |
| Estruturas | `codex/estruturas-superadmin` | `49a52f6e` | Rastreadores e artefatos de migration/modelo por unidade continuam preservados fora do commit final; `.artifacts` permanece fora de Git. |
| Coelo (Principal) | `codex/finalizar-telas-coelo-principal` | `14ff3d50` | Worktree limpa; `momentos.view` fullscreen aprovado em review independente após `008c14c2`, com 38/38 testes e analyzer focado. Circulares é o próximo recorte; backend/E2E seguem abertos. |

## Evidências e referências

- Evidência do inventário de pastas do Coordenador:
  `docs/reviews/evidence/etapa-2/coordenador/`.
- Comunicação preservou nove referências visuais no commit `f6d44af9`.
- Nenhuma referência temporária deve ser considerada preservada somente porque
  permanece no histórico da conversa; deve possuir arquivo estável e manifesto.
- Comunicação concluiu inventário 9/9 no commit `ab484019`, com origem,
  tela/fluxo e SHA-256 em
  `docs/superpowers/specs/assets/2026-09-01-superadmin-communication/manifest.md`.
- Estruturas preservou 15/15 anexos no commit `2eb3985e` e mais três QA no
  checkpoint `c249db2f`, manifestados em
  `docs/reviews/evidence/etapa-2/estruturas-superadmin/README.md`.
- Acessos/Saúde preservou 13/13 anexos no commit `4a8168d4`, manifestados em
  `docs/reviews/evidence/etapa-2/acessos-saude/manifest.md`.
- Operações preservou 30/30 PNGs no commit `86e55dc7`, manifestados em
  `docs/reviews/evidence/etapa-2/operacoes/manifest.md`.
- Coelo (Principal) recuperou 12/12 anexos do histórico local no commit
  `8f89d6d6` e os inventariou com tela/uso/dimensões/SHA-256 no commit
  `cb6fa272`, em
  `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/`. Não há referência
  ausente nem vídeo informado nessa frente.

## Handoffs recebidos

### Auth-first — `36ae7c86`

- Worktree limpa e quatro commits preservados: `ac167623`, `70065ad3`,
  `db712f24` e `36ae7c86`.
- Quatro ações Auth não-MFA propostas como Flutter/backend `local-green`;
  integração continua `blocked-supabase`, MFA permanece `blocked-decision` e
  `fail-closed`.
- Evidências informadas: `coelo_auth` 21/21, foco Superadmin 57/57, replay
  Auth-only pgTAP 29/29 e lifecycle local real completo.
- Produção permaneceu sem mutação. O ledger produtivo não é compatível com uma
  aplicação segura do pacote atual; dump/replay compatível, migration única
  forward-only, URL/redirect e E2E continuam pendentes.
- Diffs dos três rastreadores estão preservados nos commits de documentação e
  aguardam reconciliação central com o código alcançável.
- Verificação fresca do Coordenador: `coelo_auth` passou 21/21 e analyzer sem
  problemas. A regressão ampliada Superadmin terminou com 14 testes vermelhos
  tanto neste worktree (309 verdes) quanto no `dev` de comparação (295 verdes),
  incluindo débitos de rotas e três goldens de Login. Portanto, o resultado não
  caracteriza regressão nova de Auth, mas a integração permanece retida até
  revisão independente e validação pós-cherry-pick.
- O review independente encontrou bypass recovery→rota protegida; o commit
  `f280e291` corrigiu o guard e passou 66/66 Auth/guards/router + 21/21
  `coelo_auth`. O bloqueio crítico local foi removido.
- A branch ainda altera `apps/catalog`, fora do recorte exclusivo Superadmin,
  por quebra de compatibilidade do stream Auth. A frente deve preservar
  compatibilidade/remover esses dois deltas antes da integração.

### Comunicações/Avisos — `ee8d3aff`

- `notices.list` permanece Flutter `local-green` e integração
  `blocked-supabase`; nenhuma promoção foi proposta.
- Evidências informadas: 37/37 testes focados, analyzer e validador visual
  verdes, 20 fixtures coerentes e 13 goldens revisados.
- Produção, RLS, permitido/negado, vínculo revogado, tenant A/B, persistência,
  reload, auditoria e E2E continuam abertos.
- As 45 linhas propostas foram reconciliadas nos rastreadores oficiais no
  commit central `e052493b`; a frente restaurou somente esses três diffs e
  confirmou worktree limpa.
- A revisão de integração reabriu Chat: `principal-chat` pode exibir o launcher
  flutuante dentro da própria tela porque o shell só o ocultava para
  `conversations`. Nove goldens Chat e dois InviteForm também permanecem RED.
  Comunicação deve corrigir/classificar esses gates antes do cherry-pick.
- Os gates foram corrigidos depois: launcher `465482c0`, ordem multi-message/
  pós-envio `78ac0ae8`, goldens `c2396f2a`/`2401282e` e escopo Convites
  `b0dd30a5` + `57b746a5`. Rastreadores promovem somente
  `chat.list/open/send` a Flutter `local-green`; integração continua bloqueada.

### Comunicação — integração seletiva em `dev` até `f516be71`

- **Chat / lista (`chat.list`):** último passo concluído foi integrar busca,
  fixtures e ordenação newest-first; launcher duplicado foi removido. Estado
  Flutter `local-green`; backend/remoto/E2E continuam bloqueados.
- **Chat / conversa aberta (`chat.open`):** último passo concluído foi validar
  2+ mensagens, leitura e sequência visual. Estado Flutter `local-green`;
  persistência/reload remoto não comprovados.
- **Chat / envio (`chat.send`):** último passo concluído foi corrigir a ordem
  pós-envio e validar o fluxo local. Estado Flutter `local-green`; autorização,
  auditoria e E2E remotos não comprovados.
- **Chat / editar, anexar, receipts e revogar:** somente auditados/fail-closed;
  primeiro próximo passo é fechar contrato RPC, mídia, capability e negativos.
- **Convites / diretório, detalhe e formulário:** fixtures `/dev` agora respeitam
  instituição/unidade/turma/busca/limite e rejeitam combinações cross-scope;
  goldens locais passaram. CRUD produtivo, RLS, remoto e E2E seguem abertos.
- **Comunicações/Avisos / diretório e criar-editar:** integração preservou o
  estado Flutter local já registrado; RPCs de gestão e `notice_events` ausentes
  impedem qualquer promoção integrada.
- **Evidência pós-merge:** 301/301 testes focados passaram no `dev`, incluindo
  Chat, Convites, Avisos, rotas, navegação e shell; `flutter analyze` terminou
  sem issues e `git diff --check` ficou verde. Os commits `393fc7ff` (WIP de
  Circulares), `d22a9b3d` (ownership Coelo Principal) e os diffs documentais já
  reconciliados não foram incorporados por esta seleção.
- **Próximo passo:** backend/RLS/remoto somente após classificação e autorização
  nominal do ambiente. ETA ponta a ponta permanece não calculável enquanto
  esses gates externos estiverem abertos.

### Estruturas — `560ce79c`

- Commits preservados: `b0fb1293`, `d9232a94`, `0b20d76a` e `560ce79c`.
- Evidências informadas: analyzer completo sem problemas; 62 testes de
  Atividades/Chat, 18 de Auth/router, seis de adapters e 86 de shell/rotas
  estruturais passaram. Chat aparece somente como regressão/handoff histórico.
- Adapters de Unidades/Turmas não são CRUD produtivo concluído: os RPCs legados
  são people-based e o ator interno permanece bloqueado pela OQ-043.
- Migration e pgTAP de modelos por Unidade continuam não rastreados. O teste
  prevê 31 asserts, mas não houve replay Docker; estado correto é
  `in-progress/local-review`, nunca `local-green`.
- Diffs dos três rastreadores, spec e projeção de dataset estão preservados;
  `.artifacts` permanece fora da entrega. Ao reconciliar, corrigir a referência
  antiga de 12 para 31 asserts sem promover estado.

### Convites — worktree Comunicação em `ee8d3aff`

- Diretório/detalhe e fixtures `/dev` foram corrigidos localmente; importação e
  exportação permanecem placeholders explicitamente indisponíveis.
- Evidências informadas: 46 testes funcionais/responsivos, quatro goldens e 12
  testes de repository passaram; analyzer, validador visual e diff-check verdes.
- Flutter local do diretório/detalhe pode ser proposto como `local-green`, mas
  CRUD/RLS/remoto/E2E continuam abertos e Convites não está concluído ponta a
  ponta.
- `InviteFormPage` conserva overflow preexistente de 45 px em 375 px/200% e
  goldens divergentes; registrar como pendência Flutter explícita.
- Alterações e sete goldens permanecem sem commit na worktree compartilhada e
  não devem ser perdidos durante o checkpoint da frente Comunicação.

### Formulários — `dfca4b5c`

- Diretório, editor, rota de respostas e agendamento recorrente foram
  commitados; a UI separa criar, editar e ver respostas e mantém produção
  fail-closed.
- Evidências informadas: 128/128 testes de Forms, analyzer, validador visual e
  diff-check verdes; goldens do diretório/editor foram regenerados
  deliberadamente e incluídos no commit.
- Estado proposto: Flutter `local-green`; Supabase/remoto/E2E continuam sem
  promoção. Nenhum dos três rastreadores foi editado pela frente.

### Operações — auditoria backend/Supabase

- Auditoria read-only confirmou 0/40 ações E2E no recorte: Agenda 6,
  Planos 5, Cardápios 6, Forms 16 e Importações 7 continuam bloqueadas por
  decisão, schema, implantação ou composição produtiva.
- Há drift não reproduzível no ledger remoto e referências a tabelas de Agenda
  inexistentes; a orientação é não aplicar o tail de migrations em lote.
- Sequência segura proposta: reconciliar drift/replay, ACL/RLS comuns, Forms,
  Importações, Cardápios, Planos após decisão e somente então criar o backend
  novo de Agenda. Nenhuma mutação remota ocorreu.

### Convites — auditoria backend em `64a92497`

- Produção permanece com `UnavailableInviteRepository`; `/dev` usa fixture
  isolada. Não existe `SupabaseInviteRepository` produtivo atual.
- O remoto observado é SELECT-only sobre schema legado, expõe colunas
  sensíveis a `authenticated`, não possui RPCs `superadmin_invite_*` e não
  comprova os hardenings necessários. Nenhuma mutação remota ocorreu.
- Proposta: `invites.list/detail/create/resend/revoke` no máximo Flutter
  `local-green`; Supabase e integração `blocked-decision`/`blocked-supabase`.
  OQ-039, spec 047, provenance do schema, idempotência, versionamento, outbox,
  tenant negativo e E2E permanecem abertos.

### Coelo (Principal) — `0fee7a46`

- Spec 050, plano e conhecimento foram corrigidos para limitar o trabalho ao
  menu dentro de `apps/superadmin`; nenhum diff existe em `apps/admin`,
  `apps/site`, `apps/principal` ou `SuperadminShell`.
- A integração contextual de Chat deverá consumir `ChatRepository` de
  Comunicação; é proibido criar repository, RPC, migration ou widgets de
  domínio duplicados.
- `momentos.view` tem regressão aberta: a rota atual permanece no shell e a
  mídia é limitada por `AspectRatio`/aside, divergindo da experiência
  fullscreen registrada. O `local-green` deve permanecer suspenso até nova
  evidência de viewport, retorno e foco.
- Circulares preserva referências em `f6d44af9`; `d22a9b3d` é candidato a
  integração/revalidação e `393fc7ff` é WIP não integrável sem wiring/teste.

### Coelo (Principal) — Momentos `e1cf1be3`

- **Tela/subtela/action_id:** Momentos, viewer imersivo ready/navegação/
  fechar/Escape/restauração de foco, `momentos.view`.
- **Passo concluído:** viewer movido para rota top-level fullscreen, shell global
  suspenso, retorno contextual e fallback de deep link preservados.
- **Evidência independente:** 28/28 testes focados passaram; analyzer dos quatro
  arquivos afetados não encontrou issues; diff-check e worktree estão limpos.
- **Estado:** Flutter `local-green` preservado, ainda sob review independente;
  nenhum backend, remoto ou E2E foi executado. A referência está em
  `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/momentos-responsive-reference.png`
  e possui SHA-256 no manifesto.
- **Próximo passo:** concluir review; depois revalidar `circulars.view` a partir
  de `d22a9b3d`, sem incorporar o WIP `393fc7ff`. ETA informada: 10–15 min para
  o review de Momentos e 25–35 min para o recorte local de Circulares.
- **Fechamento posterior:** `008c14c2` adicionou saídas seguras também nos
  estados configuração inválida, loading, failure, unauthorized e empty; review
  independente aprovado sem achados. Gate final local: 38/38 testes, analyzer
  focal e diff-check verdes; bookkeeping em `14ff3d50`. O próximo passo agora é
  `circulars.view`/`circulars.file-actions`, ETA local 25–35 min.

### Segurança da criança — `b943a5fe`

- `child-safety.list` corrigiu overflow/alinhamento do grid sem altura rígida;
  card Criar e cards de crianças compartilham altura por linha, inclusive em
  375 px, claro/escuro e texto 200%.
- Evidência informada: 10/10 testes e um golden inspecionado/atualizado. Estado
  máximo proposto é Flutter `local-green`; backend/remoto/E2E não mudam.

### Acessos e Saúde/Cuidado — handoff `6e56d3e4`

- **Pessoas:** diretório/cards/tabela/filtros/paginação e wizard criar/editar/
  vínculos/mapa estão entregues somente em `/dev`; produção preserva leitura
  existente e mutações fail-closed. Importar/exportar, geocodificação real,
  dois testes legados produtivos e dez goldens permanecem abertos.
- **Segurança da criança:** diretório, detalhe, criar, editar e revisar estão
  Flutter local; 164 registros sintéticos coerentes e um golden focado verde.
  Lifecycle sensível, suspensão/revogação, remoto e E2E continuam pendentes.
- **Usuários internos:** diretório e wizard de quatro etapas estão locais;
  rotas produtivas agora falham fechadas em vez de 404. Ponte Auth/Convites,
  RPCs produtivas, import/export e 23 goldens permanecem abertos.
- **Perfis e permissões:** Perfis/Modelos foram unificados visualmente com abas
  Superadmin/Admin/Principal somente dentro do Superadmin; Principal continua
  read-only quando aplicável. OQ-044 bloqueia herança/composição transversal.
- **Modelos de perfil:** adapter Flutter e composição candidata existem. As
  migrations `e7520192` e `5b3c01a3` propõem quatro tabelas FORCE RLS, dez RPCs
  e 18 capabilities; evidência é somente revisão estática com planos 35+10
  asserts, sem replay Docker, Advisors, remoto ou E2E.
- **Perfis de cuidado e Planos de medicação:** diretórios/wizards e CRUD fake
  estão Flutter local. Produção permanece fail-closed por OQ-003/OQ-040 e por
  ausência de backend/RLS comprovado.
- **Gates:** 152/152 testes críticos e analyzer completo foram informados
  verdes; gate funcional Acessos 259/259 e Saúde 127/127. A dívida visual
  permanece explícita: 59 comparações divergentes fora do golden Safety e três
  cenários antigos de Convites; nenhuma atualização em massa foi autorizada.
- **Git/evidência:** branch `codex/accessos-ponta-a-ponta`, HEAD `6e56d3e4`,
  worktree limpa; 13/13 referências preservadas no manifesto. Nenhum arquivo em
  `apps/admin`, `apps/site` ou `apps/principal`. Revisões independentes Flutter
  e banco estão em andamento antes de qualquer cherry-pick.
- **P0 do review Supabase:** as RPCs candidatas de Modelos usam
  `current_person_id()`/`has_platform_permission()`, dependentes de pessoa e
  membership legada. ADR 0019/spec 039 exigem contexto interno Superadmin por
  sessão/realm, ator interno auditável e gateways nominais. Os commits de banco
  ficam bloqueados até correção e negativos cross-app; não integrar como
  closure produtiva.
- Outros achados bloqueantes: lookup de modelo ocorre antes da autorização em
  detalhe/update/delete/duplicate; anti-escalation cobre apenas `platform`;
  motivo não é obrigatório em create/update/duplicate; planos pgTAP 35+10 não
  foram executados; e o replay completo permanece RED por dependência anterior.
  As quatro tabelas são herdadas de `20260811215451`, não criadas por `e7520192`.
- **Review Flutter bloqueou promoção:** 100/100 testes funcionais passaram, mas
  cinco suítes golden terminaram `+1 -13` com diferenças materiais; o handoff
  confundiu capabilities com `action_id` e omitiu ações oficiais abertas.
  `access-profiles.detail`/`access-models.detail` só permanecem por deep link;
  filtro multi-escopo e `totalCount` produtivos estão incorretos; o mapa chama
  tiles públicos OSM sem decisão de provider/cache/privacidade; fixture de 30
  adultos compartilhados pode perder escopo. Nenhuma promoção adicional.
- Estratégia aprovada: integrar primeiro evidências e fixtures por domínio;
  Segurança infantil é a primeira fatia candidata, mantendo suspend pendente.
  Reter Perfis/Modelos, mapa/dependências e os componentes compartilhados até
  correções e regressão conjunta.

### Estruturas — checkpoint `c249db2f`

- Shell mobile, Instituições, Unidades, Turmas, Atividades e Avaliações foram
  decompostos por tela/subtela/action_id no handoff vinculante.
- Avaliações produtivas permanecem fail-closed: os 12 RPCs
  `superadmin_assessment_*` chamados pelo adapter não existem nas migrations.
  O commit `7e702447` preserva esse bloqueio e 4/4 testes de rotas passaram.
- Três diffs antigos dos rastreadores aguardam confirmação de captura central;
  não devem ser descartados até reconciliação. ETA para limpeza local após essa
  confirmação: 2 minutos. Backend produtivo estimado 8–16 h somente após
  OQ-043, contrato v2, Docker e ambiente OQ-041.

## Monitoramento e encerramento

### Retomadas ativas em 2026-09-01

- **Comunicação:** retomou três linhas paralelas: Chat RPC/RLS+adapter/cutover;
  Avisos lifecycle/audience/jobs/receipts+cutover; Convites auditoria das cinco
  decisões OQ-039. Remoto permanece read-only por OQ-041.
- **Operações:** retomou pelo inventário exato de drift e matriz de composição
  produtiva; ordem vinculante é ledger/schema → Auth/capabilities → Planos →
  Cardápios → Forms → Importações → Agenda → E2E/Advisors.
- **Auth:** a frente reportou autorização recebida na própria conversa para o
  menor ajuste fail-closed no Catalog, ETA 30–60 min. Isso ainda não é commit ou
  gate verde; aguardar handoff e verificar que não há expansão adicional.
- **Estruturas:** executa em paralelo gateways internos v2 de
  Instituições/Unidades/Turmas e schema/RPC/RLS de Avaliações. Inventário remoto
  read-only confirmou ledger até `20260821200000`, ausência das migrations v2 e
  ausência das 12 RPCs/tabelas de Avaliações. Os 34 avisos de RLS em
  `app_private` serão primeiro classificados por exposição/grants, sem correção
  cega; remoto continua sem mutação por OQ-041.
- **Coelo (Principal):** Circulares menu/diretório/arquivos fechou localmente em
  `ebc0ac29`/`cb6763ed`/`52735a18`, 21/21 e review aprovado; `393fc7ff` excluído.
  Criar/editar/detalhe/publicar e backend continuam pendentes. Próximo passo é
  Acontece/Publicar agora e Perfil sem seguidores públicos, ETA 35–50 min.
- **Pessoas/detalhe-reload:** `d4a87af8` compôs
  `superadmin_person_detail_v2`; 16/16 testes e analyzer focado verdes. Promoção
  retida até replay pgTAP; Docker instalado, daemon indisponível; remoto sem
  mutação. Lista/criar/editar continuam no legado people-based/fail-closed.
- **Avisos/status:** `c5085746` falha fechado em status remoto não resolvido;
  Flutter 5/5 e worker 2/2 verdes. Replay aguarda mutex; OQ-038/OQ-041 bloqueiam.
- **Convites/contrato:** produção Unavailable preservada; auditoria 10/10.
  Migration histórica rejeitada por realm people-based, issuer person e
  backfill especulativo. OQ-039 aguarda decisão Owner+AAL2/issuer interno.
- **Auth/Catalog:** `5e8d2655` concluiu recovery fail-closed; review sem P0/P1,
  corrida P2 corrigida, `coelo_auth` 23/23 e Auth/router 129/129. Falta integrar;
  remoto bloqueado por 17 migrations/infra/identity.
- **Formulários/leitura:** `236f12cd` conectou monitor, respostas, detalhe e jobs
  de arquivo às APIs produtivas; rotas 7/7. Commands criar/editar/publicar/
  testar/responder continuam fail-closed; sem sessão remota/E2E.

- Automação horária ativa: `etapa-2-acompanhamento-hor-rio`.
- Cada frente deve enviar checkpoint diretamente ao Coordenador pelo menos uma
  vez por hora, além de reportar conclusão de unidade, bloqueio, regressão,
  mudança de ETA, commit e proximidade de limite/contexto.
- Escrita dos três rastreadores oficiais é centralizada no Coordenador. As
  frentes executoras entregam proposta estruturada por `action_id`/gate,
  evidência, estado, bloqueio e ETA; não criam novas edições concorrentes em
  `coelo-flutter-pendencias.md`, `coelo-supabase-pendencias.md` ou
  `coelo-flutter-integrado-supabase-pendencias.md`.
- Diffs de rastreadores já existentes em worktrees são preservados e tratados
  como propostas de handoff. O Coordenador valida contra código, testes e
  ambiente antes de incorporá-los à versão canônica.
- Cada relatório deve separar concluído, pendente, bloqueado, Flutter,
  Supabase, E2E, testes, commits, worktree e ETA.
- O campo `Passo` é obrigatório por tela, subtela e `action_id`: cada linha
  registra último passo concluído, passo exato em execução, primeiro próximo
  passo, estados separados Flutter/Supabase local/Supabase remoto/E2E,
  evidência, bloqueio, commit/worktree, arquivos sujos e ETA do passo/unidade.
  Diretório, detalhe, criar, editar, arquivos, filtros e estados loading/vazio/
  erro/acesso negado não podem ser ocultados em um progresso genérico da frente.
- Conversa parada com recorte aberto recebe continuação no primeiro gate
  incompleto.
- Antes de consolidar: exigir checkpoint/commit, diff-check, varredura de
  segredos, rastreadores atualizados e lista de arquivos não rastreados.
- Depois de consolidar: executar regressão conjunta, conferir os três
  rastreadores, validar conhecimento, provar ancestralidade e só então remover
  worktrees/branches autorizadas.
