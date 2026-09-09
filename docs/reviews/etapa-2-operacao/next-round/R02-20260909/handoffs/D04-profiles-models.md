---
title: "R02 D04 Perfis e Modelos — subagente"
source: "prompts/D04.md; assignment D04 r3; specs/018-profiles-permissions-superadmin.md; inspeção da base 56eb3f19"
status: "local-green-two-packages; runtime-and-remote-gates-open"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Rodada E2-R02-20260909; subagente `/root/profiles_models`; revisão 9;
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

## Proposta concreta de composição normal para D00, sem aplicação

Arquivo `D04-models-router-proposal.patch`: patch textual do router compartilhado,
preparado a pedido do pai e **não aplicado**. Base observada
`78d81cb591333647de3feb32f187f0a72d466b7c`; SHA256 do router de origem
`47dbef916e73064809f2fadd98f6283021e680b495481c3bff00ee9d8c7a774f`;
SHA256 do patch
`aa584c2242c39511f004065ee5b1e8ce94baeaa68a5db31282de20e65f3953c3`.
`git apply --check` aprovado na worktree; isso não comprova compilação,
renderização nem E2E. Nenhum Flutter executado para esta proposta.

O delta adiciona callback da lista normal e builder normal de duplicação,
reutilizando AccessProfileDuplicatePage e adapter existentes. Guards locais:
sessão autenticada com sessionId, fora de recuperação, domínio exatamente
allowlisted, Owner com escopo platform, capacidades do domínio read/create
e platform.role_models.read. Esta última é necessária ao catálogo carregado
pelo adapter: o wrapper atual do catálogo autoriza domínio platform. Não
introduz AAL2. Repositório ausente/demo continua indisponível. O builder
observa session e usa authorizationInvalidationRevision na chave; domínio
inválido é negado antes do helper que historicamente faz fallback platform.
O callback pode existir se algum domínio for permitido; cada destino revalida
o domínio real. A autorização backend continua obrigatória para toda RPC.

Teste proposto, ainda não criado nem executado:
`apps/superadmin/test/app/router/d04_model_duplicate_routes_test.dart`,
reutilizando harness de `model_save_completion_routes_test.dart` com router
real, MockClient e repositório Supabase, em caminho normal. Plano separado
dos 60 testes verdes: **P0/F0/B0/S0/U8**.

1. Owner global AAL1 com read/create do domínio e read do catálogo: botão da
   lista abre rota normal, carrega origem/catálogo, envia duplicação, recebe
   modelo inativo e retorna à lista com nova leitura.
2. Sem create do domínio: deep link negado sem RPC de dados.
3. Owner em escopo institucional: negado sem RPC de dados.
4. Domínio desconhecido: negado sem fallback platform.
5. Revogação durante carga: resposta tardia descartada.
6. Revogação durante comando: nenhuma navegação ou recarga tardia no novo contexto.
7. Repositório ausente/demo: composição indisponível sem fixture de sucesso.
8. Envelope denied da RPC: erro honesto, rascunho preservado e nenhum retorno de sucesso.

Capturar detail/catalog/duplicate/cursor, requestId/reason/sourceModelId nas
provas pertinentes; UUIDs sintéticos válidos e nenhum ator remoto. O contexto
positivo antigo do harness tem apenas read: o novo teste deve conceder create
explicitamente, sem relaxar o guard para reutilizar fixture insuficiente.

Dependências: reserva D00 de router; revisão/aplicação na base integrada atual;
testes propostos, analyzer e validador visual; prova runtime com ator qualificado.
Não requer mudança em constantes, bootstrap, sessão ou backend para aplicar
este patch. O pacote nominal scope_filter continua obrigatório antes do deploy
do FE CSV/multisseleção; integração Git não equivale a deploy. Enquanto essas
provas não existirem, access-models.duplicate não ganha certificado FE/E2E.

## Retomada Perfis: catálogo e busca durante carregamento/falha

Base retomada `febffc887`, após orientação do Owner para continuar dentro do
corte. Recorte local: apps/superadmin -> Acessos -> Perfis -> catálogo Principal
-> busca/estados de leitura, IDs access-profiles.search e access-profiles.list.
Pendência executável: setSearch substituía loading/failure por noResults antes
de obter catálogo válido; resposta posterior ignorava a busca atual ao calcular
estado; limpar busca num catálogo vazio mostrava ausência de resultados em vez
de catálogo vazio. Não depende da decisão de visibilidade institucional.

Corrigido em `access_profile_view_model.dart`: busca local recalcula somente
estados de resultado já carregado; carga aplica busca vigente ao finalizar;
helper compartilhado mantém vazio real, resultado filtrado vazio e sucesso.
Erro e ação de retry continuam visíveis ao digitar após falha. Nenhuma mudança
visual, autorização, RPC ou regra de produto. Preserva guards e descarte por
generation existentes.

Teste novo `presentation/d04_profile_catalog_lifecycle_test.dart`: RED3/F3
pelos três comportamentos descritos, GREEN3 mais10regressões já existentes em
access_profile_view_model_test, total desta passagem **P13/F0/B0/S0/U0**.
Comando: `flutter test test/features/access_profiles/presentation/d04_profile_catalog_lifecycle_test.dart test/features/access_profiles/presentation/access_profile_view_model_test.dart --no-pub --reporter expanded`.
Analyzer dos dois arquivos limpo; format2 sem alterações; diff --check limpo.
Logs `D04-profiles-catalog-red.log` e `D04-profiles-catalog-green.log` guardam
saída de assertions/resultados, sem saída de resolução inicial de dependências.
SHA256 VM `db75e4135384bf0345e210b91804a523c98dd6cff3cfd812c0f8fb9936e7c978`;
teste `b31a17e4c56a699e4020ecf427246fc49713b5fc74b553fbec157c6dc8fdbb61`.

Os13 testes desta passagem não repetem os60 anteriores: total focal do subagente
agora **P73/F0/B0/S0/U0**, sendo58 Flutter e15pgTAP. Plano de proposta de router
continua U8 separado. Gate visual baseline já registrado permanece aberto,
sem rerun sem mudança visual. FE/BE/E2E novos0; catálogo remoto/ACL e decisões
de Perfis não estão certificados por estes testes de VM. Slot Flutter liberado
para Convites, nenhum processo próprio ativo. Memória: correção de execução de
estado existente, nenhuma nova regra durável; não criar artigo de atividade.

## Atribuição adicional do pai: Pessoas, continuação após gravação confirmada

Pai delegou dois arquivos de Pessoas explicitamente, sem ownership de VM/shared:
`apps/superadmin/lib/features/people/presentation/person_form_page.dart` e novo
`apps/superadmin/test/features/people/presentation/d04_person_form_confirmed_save_test.dart`.
Recorte apps/superadmin -> Acessos -> Pessoas -> criar/editar -> confirmação,
IDs people.create/edit. Causa demonstrada: callback onSaved lançado após ack
caía no catch de persistência, informava falha de gravação e retry executava
segundo create/update. Callback também era lido somente após await.

Correção captura callback original; guarda continuação somente após receipt
válido no contexto/identidade; retry reentrega somente navegação. Confirmação
substitui seção por painel de sucesso e congela passos/edição; footer oferece
Voltar e Continuar. Erro de navegação tem mensagem própria, sem fingir
falha da gravação. Troca de pessoa/repository e dispose limpam continuação;
guards de geração/identidade/vínculos descartam respostas obsoletas existentes.
Contrato callback continua síncrono ValueChanged; erros futuros de callbacks
async não são cobertos por esse contrato.

RED3/F3 correto; GREEN **P14/F0/B0/S0/U0** =3 novos create/update/replacement
mais11 existentes person_form_page_save_lifecycle_test. Não somar11 regressões
ao total D04 do pai se já contadas. Comando:
`flutter test test/features/people/presentation/d04_person_form_confirmed_save_test.dart test/features/people/presentation/person_form_page_save_lifecycle_test.dart --no-pub --reporter expanded`.
Analyzer2 limpo; format2; diff --check limpo. Logs finais (trecho inicial omitido
explicitamente): D04-people-confirmed-save-red.log e D04-people-confirmed-save-green.log.
SHA256 page final `0369a109452403105136e72221b849f8bd0dc142b854262b9c7e8ba1e0d0fb61`;
teste `812a4a315813814f35a531eaeafa79e7c4c0b4f4665500b358433c5248e4f285`.
Review do pai sem bloqueio funcional; ajuste editorial posterior autorizado:
footer Continuar e painel 'O cadastro foi confirmado. Continue para concluir.'.
Format/check limpos, sem rerun14 conforme orientação explícita do pai. Hash
anterior aos dois textos:3d9a6d9ff92910493837870657b60291e7e6ffba34c3d70b5a9aff6149709642.
Slot Flutter liberado e pai informado. Pacote catálogo anterior publicado pelo
pai216d38c8 (confirmação recebida); este pacote Pessoas aguarda serialização.
Nenhuma certificação E2E nem alteração de regra de produto/memória durável.

## Review independente nominal Safety, somente leitura

A pedido do pai, revisada candidata20260909190000 + teste próprio do Safety.
Achados iniciais bounds arrays/cursor, allowlist dados e preflight/minimização
foram enviados ao autor, que corrigiu arrays100/tipos/chaves, allowlists,
preflight helpers/RLS/ACL/triggers e postflight legado/owner/grants. Cursor.name
vem People sem máximo físico: preservado roundtrip sem limite120 arbitrário.
Rereview do delta não identificou novo bloqueante estático. Autorização antes
lookup, scope platform/capability/AAL1, audit interno e ausência de bridge
preservados. **Runtime Safety continua U43**, nenhum SQL/Docker executado por
este revisor; parse não certifica app/segurança. Hash final é do autor Safety.

## Capturas candidatas de confirmação, encerradas antes16:20

Pai delegou evidência visual Pessoas/Usuários internos. Entrega restrita a
`evidence/D04`: harness d04_confirmed_forms_capture_test.dart,4PNGs candidatos,
confirmed-forms-capture-final.log e confirmed-forms-candidates.md com hashes,
base, limitações e falhas do harness resolvidas. Final P4/F0/B0/S0/U0 em
mobilelight375x900 e desktopdark1440x900. Quatro imagens finais abertas:
painel/mensagem/ações íntegros, semoverflow e rodapé não cobre conteúdo final.
PessoasVoltarativo; UsersCancelarativo e Voltardisabled preservam fluxo do autor.
Nenhum golden oficial, código de app ou referência aprovada mudou por captura.
Não somar reruns a4; não repetir lotes funcionais. Estado capturado é editar
após confirmação; criação e demais cenários explicitamente fora. Slot liberado;
nenhum processo próprio ativo. Pai fará revisão das imagens finais.

## Reserva D00 r4 recebida16:19: composição normal Models/Convites

Assignment canônica r4 de16:15 explicitamente reservou LOCAL os hunks de
routerprofileModelDuplicate/onDuplicate com Owner/capacidade/contexto real e
routerInviteDetailPageallowCommands conforme contrato existente, sem Auth.
Pai delegou único writer router a este subagente; Invites escreveu teste próprio
e pai navigation. Ambos patches propostos passaram apply --check e foram
aplicados; router57inserções/1remoção no delta conjunto, sem abertura global.
Convites replica exatamente allowCommands !Unavailable do diretório; permissão
por ação continua autoritativa na resposta e backend. Pai publicouNav/Invite
separados emef1927f2d antes do corte.

Modelos normal: guardOwner+scopeplatform+sessão válida+domínio allowlisted+
read/create do domínio+readplatformcatalog; callbacklista abre rota normal,
duplicate responde inativo e retorna com releitura. Diretamente semcreate,
escopoinstitution e domínio inválido são negados sem RPC de dados.
Teste novo test/app/router/d04_model_duplicate_routes_test.dart **P4/F0**;
params p_request_idUUID, source_model_id, reason e statusinactive também
verificados no positivo rerun1, sem somar ao4. Plano original8 agora
**P4/F0/B0/S0/U4**: revogação carga/comando, repoausente/demo e RPCdenied
ficam para consolidação, não proclamar U0. Logs D04-models-router-green4.log
e D04-models-router-params-green1.log. Testecriado apósREDcallbacknull.

Lote compartilhado anterior comprovou17navigation+4internal_user_routes+
5invite_command_routes =26 verdes. Logfinalparcial honesto em
D04-router-first-green-partial.log: positivoModels falhou em fixturedetail e
teardown aguardou fakeasync; runner foi encerrado semcertificar Model. Corrigida
fixtureResponse(request:request), construçãoSupabaseClient/tearDownAll fora do
testWidgets; Model4 final verde. Nenhuma mudançaapp para corrigir fixture.
Não somar3negativas/RED/reruns ao4final. NavRED isolado está emD04-navigation-red.log.

Router SHA256 `475c1f3c068e2f789bb70ae58af7e978bc4e8bdef233bbe0a27cd15a6735f4d8`;
testeModels `721fe94deb03b0899161228a4832b83de3559cd7c5a012d1cbe112872241f30b`.
Diffcheck limpo; analyzer3 router+2testes novos concluído exit0,41.1s.
Pai recebeu resultado após snapshot; D04-router-analyzer3.log preserva resultado.
Pai publicou Models em1ac0a364a; snapshot16:30 preservou P4/U4. Nenhum remoto/deploy realizado.
CSVmultiscope continua exigir apply nominal anterior ao deployFrontend.

## Consolidação autorizada do plano de duplicação: P8/U0 e negativa segura

Após snapshot16:30 o pai autorizou somente concluir quatro casos do plano já
aberto, até17:15. Slot encerrado antes16:40. Teste de rota agora tem9casos:
8 originais +1 controle adicional de validação. Revogação durante carga descarta
resposta antes do catálogo; durante comando impede callback/releitura tardios;
repositórios ausente e demo são rejeitados; RPCdenied é negada sem navegação.

Review independente Invites encontrou que a página preservava fonte, motivo,
nome e requestId após AccessProfileUnauthorizedException. Pai confirmou e
autorizou correção concreta nesta consolidação. RED1 reproduziu motivo retido.
Corrigenda do plano antigo: o caso8 que pedia rascunho preservado para qualquer
denied era incorreto. Negativa de autorização agora limpa dados/recibo local,
invalida geração e remove formulário/submit; erro comum de validação mantém
rascunho e possibilidade de correção. Isso aplica invariantes existentes de
negação de acesso; não altera regra de domínio nem política AAL1.

Arquivos aptos, sem alteração adicional de router:

- lib/features/access_profiles/presentation/access_profile_duplicate_page.dart:
  `ac5287b259bd120dd5b453d58ed4b9ae84d8cb05017c1de0befcf4e2e01667be`.
- test/app/router/d04_model_duplicate_routes_test.dart:
  `2d7da52647d68c81ddf7109450858767c160b3f83255696eb8e95f256570983c`.
- test/features/access_profiles/presentation/model_command_consumer_test.dart:
  `3ddfdafefa22bcd7d3af76410bbabd4a6e06afc67b45cc6ce2d338c3444ab908`.

Comando final, de apps/superadmin:
`flutter test test/app/router/d04_model_duplicate_routes_test.dart test/features/access_profiles/presentation/model_command_consumer_test.dart --no-pub --reporter expanded`.
**P18/F0/B0/S0/U0** =9router+9consumer. Consumer já estava nos37 originais;
não somar rerun. Delta líquido do pai é **+5IDs únicos**,429→434P e F1baseline
visual mantido, conforme reconciliação do writer. Plano8 original agoraP8/U0.
access_profile_duplicate_context_test3 também passou na execução intermediária;
nenhuma necessidade de rerun sem mudança de código posterior.

Regressão intermediária única era a asserção antiga duplicate-denied do
consumer que exigia preservar rascunho mesmo sem autorização. Ajustada somente
essa expectativa, preservadas as demais; lote final inteiro verde. Uma tentativa
de selecionar dois testes por dois --plain-name não encontrou testes (AND);
não somar como execução de casos. Logs finais completos:
D04-models-authorization-denial-red.log,
D04-models-consolidation-green18.log,
D04-models-consolidation-analyzer3.log. Analyzer3 limpo14.7s; format/check limpos.

Pai notificou publicação anterior1ac0a364a e snapshot54e910ffb; este delta final
aguarda commit/push serializado. SlotFlutter liberado diretamente paraInvites;
nenhum processo/recurso próprio ativo. Memória no-op: aplicação de invariantes
existentes, sem novo conhecimento durável. Nenhuma nova certificação E2E/remota.
