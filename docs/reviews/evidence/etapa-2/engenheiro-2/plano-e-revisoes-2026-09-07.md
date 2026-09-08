---
title: "Engenheiro 2 — plano e revisões de desbloqueio"
source:
  - "Pedido do Owner de 2026-09-07 encaminhado pelo Coordenador — Etapa 2 E2E"
  - "decisions/0019-superadmin-internal-identity.md"
  - "decisions/0032-mvp-private-media-r2.md"
  - "decisions/0029-superadmin-agenda-backend-authorization.md"
  - "specs/050-superadmin-agenda-backend.md"
  - "specs/039-superadmin-internal-auth-session-context.md"
  - "docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md"
  - "docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md"
  - "docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md"
status: "evidencia-local-em-andamento; sem-conclusao-e2e"
generated_at: "2026-09-07"
---

# Engenheiro 2 — plano visível

Atualização: 2026-09-08, 02:40 BRT. O recorte é diagnóstico e revisão independente para o Coordenador. A única escrita autorizada neste checkout nesta rodada é esta evidência por apply_patch; código, Git e rastreadores centrais permanecem sob seus writers. A01/N01 são os pacotes do coordenador. F-READ01 foi adotado pelo Coordenador como preparação local mínima; isso não cria autorização de comandos, autoria ou deploy. Não foi encontrada API para controlar o contador nativo de passos; este MD foi aberto no painel direito da tarefa.

## Marcos por tela

1. Contrato e inventário.
2. Backend, segurança e negativas.
3. Cliente e estados.
4. Integração real, persistência e reload.
5. Regressão, visual e negativas.
6. Revisão, evidências e commit.

Um passo em revisão não significa que os anteriores passaram. Leitura estática e planejamento de SQL não constituem execução no banco.

| Tela | Passo atual | Subtela / ação | Camada e objetos | Subagente / responsável | Teste / resultado nesta revisão | Próximo gate |
| --- | --- | --- | --- | --- | --- | --- |
| Atividades / diretório | 2/6, RED serial registrado pelo Coordenador | activities.list / A01 pgTAP | activity_definitions, links e RPCs directory_v2/filter_options_v2; BD executado pelo Eng1, não aqui | a01_fixture_auth, a01_foundation_replay, a01_contract_assertions e Engenheiro 2 | Base54 aplicada; fixture89 completa,47FAIL/42PASS, sem aborto/erroACL; checkpoint central22:15 registra cleanup nominal zero. | Corretiva nominal20260907222911 reservada à E2E5; review/hash e futuro GREEN serial do Eng1. |
| Avisos / formulário | 6/6, revisão nominal concluída; tela E2E aberta | Criar v1, editar scheduled e replay / N01 cliente | Flutter; public.platform_notices e RPCs save_draft_v2/publish_v2, somente SQL lido | n01_backend_contract, n01_controller_states, n01_test_evidence e Engenheiro 2 | Sem bloqueantes no delta 76b9b121+c1e42c6a; testes não reexecutados. Publish adicional em save scheduled NÃO existe no SQL atual. | N01 SQL: autorização, geração, job, worker e replay real. |
| Home → Login | 6/6, revisão NAV concluída e integração central registrada; E2E aberto | Logout desktop / D01-UI e NAV-LOGOUT01 | Flutter; provider de URI e lifecycle da navegação; nenhum BD | Engenheiro 2 e a01_fixture_auth; writer E2E2 | c399e5ca integrado como 0269a2fb; Coordenador registra suíte combinada de destino249/249 incluindo NAV/D01. Nenhuma nova execução aqui. | Sessão real e demais gates da vertical; a revisão estática não certifica E2E. |
| Momentos / mídia | 6/6, revisão estática do recorte M02 concluída | Transporte R2 e wrapper Momentos / M02 | Edge `moments-media/index.ts`, wrapper e `_shared/r2_s3.ts`; nenhum BD nesta fatia | `operations_oq` signer; `care_contracts` consumers/API/env; `structures_locations` testes | Sem bloqueantes identificados no SHA 6e7bc23b59f0abfea5b324c9d149e31872c13bdd; testes não executados por esta revisão. | Coordenador integrar pacote nominal; configuração privada e E2E seguem gates próprios. |
| Chat / imagem M03 | 2/6, contexto/locks e fonte AAL revisados | Finalize privilegiado / decoder privado | Upload session candidata; auth.sessions/users/AMR, membership/link/role/grant, conversa e receipt | Engenheiro 2 + três subagentes de leitura; E2E3 writer, Auth depende da E2E1 | GoTrue2.196.0 nominal: user→session em exclusão, ban preserva sessão, AAL atual aceita1/2 explicitamente; NULL/aal3 e recovery não viram autorização. JWT não é réplica da coluna. Sem corrida executada. | E1 validar resolver/AMR/predicados; E3 cotejar novos FKs e locks. Decoder, elegibilidade/custo e prova real continuam gates separados. |
| Agenda / leitura | 2/6, RED nominal relatado pelo Eng1 | agenda.view/detail/permissions, list/get/contexts / AG-READ01 | Agenda, contextos, catálogo/grants039 e auditoria | Engenheiro 2 revisor; E2E5 writer/Eng1 replay | Eng1 informou base53 aplicada, catálogo/audit14 10/10 PASS e fixture114 com21 PASS/93 FAIL, sem aborto; três readers v2 ausentes. Não é execução do Eng2. | Coordenador/E2E5 reservarem corretiva dos readers; nenhuma conclusão Flutter/E2E ou consulta de ledger independente inferida. |
| Chat / lote de anexos | 1/6, lacuna de produto confirmada no recorte | Quantidade por mensagem/lote / M03 batch | PRDs, ADR0032, spec028 e contratos SQL, somente leitura | Engenheiro 2 + a01_fixture_auth + a01_contract_assertions; decisão Owner via Coordenador | Nenhum máximo numérico positivo aprovado localizado; formatos/bytes/pixels e paginação não são contagem de anexos. | Owner definir quantidade e relação mensagem/lote; batch sem máximo não habilitável em produção. |
| Formulários | 1/6 contrato adotado para preparação; 2/6 dependências | Diretório / `forms.list` | Flutter; `public.forms`, `public.form_versions`, `public.form_occurrences`; reader interno candidato | `operations_oq` + `care_contracts`; execução reservada a Engenheiro 1/E2E4 | DTO e dependências mapeados; nenhuma execução. | Perfil nominal com duas fontes Forms e fixture interna separada. |
| Formulários / Local interno | 1/6, duas lacunas de política delimitadas | forms.location-question / forms.location-answer | Produto e contrato; catálogo e respostas; nenhum SQL/RPC definido nesta revisão | Engenheiro 2 + a01_fixture_auth + a01_contract_assertions; E2E4 consumidora | Fontes aprovam IDs/snapshot e visibilidade atual; não decidem população das opções nem transporte do campo revogado numa nova revisão. | Coordenador encaminhar as duas perguntas de produto delimitadas; sem inferir oneOff ou exceção de autorização. |
| Atividades | 3/6 cliente; 2/6 pendente do delta SQL | Diretório e filtros / A01 | Flutter; `superadmin_activity_directory_v2`, `superadmin_activity_filter_options_v2`, `public.activity_definitions` e vínculos | `structures_locations` + Engenheiro 2; writer E2E5 | Três achados de controller e receitas RED entregues; SQL ainda vazio na leitura de aproximadamente 19:57 BRT. Nenhum teste executado. | Delta estável, revisão SQL/DTO e evidência do writer. |
| Avisos | 2/6 backend e replay | Publicação, reativação e auditoria / N01 | `public.platform_notices`, `public.notice_receipts`, `app_private.notice_publication_jobs`, `audit.audit_logs`, worker | `care_contracts` + Engenheiro 2; writer E2E3 | Mapeados jobs, geração de métricas e atribuição; sem execução. | Patch nominal e provas comportamentais, incluindo auditoria de sistema correlacionada ao pedido interno. |
| Avisos | 2/6 compatibilidade de replay | Preparação do BD para N01 | `public.notice_events`, `analytics.notice_events`, `public.platform_permissions` | `operations_oq` labels; `structures_locations` proveniência; Engenheiro 1 executa | Evidência 36af0136 do Eng1 registra RED 42P01 em notices_production, statement22; 52 arquivos e cleanup próprio zero. Nenhuma execução aqui; 23502 não esperado nessa base. | Ponte transitória nominal separada, com revisão de estrutura/ownership/dependentes/remoção antes de qualquer execução. |
| Medicação | 3/6 achado entregue ao writer | Salvar e reaplicar recibo / MED-STALE | Flutter; nenhum BD nesta fatia | Engenheiro 2/care; writer E2E4 | Resposta tardia após dispose/troca de contexto e receita RED entregues. | Writer corrigir e apresentar regressão; nenhuma correção validada por este revisor. |

## Subagentes e recortes

| Subagente | Recorte desta rodada | Limites |
| --- | --- | --- |
| `a01_fixture_auth` | A01 fixtures, markers, actor/role, negativas e saída TAP | Somente leitura; diagnóstico de TAP não executado. |
| `a01_foundation_replay` | A01 perfil Foundation67, hashes e dependências | Somente leitura; nenhum staging, Docker ou SQL. |
| `a01_contract_assertions` | A01 arrays, projeção, options e limites do futuro GREEN | Somente leitura; nenhuma revisão ampla de outros módulos. |
| `n01_backend_contract` | N01 cliente contra versão, estados, permissões e replay do backend existente | Somente leitura; nenhum SQL, teste ou patch. |
| `n01_controller_states` | N01 controller: edição agendada, replay active/paused e resposta tardia | Somente leitura; nenhum patch ou teste. |
| `n01_test_evidence` | N01 testes dos dois commits e limites das evidências de 99/103 casos | Somente leitura; resultado do writer não é execução deste revisor. |
| Engenheiro 2 | Consolidação, conferência independente e revisão futura dos deltas nominais | Contato com Coordenador; nenhum writer concorrente. |

## Deltas estruturados

- **Forms:** `SupabaseFormsApi` já é composto em `superadmin_auth_scope.dart:281`. `FormsRpc.list` chama `form_list`; a implementação em `20260813155121_forms_commands_and_projections.sql:603` exige `require_forms_actor('forms.read')`, ainda baseado em `current_person_id()`. `superadmin_forms_context`, em `20260901190638_superadmin_forms_context_contract.sql:11`, também usa pessoa e `platform_memberships`. Não existe contrato Forms v2 nominal nas fontes pesquisadas. Primeiro candidato: somente listagem interna, projeção existente e envelope SAI, com alcance derivado no servidor; filtro nulo não concede alcance global. Overview, edição, publicação, respostas e exportação ficam em fatias próprias.
- **A01:** a definição efetiva anterior é `20260831234307_activities_v2_final_review_hardening.sql:54`, não a migração anterior de gateways. Preservar UUID seguro, total/paginação e isolamento. A busca baseline só considera nome (:77), enquanto o design de inspeção de 2026-07-29:56 inclui descrição. Os testes do delta devem provar contagens independentes 2 unidades/3 grupos, páginas com empates em ambas as ordens e alcance institucional A/B com filtros vazios ou adulterados. São critérios de revisão, não alegação de execução.
- **A01, cliente:** três achados preexistentes conferidos em `activity_directory_view_model.dart`: busca altera query sem invalidar resposta pendente até iniciar o debounce (:67–71/:133–141); dispose não invalida requisição em curso, que ainda chama `notifyListeners` (:158/:162–164); grupos são filtrados somente por unidade, logo escolher instituição sem unidade ainda oferece grupos de outra instituição (:53–60/:74–75). REDs mínimos: finalizar A antes do timer de B; finalizar reads depois de desmontar; selecionar A em catálogo A/B e conferir descendentes. O widget já oculta conteúdo e toolbar quando não autorizado; não foi reportado bypass nessa renderização. Casos enviados ao Coordenador, sem alteração pelo revisor.
- **N01:** `20260901185008_superadmin_internal_notices_v2.sql` publica diretamente como `active` (:719) e soma receipts de todas as gerações (:271). O materializador legado chama auditoria com `approved_by` (`20260812003000_notices_production.sql:582`), mas v2 registra identidade interna (:723); a auditoria legada exige FK não nula para People. Edição agendada aumenta versão (:629/:655) e invalida o job anterior; reativação (:788) também precisa de geração coerente. Preservar agendamento pelo `available_at` e conclusão apenas após materialização integral.
- **N01, execução assíncrona:** o appender interno exige identidade, auth link, membership, sessão, AAL e capability (`20260827233000_superadmin_internal_auth_context.sql:613–618`); somente `published_by_internal_identity_id` não é atribuição suficiente. A conclusão requer fonte privada e consistente dessa atribuição, sem fabricar pessoa ou usuário service-role. A Edge espera claim retornando `id` e run retornando `state` no topo; mudar para envelope SAI exige adaptar/testar o consumidor. Com dois destinatários e lote de um, o materializador legado conclui na terceira chamada, vazia. Esses detalhes ainda serão confrontados com o pacote nominal N01.
- **Auth — correção de checklist:** ADR0019:58–70 e spec039:397–416 supersedem temporariamente AAL2 obrigatório no realm interno. Durante o MVP, AAL1 e AAL2 são válidos inclusive para Owner/capacidades `requires_mfa`. Permanecem sessão viva, conta confirmada, realm, vínculo, capability, grant, escopo, tenant, revogação e auditoria. Referências anteriores do Engenheiro 2 a AAL2 obrigatório no contrato interno foram corrigidas ao Coordenador. Contratos people-based não foram supersedidos.

## Ambiente e limites da evidência

## Parecer M02 — 2026-09-07, 20:18 BRT

Commit revisado: `6e7bc23b59f0abfea5b324c9d149e31872c13bdd`, worktree E2E3 `a9f2`. Resultado: nenhum defeito bloqueante identificado no recorte de extração do transporte R2. A revisão foi dividida em três recortes independentes e consolidada pelo Engenheiro 2, comparando o commit ao parent.

- Consumer real permanece `moments-media/index.ts` por meio do wrapper. Os cinco nomes `MOMENTS_R2_*`, defaults PUT 300s/GET 120s, HEAD/DELETE, campos de retorno e códigos `moments_r2_*` foram preservados. Index runtime, configuração Supabase/Deno, adapter Flutter, caches e idempotência não mudaram.
- Configuração agora é validada também no construtor, copiada/congelada e rejeita endpoint com userinfo/query/fragmento. Query SigV4 usa ordenação lexical explícita. Não foi encontrado caller vigente que dependa dos formatos rejeitados ou da mutação da configuração.
- Dois vetores GET/PUT usam assinaturas esperadas literais calculadas independentemente, sem helpers do módulo no expected. Não houve remoção de assertion no teste de index. Cobertura adicional de assinatura para chave especial/HEAD/DELETE e sucessos/defaults do wrapper seria possível, mas não foi encontrado defeito concreto que a torne bloqueante para esta extração.
- O documento do writer registra 29/29, check e lint; esta revisão não os reexecutou nem recebeu prova R2 real. Validação de endpoint é sintática, não prova inventário ou privacidade de bucket. Não há novo consumidor autorizado, mudança de bucket, produção, Storage ou Stream.

Fontes técnicas consultadas: [Cloudflare R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/) e [AWS SigV4](https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sigv4-query-string-auth.html). Evidência do writer: `docs/reviews/evidence/etapa-2/comunicacao/2026-09-07-r2-shared-transport.md` no mesmo commit. O parecer fecha somente esta revisão de código, não a tela inteira nem o E2E de mídia.

## D01-UI — logout desktop, 2026-09-07, 20:35 BRT

**Passo 5/6 | Home → Login | logout / D01-UI | Flutter, navegação compartilhada; nenhum BD | Engenheiro 2 + care_contracts + structures_locations + operations_oq | travamento localizado por VM service | próximo gate: writer aplicar e testar a correção mínima de lookup.**

Recorte nominal recebido do Coordenador: worktree `C:/Users/adrie/.codex/worktrees/3811/Coelo`, HEAD `c11614d52a39a133e5f3fb44baccc38aee192711`. Objetivo: localizar a causa do probe opt-in a 1440×900; fora do escopo: editar código/guard/shell, testes amplos concorrentes, banco, Docker, produção e mudança estrutural de rotas. Ordem: fixture → sessão/router → navegação/layout → captura limitada da pilha → handoff. Critério de parada: causa localizada e próximo delta pequeno atribuível ao writer. Revisão e captura concluídas nesta rodada; correção ainda não aplicada pelo Engenheiro 2.

### Evidência executada

Probe: [desktop_logout_regression_probe_test.dart](C:/Users/adrie/.codex/worktrees/3811/Coelo/apps/superadmin/test/app/router/desktop_logout_regression_probe_test.dart:36). Duas execuções diagnósticas do mesmo arquivo, sem editar sua fonte, com comando nominal acrescido de instrumentação local:

```text
flutter test --no-pub --dart-define=RUN_DESKTOP_LOGOUT_PROBE=true test/app/router/desktop_logout_regression_probe_test.dart --reporter expanded --enable-vmservice --disable-dds --verbose
```

Cada execução teve limite externo de 85 segundos e cleanup da própria árvore de processos. A primeira capturou uma pilha; a segunda, três amostras pausadas após 10 segundos de teste, separadas por resume de um segundo. A segunda terminou a captura em 19,1 segundos, com processo de teste ainda sem concluir; `taskkill /PID <processo próprio> /T /F` retornou 0 e o launcher Python encerrou com 0. Isso é reprodução diagnóstica interrompida, **não PASS nem confirmação de correção**. Não houve execução de suíte ampla. Na primeira, a impressão do texto de cleanup falhou por encoding após taskkill já retornar 0; a ausência do PID pai foi conferida.

As três amostras da segunda execução repetiram:

```text
GoRouterState.of — package:go_router/src/state.dart:130
_CoeloNavigationContentState._environment — superadmin_navigation.dart:310
_CoeloNavigationContentState.build — superadmin_navigation.dart:445
```

O contexto dentro de `GoRouterState.of` manteve identityHashCode `825660570`, a rota `635752072` e o state da navegação `3417960680` nas três amostras. Os frames superiores variaram entre lookup do mapa e dependência de inherited widget; a chamada não avançou para fora desse caminho. A pilha foi limitada a 96 frames, portanto não se afirma que sua base inteira foi capturada.

### Causa localizada e menor candidato

O getter [superadmin_navigation.dart:308](C:/Users/adrie/.codex/worktrees/3811/Coelo/apps/superadmin/lib/app/navigation/superadmin_navigation.dart:308) consulta `GoRouterState.of(context)` apenas para decidir o prefixo `/dev/`. A consulta entra no `while (true)` do GoRouter 16.3.0 (`state.dart:118–149`). Quando não encontra a associação da Page, troca contexto por `Navigator.maybeOf(context).context`; o Flutter 3.44.2 devolve o próprio Navigator quando o contexto já é seu StatefulElement (`navigator.dart:2962–2970`). O `catch GoError` atual não protege de uma consulta que não retorna. A captura identifica o loop da consulta; não identifica um defeito de constraints ou de autorização.

A avaliação acontece no build da navegação mesmo com busca vazia (:442–446). No desktop a sidebar é montada; no compacto o Drawer fechado não monta seu child (`drawer.dart:663–682`). Essa diferença explica a manifestação desktop sem atribuí-la a RenderFlex. A remoção do host no ShellRoute e a transição seguem como contexto estrutural da reprodução, não como alteração necessária já demonstrada.

**Menor candidato para o writer de navegação:** obter a URI pelo router, mantendo o fallback production:

```dart
final isDevelopment =
    GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path
        .startsWith('/dev/') ?? false;
return isDevelopment
    ? CoeloNavigationEnvironment.development
    : CoeloNavigationEnvironment.production;
```

O próprio shell já usa a mesma forma em [superadmin_shell.dart:1643](C:/Users/adrie/.codex/worktrees/3811/Coelo/apps/superadmin/lib/app/shell/superadmin_shell.dart:1643). Essa é uma correção candidata do lookup de navegação, ainda sem execução GREEN; não exige alterar sessão, permissões ou topologia de rotas. Como `GoRouter.maybeOf` não registra dependência de mudança da URI, o writer deve preservar/verificar atualização de ambiente quando a navegação permanece montada ao alternar entre produção e preview.

Gate mínimo: probe nominal retornar com /login e sem conteúdo autenticado; regressão no limite 839/840 e 1440×900; fallback sem router; filtro /dev e permissões preservados. A diferença entre `CoeloTheme.light` no probe e o tema canônico sem transição visual do App foi encontrada, mas deixou de ser a hipótese prioritária após a captura do loop. Não recomendar refatoração de ShellRoute ou remoção de animações como correção sem necessidade demonstrada.

## Parecer N01 cliente — 2026-09-07, 20:57 BRT

**Passo 6/6 da revisão nominal | Avisos / formulário | criar, editar scheduled e reconciliar publish | Flutter e contrato SQL lido; nenhum BD executado | Engenheiro 2 e três subagentes | sem bloqueantes identificados no delta | próximo gate: backend N01 de geração, autorização e materialização.**

Commits: `76b9b121a4a3501ea635121eacc541d0ec0d62e0` e `c1e42c6a2f8aba178930dc94f83fe4c826af826f`. Parecer: nenhum defeito bloqueante introduzido identificado no recorte cliente contra o v2 existente. WIP posterior de repository/page/testes na worktree a9f2 foi excluído; as fontes relevantes foram comparadas ao commit nominal. O encerramento desta revisão não promove o formulário nem o pipeline a E2E concluído.

- **Versão:** SQL `20260901185008_superadmin_internal_notices_v2.sql:590/616` exige criação sem expected_version e grava 1; edição confere a versão (:626) e incrementa exatamente um (:655). Controller :673 agora corresponde a isso. O adapter continua enviando os parâmetros reais; create→publish usa recibo 1 como versão esperada. Fakes/Development foram alinhados e não foram conectados ao caminho de produção.
- **Estados e replay:** save aceita draft/scheduled/paused; publish aceita somente draft (SQL :629/:708). Controller :728–735 reconcilia o publish ambíguo com o mesmo request ID antes de nova decisão. Depois de recibo active e edição local, :738–742 impede novo save e preserva os campos; paused também é recusado antes de save. Scheduled permite editar pela versão reconciliada, retornando o save sem publish extra (:748). Retomada de paused segue comando de ciclo separado.
- **Idempotência:** SQL valida contexto/capacidade antes do cache (:568/:685), associa recibo à identidade/request/ação e conflita quando o mesmo request muda de conteúdo (:580/:696). O replay entrega o recibo original antes de conferir a versão corrente; é coerente com a intenção pendente do controller.
- **Feedback:** página :864–866 distingue scheduled de active a partir do recibo; adapter HTTP injetado demonstra o mapeamento, não o banco. A composição real continua `SupabaseNoticeRepository(client)` em auth_scope:271 → main:43 → app:227 → router. O recebimento de scheduled após edição confirma apenas o registro salvo; não prova job criado, geração congelada ou destinatários materializados.

### Precisão das permissões e gate de backend

O backend existente exige **notices.manage para save** e **notices.publish para publish/ciclo**. A sequência salvar um draft e publicar usa as duas RPCs e por isso necessita das duas capacidades. **A edição de scheduled ou paused pelo save atual não verifica adicionalmente notices.publish.** Nenhuma dessas duas mudanças cliente adiciona essa autorização no servidor. Assim, não se pode registrar “publish além de manage já garantido na edição agendada”.

A exigência adicional para edição que recongela publicação pertence ao N01 SQL pendente, junto de job, geração, reautorização do worker e auditoria. O SQL existente ainda escolhe scheduled/active diretamente (:719–725). O próximo teste de backend deve provar que um ator manage-only não altera a publicação agendada que exija publish, incluindo revogação e replay, além da versão/geração correta para um ator autorizado. Esse é gate pendente já reconhecido pelo writer, não um novo defeito introduzido pelo delta cliente.

### Limites da validação

Os quatro REDs revisados cobrem scheduled edit, replay scheduled, replay active e paused, com assertions de versões, contagem de saves/publicações e request ID. O teste antigo que aceitava editar active foi corrigido para o contrato; interações mobile continuam por tap real, com scroll e alvo hitTestable. A fixture stateful não modela capabilities, congelamento, job ou worker; não existe matriz manage-only/publish/revogação nesses testes.

O autor relata 99/99 e depois 103/103 não-golden, além de analyzer; esta revisão não reexecutou Flutter, Dart, SQL ou remoto. O fixture anterior da página ainda tem um registro carregado com versão padrão zero; isso limita aquele teste de feedback, sem contrariar o teste do adapter/controller que exige versão real 1. Goldens, persistência, materialização, reautorização e auditoria permanecem abertos. Memória de conhecimento: no-op; nenhum contrato novo aprovado.

## Parecer A01 pgTAP e replay — 2026-09-07, 21:12 BRT

**Passo 2/6 | Atividades / diretório | activities.list / A01 RED | public.activity_definitions, activity_unit_links, activity_group_links e RPCs directory_v2/filter_options_v2 | a01_fixture_auth, a01_foundation_replay, a01_contract_assertions e Engenheiro 2 | revisão estática nominal | próximo gate: corrigir TAP e definir perfil A01 executável antes da fila serial.**

Commit revisado: `142bfbecfdb158f8aa59aea39a3db23fae12c352`, worktree `1c73`. Objetivo restrito ao pgTAP `superadmin_internal_activities_v2_directory_contract_test.sql` e handoff de `agenda-operacoes/2026-09-07-activities-a01-red-handoff.md`. Ordem: perfil/dependências → fixture/role → assertions/projeção → interpretação RED/GREEN. Fora do escopo: revisão completa do adapter, implementação da migration vazia, execução de SQL/Docker/remoto e mudanças de código/manifesto. Critério de parada: parecer suficiente para o Coordenador decidir a fila nominal; estimativa de revisão 15–20 minutos. Nenhum teste, SQL, Docker, stage ou commit executado por este revisor.

**Parecer: ajustar o pacote antes de conceder o replay funcional proposto.**

1. **Perfil não chega de forma válida ao pgTAP.** Os 67 arquivos, ordem e hashes CRLF conferem; SHA256 bruto do manifesto `4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59`. Isso não prova cadeia executável. O manifesto :64 inclui `20260901101500_superadmin_internal_chat_v2.sql`; seu preflight :12–13 exige `public.chat_attachment_metadata` e lança 55000 se ausente. A tabela é criada por `20260812000000_chat_production_contract.sql:14`, excluída dos 67. Os dois preflights admitidos em Prepare :178–180 não a criam. Trata-se de barreira determinística antes do pgTAP; não se afirma que seja o primeiro erro absoluto de uma execução nunca realizada. Labels omitidas no Chat após a limpeza de defaults e a dependência posterior de Notices em public.notice_events também permanecem problemas da seleção. Nenhuma dessas falhas é RED de arrays/projeção/options.
2. **Duas colunas contaminam a saída TAP.** [Teste:276](C:/Users/adrie/.codex/worktrees/1c73/Coelo/packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql:276) usa `select is(directory...), is(options...)`. O wrapper :274 chama `supabase test db`, que executa pg_prove. Seu handler padrão produz psql sem alinhamento e não converte o separador de campos em nova linha; dois resultados na mesma linha deixam a contagem/parse TAP incorreta mesmo quando ambos passam. Menor ajuste: dois SELECTs separados, cada um com uma coluna TAP e ordenação por label. É análise de formato, não erro observado por execução nesta revisão. Fontes: [CLI Supabase](https://supabase.com/docs/reference/cli/supabase-test-db) e [handler pgTAP v3.36](https://raw.githubusercontent.com/theory/tap-parser-sourcehandler-pgtap/v3.36/lib/TAP/Parser/SourceHandler/pgTAP.pm).
3. **Negativas/scoped não rodam sob o papel SQL pedido.** `SET LOCAL ROLE authenticated` aparece apenas em :250–252 para duas chamadas positivas AAL1; :253 faz RESET ROLE. Chamadas scoped/cross-tenant (:149–170), inputs inválidos e matriz expired/aal3/revoked/People-only/deny (:257–275) executam como postgres, embora tenham claims reais. Isso verifica decisões internas de wrappers SECURITY DEFINER, mas não a matriz completa sob authenticated. Menor ajuste: invocar essa matriz/scoped como authenticated, afirmar current_user e conceder apenas o necessário nas tabelas temporárias de resultados; voltar ao executor somente para comparações privadas/auditoria. Não converter helper em SECURITY DEFINER nem conceder privilégios nas tabelas de domínio.

O checker65 está desatualizado, como o handoff já diz, porém Invoke/Prepare não o chamam. O comando FoundationOnly/alvo `20260901200206` é aceito pela seleção; o defeito de dependências permanece mesmo sem o checker. Não há perfil A01 dedicado nos scripts de `1c73`. Próximo gate de infraestrutura: descriptor fechado e revisado com Coordenador/Eng1. Não trocar por AuthOnly, pular migrations ou inserir bridges por inferência. A autorização nominal de diagnóstico N01 do Eng1 não autoriza transformar essa cadeia em GREEN A01.

### O que o teste demonstra e o que ainda falta

As fixtures são sintéticas, em transação/rollback: identidades internas separadas de People, sessão confirmada, membership revogada com versão coerente, escopos, role permissions explícitas e marker de escrita revalidado. Não foi identificada nulidade obrigatória ou enum incompatível nessas fixtures. `created_at default now()` conserva o empate esperado entre as atividades na transação.

A baseline `20260831234307` rejeita os novos arrays (:63), busca somente nome (:77) e entrega projeção parcial (:90–105): são REDs funcionais legítimos quando o banco estiver preparado. O helper de options ausentes retorna NULL, e seus asserts positivos falham sem inventar API ou sucesso. As assertions negativas de não vazamento podem passar com NULL isoladamente, mas os positivos impedem GREEN vazio.

Antes de interpretar um futuro GREEN como contrato completo, complementar: paginação com total=2, limit=1, offsets0/1 e cardinalidade exata, página offset2 vazia mantendo total e ASC/DESC real; atividade com 2 unidades × 3 grupos para detectar multiplicação de joins, inclusive sob filtro; unidade/grupo autorizado sem vínculo com atividades presente em options com parent_id correto. As fixtures atuais têm somente 1×1 por atividade e todas as estruturas de A estão vinculadas. Essas lacunas limitam o futuro GREEN; não explicam as falhas funcionais esperadas da baseline.

O único resultado desta rodada é o parecer de revisão. A evidência do writer relata 37/37 HTTP simulados e SQL não executado; não foi promovida a persistência, produção ou E2E. Memória de conhecimento: no-op, sem regra nova aprovada.

### Follow-up A01 — cdbcb46d, 2026-09-07, 21:30 BRT

Revisado `cdbcb46d15aa34e61cadd0a8a3f77e9dff139312`, obtido do checkpoint atual do Coordenador. O delta preserva as expectativas, separa as dez negativas em SELECTs de uma coluna, adiciona quatro verificações de current_user e executa scoped/inputs/AAL1/negativas como authenticated. SELECT/INSERT nas temporárias são suficientes, o helper continua invoker, e a auditoria ocorre após RESET ROLE. Contagem estrutural prevista: 73 assertions se todos os comandos completarem; nenhuma foi executada nesta revisão. Handoff suspende expressamente o comando Foundation antigo. Checker65 da worktree não reabre o conserto já integrado no harness do Eng1.

**Condição residual do executor:** `20260827214000_harden_default_function_execute_privileges.sql:15–20` revoga EXECUTE padrão global de funções criadas por postgres. Se pgTAP for instalado depois por postgres sem ACL adicional, os próprios `is/ok` executados sob authenticated podem abortar 42501. Não foi consultado catálogo, portanto a ocorrência no runner não está comprovada. As caches de pgTAP têm grants próprios em plan(); o ponto é EXECUTE nas funções da extensão.

Menor forma de eliminar essa dependência, já usada no `superadmin_internal_auth_context_test.sql:25–32/130–141`: capturar resultados das RPCs e current_user nas temporárias enquanto authenticated; aplicar RESET ROLE e só então emitir TAP sobre os valores capturados. Isso preserva o papel real da chamada sem ampliar os grants da extensão ou das tabelas de domínio. Alternativamente, o executor deve comprovar a ACL efetiva antes de classificar eventual abort como RED do contrato. O novo perfil continua sob Eng1/Coordenador; Foundation67, cardinalidade/2×3 e options sem vínculo não foram promovidos.

### Descriptor mínimo A01 — 36af0136, 2026-09-07, 21:52 BRT

**Passo 2/6 | Atividades / diretório | activities.list / base A01 | SQL de atividade, identidade interna, permissões e auditoria | Engenheiro 2 + a01_foundation_replay + a01_contract_assertions; Eng1 é writer/executor do harness | revisão estática do descriptor | próximo gate: decisão central e seletor nominal fechado.**

Artefato concreto: `docs/reviews/evidence/etapa-2/engenheiro-1/a01-minimum-base-analysis.json`, commit `36af01369db8ff9308807f1372ff1338d4c71119`. SHA256 normalizado CRLF/UTF-8 do descriptor: `47753ad8a3b49a73e60949d7fd87e8881bfc5fb7c161ae30936a61ee270ea6c5`. Objetivo: conferir seleção, proveniência das dependências e possibilidade de alcançar o RED funcional. Ordem: hashes/posições em paralelo com dependências SQL → fixture → gate de execução. Sem revisão geral de commands, implementação, SQL, Docker, Pester ou remoto. Critério de parada: parecer sobre essa proposta; aproximadamente dez minutos.

**Parecer favorável à consistência estática da base proposta.** A regra Auth seleciona 45 canônicas; os sete adicionais Atividades ocupam posições canônicas 44–50, entre Auth interno e auditoria de negativas. São 52 canônicas mais dois preflights, 54 arquivos únicos. Todos os hashes conferem. Considerando os preflights, os sete ficam nas posições 46–52; os preflights ficam em 29 e 42. O target continua `20260901200206`, sem a futura corretiva A01.

As dependências conferidas dos sete incluem current_person_id, set_activity_updated_at, activity_slugify, superadmin_internal_context, require_superadmin_internal_context, auditoria de negativas e audit_outcome. Seus criadores estão em Auth45. A função audit_append_superadmin_internal de Auth tem 13 parâmetros; Atividades cria sobrecarga com 14, portanto não há colisão por assinatura. As tabelas auxiliares de assignments/capability actions/policies/settings/participantes também pertencem à base. Não foi identificada exigência adicional de Chat v2, Notices ou dos hardenings omitidos. auth.uid/jwt, auth.sessions e extensions.digest permanecem requisitos do runtime Supabase já usados por Auth45.

Na fixture cdbcb46d, tabelas de identidade interna e domínio têm criadores nessa seleção; audit.audit_logs vem da transferência de public.audit_logs na migration `20260623203230:10–11`. As colunas de unidade/tipo (`20260729140915:8`), distribuição/governança (`20260724152713:4–7`) e versão/handle de atividade (`20260811192514:150–153`) estão incluídas. Essa conferência não executa triggers nem comprova o fixture em banco.

**Gates mantidos:** Invoke/Prepare ainda aceitam somente N01PrerequisitesRed como perfil nominal, e AdditionalMigration rejeita as sete versões históricas; runtime_selector null está correto. Aprovar o descriptor não cria comando A01 executável. A migration global de EXECUTE `20260827214000` faz parte de Auth45, logo a condição pgTAP já registrada permanece: obter resultados/current_user sob authenticated e emitir TAP depois de RESET ROLE, ou comprovar a ACL efetiva. Ausência de filter_options_v2, arrays rejeitados e projeção incompleta são REDs funcionais previstos depois da preparação; não foi atribuído GREEN ao perfil ou ao produto. Cardinalidade/2×3/options sem vínculo continuam gates do futuro GREEN.

O mesmo commit contém a evidência do Eng1 de N01PrerequisitesRed: execução às 21:28:14 BRT, 52 arquivos, exit1 e 42P01 em notices_production statement22; cleanup próprio verificado às 21:30:09 BRT. A leitura confirma o relato recebido, sem execução independente nesta tarefa. Auth45 mantém os defaults de labels do preflight e exclui a cleanup; não extrapolar o antigo risco 23502 da Foundation para esse diagnóstico. Ponte local permanece pacote separado, sem autoria ou execução aqui. Memória de conhecimento: no-op.

## Follow-up NAV-LOGOUT01 — 2026-09-07, 21:44 BRT

**Passo 6/6 | Home → Login / navegação | logout e disponibilidade por URI | Flutter, CoeloNavigationContent; nenhum BD/schema/RPC | Engenheiro 2 + a01_fixture_auth; writer E2E2 | revisão estática c399e5ca sem bloqueantes | próximo gate: integração central e validação do destino.**

Commit nominal `c399e5cac319ffb7a6b87b5d4996f42362a289ac`, worktree 3811. Objetivo: fechar o follow-up do diagnóstico D01-UI, conferindo lookup, atualização do ambiente e descarte do listener. Ordem: delta produtivo → contrato do SDK instalado → sete testes e evidência. Fora do escopo: novo probe, execução Flutter/BD, shell, guards, Session, topologia, D01 extra-fetch e lifecycle de Instituições. Parada: parecer sobre este commit; revisão em aproximadamente dez minutos, sem implementação paralela.

O getter deixou de chamar GoRouterState.of, removendo a chamada que ficou no loop capturado. didChangeDependencies (:295) obtém o provider pelo InheritedGoRouter, evita assinatura duplicada por identidade, remove o anterior e assina o novo. O callback (:309) apenas solicita rebuild enquanto mounted; dispose (:322) remove o listener. Sem router, mantém ambiente de produção.

No Flutter instalado, Router.maybeOf (`router.dart:507–509`) registra dependência em _RouterScope; este notifica quando provider, delegate ou parser mudam (:877–882). Isso complementa InheritedGoRouter, cujo updateShouldNotify retorna false no GoRouter 16.3.0. A troca de MaterialApp.router pode, assim, atualizar a assinatura mesmo com o conteúdo preservado. A leitura de URI não percorre Navigator/Page e não altera autorização ou rotas.

Os testes reutilizam a mesma instância do host e conferem seu Element por GlobalKey. A pesquisa Cardápios permanece durante produção→dev→produção; a troca real de MaterialApp.router ainda verifica second.go('/home'), portanto exige ouvir o novo provider. O teste isolado começa com providers sem listeners, comprova detach do anterior, remoção do provider e dispose final, e muda ambas as URIs depois sem exceção. São sete casos: três larguras, sem router, transição de URI, troca real de router e lifecycle isolado.

**Parecer:** sem defeito bloqueante identificado nesse delta. O writer relata 7 testes dedicados, 49 regressões e analyzer sem issues; esta revisão não os reexecutou. O caso 839 usa Drawer fechado e find.byType com skipOffstage padrão: prova redirect/settle, sem provar logout com Drawer aberto ou ausência de navegação offstage. Esse limite não bloqueia a correção do travamento desktop e não amplia o recorte. Não há sessão real, persistência ou certificação E2E. Memória: no-op, comportamento existente corrigido.

## Formulários / Local interno — parecer documental, 2026-09-07, 21:58 BRT

**Passo 1/6 | Formulários / editor e resposta | forms.location-question e forms.location-answer | produto/contrato; nenhum BD/schema/RPC implementado | Engenheiro 2 + a01_fixture_auth + a01_contract_assertions; encaminhamento pelo Coordenador | duas lacunas reais delimitadas | próximo gate: decisão nas fontes canônicas antes do comportamento dependente.**

Pedido nominal do Coordenador: resolver pela evidência original se o autor fixa opções catalogadas ou se o catálogo é resolvido ao responder, e se edição/revalidação pode manter uma seleção cujo local foi revogado. Incluído: fontes aprovadas, projeção Knowledge, limites do contrato candidato `9d4da9d380c7885af530139c95e9892c7084505e` e formulação de perguntas quando não houver regra. Fora: nova decisão de produto, código, teste, SQL, mídia, ponte N01 ou ordens às frentes. Ordem: autoridade documental → opções/autoria e histórico/revogação em paralelo → confronto das conclusões → perguntas. Parada: evidência suficiente e lacunas delimitadas; aproximadamente dez minutos. Única escrita: este MD por apply_patch.

### Regras que já estão aprovadas

- O [desenho de Locais de 02/09:3](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md:3) registra decisões do Owner e status approved-design. [Linhas 59–62](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md:59): pergunta Local interno, única/múltipla, opções internas catalogadas e visíveis ao respondente; respostas guardam IDs estáveis e snapshot textual da versão. As ações [editor/resposta:87](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md:87) preservam esses limites. Formulários não receberam a alternativa pontual concedida separadamente a Turmas, Atividades e Eventos.
- [Locais:117](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md:117) exige validação de ator, capability, tenant, escopo, ownership e visibilidade em toda leitura/escrita; [visibilidade:130](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-09-02-superadmin-locais-mapas-agendamentos-design.md:130) inclui as opções de Formulários. Snapshot não torna um local revogado uma opção atualmente autorizada.
- O [desenho aprovado de Formulários:205](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:205) deixa a distribuição escolher envio definitivo ou editável até o encerramento. [Versionamento:299](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:299) congela a publicação e preserva versões de ocorrências abertas/concluídas; o [detalhe:344](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:344) conserva versão e ordem originais. Consultas/comandos continuam sujeitos à [reautorização:493](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:493).
- Perda do vínculo do respondente já tem regra própria em [Formulários:241](C:/Users/adrie/Documents/Coelo/docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:241): deixa de poder responder, enquanto respostas existentes permanecem. Isso não define a política de edição quando apenas o local perde validade/visibilidade. Preservar registro histórico não concede ao antigo respondente acesso irrestrito a esse histórico ou ao catálogo.

### Lacunas e perguntas para decisão

**1. População das opções da pergunta.** Nenhuma fonte aprovada localizada diz que o autor escolhe um subconjunto fixo de IDs, nem que o catálogo inteiro é recalculado ao responder. Imutabilidade da versão e snapshot são compatíveis tanto com uma lista congelada quanto com uma configuração de resolução congelada; não escolhem entre elas.

Pergunta registrada: **na pergunta Local interno, a publicação congela os IDs escolhidos pelo autor, ou congela uma configuração de catálogo/escopo que resolve os candidatos ao responder, incluindo locais criados depois da publicação?** Em ambas as alternativas, visibilidade e autorização atuais continuam obrigatórias. Não transportar por inferência os limites e ramificações das escolhas genéricas para o novo tipo.

**2. Campo histórico numa nova revisão.** A preservação do ID/snapshot existente tem respaldo. Não foi localizada regra autorizando carregar um local agora revogado numa nova revisão editável, mesmo quando só outra pergunta muda; tampouco regra exigindo substituição automática, apagamento do histórico ou bloqueio de toda edição. Leitura histórica e novo uso autorizado são operações distintas.

Pergunta registrada: **quando o local selecionado perde validade ou visibilidade, uma nova revisão pode conservar aquele campo inalterado apenas como histórico, ou todo reenvio exige uma referência atualmente autorizada, com remoção quando opcional?** A decisão precisa cobrir pergunta obrigatória sem alternativa válida. Nenhuma dessas opções foi escolhida por esta revisão.

### Autoridade e handoff

O catálogo antigo de Formulários de 13/08 excluía localização em :163–164/:646. A aprovação posterior e específica de Local interno em 02/09 permanece o escopo atual encaminhado pelo Coordenador; a exclusão antiga não reabre essa aprovação nem autoriza geolocalização ou texto pontual. O contrato Dart candidato de 07/09 e sua projeção Knowledge descrevem representação de snapshot, não políticas de autoria, catálogo dinâmico ou exceção para revogação.

As perguntas ficam registradas neste MD, para encaminhamento pelo Coordenador às fontes/rastreadores sob seu ownership. Não foi editado docs/open-questions.md, fonte canônica, código ou backend. Não houve mensagem às frentes. Memória de conhecimento: no-op; nenhuma nova decisão durável aprovada e nenhuma conclusão E2E.

## M03 — parecer de processador privado, 2026-09-07, 22:11 BRT

**Passo 2/6 | Chat / imagem | finalize e decoder M03 | Worker/Images candidato, R2 privado e catálogo Postgres existente | Engenheiro 2 + a01_fixture_auth + a01_foundation_replay; E2E3 writer | documentação oficial e inventário GET mínimo | próximo gate: contrato de saída e prova nominal de alta fidelidade, com habilitação/custo definidos.**

Pedido nominal do Coordenador: avaliar Images binding como processador auxiliar, R2 único master, alternativas existentes, memória/pixels/EXIF/GPS/reencode e evidência sintética mínima. Ordem: proposta/ADR → docs oficiais e tipos → inventário mínimo → viabilidade/gates. Fora: ativação, contratação, provisionamento, Worker, --remote, transformações remotas, SQL e autoria de `_shared/media_image_contract` já reservada à E2E3. Critério de parada: parecer acionável; aproximadamente quinze minutos. Skills Cloudflare, Coelo-backend e RTK conforme o recorte.

Snapshot lido: base `7773eb4f` mais adendo WIP em `docs/superpowers/plans/2026-09-07-media-chat-m03-catalog-proposal.md`, hash Git do arquivo `1dff3c2ebc04b76802237ebd43f1e3b65e3f90a4`; seção Decoder a partir de :209. Não foi tratado como commit de implementação.

### Viabilidade e limites comprovados

O binding recebe bytes privados, admite origem R2 e produz nova imagem; não exige hospedagem em Images ou URL pública. A documentação informa decode/reencode completo sem cache. É compatível com processador auxiliar e persistência exclusiva no R2, mas não comprova retenção zero pelo serviço nem o pacote Coelo. [Contrato oficial](https://developers.cloudflare.com/images/optimization/binding/).

**Ponto concreto do JPEG:** a documentação geral oferece metadata=none, mas esse campo não aparece nos tipos oficiais ImageTransform/ImageOutputOptions. Não presumir que forçar o parâmetro em JavaScript garante suporte. WebP/PNG são formatos já permitidos pela ADR e a documentação declara descarte de metadados, constituindo alternativa técnica para saída a avaliar com fixtures. Orientação e cor precisam sobreviver à normalização. Nenhum booleano sanitizado substitui inspeção dos bytes. [Metadados](https://developers.cloudflare.com/images/optimization/features/#metadata), [tipos oficiais](https://github.com/cloudflare/workerd/blob/main/types/defines/images.d.ts#L35).

`.info()` informa formato/bytes/dimensões, sem frames, orientação ou inventário EXIF. Não comprova decode integral, arquivo não truncado ou saneamento. SVG e GIF continuam sujeitos à allowlist Coelo; anim:false converte, não comprova rejeição de GIF animado. Política de APNG/WebP animado não deve ser inventada. [Tipo ImageInfoResponse](https://github.com/cloudflare/workerd/blob/main/types/defines/images.d.ts#L5).

A ADR 0032:130–146 exige validação real e, para foto comum, origem até 10 MiB/36 MP, master até 2560 px/4 MiB e remoção EXIF/GPS. O binding publica teto de entrada de 20 MB. A tabela geral também publica 100 MP e 12.000 px para formatos fora das exceções WebP/AVIF; é necessário comprovar o alcance dessas regras no binding, incluindo imagem estreita acima de 12.000 px ainda dentro de 36 MP. Não ampliar a allowlist nem reduzir o limite Coelo para contornar restrição do fornecedor. Dimensão final sozinha não garante 4 MiB: medir bytes e checksum do resultado antes de ready. [Limites oficiais](https://developers.cloudflare.com/images/get-started/limits/).

RGBA integral de 36 MP usa 144.000.000 bytes, cerca de 137,3 MiB, antes do codec. Excede 128 MB por isolate Worker; duas cópias também superam 256 MB do Edge Supabase. É cálculo, não benchmark nem prova contra todo decoder em tiles/streaming. O serviço Images processa fora desse bitmap JS/WASM; ainda é preciso limitar buffering/concorrência e medir CPU do gateway. Supabase limita CPU por requisição a 2 s. [Workers](https://developers.cloudflare.com/workers/platform/limits/#memory), [Supabase Edge](https://supabase.com/docs/guides/functions/limits).

### O que pode avançar localmente

O simulador offline suporta apenas width/height/rotate/format; Vitest usa esse modo por padrão. Serve à composição e parte dos contratos. Sanitização, animação, qualidade e limites reais continuam sem prova equivalente. Tanto --remote quanto images.remote=true acessam Cloudflare e permanecem fora desta autorização. [Desenvolvimento local](https://developers.cloudflare.com/images/optimization/binding/#interact-with-your-images-binding-locally), [bindings por ambiente](https://developers.cloudflare.com/workers/local-development/bindings-per-env/).

Fixtures propostas, sem geração ou execução aqui:

| Grupo sintético | Evidência mínima |
| --- | --- |
| JPEG assimétrico, orientação6 e espelhada, GPS/EXIF/XMP/IPTC/thumbnail | Pixels orientados, rótulo/MIME reais e ausência dos metadados proibidos por inspeção independente, inclusive sem resize. |
| PNG/WebP transparentes com metadados; HEIC válido quando incluído no recorte | Preservação visual/alpha, conversão permitida e saída dentro de bytes/dimensões. |
| Truncado, MIME falso, SVG/PDF e GIF animado | Negação compatível com a allowlist, sem ready ou fallback ao bruto; frames não inferidos de info. |
| Fronteiras bytes/pixels/lado e conteúdo pouco compressível | Limites imediatamente antes/depois, saída até4 MiB e checksum calculado sobre bytes produzidos. |
| Falha de output ou gravação parcial | Nenhum master/binding publicável; cleanup/idempotência no protocolo já reservado à E2E3. |

O módulo puro e seus REDs locais podem avançar sob a reserva existente; sua implementação não foi duplicada. A futura prova no serviço real exige pacote nominal, fixtures sem dados pessoais, conta/Worker identificados e condições de parada. Não foi solicitado teste remoto nesta revisão.

### Disponibilidade e custo: não presumidos

Desde 01/07/2026, a cobrança do binding usa combinações únicas de fonte/parâmetros no mês; info não é cobrado. Pricing atual anuncia 5.000 transformações únicas/mês no Free, erro 9422 além da franquia, e US$ 0,50/1.000 adicionais no Paid. [Mudança oficial](https://developers.cloudflare.com/changelog/post/2026-07-01-binding-unique-transformations/), [preços](https://developers.cloudflare.com/images/pricing/).

Há divergência documental de elegibilidade: pricing mais recente inclui fontes externas/bindings na franquia, mas o tutorial R2 ainda pede Images Paid. Não garantir dispensa de plano nem contratar por inferência; billing legado também pode rejeitar o binding. [Pré-requisito do tutorial](https://developers.cloudflare.com/images/tutorials/optimize-user-uploaded-image/#prerequisites), [erro9432](https://developers.cloudflare.com/images/reference/troubleshooting/).

Inventário autorizado, somente GET, na conta conectada: listagem R2 confirmou coelo-media-prod/coelo-documents-prod/coelo-transient-prod; listagem de Workers retornou sucesso 200 e zero scripts. Nenhum objeto foi lido. Não existe Worker processador ativo comprovado nessa conta. A busca local não encontrou outro decoder implementado/aprovado. Tentativa GET de subscriptions/account-settings retornou erro 10000 Authentication error; o plano/entitlement permanece desconhecido. Não se tentou mudar credenciais, habilitar produto ou executar transformação.

**Parecer:** candidato arquitetural viável, ainda sem prova de sanitização integral, elegibilidade ou operação. Fechar formato de saída e metadados nominalmente, executar a matriz local possível e preservar como gates o processador real, os limites completos, a autorização/custo e o protocolo de finalização. R2 master e catálogo único continuam invariantes. Memória de conhecimento: no-op, nenhuma nova decisão de produto aprovada.

## M03 — complete privilegiado, contexto persistido e locks, 2026-09-07, 22:32 BRT

**Passo 2/6 | Chat / imagem | claim/complete/send M03 | Postgres/Auth e catálogo candidato | Engenheiro 2 + a01_fixture_auth + a01_foundation_replay + a01_contract_assertions | leitura estática nominal | próximo gate: resolver e protocolo concorrente compatíveis com os writers, com review Auth E2E1.**

Pedido do Coordenador: avaliar o núcleo privado existente e a ordem de locks para reautorizar o contexto persistido após decode. Incluído: proposta e5c155a35f7bf21f8670c696a385f1a2a4392dfd, cinco âncoras do ator, writers de revogação e conversa, receipts e matriz de corridas. Fora: implementação Auth/helper compartilhado, SQL, Docker/replay, decoder, mensagens às frentes e remoto. Ordem: proposta → resolver → escritores/locks → contrato e gates. Parada: parecer nominal consolidado, aproximadamente quinze minutos; nenhuma certificação de atomicidade ou GREEN.

O commit altera somente a proposta `docs/superpowers/plans/2026-09-07-media-chat-m03-catalog-proposal.md`. Prepare/authorize autenticados e claim/complete privilegiados são assinaturas candidatas, não RPCs implementadas. Não foi encontrado resolver canônico que reautorize o ator interno a partir de upload_session.

### Núcleo reaproveitável e limite de confiança

Fonte H: `20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql:63–209`, vigente na worktree a9f2. `require_superadmin_internal_context` é STABLE/SECURITY DEFINER, search_path vazio, owner postgres e EXECUTE revogado inclusive de service_role. Depende de auth.uid/JWT e não adquire locks. Extração relacional candidata: H:97–115 e123–186; não é autorização para mudar Auth nesta tarefa.

| Dado | Verificação existente | Contrato necessário para o caminho privilegiado candidato |
| --- | --- | --- |
| auth_user_id e session_id | H:83–115: sessão exata, mesmo usuário, not_after e email confirmado | Derivar da upload_session persistida e reler sessão/usuário atuais; o serviço não escolhe ator. A autorização anterior/ticket não substitui a nova verificação. |
| internal_identity_id e internal_auth_link_id | H:123–135: link por usuário e status ativo | Conferir igualdade com as âncoras persistidas, sem fabricar pessoa/realm nem transferir upload para novo link. |
| internal_membership_id | H:137–152: seleciona membership por identity, priorizando ativa | Revalidar a membership original exata. Outra membership ativa não herda ticket/lease de uma membership revogada. |
| role, escopo e capability | H:154–186: papel ativo, limite de escopo, permissão ativa e grant allow ativo/não revogado | Derivar do estado atual da membership; capability fixa do comando, por exemplo chat.internal.send. Snapshot de papel/escopo não autoriza e IDs livres do Gateway não entram no resolver. |
| AAL | H:117–121: JWT real; ADR0019 admite AAL1/AAL2 | Preservar AAL1. auth.sessions.aal é candidato para o adaptador privilegiado, ainda dependente de validação E2E1; não usar JWT/GUC fictício nem exigir AAL2 por inferência. |
| instituição e conversa | Chat C:284–291, fonte abaixo | Derivar a conversa da upload_session, resolver instituição real e conferir compatibilidade com escopo atual; conversa active e is_read_only=false. |

O tipo `superadmin_internal_context` em `20260827233000_superadmin_internal_auth_context.sql:954–959` contém as cinco âncoras e campos derivados, mas não versões; resolved_institution_id sai NULL do helper H. A identidade não tem coluna status. Não atribuir ao helper checks adicionais de lifecycle que ele não executa. `audit_append_superadmin_internal` confere coerência de ator, mas não substitui reautorização. O helper People `can_access_chat_conversation` e `moments_actor_for_auth_user` têm outro contrato e não são adaptadores internos.

Uma assinatura privada candidata seria `require_chat_image_upload_actor_v1(upload_session_id)`: carrega as âncoras persistidas, sem aceitar user/membership/role/scope/AAL/capability do Gateway. Deve permanecer inacessível diretamente aos papéis API; apenas RPCs nominais a alcançam após validar ticket/lease/operação. O wrapper autenticado mantém JWT real; a extração compartilhada e seu adaptador privilegiado exigem reserva/review E2E1.

### Writers e restrições de ordem comprovadas

Fontes da worktree a9f2: U=`20260901210000_superadmin_internal_users_directory.sql`; P=`20260811215451_access_profile_management_v2.sql`; A=`20260901190927_deploy_superadmin_internal_auth.sql`; C=`20260901101500_superadmin_internal_chat_v2.sql`. O blob de U no commit e5c155a3 e no HEAD consultado de E2E1/3ce0 é o mesmo: bf212939010bf79f508cf7e92e5dc9d4d007530e.

| Writer/estado protegido | Ordem observada | Consequência para M03 |
| --- | --- | --- |
| Suspender/revogar contexto interno | U:580 request advisory → U:591 membership FOR UPDATE → U:594 auth_link FOR UPDATE → status/version → auditoria | Preservar membership antes de auth_link. O advisory é por request, não cerca outro comando do mesmo ator. Não altera auth.users/sessions. Revoked é terminal neste writer, U:600–601. |
| Alterar papel/escopo do usuário | U:470 profile FOR UPDATE → U:472 membership FOR UPDATE → U:511 UPDATE membership → U:519 DELETE/U:527 INSERT scopes | Membership já serializa esse writer de scopes. Profile só precisa entrar na ordem caso o novo fluxo precise bloqueá-lo; não acrescentar locks sem dependência. |
| Alterar capabilities do papel | P:721 request/receipt → P:722 access-profile-full-authority → P:734 UPDATE role → P:737 UPDATE grants → P:738 upsert grants | Um lock conflitante no pai role cerca esse writer nominal, inclusive upsert. Não comprova sentinel universal para qualquer DML em grants. |
| Envio interno atual | C:284 require interno → C:285 instituição/escopo → C:288 conversa FOR SHARE → C:293 request advisory → C:296 receipt FOR UPDATE | Complete precisa proteger conversa até ready; send precisa reautorizar e protegê-la novamente durante mensagem/bindings/receipt. Conciliar sessões/ativos com essa ordem, sem presumir deadlock antes de mapear recursos/namespaces comuns. |
| Conversa tornada read-only pelo ciclo infantil | `20260729153100_child_context_lifecycle_trigger_hardening.sql:21–50`; AFTER UPDATE de child_contexts/child_unit_links em `20260724162210:333–353` | Ordem linha infantil → conversa. O caminho interno atual não depende de participante infantil; inserir lock infantil depois da conversa criaria inversão. |
| Logout/revogação do provedor | `_client.auth.signOut()` em coelo_auth gateway:214 | A implementação e ordem de locks do GoTrue não estão comprovadas nas fontes locais; não afirmar cobertura de auth.users/sessions por advisory Coelo. |

Triggers de realm em A:455/466 usam advisory por auth_user_id apenas em inserção/alteração do vínculo, não em simples suspensão por status. Last-owner em A:558/589/620 é adquirido dentro dos triggers depois das linhas nos writers examinados; não antecipá-lo ao mesmo conjunto de linhas sem verificar inversão. A auditoria adquire audit.audit_logs.chain depois das mudanças. Não foi encontrada necessidade de M03 adquirir esses locks de governança para uma leitura autorizadora.

FOR KEY SHARE permite updates de campos não chave; FOR SHARE bloqueia UPDATE/DELETE concorrentes, mas permite KEY SHARE. Assim, SHARE no pai não bloqueia universalmente INSERT filho por FK. A unicidade role_id/permission_id impede grant duplicado, mas não protege todo predicado ausente. Advisory exige participação dos writers. Estas são restrições do PostgreSQL, não resultado de corrida executada. [Locks oficiais](https://www.postgresql.org/docs/current/explicit-locking.html).

`access_profile_catalog_versions` não é geração de grants: o trigger P:1256 cobre platform_permissions, não platform_roles/platform_role_permissions. DML direto e pacotes de migration continuam sujeitos à aplicação nominal serializada; não declarar que um advisory novo só no M03 resolve a cobertura. A ordem intent → upload_sessions → assets → contexto da proposta:195 permanece incompleta; existem apenas as restrições parciais acima e ainda falta cotejo com Auth do provedor.

### Contrato da transação e evidências exigidas

1. Claim valida operação/ticket/contexto e grava lease; commit antes de decode ou R2. O tempo de processamento externo não mantém transação SQL aberta.
2. Complete valida a lease nominal e carrega as referências persistidas; adquire locks compatíveis na ordem comum; relê autorização atual, conversa, versões/lease e hashes de saída. Revalidar também antes de devolver receipt existente.
3. Após esperas por locks, conferir expiração com relógio atual. now/current_timestamp ficam no início da transação; clock_timestamp reflete o instante corrente. A escolha de volatilidade precisa permitir leituras atualizadas: STABLE mantém o snapshot da query chamadora. Não transplantar a classificação do helper H sem revisão. [Tempo PostgreSQL](https://www.postgresql.org/docs/current/functions-datetime.html), [volatilidade e snapshots](https://www.postgresql.org/docs/current/xfunc-volatility.html).
4. Só então publicar ready, receipt e auditoria na mesma transação curta. Saída parcial, lease inválida ou perda de autorização não publica ready. O send reautoriza e vincula sessões/ativos/mensagem/receipt atomicamente; ready anterior não concede envio futuro.

A garantia verificável é de ordenação: se a revogação efetiva completar primeiro, complete deve negar; se complete adquirir as barreiras necessárias primeiro, o revogador espera e ready é anterior à revogação. Isso não significa apagar retroativamente o histórico ready. Reativação de grants ou suspensão seguida de ativação antes do complete exige explicitar se basta autorização atual ou se versões invalidam a lease; não foi inventada uma regra nova para esse caso.

Matriz concorrente proposta, não executada: duas conexões locais com barreiras determinísticas, cobrindo revogação de sessão/link/membership, troca de papel/escopo, grant deny/revoke e conversa read-only nas duas ordens de commit; expiração durante espera; substituição de membership; replay após revogação; claim duplicado/lease vencida; complete/send/discard simultâneos. Observar ready, binding, mensagem, receipt, auditoria, SQLSTATE e ausência de deadlock. Auth deve validar primeiro os writers/fixtures nominais; Eng1 mantém exclusividade do replay serial.

Limite adicional da proposta: Delete de mensagem remove binding precisa de comando definido. C:96–98 tem FK receipt→message ON DELETE RESTRICT; o cascade da metadata só atua no DELETE físico, não em status/deleted_at. Nenhuma RPC canônica de delete/archive foi encontrada neste recorte. Não incluir implementação de exclusão por inferência nem comprometer a preservação dos receipts.

**Parecer:** núcleo relacional reutilizável, porém resolver por upload_session e atomicidade com revogação ainda não comprovados. Próximo gate nominal: E2E1 validar adaptador/AAL e cobertura de locks Auth; E2E3 conciliar complete/send/discard com as ordens parciais e apresentar a matriz local. Nenhum Auth/shared helper, código, SQL, teste, Docker ou remoto alterado/executado. Memória de conhecimento no-op; proposta técnica não é decisão aprovada de produto.

### M03 — módulo puro 3efe3865, revisão estática às22:40 BRT

**Passo 2/6 | Chat/imagem | validação de métricas source/master | `_shared/media_image_contract.ts` | Engenheiro 2 e a01_contract_assertions; writer E2E3 | sem bloqueantes estáticos; nenhuma execução | próximo gate: composição com decoder e catálogo nominais.**

Recorte: commit 3efe3865d5739fc9d122ab814d6d7747b89f7e3c indicado no checkpoint central; módulo117linhas, testes285linhas e evidência32linhas, lidos no SHA. Ordem contrato/ADR → cobertura → consumidores; fora decoder, I/O e testes já executados pela frente. Critério de parada: parecer do delta, aproximadamente cinco minutos.

Limites por finalidade conferem com ADR0032:138–148. A divisão do orçamento de pixels evita multiplicação insegura; width/height/bytes exigem inteiros seguros positivos, e master limita largura e altura separadamente. Crops avatar1:1/capa3:1, MIME normalizado, checksum apenas sintático, allowlist de campos e cópia congelada são coerentes com o recorte puro. Testes:91–145 cobrem fronteiras inclusivas e excedentes; :202–228 tipos/não finitos/frações/inteiros inseguros; :231–272 checksum/campos/finalidade/estágio inválidos. Nenhuma falha acionável identificada.

No SHA, git grep encontrou validateImageMetrics apenas na definição e nos testes, sem consumidor produtivo. O pacote não calcula checksum, não prova MIME/bytes, decode completo, saneamento, autorização ou ready. Também não pareia origem/master: a composição deve aplicar os limites aos bytes originais HEIC/HEIF e exigir a conversão JPEG/WebP da ADR0032:135–137; aceitar PNG no validador genérico não autoriza PNG como master de uma origem HEIC. Isso é gate da composição ainda ausente, não bloqueante desta função isolada.

A evidência da frente relata19/19 do módulo e30/30 com transporte, typecheck/lint/formatter. Nenhum teste foi reexecutado nesta revisão. Sem código ou configuração alterados; memória no-op.

## M03 — fonte primária GoTrue e revogação, 2026-09-07, 22:50 BRT

**Passo 2/6 | Chat/imagem | complete versus signOut/revogação Auth | auth.users/auth.sessions e dependentes | Engenheiro 2 + três subagentes de leitura | SDK instalado, harness e fonte pública oficial congelada | próximo gate: E2E1 validar predicados/ordem e E2E3 incorporar ao protocolo nominal.**

Pedido adicional do Coordenador após o parecer: identificar os writers reais do provedor que faltavam ao crosswalk. Incluído: signOut do pacote atual, versão nominal local, logout, ban e exclusão de usuário com impacto em sessões. Fora: demais fluxos GoTrue, consultas a serviços Coelo, Docker, execução concorrente e autoria Auth. Ordem SDK/pin → código primário → locks/predicados → efeito no complete. Parada: evidência acionável delimitada, aproximadamente quinze minutos. O módulo de métricas já integrado não foi reavaliado.

### Versão e alcance da evidência

Lockfiles e package_config efetivo de a9f2 resolvem gotrue2.26.0, supabase2.14.0 e supabase_flutter2.16.0. São versões do cliente Dart. O gateway Coelo:214 chama auth.signOut sem scope; o SDK gotrue_client.dart:976 usa **SignOutScope.local**, repassado explicitamente ao Admin API. O default global do Admin API não se aplica a esse callsite.

O harness principal/a9f2/E1 e Test-LocalAuthLifecycle fixam **supabase@2.116.0**. A tag oficial da CLI resolve commit997a1e69a4a83466964ed874d3a604c88a7b3866; seu Dockerfile:13 e ServiceCatalog:175 fixam **GoTrue v2.196.0**. Os dois binários locais em cache da mesma CLI também contêm essa constante pública. [CLI Dockerfile](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/apps/cli-go/pkg/config/templates/Dockerfile#L13), [catálogo](https://github.com/supabase/cli/blob/997a1e69a4a83466964ed874d3a604c88a7b3866/packages/stack/src/ServiceCatalog.ts#L172).

Base primária preferida desta revisão: **supabase/auth v2.196.0 → commit0204331ca41a5b49f076b6fa3dc6c0d20b996590**. A primeira consulta usou master congelado0907af9; logout.go/auth.go/sessions.go e a FK de sessões foram comparados e são idênticos no ref nominal. adminUserDelete também é idêntica, com deslocamento de linhas; ban mantém a mesma lógica. Links seguintes usam o commit nominal, não master móvel.

Não foi identificada a versão de produção. O cache ignorado main `.temp/gotrue-version=v2.193.1`, de27/07, não está em a9f2/E1 nem é copiado pelo staging. O harness só inicia GoTrue com RunAuthLifecycle; sem essa opção exclui gotrue, e perfis nominais recusam sua combinação com RunAuthLifecycle. AuthOnly seleciona migrations, não inicia o serviço. Portanto pgTAP dos perfis nominais não é execução desse writer GoTrue. Fontes locais E1: Invoke-SafeLocalMigrationReplay.ps1:44/94/225/280; Test-LocalAuthLifecycle.ps1:12. Default empacotado não comprova digest ou container de uma rodada anterior.

### Caminho de logout e locks efetivos

O cliente instalado envia POST /auth/v1/logout?scope=local com token real capturado da sessão corrente e body vazio. Antes do HTTP, o SDK remove a sessão em memória, limpa PKCE e emite signedOut; sem token, nem chama o servidor. Ignora AuthException401/403/404 e propaga outros erros sem restaurar a sessão. O listener Flutter limpa persistência via unawaited. Assim, saída visual, signedOut ou LogoutResult.success isolados não constituem prova de revogação confirmada no banco. Fontes locais: gotrue2.26.0/gotrue_client.dart:984–1009; gotrue_admin_api.dart:63–78; supabase_flutter2.16.0/supabase_auth.dart:89–91/183–199.

No GoTrue nominal, a rota usa requireAuthentication. O middleware valida o JWT e lê usuário e sessão; FindSessionByID recebe false, sem seu ramo FOR UPDATE SKIP LOCKED. Esses reads prévios não são locks retidos de usuário/sessão para a transação de logout. O middleware também rejeita usuário banido. [Rota](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/api.go#L275), [middleware:20/118–163](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/auth.go#L20).

O handler abre transação, registra auditoria e chama LogoutSession para scope local e sessão presente. O model executa DELETE da sessão pelo id; o lock de exclusão é adquirido pelo próprio DELETE, sem advisory Coelo nem lock prévio de auth.users nesse caminho. Global exclui por user_id; others exclui por user_id exceto a sessão corrente. Nenhum deles ordena explicitamente várias sessões. Sessão ausente no contexto faz o handler cair no ramo global; o fluxo interno válido exige session_id real. [Handler:46–65](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/logout.go#L46), [models:358–369](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/sessions.go#L358).

A auditoria do GoTrue é auth.audit_log_entries, com INSERT quando habilitada, não audit.audit_logs.chain do Coelo. A transação de logout grava a auditoria antes do DELETE. [Modelo de auditoria:160–170](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/audit_log_entry.go#L160).

### Usuário, banimento e exclusão

| Writer relevante | Sequência comprovada | Efeito no contrato M03 |
| --- | --- | --- |
| Ban simples | adminUserUpdate:248 abre transação; :365 Ban; :370 auditoria. Ban em user.go:987–994 atualiza somente banned_until. | Não remove sessões nesse ramo. Usuário/sessão existentes e email confirmado não bastam para reproduzir a rejeição do provedor. |
| Soft delete | admin.go:592 transação/auditoria → :606 SoftDeleteUser; user.go:1070 UPDATE users/deleted_at → limpeza de tokens/metadados → :1111 Logout. Handler limpa outros dependentes e repete Logout em:623. | Ordem relevante usuário → sessões. Usuário permanece fisicamente; deleted_at precisa de predicado explícito. Handler retorna cedo quando já deletado (:602–604). |
| Hard delete | admin.go:627 pede Destroy(user). FK sessions.user_id→users.id ON DELETE CASCADE remove sessões, se DELETE concluir. | Ordem pai→dependentes decorre de FK, sem ordem total provada entre todos os dependentes. No Coelo, auth_link referencia users sem cascade; pode impedir exclusão física. Tentativa de delete não é revogação confirmada. |

Fontes: [admin.go nominal](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/admin.go#L592), [Ban/IsBanned](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/user.go#L987), [soft delete](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/user.go#L1070), [FKs de sessões/refresh_tokens](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/migrations/20220811173540_add_sessions_table.up.sql#L8). FK Coelo:20260901190927_deploy_superadmin_internal_auth.sql:364. O código IsBanned compara o relógio atual com banned_until; nil significa sem ban. A observação sobre Ban é do payload simples, sem combinar outro comando como troca de senha.

### Efeito concreto sobre complete e próximo gate

- Para o logout local revisado, bloquear a **sessão exata** com FOR SHARE até o commit de complete conflita com seu DELETE. Logout que conclui primeiro elimina a linha e complete deve negar após reler; complete que obtém a barreira primeiro pode concluir antes do DELETE. O evento local signedOut antecede essa barreira no servidor.
- Bloquear auth.users com FOR SHARE cobre a atualização concorrente de banned_until/deleted_at, mas **o predicado também precisa existir**. H vigente só verifica existência/email confirmado; copiar H com locks mantém a lacuna de ban. E2E1 deve validar a paridade do novo resolver com ban/deleted_at, preservando AAL1. Não houve alteração Auth.
- Entre esses dois registros, respeitar **auth.users antes de auth.sessions**, coerente com soft/hard delete. Sessão→usuário pode inverter essa ordem. Isso acrescenta uma restrição comprovada ao crosswalk anterior, não certifica ordem total de Auth+Chat+catálogo.
- Conferir os futuros FKs da upload_session: referência RESTRICT/NO ACTION à sessão pode impedir o logout; CASCADE/SET NULL pode fazer a exclusão da sessão bloquear a upload_session. Nesses casos, upload_session→sessão no complete pode inverter a ordem do revogador. A proposta ainda não tem DDL nominal que permita fechar esse cotejo; não escolher política de retenção/cascade por inferência.
- Próxima prova local nominal: logout DELETE da sessão exata e ban UPDATE em duas conexões, com as duas ordens de commit; soft delete usuário→sessões; replay após revogação; lease expirada durante espera; novas FKs e conservação da evidência de autoria. Deve medir tanto predicados quanto ausência de deadlock. Nenhuma corrida foi executada aqui e o replay continua sob o Eng1.

As consequências de SHARE/DELETE e ordem concorrente acima são inferências da semântica PostgreSQL aplicada ao código lido. [Locks PostgreSQL](https://www.postgresql.org/docs/current/explicit-locking.html). O recorte não auditou refresh, todos os caminhos de senha/MFA, todos os hooks ou alterações remotas do provedor. A dependência deixou de ser ordem GoTrue desconhecida para ser protocolo nominal com versão/default local identificado e duas restrições concretas: usuário→sessão e predicado de ban; versão remota, FKs novas e prova concorrente continuam gates delimitados. Nenhuma consulta a produção, SQL, Docker, execução de CLI, código ou configuração alterados. Memória de conhecimento no-op.

## M03 — auth.sessions.aal e recovery, 2026-09-07, 23:06 BRT

**Passo 2/6 | Chat/imagem | AAL do adaptador privilegiado | auth.sessions.aal e auth.mfa_amr_claims | Engenheiro 2 + três subagentes de leitura | fonte primária GoTrue2.196.0/0204331ca41a5b49f076b6fa3dc6c0d20b996590 | próximo gate: E2E1 validar contrato explícito de AAL e proveniência operacional.**

Pedido nominal do Coordenador: verificar schema, login/refresh/recovery/MFA, relação coluna/JWT e marcador canônico de recovery. Incluído somente esses writers; fora implementação Auth, demais fluxos do provedor, SQL, Docker e serviços Coelo remotos. Ordem schema → writers → JWT → recovery → decisão técnica. Parada: parecer do gate, aproximadamente dez minutos. A base continua sendo o default local identificado; versão/configuração de produção não verificadas.

**Resposta técnica: sim, aal1/aal2 da linha EXATA de auth.sessions são utilizáveis como AAL persistido atual no adaptador privilegiado. Não são uma cópia garantida do JWT real emitido anteriormente nem autorização suficiente por si.** Exigir vínculo exato sessão/usuário/upload, estado e prazo válidos, demais âncoras/predicados já mapeados e fonte server-side. Aceitar somente valores exatos aal1 ou aal2; negar NULL/aal3/estado inconsistente, sem coalesce ou fallback de parser e sem impor AAL2 ao M03. O contrato autenticado continua usando JWT real; isto não autoriza trocar silenciosamente a semântica do helper compartilhado.

### Schema e writers nominais

O enum aal_level admite aal1/aal2/aal3; a coluna é adicionada explicitamente nullable, sem default. Busca focal nas migrations posteriores não encontrou mudança dessa nulidade/default/tipo. NewSession escreve aal1 no código, o que não estabelece default SQL. ParseAAL(nil/desconhecido) retorna AAL1, enquanto GetAAL(nil) retorna vazio; nenhum fallback é contrato automático Coelo. [Enum:15](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/migrations/20221003041349_add_mfa_schema.up.sql#L15), [coluna:3](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/migrations/20221003041400_add_aal_and_factor_id_to_sessions.up.sql#L3), [modelo de sessão](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/sessions.go#L52).

| Caminho | Efeito persistido e limite |
| --- | --- |
| Login novo, algoritmos novo/legado | Cria sessão em aal1, registra o método AMR e gera token dentro da transação; resposta só após retorno bem-sucedido. |
| Refresh comum | Tranca/relê sessão, atualiza dados/contador de refresh e emite novo JWT. Não regrava aal nem adiciona AMR token_refresh; não sincroniza coluna com claim automaticamente. |
| Verificar TOTP/telefone/WebAuthn | Adiciona AMR MFA, calcula nível, atualiza aal/factor_id e emite JWT mantendo o MESMO session_id. Depois invalida sessões do usuário com aal menor que aal2. |
| Desinscrever/remover fator | Remove AMR do tipo correspondente e grava aal1/factor_id=NULL nas sessões associadas ao user/factor, mantendo seus IDs. Não entrega JWT substituto na desinscrição. |
| Rejeição de hook MFA habilitado | Pode excluir todas as sessões do usuário; existência precisa ser revalidada mesmo quando o AAL anterior era aceito. |

Fontes: [login e emissão:873–935](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/tokens/service.go#L873), [refresh:581–650](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/tokens/service.go#L581), [helper MFA:303–406](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/token.go#L303), [TOTP e invalidação](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/mfa.go#L661), [downgrade:415–429](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/factor.go#L415), [remoção administrativa:648–658](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/admin.go#L648).

### Por que o JWT pode diferir

GenerateAccessToken recarrega a sessão, porém calcula aal/amr pelos AMRClaims; esse cálculo começa em aal1 e reconhece métodos MFA, sem ler Session.AAL. O Custom Access Token hook pode substituir claims e não exige igualdade com a coluna. O token assinado permanece imutável quando MFA altera o registro. Portanto não exigir igualdade com JWT antigo, não fabricar JWT e não alegar que um refresh corrige toda divergência. [Geração e hook:665–741](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/tokens/service.go#L665), [cálculo por AMR:384–411](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/sessions.go#L384).

### Recovery é outra dimensão

Existe marcador persistido por sessão em mfa_amr_claims.authentication_method. É TEXT NOT NULL, único por sessão/método e com FK em cascata; não possui enum/check de métodos nem constraint exigindo ao menos um AMR na sessão. [Schema:52–59](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/migrations/20221003041349_add_mfa_schema.up.sql#L52).

O caminho PKCE preserva flowState.AuthenticationMethod até AddClaimToSession: recovery gera o método explícito recovery. O Superadmin usa FlutterAuthClientOptions padrão e o SDK supabase2.14 define PKCE; fontes locais superadmin_auth_scope.dart:415 e supabase_client_options.dart:17. Mesmo assim, essa escolha do cliente não controla todos os requests possíveis ao provedor. [Exchange PKCE:254–265](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/token.go#L254).

Nos caminhos verify GET implicit e verify POST, recovery também passa por emissão com método OTP. A categoria upstream IsRecovery engloba otp, magiclink e recovery e é usada no contexto de mudança de senha; não é sinônimo estreito de reset de senha para política do Coelo. Session.IsRecovery ignora métodos inválidos e retorna false para lista vazia. Portanto ausência de uma linha recovery não prova sessão operacional, e copiar IsRecovery para proibir todo OTP/MagicLink ampliaria a política sem base. [Verify:185/285](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/verify.go#L185), [categoria:62–69](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/factor.go#L62), [uso na mudança de senha:175](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/user.go#L175).

Para o M03, negar sessão identificada como recovery independentemente de aal1/aal2; MFA não transforma o propósito recovery em autorização de upload. Quando AMR/proveniência não permitir distinguir o fluxo admitido, não autorizar somente pelo nível AAL. E2E1 deve explicitar o guard server-side dos fluxos aceitos e seu tratamento de AMR ausente/inválido/ambíguo; não inferir categoria pelo evento/URL do cliente ou AAL. Esta é a lacuna delimitada de composição, sem proibir genericamente OTP/MagicLink nem criar um novo fluxo Auth nesta tarefa. A spec039 mantém recuperação/reset fora de sua implementação (:44/391).

### Consequência adicional de concorrência

O helper MFA insere/upserta AMR ANTES de FindSessionByID(true), cujo lock usa FOR UPDATE SKIP LOCKED; depois grava aal/factor_id. Downgrade lê sessões associadas, remove AMR e só então faz UPDATE nas sessões. Assim, não descrever todo writer AAL como session-first nem acrescentar locks AMR depois da sessão sem cotejo: pode haver inversão. [AMR upsert](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/amr.go#L28), [helper:317–321](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/api/token.go#L317), [downgrade](https://github.com/supabase/auth/blob/0204331ca41a5b49f076b6fa3dc6c0d20b996590/internal/models/factor.go#L415).

Próximo gate nominal E1: adaptar fonte AAL com allowlist estrita e guard de proveniência; validar NULL/aal3, sessão exata versus substituta, recovery em PKCE/OTP, AAL2 com AMR recovery, refresh sem equivalência de claim e corrida com MFA/downgrade/exclusão. São casos propostos, não executados; não requerem AAL2 para M03. Nenhum SQL, Docker, teste, serviço Coelo remoto, código ou Auth alterados. A árvore nominal não contém MFA recovery_codes.go do master posterior; esse recurso não foi incluído. Memória no-op.

## M03 — quantidade de anexos Chat, 2026-09-07, 23:29 BRT

**Passo 1/6 | Chat | máximo de anexos por mensagem/lote | produto e contrato batch | Engenheiro 2 + a01_fixture_auth + a01_contract_assertions | ausência confirmada nas fontes delimitadas | próximo gate: decisão numérica do Owner, encaminhada pelo Coordenador.**

Pedido nominal: localizar fonte canônica aprovada de quantidade, sem inferir número ou transferir limites de Circulares/Acontece. Ordem PRDs/originais → ADR/design/Knowledge → spec/SQL; fora auditoria genérica, código, política, novos módulos M03 ou execução. Parada: fonte encontrada ou lacuna documentada, aproximadamente cinco minutos.

| Fonte consultada | O que estabelece e limite desta evidência |
| --- | --- |
| docs/product/prd-master.md:468–492, especialmente:484; prd-app.md:195–224, especialmente:209 | Chat aceita anexos básicos imagem/PDF; não quantifica anexos por mensagem/lote. Os DOCX preservados Master§26/App§11 confirmam o texto. Markdown derived-from-official-docx; originais indicam draft para validação. |
| PRD Superadmin e DOCX preservado correspondente | Não estabelece quantidade de anexos Chat. Limites de planos/storage e imagem de popup pertencem a outros contratos. |
| decisions/0032-mvp-private-media-r2.md:130–155/175 | Formatos, bytes/pixels/dimensões por finalidade e R2 para Chat; nenhum máximo de quantidade. Documentos canônicos de segurança/mídia e ADRs de mídia anteriores também não forneceram esse número na busca focal. |
| docs/superpowers/specs/2026-07-28-superadmin-chat-local-redesign-design.md:111–112/190; Knowledge Chat UI/grupos | Anexos simulados e status approved-for-local-prototype. Os designs de27/07 estão superseded; medidas de UI/destinatários não são cap de anexos. Spec050 e Knowledge Principal Chat não acrescentam quantidade. |
| specs/028-superadmin-conversations-production.md:49–53/62–63, status approved | Gateway R2, MIME real/tamanho/checksum, apresentação e retry; nenhum número de anexos. |
| 20260812000000_chat_production_contract.sql:14–36/705–723 | Limite26.214.400bytes por item (:28), sem constraint de contagem. O send recebe uuid[] e rejeita qualquer array não vazio enquanto falta gateway (:722–723): indisponibilidade, não cap de produto igual a zero. |
| 20260901101500_superadmin_internal_chat_v2.sql:277–320 | Send textual com conversa/texto/request_id e attachments vazio; não define lote ou máximo. Agregações de anexos e paginação não estabelecem contagem por mensagem. |

O recorte SQL/spec foi fixado em a9f2/f332f2a97d1551e7a66a4f01882de316f79fa332. Originais conferidos: docs/source/originals/docx/Coelo PRD Master v1.docx, Coelo PRD App Oficial v1.docx e Coelo PRD Superadmin Oficial v1.docx. Busca focal adicional por quantidade/máximo/por mensagem/por lote nas fontes normativas não trouxe regra quantitativa Chat. Esta é ausência no conjunto revisado, não afirmação sobre toda comunicação histórica do Owner.

**Gate do Owner:** definir o máximo de anexos por mensagem Chat e sua relação com o lote operacional, para validação server-side do contrato nominal. Nenhum número foi escolhido. **Batch sem máximo não é habilitável em produção**, conforme orientação expressa do Coordenador. Limites de outros domínios, bytes por arquivo e tamanho de página não suprem a decisão. Registro somente neste MD; Coordenador mantém perguntas/rastreadores canônicos. Nenhuma edição de produto/código ou teste executado; memória no-op porque não houve decisão aprovada.

## AG-READ01 — catálogo, grants e dependências, 2026-09-07, 23:57 BRT

**Passo 2/6 | Agenda | list/get/contexts | catálogo039, contexto e audit | Engenheiro 2 + três subagentes de leitura | proposta b22718fa7ae375e465bcf6da81a43bfe544e585d da wt1c73 | próximo gate: composição nominal/fixture sintética e auditoria comprovadas pelo Coordenador/Eng1.**

Recorte pedido: inventário de agenda.read, dependências mínimas dos três READs e equivalência de auditoria. Ordem fontes aprovadas → catálogo/seeds/writers → objetos consultados → auditoria; fora writes/requests/responses de Agenda, backend compartilhado, SQL, Docker, serviços remotos, código/Git e matriz de papéis inventada. Parada: parecer estático acionável, aproximadamente dez minutos. A proposta foi lida no SHA, sem tratá-la como implementação. Knowledge superadmin-agenda consultado com ADR0029/specs006/050.

### Catálogo existente não comprova grant

ADR0029 autoriza backend produtivo exclusivamente Superadmin e revalidação interna. Spec050:50–56 exige capability efetiva; spec006:136–154 remete as sete capacidades de escrita a Perfis e Permissões. Não foi localizada nessa autorização uma matriz que conceda agenda.read a Owner/Operations/Content/etc.

`20260901183836_superadmin_agenda_production.sql:8` declara agenda.read ativa, risco normal, requires_mfa=false; o arquivo não insere role grants. O seed Owner genérico `20260623191021_superadmin_foundation_v1.sql:956–961` faz CROSS JOIN com o catálogo daquele momento, ANTES de Agenda existir, sem concessão dinâmica futura. Os demais papéis têm listas explícitas. Os seeds posteriores Notices185008:158, Invites190432:56, Circulars191921:123 e Users210000:25 restringem códigos aos próprios domínios; role_models em20260901170731:162–173 também não cobre Agenda. Nenhum grant automático de Agenda foi localizado nas migrations, incluindo039.

Writers genéricos de criação/edição de perfil em `20260811215451_access_profile_management_v2.sql:425–428/737–742` podem gravar grants mediante chamada/payload. Sua existência não prova execução. Portanto não se afirma que nenhum papel tem Agenda em produção: o estado efetivo de banco não foi consultado. H vigente20260901200206:154–185 exige papel/capability/grant ativos, grant não revogado e allow, INCLUSIVE Owner; AAL1 continua permitido.

Para destravar testes sem inventar produto: fixture nominal, inteiramente rollback, com papel sintético ativo, grant explícito só de agenda.read e identidade/link/membership/sessão sintéticos válidos; negativas por ausência/deny/revogação/inatividade. As sete capabilities anunciadas por contexts devem refletir o estado real desses grants; disponibilidade de mutações fica em campo separado. A fixture não autoriza seed nos papéis reais nem comprova matriz produtiva. A preparação/execução permanece na reserva do Coordenador/Eng1.

### Objetos mínimos de leitura

| RPC candidata | Objetos/âncoras físicas |
| --- | --- |
| superadmin_agenda_list_v2 | agenda_events, DDL20260901183836:22; hierarquia institucional para validar contexto/audience conforme proposta. |
| superadmin_agenda_get_v2 | agenda_events + agenda_history_receipts, DDL:103; vínculo evento/instituição. agenda_responses pertence ao get legado:197 e fica fora deste reader. |
| superadmin_agenda_contexts_v2 | institutions/units/groups da Foundation20260623191021:231/254/265 e activity_definitions de20260724120307:70. Contexts20260901193717:52/91/105/123 mostra joins; não cria essas tabelas. |

Activities aqui é **activity_definitions**, não uma tabela activities. Sua FK composta de origem depende da chave units(id,institution_id), criada em20260724120307:27–28, e do tipo activity_origin_scope. Institutions/units/groups já têm os campos de status/hierarquia usados pelo reader nas foundations. People é dependência física para autores NOT NULL de events/history/activity_definitions; não exige person_auth_link ou autenticação People para o ator interno que lê.

Auth requer as entidades internas039, composite superadmin_internal_context, roles/permissions/grants, auth.users/sessions/not_after, access_scope_rank e max_scope_kind (governance20260729144440:3–8/85), mais H vigente20260901200206. Tipos e entidades internos constam no deploy20260901190927:344–387/1287; a escolha entre cadeia histórica/consolidada pertence ao manifest nominal do Eng1, sem duplicar fontes equivalentes.

Não são dependências funcionais desses READs: assert_agenda_permission/has_platform_permission/People memberships legados, comandos/requests/publication e suas respostas, nem toda a cadeia de comandos/participação/proveniência Activities. Porém as migrations completas criam/tocam objetos adicionais. A lista acima é crosswalk de objetos, **não manifest fechado nem número de migrations para replay**; não autoriza recortar migrations ou pular dependências.

### Auditoria: reutilização equivalente delimitada

O append Auth039 de13argumentos, `20260827233000:613–649` e equivalente no squash20260901190927:946–982, preserva ator interno/link/membership, hash_version2, sessão hashSHA256, capability/AAL, ação/outcome/correlação/instituição. **Não recebe nem grava after_json**, portanto não satisfaz row_count da proposta.

O overload de14argumentos, mesma assinatura mais jsonb, está em `20260831211945_activities_v2_internal_gateways.sql:49–60`, com owner/revokes:732–751. Mantém atribuição interna e grava after_json; sua definição não depende de tabelas ou marcador de Activities. É a reutilização equivalente identificada, desde que exista e tenha privilégios comprovados na base nominal. Não foi identificado outro helper equivalente para essa combinação. Isso não autoriza extrair/criar/alterar helper compartilhado nem importar automaticamente toda a cadeia Activities.

Redução comprovada de dependência: `audit_mask_payload` de `20260812000847_audit_production.sql:114–117` já preserva row_count numérico, e audit_minimize_payload:130–141 usa essa máscara para agenda.*. A extensão Activities acrescenta counts aninhado, desnecessário ao payload proposto. **Não é necessário trazer essa alteração da máscara só para row_count**, mas ainda é necessário provar o overload14. Exclusividade de row_count é responsabilidade dos readers/fixture, pois a máscara genérica aceita outros campos.

Negativas podem reutilizar o helper de negação endurecido20260901124500:6–59, também no squashAuth:1487–1540, respeitando os limites de atribuição/sessão identificável. Não exigir audit de uma chamada que não entrou na RPC ou não tem sessão atribuível. Ambos os append deixam falhas de INSERT/trigger propagarem; os novos readers precisam manter o append fora do catch de leitura para não devolver sucesso/data após falha. Essa composição ainda não foi executada.

**Parecer:** backend/capability autorizados e catálogo localizado; seed automático de concessão não localizado e grants reais desconhecidos. A fixture sintética pode isolar esse requisito sem criar matriz produtiva. Base de READ e overload14 precisam de comprovação nominal; a máscara row_count antiga é suficiente. Nenhum comando, helper, Auth, código, SQL, teste, Docker, manifesto ou remoto alterado/executado. Memória no-op: inventário não cria nova decisão aprovada.

## AG-READ01 — manifesto candidato de dependências, 2026-09-08, 00:40 BRT

**Passo 2/6 | Agenda | DDL, filas, list/get/contexts e audit14 | Engenheiro 2 + três subagentes de leitura | inventário candidato para validação do Eng1; nenhum perfil executável criado.**

Contrato solicitado pelo Coordenador: produzir conjunto nominal candidato sobre a base Auth existente, incluindo efeitos dos arquivos completos e privilégios. Ordem: conferir base por hash → dependências de criação → efeitos de triggers/população → lista ordenada e gates. Fora SQL, Docker, replay, helpers novos/alterados, código/Git, perfil compartilhado e outras verticais. Parada desta fatia: entregar manifesto candidato e impedimentos verificáveis; estimativa de inventário 20–30 minutos, sem ETA de replay. Fontes Agenda/Activities sem diff contra b22718fa7ae375e465bcf6da81a43bfe544e585d; HEAD observado da wt1c73 eb782626724531ad2f6d55d4b38312b6e785589a.

### Base herdada comprovada em disco

Fonte do Eng1: `packages/coelo_database/replay/foundation-migrations.sha256`, SHA256 UTF-8 normalizado CRLF `4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59`. Seletor Auth em `Prepare-SafeMigrationReplay.ps1:162–172`: entradas do manifesto com versão <=20260812001975, mais 20260827214000, 20260827233000, 20260901124500 e 20260901200206. A leitura independente selecionou **45 entradas, zero divergências de hash** contra os arquivos da wt1c73. Harness observado em 5ef2fc4eab0676b09b845524807af5c4a013d6a7; nenhum script foi invocado.

Essa base já contém instituições/unidades/grupos/People, Activities foundation e evolução até agosto12, catálogo/labels, governança de papéis, AuditProduction, Auth039 histórico e hardening vigente. Não acrescentar novamente foundation Activities nem misturar o squash Auth20260901190927 com a cadeia histórica. A presença no inventário não é uma nova prova de execução desta composição.

### Lista candidata, preservando arquivos inteiros de Agenda

Todos os caminhos abaixo são relativos a `packages/coelo_database/migrations`. Hashes são SHA256 de texto UTF-8 normalizado CRLF, recalculados independentemente. Posição é a intercalação canônica com a base45; não é ordem para executar adições depois de Auth.

| Posição canônica | Arquivo completo | SHA256 CRLF UTF-8 | Razão e limite |
| --- | --- | --- | --- |
| 44 | 20260831195944_activities_v2_actor_provenance_semantics.sql | 19c3168014d7710b248da92100bb1b61528e9299150a54da74080315e8b99745 | Fornece guard/marker exigidos pelo próximo arquivo; recria nove triggers. |
| 45 | 20260831203645_activities_v2_permissions_receipts.sql | 84bfc497aae6e4d8ad950fc03035896d6b9246c42531823e32ce34817b0d02b5 | Cria receipt tipado e activity_admin_capability_actions; DO e triggers exigem guard, timestamp e identidade interna. |
| 46 | 20260831211945_activities_v2_internal_gateways.sql | 443be75040ca103a7a6723aa90037359c11c1681afdc6a6361c2d81f667a6dfa | Disponibiliza audit14; arquivo inteiro também cria wrappers Activities e substitui máscara/trigger de auditoria. |
| 48 | 20260901183836_superadmin_agenda_production.sql | 96d909e33598300619a03b8975fa0c6fca243894f1af8fd33acb9458a5926f3d | Catálogo, cinco tabelas, índices/RLS e RPCs legadas, inclusive comandos fora do teste. |
| 49 | 20260901184240_agenda_fk_index_hardening.sql | 05c581aa6c8452e98c30592b9dab137f7900b8fb7e22dfe6954222cc359a0df0 | Preserva sete índices nominais; não é dependência lógica de criação das RPCs. |
| 50 | 20260901193717_superadmin_agenda_contexts.sql | d177e4253a6552d88dfe3626afe0834ac3a230bef58db5a0baeaa61951025b27 | Preserva a RPC contexts legada para compatibilidade; não fornece tabela nem helper obrigatório ao futuro reader independente. |

O hardening de negação Auth20260901124500 ocupa a posição47; H20260901200206 termina na51. Dois preflights existentes permanecem em suas posições relativas: `20260811151253_assert_function_execute_preflight.sql`, hash `718c2de052e9df29abc42642806d9a5e4d98c8964665453de6f14f0f8b61ab75`, imediatamente antes de Groups20260811151254; e `20260811215452_access_profile_labels_replay_bridge.sql`, hash `d97e02796fcd5897707b5657b7a1c1df690f831e09ed98df6ed21886f75f9ef3`, entre AccessProfile20260811215451 e AuditProduction20260812000847.

União calculada **somente em memória**: 51 nomes canônicos +2 preflights =53 nomes, zero nomes/versões duplicados, limite final20260901200206. Isso comprova a aritmética do inventário, não 53 migrations aplicadas ou um perfil fechado. Não há fixture, alvo corretivo, comando de execução ou nova ponte nesta lista. O seletor atual AdditionalMigration não aceita essas adições históricas anteriores ao limite Auth; Eng1 precisa validar um perfil nominal próprio, sem flexibilizar o guard. Os dois últimos arquivos Agenda preservam índices e a superfície legada: não são apresentados como mínimo matemático de objetos para os novos READs.

### Por que a dependência de audit14 não importa automaticamente sete migrations Activities

Gateways211945:211 declara `superadmin_internal_activity_command_receipts%rowtype`; receipts203645:57 cria a tabela. O DO de receipts:3–17 exige imediatamente `guard_activity_v2_actor_provenance()`, `set_activity_updated_at()` e internal_identities. Semantics195944:3–78 usa CREATE OR REPLACE para fornecer marker/guard, e :80–106 instala triggers sobre tabelas já cobertas pela base. As assinaturas/composites, enum audit_outcome, funções SQL e relações consultadas pelo restante do arquivo gateways foram cruzadas com essa base.

192831/195118 não se demonstraram necessários para **criar** esse candidato: 195944 pode criar os helpers e não lê as colunas geradas actor_kind de192831. Os hardenings231645/234307 tampouco são pré-requisitos de criação do appender. Isso não certifica comandos ou runtime de Activities e não autoriza omitir hardenings numa entrega desse domínio. O candidato é restrito ao diagnóstico Agenda, com o gate de população abaixo. Não recortar audit14 para outro arquivo nem alterar helper compartilhado.

O arquivo gateways inteiro modifica globalmente audit_mask_payload:27–47 e audit_activity_change:139–170. A primeira alteração não é necessária para row_count, já aceito pelo AuditProduction, mas é um efeito inevitável desta seleção por arquivo inteiro. Seu DO:732–751 revoga os wrappers ali enumerados; não incluir231645 apenas para conceder execução a comandos Activities. A distinção entre dependências do corpo, objetos tipados e DDL imediato segue a documentação PostgreSQL17 de [CREATE FUNCTION](https://www.postgresql.org/docs/17/sql-createfunction.html), [declarações](https://www.postgresql.org/docs/17/plpgsql-declarations.html) e [dependências](https://www.postgresql.org/docs/17/ddl-depend.html); leitura estática não substitui compilação normal e execução nominal.

### DDL, filas e leitores: efeitos a preservar e conferir

Production183836:3–20 faz INSERT/UPSERT no catálogo, usa labels de AccessProfile:5–8 e dispara platform_permissions_catalog_version:1256; tabela/version bump já estão na base. Cria agenda_events:22, agenda_publication_requests:56, agenda_guardian_requests:70, agenda_responses:90 e agenda_history_receipts:103. FKs externas são People/institutions; demais FKs ligam as próprias tabelas Agenda. Tipos nativos e CHECKs textuais, sem enum Agenda novo. DO:116–122 força RLS/revoga acesso direto; índices:124–135 e hardening184240 preservados.

List/get legados estão em183836:175/190; get legado inclui responses, que o reader v2 proposto exclui. Contexts193717:3 consulta instituições/unidades/grupos/activity_definitions e helpers/memberships People quando chamado; sua migration não executa essas consultas. O DO final de production:298–310 também concede EXECUTE de save/command/requests/decide_publication a authenticated. Esse efeito nominal deve constar do perfil e não significa autorização para exercitar comandos ou conectá-los no app. As filas e responses podem permanecer vazias no teste READ; não simular publicação, reservas ou respostas para satisfazer uma FK que não existe.

### Preflight e fixture: gates antes de fechar o pacote

1. Provar assinatura exata `app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)`, retorno uuid, owner postgres, SECURITY DEFINER/search_path vazio e ausência de EXECUTE para public/anon/authenticated/service_role. Audit13 existente não satisfaz esse teste. Conferir denial helper `(text,text,text,uuid,uuid)` e H vigente, sem alterar ambos.
2. Conferir audit.audit_logs e trigger append-only/minimização: AuditProduction:294–297 e implementação Auth27233000:485–588. Futuro sucesso deve preservar ator/link/membership, hash da sessão e somente row_count; falha de INSERT/trigger precisa propagar fora do catch do reader. Nada disso foi executado aqui.
3. Fixture inicial de shape pode verificar os três readers ausentes sem popular Activities. Resolver assinatura via to_regprocedure/OID e transformar ausência em asserção RED; não abortar a suíte chamando has_function_privilege com texto de função inexistente. Esse RED de existência não equivale a testar autorização/comportamento.
4. Para a fixture behavioral, o grant isolado agenda.read em papel sintético foi autorizado pelo Coordenador, sempre rollback. Leitor039 permanece sem person_auth_link; chamadas devem ocorrer sob authenticated, captura TEMP seguida de RESET ROLE para TAP/audit. Matriz de papéis reais não foi concedida.
5. **População de Activities é gate concreto:** guard195944:68–75 exige current_person_id() igual ao created_by_person_id não nulo, inclusive quando INSERT é emitido por postgres. Inserir somente uma linha People estrutural não basta após esses triggers. A fixture deve declarar um autor global sintético separado do leitor039 e provar a atribuição legítima, ou outro caminho nominal já aprovado. Isso não é bridge para autorizar o leitor. Não desabilitar trigger, fabricar marker nem adicionar192831 como tentativa automática: esse arquivo não resolve a comparação de autor não nulo. O método e os dados precisam integrar o pacote nominal que Eng1 validar.

6. Activity populada também exige ao menos um activity_unit_links ativo/não encerrado: Foundation20260724120307:688–696, constraint triggers inicialmente adiados:1048–1056. Validar esses constraints durante o setup; terminar só em rollback pode esconder uma fixture inválida. A inserção de Activity/vínculo gera audit pelo trigger vigente211945:139–169; capturar baseline depois do setup e contar por correlação/ação, sem DELETE/UPDATE na cadeia audit. Versões e revogação terminal de links/memberships internos exigem linhas independentes ou savepoints, não reativação artificial.
7. Para list/get, a Pessoa estrutural sem Auth link basta aos autores obrigatórios de Agenda; histórico exige request_id único e ação allowlisted. History183836:103–113 possui FKs separadas, sem FK composta evento/instituição: evento A com histórico B é uma fixture adversarial possível sem desativar constraint. Groups têm unidade obrigatória e FK composta de instituição; não usar vínculo estruturalmente impossível apenas para gerar um caso. Sentinelas de DTO ficam em campos existentes/JSON, sem ALTER TABLE. Comparar eventos/receipts antes/depois; não presumir imutabilidade do histórico porque a tabela se chama receipt.

**Entrega:** manifesto candidato auditável, com efeitos laterais e gates de autoria/validade da fixture delimitados. Não foi criado JSON/harness executável, não houve extração/alteração de helper, SQL, Docker, replay, mutação remota, código, stage ou commit. Somente este MD foi atualizado. Memória no-op: inventário e proposta não constituem decisão durável aprovada.

## F-AUTHOR — proveniência de forms.deleted_at, 2026-09-08, 01:01 BRT

**Passo 2/6 | Formulários / rascunhos | dependência G de distribuição legada | Engenheiro 2 + três subagentes read-only | proveniência Git e primeiro impedimento; sem execução.**

Recorte solicitado pelo Coordenador: localizar DDL/commit/blob de forms.deleted_at ou demonstrar introdução do consumidor sem predecessor disponível; comparar G194209, hardening194256 e F-AUTHOR somente nessa dependência. Ordem: arquivo efetivo → parent/rename/blobs → consumidores/fixtures → gate acionável. Fora restante da closure, perfis do Eng1, SQL/Docker, bridge, restauração canônica, edição de helper, grants e nova política de exclusão. Parada: fonte nominal e limite da prova entregues; estimativa de leitura 5–15 minutos. Fonte atual fixada na wt f6c2, HEAD441c5842afec75ee8006fb3236fefbf39f8ae1ef.

### Origem comprovada da referência, sem DDL correspondente localizado

| Evidência | Identificação nominal |
| --- | --- |
| Introdução do consumidor | Commit `4a3cf88752d3f9f7ea53260548d0aca3f5a8610e`, parent `09bf4e71b81711cfd5a44852c94805415b5ab237`; única migration alterada: adição de `20260901194000_forms_distribution_target_authorization.sql`, 106 linhas. |
| Rename, sem mudança de conteúdo | Commit `a0796b43d305c4c4bfbd852e9c5ffb370a7b3139`: R100 para `20260901194209_forms_distribution_target_authorization.sql`. |
| Blob G | `2b80366b10f095d4b8ba3971e655cecf8f462340`, idêntico na introdução, rename e HEAD examinado. O SELECT em :16–19 usa public.forms e exige form_record.deleted_at. |
| DDL predecessor e atual | `20260813155005_forms_definition_and_capabilities.sql:4–33`; blob `785b2ed4fbae74e98e122cb329c2c2ddf72d5e65`, idêntico no parent de4a3cf887 e no HEAD atual. Possui archived_at:21 e status draft/published/archived:23; não possui deleted_at. |
| Hardening posterior | `20260901194256_forms_distribution_rpc_grants_hardening.sql`, blob `833008b81ba91ca5679fc39f74873b9750b9a42d`; apenas dois REVOKE EXECUTE de service_role, :3–6. |
| Pacote F-AUTHOR01 examinado | `20260908030000_superadmin_internal_form_drafts_v2.sql`, blob `3c6fcfe072a38a35f79dad22c482c3ccc22794ad`. |

As buscas delimitadas cobriram migrations atuais, histórico dos SQL Forms nas refs locais e SQL de packages/coelo_database fora de migrations. Não foi localizado predecessor DDL removido que crie forms.deleted_at. A conclusão é **ausência no conjunto verificado**, não afirmação sobre qualquer banco remoto ou todo histórico externo. Há prova de que o commit consumidor não trouxe a coluna; não há arquivo nominal de criação dessa coluna a acrescentar à closure a partir dessas fontes.

### Dependência efetiva e primeiro impedimento

G194209:3–28 cria/substitui `app_private.form_assert_distribution_target(uuid,uuid,uuid) RETURNS void`, PL/pgSQL, SECURITY DEFINER, search_path vazio. Seu primeiro SELECT verifica form_id/institution_id/**deleted_at**; só depois consulta audit_actor_has_permission para forms.manage. G também redefine `public.form_save_application(uuid,bigint,jsonb)` e `public.form_save_schedule(uuid,bigint,jsonb)`, retornando jsonb. Os wrappers exigem o tipo composto form_applications nas declarações:45/81 e chamam o helper em:64/92 antes do comando privado. A tabela vem de Forms155116:1; cardinalidade20154638 não acrescenta a coluna ausente.

G contém CREATE OR REPLACE/REVOKE/GRANT, sem ALTER TABLE, trigger, DO ou chamada imediata ao helper. O hardening194256 exige as assinaturas públicas existentes e revoga somente service_role. Assim, **aceitar CREATE e localizar a assinatura não prova execução do SELECT**. PostgreSQL prepara/análise SQL de PL/pgSQL quando o trecho é alcançado; erros semânticos podem aparecer nessa etapa, conforme [PostgreSQL17, Plan Caching](https://www.postgresql.org/docs/17/plpgsql-implementation.html#PLPGSQL-PLAN-CACHING).

**Primeiro impedimento deste caminho:** numa base sem a coluna, após passar pelas verificações anteriores do wrapper, o SELECT G:14–19 tem referência inválida e o SQLSTATE esperado é42703, antes da checagem de permissão de destino e da delegação ao comando privado. Não é um novo resultado de replay desta revisão e não significa que toda chamada falha nesse ponto: autenticação ausente ou application inexistente podem negar antes. Coluna inexistente tampouco equivale a coluna existente com valor NULL.

### Por que F-AUTHOR não elimina nem comprova esse gate

O preflight de F-AUTHOR01:11–17 verifica somente to_regprocedure do helper G. Os wrappers em:1477–1551 acrescentam a barreira de rascunho interno antes dos caminhos legados, preservando chamadas a G:1518/1547. Nenhuma coluna forms.deleted_at é criada ou diretamente consultada pelo pacote. Suas referências deleted_at:1586/1659/1692 pertencem a **institutions**, assim como o teste:392–410; a ocorrência FormsJobs155124:572 pertence a People.

A fixture `superadmin_internal_form_drafts_v2_test.sql:278–280`, blob `479b16e2f93b2b87ab22ff6d077fd7d27648bd00`, exclui application/schedule/remove_schedule dos controles positivos de receipt legado. Negativas de rascunhos internos são barradas antes de G. Portanto um futuro GREEN desses casos pode provar a barreira F-AUTHOR e **não** o caminho positivo de distribuição legada. O Eng1 já registra essa distinção na sua closure:169–171; a novidade entregue aqui é a origem exata do consumidor e a comparação dos blobs.

O legado `form_archive_or_delete` em155121:853–862 faz DELETE físico de rascunho elegível; nos demais casos arquiva com status/archived_at. F-AUTHOR preserva esse corpo e a fixture:302 confere exclusão física. Isso documenta o comportamento encontrado, sem decidir política futura. Acrescentar uma coluna nullable só para fazer G avançar não implementaria exclusão lógica nem faria os demais leitores filtrá-la. Não substituir silenciosamente deleted_at por archived_at/status e não inventar contrato de soft-delete.

**Entrega e próximo gate:** referência introduzida sem DDL correspondente localizado; rename preservou o mesmo defeito de dependência. O Coordenador pode encaminhar uma correção nominal do consumidor contra o schema/contrato aprovado, com teste que efetivamente alcance G, ou exigir um predecessor verificável se houver fonte externa válida. Eng1 continua dono do manifesto executável. Nenhum bootstrap, bridge, restauração, helper, grant, SQL/Docker, código ou Git foi alterado; só este MD. Memória no-op: não houve decisão durável aprovada.

## F-AUTHOR — correção mínima candidata de G e arquivados, 2026-09-08, 01:09 BRT

**Passo 2/6 | Formulários / distribuição legada | G194209 versus application/schedule/remove_schedule | Engenheiro 2 + três subagentes de leitura | proposta técnica, nenhum código ou SQL alterado.**

Recorte adicional do Coordenador: comparar a validação inválida G:19 com fontes aprovadas e guards privados, propondo a menor correção compatível ou delimitando decisão realmente ausente. Ordem: conhecimento/fonte canônica → comandos efetivos → caminho dos testes → parecer. Fora política nova de soft-delete, DDL, helpers alterados, execução, demais jobs e infraestrutura. Parada: parecer para Eng1/E4/Coordenador; estimativa 5–15 minutos. Código permanece fixado em f6c2/441c5842afec75ee8006fb3236fefbf39f8ae1ef.

**Candidata recomendada:** retirar somente o predicado `and form_record.deleted_at is null` de `app_private.form_assert_distribution_target`. Preservar integralmente existência por form_id, correspondência institution_id, chamada `audit_actor_has_permission(p_actor,'forms.manage',p_institution_id,false)`, erros, assinatura, owner/ACL e search_path. O patch futuro deve ser nominal e forward-only; não editar a migration histórica. Não eliminar G inteiro: os comandos privados não substituem sua autorização por instituição. O hardening194256 continua intacto.

A correção remove uma referência impossível no schema verificado. Como a exclusão elegível existente é física, a verificação de existência continua rejeitando o formulário removido. **Não trocar o predicado por archived_at/status nem estabelecer veto novo para arquivados.** A proposta preserva o comportamento restante dos comandos; não promove uma política operacional de arquivamento a decisão aprovada.

### Fontes aprovadas e limite da decisão

Projeção `docs/knowledge/team/superadmin-forms-production.md`, status validated, :41–47 distingue ciclo persistido e situação operacional: arquivado permanece registro apresentável no diretório. Fonte canônica `docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md`, status approved-design, :298–305 preserva identidade, agendamentos e histórico; :313–314 permite exclusão definitiva apenas do rascunho nunca publicado sem agendamentos/respostas e arquiva os demais. As cláusulas :217–219, :265–274 e :503–507 permitem aplicações/agendamentos sujeitos a autorização e versão.

Essas fontes **não especificam uma matriz de operações após arquivar**: criar/editar aplicação, criar/editar agendamento e remover agendamento. Tampouco resolvem integralmente o efeito de arquivar sobre ocorrências abertas/futuras, respostas e lembretes. O plano UI31/08 local-green não supre decisão de produto. A lacuna deve ser tratada pelo Coordenador se houver intenção de mudar esse comportamento; não justifica inventar filtro global em G nem impede formular a correção estrutural delimitada acima.

### Guards privados que a candidata preserva

| Comando efetivo em F-AUTHOR030000 | Comportamento relevante |
| --- | --- |
| form_save_application:1036–1095 | forms.manage_applications, payload/limites, barreira de draft interno antes do replay, advisory lock/aplicação FOR UPDATE e versão. Não veta Forms/aplicação por status; permite atualizar application.status dentro da constraint. Trigger tenant de Forms155126:79–83 preserva relação real. |
| form_save_schedule:1098–1176 | Mesma capability, payload/fuso, barreira antes do replay, advisory lock de aplicação e schedule FOR UPDATE. Schedule existente precisa estar active, pertencer à aplicação e ter versão esperada. Não exige Forms publicado nem aplicação ativa para salvar configuração. Enfileira generate_occurrences:1169–1171. |
| form_remove_schedule:1179–1211 | Mesma capability, barreira antes do replay, existência/active/versão e lock do schedule. Arquiva schedule e cancela ocorrências scheduled. Não consulta status Forms/aplicação. O wrapper público legado Forms155121:2166–2169 não passa por G; mantê-lo fora da correção deste helper. |

O replay privado valida ator/comando/hash/versão esperada e pode devolver receipt antes dos checks posteriores de estado. Não reposicionar essas verificações neste patch. A barreira de rascunho interno F-AUTHOR nos wrappers continua anterior a G e a efeitos; nenhuma liberação de autoria/distribuição interna decorre da correção.

Salvar configuração não equivale a gerar distribuição efetiva: `form_generate_occurrences` de Forms155124:350–353 exige schedule/aplicação ativos e formulário published com published_version_id para inserir novas ocorrências. Isso **não prova interrupção de todo fluxo ao arquivar**, pois o mesmo corpo atualiza ocorrências existentes em:428–436 sem repetir todos esses filtros. Nenhuma mudança em worker/geração está sendo proposta.

### Teste legado não alcança o ponto que afirma testar

`forms_editor_application_authorization_test.sql:100–118` espera22023 para par formulário/instituição forjado, mas envia application id terminado003 (:106), enquanto o setup:51–72 insere somente001/002. G:51–56 encontra o ID de aplicação inexistente e nega com P0002 antes do helper:64. Portanto esse caso não comprova G:19; remover deleted_at também não corrige sua premissa. Conclusão estática, sem execução. Não reutilizar seu setup com trigger desabilitado: o novo teste de par forjado pode usar somente payload incompatível e linhas estruturais válidas.

Gates para o pacote nominal do writer/executor:

- Reproduzir a referência inválida num caminho que **alcance G**: criação sem application id, com ator e demais precondições válidos; depois provar alvo válido e negativa de par A/B. Teste de application inexistente permanece separado, com erro correspondente.
- Preservar negativas de ator/capability, autorização institucional, formulário fisicamente removido e vínculo schedule→application. Exercitar versões/replay sem transformar sucesso por receipt em prova do lookup que não executou.
- Caracterizar arquivado separadamente do removido: o patch mínimo não acrescenta veto geral de status. Não declarar matriz de arquivados aprovada; eventual nova regra deve ser específica por ação e nominalmente decidida.
- Preservar a negativa de draft interno antes de G/replay e os contratos de schedule active/removal. Asserções sob authenticated com captura e TAP após RESET ROLE; nenhum grant de teste ou desativação de trigger.

**Entrega:** candidato mínimo e decisão de produto delimitados, destinados a Eng1/E4 e Coordenador para reserva/revisão do pacote. Nenhuma implementação, execução, grant, coluna, bridge, alteração histórica ou integração feita pelo Engenheiro2. Apenas este MD foi atualizado; memória no-op por ausência de decisão durável nova.

## Perfis — READ institucional e catálogo global, 2026-09-08, 01:54 BRT

**Passo 1/6, contrato; 2/6, dependências de READ | Perfis | proposta84a42e7b | Engenheiro 2 + três subagentes somente leitura | decisão parcialmente suficiente; uma pergunta de visibilidade delimitada.**

Recorte do Coordenador: confrontar proposta,018/039/ADRs e catálogos/agregações para ator interno scope institution, evitando confundir criação de perfil global com READ. Ordem: proposta integral → fontes aprovadas → consulta efetiva → decisão necessária. Fora SQL/grants/Conta, implementação, testes, revisão de membership_count/contexto/CSV/base1 já reconciliados. Parada: parecer acionável com citações exatas e pergunta mínima, estimativa 5–15 minutos. Fonte: wt3ce0, commit `84a42e7b807114158c640b981f3fe3bd4a5a1ab0`; proposta blob `63c806a084128d7d2ffbb96c1963a96a8ae5e793`, spec018 blob `933b71c2e3fff68aa4c785c98914b3e8a3c4483a`, spec039 blob `b7a0c41645865eb571a51fe542e76c8dc72a1814`.

### O que as fontes já decidem

| Fonte e status | Trecho exato | Implicação no recorte |
| --- | --- | --- |
| specs/018-profiles-permissions-superadmin.md:138, approved-for-implementation | “leitura exige `platform.read`” | READ não exige capacidade de governança por analogia. |
| Spec018:144 | “escopo efetivo nunca excede o máximo do perfil nem o alcance do operador” | A capability não elimina a restrição real de alcance. |
| Spec018:101–103 | “Perfis Admin criados nesta central são bases globais reutilizáveis” | É regra da criação/natureza do perfil; não decide quais definições globais um leitor institucional vê. |
| specs/039-superadmin-internal-auth-session-context.md:145–146, approved-for-implementation | “antes de ler, assinar, escrever, retornar dado ou registrar sucesso” | Revalidar contexto na própria transação também é exigência explícita de READ. |
| Spec039:181–182 | “membership `institution` só resolve `scope_institution_id`” | Instituição de outro recurso não pode ampliar alcance pelo parâmetro. |
| decisions/0019-superadmin-internal-identity.md:21–24, accepted | “Perfil define o teto; vínculo guarda o alcance efetivo.” | Metadados do perfil e autorização operacional do vínculo são conceitos distintos. |
| Design aprovado de Acessos01/09:148–163 | “Aplicativo e alcance são eixos diferentes”; “Superadmin pode administrar os catálogos dos aplicativos inferiores sem que isso conceda acesso operacional fora dos vínculos atribuídos.” | Aplicativo/domínio do perfil não representa a instituição autorizada do leitor. |
| Mesmo design:226–227, approved-for-implementation | “leitura e escrita confinadas por tenant, instituição, unidade, turma, criança e vínculo real” | Dados de uso/atribuições de B não entram na resposta autorizada apenas para A. |

A projeção validated `docs/knowledge/team/superadmin-access-profiles.md:43–51` e `docs/security/auth-multitenant-permissions.md:552–558` limitam **comandos de governança/mutações** a membership global com os grants respectivos. Esse texto não justifica negar toda leitura institucional. ADR0017:25–33 também distingue teto/vínculo e governança, sem fornecer uma matriz de visibilidade de definições globais. As regras temporárias de AAL do realm interno permanecem como já reconciliadas; não reabrir MFA por citações históricas.

### Catálogo visível e agregado autorizado são problemas diferentes

O cursor legado `20260811215451_access_profile_management_v2.sql:476–485` lista todos os institution_roles e conta assignments ativos/válidos por role_id, sem instituição. Um mesmo perfil global com institution_id NULL pode ter atribuições em A e B sob constraints válidas: `20260729144440_profiles_permissions_governance.sql:116–125` exige coincidência institucional do papel somente quando seu institution_id não é NULL. Logo, **filtrar só as linhas de perfis para global/local A ainda permite que o count do perfil global some B**.

A instituição real do assignment deriva de `institution_memberships.institution_id`, alcançada pelo membership_id; essa relação estrutural pode delimitar o agregado sem acrescentar People/Auth ou mudar o significado de atribuições ativas reconciliado. O filtro p_scope compara max_scope_kind e não substitui autorização institucional. Perfil local B e dados de uso de B permanecem fora do alcance de A; esse limite decorre das fontes, não depende de uma decisão para permitir vazamento de agregado.

Preservados integralmente: membership_count, origem de cada contador por domínio, ausência de exigência de auth-link no contador interno global, contexto/domínio, payload cru/42501, CSV e base1. O ramo do **ator global** continua reconciliado. A revisão não propõe alterar nomes, fórmulas globais ou protocolo do consumidor.

### Única decisão de visibilidade ainda não localizada

As fontes examinadas não dizem se um leitor interno institucional pode enumerar **todas as definições globais de perfis**, inclusive as sem uso na sua instituição, ou se sua seleção deve se limitar a perfis utilizados ali. “Bases globais reutilizáveis” e “Superadmin pode administrar catálogos” descrevem o modelo/capacidade da superfície, mas não vinculam expressamente essa seleção de linhas à membership institution. O SQL legado sob autoridade global não serve como precedente de autorização para esse novo ator.

Pergunta mínima ao Owner via Coordenador: **“Para um usuário interno restrito à instituição A com platform.read, o diretório de Perfis deve mostrar também todas as definições globais, mesmo sem atribuição em A, mantendo os perfis locais e todos os dados de uso limitados a A?”**

Essa pergunta não reabre os contadores já definidos nem pergunta se pode expor B. Também não inclui Conta, Principal ou catálogo detalhado de permissões fora deste list. Não transformar a ausência dessa resposta numa negação permanente de todo READ institucional. O recorte já definido para ator global pode continuar na preparação autorizada; a seleção de globais para ator institucional precisa dessa decisão específica antes de fixar suas expectativas de SQL.

**Parecer:** a alegação de lacuna ampla da proposta pode ser reduzida: capability, revalidação e isolamento de dados de uso estão decididos. A pergunta restante é somente a visibilidade das definições globais sem uso institucional. Nenhum código, SQL, grant, Conta, teste ou perfil foi alterado. Memória no-op: a pergunta permanece proposta no MD operacional, sem nova regra publicada como aprovada.

### Atualização recebida — AG-READ01

Eng1 informou que a closure53 candidata foi aplicada integralmente no replay nominal: enum Auth real e catálogo/audit14 com10/10 PASS; fixturea3b com114 TAP,21 PASS/93 FAIL, sem aborto, sendo a ausência das três RPCs v2 os primeiros gates. Cleanup nominal zero em2026-09-08 04:48:47UTC (01:48:47BRT). Não foram necessárias adições improvisadas. É relato do executor recebido nesta tarefa, não execução/revalidação pelo Eng2; ele explicitou baseCLI+catálogo, sem consulta independente de ledger. E2E5 recebeu o resultado para próxima reserva; não é E2EFlutter. Não repetir inventário concluído ou testes; encaminhar eventual parecer apenas à coordenação.

## F-AUTHOR — revisão nominal do preflight vazio, 02:23 BRT

**Contrato:** revisão integral do script, testes e evidência de preparação no commit `76ab008dbab03335f359d356864455b0e38613ea`, sob solicitação concreta do Coordenador. Incluídos ownership, endpoint Docker local, base vazia, cron off persistente na mesma instância, cleanup e duração das chamadas nativas. Fora do escopo: closure64, execução Docker/SQL/Pester, correção de código e contratos já aprovados. Ordem: script completo → testes/evidência → três fatias independentes de leitura → parecer consolidado. Parada: entregar achados acionáveis ao Coordenador, mantendo Eng1 como operador exclusivo. Estimativa do recorte: 10–15 minutos. Evidência esperada: âncoras nominais e limites explícitos da verificação estática.

Fontes locais lidas integralmente na worktree `.worktrees/e1-replay-harness`: `packages/coelo_database/scripts/Invoke-FormsAuthoringRuntimePreflight.ps1` (459 linhas), `packages/coelo_database/scripts/tests/FormsAuthoringRuntimePreflight.Tests.ps1` (422 linhas) e `docs/reviews/evidence/etapa-2/engenheiro-1/forms-authoring-runtime-preflight-preparation-2026-09-08.md` (111 linhas). HEAD avançou para `cb416a6b6c37697466a653c11ba85418a9d16d39`; diff dos três arquivos contra o nominal e status restrito vieram vazios. As conclusões permanecem sobre o pacote solicitado. Subagentes de leitura: `a01_foundation_replay` (ownership/endpoint), `a01_contract_assertions` (processos/cleanup), `a01_fixture_auth` (catálogo/cron/atividade).

### P1 — chamada nativa sem limite pode impedir cleanup e reter o lease

O wrapper nas linhas 117–133 usa chamadas síncronas `npx.cmd` (124) e `docker` (128), sem timeout/cancelamento. Se start, inspect, exec/psql ou restart não retornar, a execução não chega ao finally principal. Se o travamento ocorrer no stop (420) ou na inspeção residual (426), o próprio finally fica bloqueado antes de ReleaseMutex/Dispose (438–439). O mutex permanece ocupado enquanto o processo proprietário viver; não se afirma retenção depois da morte do processo. Recursos nominais podem permanecer ativos sem um resultado final que comprove cleanup.

`health_timeout=2m`, `restart --time 10`, `pg_isready -t 1` e as 60 tentativas não limitam a espera pelo processo CLI/Docker. A frase da evidência de preparação de que o mutex é sempre liberado precisa dessa condição de retorno. O risco é operacional concreto para o lease compartilhado e o checkpoint, mesmo sendo uma stack vazia; não implica que houve travamento ou atividade externa nesta revisão.

**Menor encaminhamento:** limitar a duração de cada chamada nativa, inclusive cleanup, com encerramento somente da árvore de processos criada por ela, output bruto suprimido e falha explícita quando a terminação não puder ser comprovada. Liberação/dispose devem ficar em finally externo ao cleanup. Isso não exige um deadline global da operação nem alteração da closure. Preservar TEMP e `Cleanup=unproven` quando stop/inspeção não puderem comprovar zero. O teste útil é um processo fake que nunca termina em start e em stop, conferindo retorno limitado, ausência de filhos órfãos e liberação do lease. Os mocks atuais substituem toda a fronteira nativa (testes:52) e sono/mutex (44–51); simular código de saída ruim não cobre processo travado.

### Alcance do guard local — daemon confirmado, binding da porta não comprovado

O guard 139–149 rejeita endpoint remoto e exige named pipe Windows, fixando o nome do contexto nas chamadas Docker. Isso é coerente para selecionar um daemon local. Escolher o número da porta usando TcpListener Loopback (16–19) não garante que o banco seja publicado exclusivamente em loopback, pois o listener é fechado; a inspeção 172–186 não inclui PortBindings/NetworkSettings.Ports. A configuração efetiva de rede/daemon não foi inspecionada nesta revisão.

O [CLI 2.116.0, postgres.service.ts:415](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/postgres.service.ts#L415) fornece hostPort e containerPort sem IP do host. O [Docker documenta](https://docs.docker.com/engine/network/port-publishing/#setting-the-default-bind-address-for-containers) que publicar sem endereço específico usa todas as interfaces por padrão, podendo esse padrão ser configurado. Portanto, **não há prova de exposição real, nem prova de loopback exclusivo**. Se o contrato operacional exigir esse isolamento adicional, cabe garantir a publicação local antes do start e verificar o binding efetivo. Não propor mudança global do daemon como correção automática. Esta observação não redefine por si só o gate de endpoint local já solicitado.

### Gates estáticos coerentes e limites do parecer

- Identidade aleatória inédita, ausência prévia de recursos por nome/label, filho imediato de TEMP, marker/config literais, árvore sem reparse e migrations vazias: guards coerentes (40–110, 152–169).
- Container por nome/ID/label/workdir/imagem oficial; exatamente um volume e uma rede nominais; ALTER e restart pelo ID observado; comparação de ID, imagem/digests, volume/rede e timestamps depois: coerentes (171–202, 389–410).
- SQL fixo de catálogo/contagens e uma única mutação autônoma `ALTER SYSTEM SET cron.launch_active_jobs = 'off'` (205–258). Zero tabelas de aplicação e ledger ausente ou zero; extensão não instalada preserva NULL e não consulta tabela ausente. Jobs/runs/requests/responses devem ser zero quando disponíveis, antes e depois (288–362).
- Cron após restart exige setting/reset_val off, fonte de configuração, pending_restart false, zero erros e uma entrada aplicada off de postgresql.auto.conf, além de novos timestamps na mesma instância (352–360, 403–410).
- Para chamadas que retornam, cleanup separa stop de inspeção residual; TEMP só é removido com ownership, stop e recursos zerados. Falhas não viram PASS (413–451). A ressalva P1 impede afirmar encerramento garantido.

**Parecer nominal:** devolver P1 antes da liberação operacional, sem reabrir contratos aprovados ou ampliar para 64 migrations. Fora desse achado, nenhum novo bloqueador estático identificado nos guards examinados. Os 62/62 PASS são evidência relatada pelo Eng1 com fronteira mockada; não foram reexecutados aqui e não provam runtime real. As contagens representam snapshots observados, não histórico universal de ausência de atividade. Nenhum script, teste, Docker ou SQL executado por Eng2/subagentes. Nenhum código/Git/rastreador alterado. Memória no-op: somente evidência operacional, sem nova decisão de produto.

## F-AUTHOR03 — invariantes e decisão administrativa, 02:32 BRT

**Contrato:** atender ao recorte do Coordenador sobre `8cde3915f7ce6ac680e9ba388313cb85ce20c4d6`. Incluídos crosswalk integral, reparos G/proveniência/XOR/identidade de ator e receipt, capacidades efetivas e limite administrativo após publicar. Fora de escopo: implementação, publicação real, autoria02, mudanças de grants, triggers desativados, workers/respondentes e contratos já reconciliados. Ordem: crosswalk → fontes aprovadas/matriz01 → corpos SQL efetivos → três revisões de leitura → menor pacote e pergunta restante. Critério de parada: parecer acionável apenas ao Coordenador. Estimativa: 10–15 minutos. Nenhum código, SQL, teste, Docker ou rastreador alterado/executado.

Fonte nominal: `docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-08-publish-distribution-nominal-crosswalk.md`, 118 linhas, blob `6263fa4c5ffb9c106c415c2c0b16077f1f3e1de7`. Worktree E4 `C:/Users/adrie/.codex/worktrees/f6c2/Coelo`; status restrito e diff do crosswalk/pacote01 contra o commit nominal vazios. Pacote01 `20260908030000_superadmin_internal_form_drafts_v2.sql`, blob `3c6fcfe072a38a35f79dad22c482c3ccc22794ad`; trigger `20260813155126_forms_security_performance_closure.sql`, blob `658e88a86023366e5c011dd3380d27fa50c67e5d`; G `20260901194209_forms_distribution_target_authorization.sql`, blob `2b80366b10f095d4b8ba3971e655cecf8f462340`. Conferidos ADR0019 accepted, spec039, design Forms13/08 approved-design, conhecimento Forms validated e matriz01 de coexistência já fechada. Subagentes: foundation (ator/XOR/receipts), assertions (trigger/proveniência), fixture (capacidades/coexistência).

### Menor pacote corretivo agora: dois corpos de função, sem habilitar publicação

1. **G:** remover somente `and form_record.deleted_at is null` do helper `form_assert_distribution_target`, conforme parecer anterior. Preservar IDs e relação form/institution, checagem efetiva de forms.manage, erros, assinatura/owner/search_path/ACL e wrappers atuais. Não acrescentar status ou archived_at, coluna sintética, bypass ou nova regra de arquivamento. O controle positivo precisa alcançar G; aplicação inexistente retorna P0002 antes dele. A análise de proveniência já encerrada não foi repetida.
2. **Proveniência de form_versions:** republicar forward-only somente `block_published_form_definition_mutation`, comparando `created_by_person_id` e `created_by_internal_identity_id` com `IS DISTINCT FROM`. Preservar os outros campos, transições, triggers, proteções de estrutura publicada e grants. A versão01 tornou People nullable e acrescentou FK interna/XOR (030000:41–44); o trigger anterior ainda usa People `<>` e omite a coluna interna (55126:13–21). Trocar interno A→B ou alternar People↔interno durante working→published ou published→superseded mantém XOR/FKs válidos, mas pode deixar a expressão do IF em NULL e passar sem raise. Isso viola a proveniência já protegida, não exige inventar regra de produto.

**REDs úteis:** alterações de creator durante uma transição permitida, com as duas identidades válidas e XOR satisfeito; controles das mesmas transições preservando o creator em cada realm. UPDATE isolado de autor sem transição já falha pelo estado e não comprova o reparo. Distinguir o teste estrutural do trigger de uma prova de autorização da RPC. Regressões existentes de conteúdo publicado, exclusão e transição permanecem; sem desativar trigger para produzir a premissa. Eng1 reserva/executa o futuro replay; não há SQL escrito nesta proposta.

Essa corretiva pode ser preparada sem esperar a decisão de coexistência. Mantém a barreira draft-only01, o cliente02, receipts, enum e capabilities existentes. Nomes/timestamp da migration pertencem à reserva central; não foram inventados. Não acrescentar correções de todos os writers legados a esse pacote mínimo.

### Invariantes técnicas obrigatórias no futuro comando interno

ADR0019:18–24/44–49 e spec039:78–81 separam identidade/credencial/escopo interno de People. O publish legado em 030000:736 resolve People, usa `form_begin_command` People (745–746), escreve updater People (772) e auditoria People (782–787). Receipt legado exige FK People em 155121:1–8. Nenhum desses caminhos deve ser adaptado mediante People artificial, fallback de realm ou helper global permissivo.

O XOR do updater é um **risco latente da evolução**, não um caminho nominal atual reproduzido: o guard bloqueia rascunho interno antes do receipt (744/751); o save interno já escreve autoria interna e limpa updater People (1726–1742). Se uma evolução habilitar o publish legado sobre recurso com updater interno sem mudar a escrita, ambos ficam não nulos e a constraint falha. O comando interno futuro deve preservar os criadores existentes e registrar o ator atual interno no updater, limpando o par People; nova working version recebe o creator real de quem a criou. Se a política futura admitir escritores People no mesmo recurso, seus writes também precisam satisfazer XOR. Esse trabalho pertence à fronteira aprovada futura, não justifica abrir agora todos os writers.

O receipt draft01 (030000:49–57/1678–1722) vincula request, ator interno, instituição, recurso, expected_version, hash e snapshot original; seu gate de estado é draft-only e não possui discriminador de comando. Não colocar publish silenciosamente nessa tabela/semântica. Um receipt próprio de publicação com identidade interna real, idempotência e reautorização é fechamento de engenharia/coordenação; seu nome ou armazenamento não são, por si, perguntas de produto. Preservar receipts01 e seu snapshot. No futuro replay de publish, reautorizar estado/alcance atuais, mas não exigir novamente working_version: a primeira publicação já limpa esse campo (769), e copiá-lo como pré-condição de replay quebraria a idempotência. O resultado reaplicado permanece o original, não uma projeção posterior.

Congelamento da publicação, nova working version após edição, identidade/agendas estáveis e preservação de ocorrências abertas/concluídas estão decididos (design13/08:298–305; conhecimento:17–22). Primeira publicação e republicação precisam respeitar isso; não são novas opções para o Owner. Da mesma forma, sessão/escopo/capacidade reais, rechecagem após espera/locks, auditoria obrigatória e rollback não são opcionais.

### Capacidades: compatibilidade precisa por operação

O design13/08:470–473 e catálogo 155005:391–393 distinguem read/manage/publish/manage_applications. Publish atual exige forms.publish (030000:736), sem implicar grant de manage/read. Saves de application/schedule exigem manage_applications no comando privado e forms.manage em G; **remove_schedule exige manage_applications e não passa por G** (030000:1187–1206). Portanto, a linha45 do crosswalk não deve generalizar a conjunção para toda operação de agenda.

Preservar essa conjunção efetiva nos saves é compatibilidade, não requer nova decisão Owner nem concede manage implicitamente. Reduzi-la para somente manage_applications amplia o acesso atual e requer decisão explícita; não se apresenta a conjunção encontrada no código como regra de produto aprovada. Não reabrir catálogo inteiro nem alterar grants de negócio neste recorte.

### Única decisão de produto indispensável antes de habilitar publish

A matriz01:65–70 e o predicado 030000:70–72 protegem somente rascunhos internos nunca publicados. Publicar sai da condição; voltar a draft não restaura first_published_at nulo. O design13/08:63–64 prevê Admin como gestor/respondente, mas não fecha a coexistência das portas administrativas legadas para o recurso que nasce no realm interno. Não deixar esse efeito técnico decidir o produto silenciosamente.

**Pergunta mínima ao Owner, via Coordenador:** depois da primeira publicação de um formulário criado pelo realm interno, gestores institucionais People com capacidades e escopo válidos poderão administrar o mesmo recurso, ou sua gestão permanecerá nos endpoints internos?

A resposta precisa materializar uma fronteira administrativa explícita por recurso/escopo, cobrindo portas de listagem/ID/replay e operações indiretas antes de habilitar a primeira publicação. Não usar autoria como atalho permanente de autorização, não revogar grants globalmente e não bloquear a audiência legítima. Responder já depende de elegibilidade real (design:241–245/485); autoria interna não concede participação ao usuário039 nem retira acesso de respondentes elegíveis. A publicação não inclui alteração de workers ou abertura de Admin/Principal nesta etapa.

**Parecer:** G + trigger podem avançar como menor corretiva nominal forward-only, sem aguardar nova política. Depois do fechamento administrativo, preparar um pacote03 separado de publish/reader compatível/receipts/versionamento; aplicações e agendas nominais vêm em etapa própria, preservando a matriz efetiva de capacidades salvo decisão explícita. Autoria02 permanece intacta. Nenhum teste executado ou aprovação E2E inferida. Memória no-op: os reparos preservam invariantes existentes e a pergunta ainda não virou decisão aprovada.

## LOC — fechamento exato de locations no helper remoto #4, 02:40 BRT

**Contrato:** revisão da proposta E2 autorizada pelo Coordenador enquanto se aguarda o patch de timeout F-AUTHOR. Incluídos somente helper #4, pins/proveniência, retirada exata do bloco locations e preservação de OR NULL/ausência de students. #6 considerado apenas para distinguir EOL e ordem dos gates. Fora de escopo: restante LOC, CHILD, novos acessos remotos, execução de SQL/regex/PostgreSQL/testes/Docker, edição de candidato e grants. Ordem: evidências integrais → candidato nominal → fontes de origem → provas faltantes → parecer. Critério de parada: desenho mínimo e gates acionáveis ao Coordenador. Estimativa: 10 minutos. Duas revisões independentes de leitura: assertions (transformação) e foundation (pins/snapshot).

E2E2 `E2E 2 — Estruturas, Pessoas e Locais` foi consultada por read_thread; os turnos recentes não retornaram conteúdo, portanto não serviram de evidência técnica. Fonte material na worktree3811: commit `25cd74a97e22af6685ae91a0abb213febff3b173`, documentos integrais `2026-09-08-location-fingerprint-provenance.md` e `2026-09-08-location-remote-canonical-comparison.json` em `docs/reviews/evidence/etapa-2/estruturas/`. Hashes de arquivo lidos: `684fe63cea299e123c6aff45d7864fcc59ccb2e2` e `db08c48b7c6e557bbd0a2ea523cbee8dea4aa09a`. Candidato nominal `20260908031000_superadmin_location_catalog_v2.sql`, blob Git `8d26581692ff78db923de98d7c788257857fbbdb`. Ao final apareceu WIP concorrente nesse SQL (15 inclusões/3 exclusões), separado do snapshot revisado; **este parecer não aprova esse WIP**.

### Diagnóstico suficiente; pacote executável ainda não apresentado

A evidência E2 relata consulta de catálogo remoto autorizada em 05:28:22Z, sem dados de negócio, e compara o resultado ao Auth47 nominal do Eng1 `d119cef32661d066f005d8e6c49a589e8129026f`. Não foi repetida consulta remota nem executada função nesta revisão.

| Helper #4 | MD5 definição raw | MD5 CRLF→LF |
| --- | --- | --- |
| Remoto registrado / pin LOC | 65fe6408f0f2c6b0c1c9d71a809f2d80 | 516a06602a96073317e495dbb9d5b040 |
| Auth47 / canônico | 70700ddc38d42df4fae75765b7ff2617 | b951e603ef34b7d26597356a16eb6d06 |

Logo, #4 não é somente EOL. A definição remota registrada usa `(p_institution_id is null OR ...=p_institution_id)` em units/locations/groups/professionals e não possui students. A fonte canônica exige instituição não nula e contém students com projeção infantil. A origem/aprovação do delta remoto não foi comprovada por esses anexos; preservá-lo fora do cutover LOC evita alteração incidental, sem promover todo o comportamento observado a política aprovada.

LOC31000:519 exige literalmente `and location.institution_id=p_institution_id and location.status='active'`. O trecho remoto documentado termina em `or location.institution_id=p_institution_id) and ...`. A incompatibilidade é verificável por leitura; a contagem offline relatada pela E2 não é execução da regex PostgreSQL. Trocar o pin #4 pelo hash Auth47 aceitaria outro contrato e não resolveria a transformação do remoto.

### Menor transformação e provas exigidas

**Aprovação da direção da proposta:** retirar somente a expressão locations da definição remota nominal, substituindo-a por `'locations','[]'::jsonb`. Não alterar os OR NULL de units/groups/professionals, o guard activities.read, institutions, taxonomy/templates, assinatura, owner, configuração ou ACL. A ausência de students significa **chave ausente**, não students=[]; também não aceitar a versão canônica com essa seção. Não transformar regex em alternativa genérica que aceite ambos os contratos.

Para tornar essa proposta revisável/executável, ainda faltam:

1. **Snapshot completo #4**, obtido da definição remota já observada, com bytes/EOL e hash do artefato. A evidência diz que o corpo completo ficou somente em memória; diff sanitizado e hashes bastam para o diagnóstico, mas não permitem certificar o bloco integral nem um pin de saída. Não reconstruir a fonte canônica com o diff e chamá-la de snapshot observado. Qualquer normalização deve ser explicitamente nominal e gerar novos pins identificados.
2. **Fixture local separada:** entrada Auth47 conhecida → snapshot #4 com pós-condição exata. Preservar signature, postgres owner, SECURITY DEFINER, stable, search_path vazio e ACL nominal. Owner merece comparação explícita: o preflight atual exclui o proprietário ao comparar ACL (90–93), e pg_get_functiondef não fixa por si essa propriedade. Não reescrever migration histórica ou executar no remoto.
3. **Patch congelado com diff mínimo:** uma ocorrência do bloco completo revisado, prefixo/sufixo fora dele intactos, hash de saída previamente revisado, ausência de referência public.activity_locations e metadata/ACL preservados. Contar um match e não encontrar a tabela depois são gates úteis, mas sozinhos não provam preservação das outras seções.
4. **Prova funcional local futura:** alcançar o wrapper autorizado sobre a mesma fixture antes/depois, com instituição nula e explícita; locations=[]; demais chaves/valores equivalentes ao snapshot; students ausente. Dados sintéticos elegíveis em duas instituições evitam que arrays vazios escondam troca OR→AND. Nada de grants amplos ou consulta a linhas remotas para essa prova. O teste atual LOC em `superadmin_location_catalog_v2_test.sql:70–71` apenas procura ausência textual de public.activity_locations; não prova OR NULL ou formato completo de payload.

### Ordem dos REDs e separação de #6

No Auth47, o primeiro fingerprint divergente é #4. Após instalar somente o snapshot remoto #4, o candidato original ainda encontra #6 raw divergente. A regex de #4 é uma barreira posterior. Contraprovas devem identificar seu primeiro bloqueio; uma execução que para antes não prova as demais negativas. Não mascarar esses REDs alterando pins para o estado mais conveniente.

Para #6, os anexos registram igualdade LF remoto/local `3167d90039df952c9ae561f28486223c`; isso sustenta tratar somente CRLF→LF nessa assinatura, preservando os outros gates. Não generalizar essa equivalência para #4, não fazer trim ou normalização global. Nenhum ensaio foi repetido nesta tarefa.

**Parecer final do recorte:** proposta de fechamento exato está coerente e preserva a fronteira solicitada; falta o snapshot integral e o patch nominal para aprovação estática executável. Encaminhar esses artefatos ao review conjunto E2/E5/coordenação antes do replay exclusivo do Eng1. O WIP concorrente não foi revisado. Nenhuma nova decisão Owner é necessária para preservar OR NULL/ausência de students durante esse cutover; alterá-los exige recorte separado, pois muda o contrato legado fora de LOC. Nenhuma execução, alteração de código/Git/rastreador ou conclusão GREEN/E2E. Memória no-op: evidência operacional de drift, sem regra nova aprovada.

### Atualizações recebidas de gates anteriores

Follow-up A01 `e927c417fd79a6b879e2e61538ec02cffc067db2`: conferido somente o delta da condição EXECUTE levantada aqui. Resultados das RPCs e current_user são capturados como authenticated, inclusive AAL1 e ausência de claims; TAP é emitido depois de RESET ROLE. Resolve esse ponto sem grant amplo em extensão/domínio. Checkpoint central22:15 atualiza: replay54 do Eng1 iniciado22:10:28 aplicou a base, fixture89 terminou47FAIL/42PASS, sem aborto/erroACL; cleanup22:13:47 com recursos nominais zero. Corretiva20260907222911 reservada à E2E5, seguida de review/hash e futuro GREEN serial. Não foi executada nem recontada a suíte nesta tarefa. NAV foi integrado como0269a2fb e compôs249/249 testes no destino segundo o checkpoint central de22:01; não são execuções do Engenheiro2.

## Gates ainda abertos

Revisão N01 cliente em 2026-09-07, 20:54 BRT: objetivo restrito aos commits `76b9b121a4a3501ea635121eacc541d0ec0d62e0` e `c1e42c6a2f8aba178930dc94f83fe4c826af826f` da worktree a9f2. Ordem: delta → contrato SQL existente → controller/retry → adapter/feedback → testes/evidência. Parada: parecer acionável do pacote, sem declarar job ou E2E concluído. Pendências conhecidas: geração/materializador N01, reautorização de edição scheduled e worker, replay SQL real, auditoria e goldens. Esses gates não são executados nesta revisão. Após o aviso de reinício, HEAD e WIP foram conferidos, e os três subagentes de leitura foram recriados porque os anteriores já não constavam da equipe ativa. A E2E2 permanece writer único de NAV-LOGOUT01; nenhum novo probe/patch foi executado aqui.

N01 exige quatro pré-requisitos nominais: 20260812002900, 20260812003000, 20260820212340 e 20260820220500. A cadeia move notice_events para analytics, mas consumidores posteriores ainda exigem tabela public; um alias por view não atende ALTER TABLE/FK. Não foi encontrado snapshot completo comprovadamente equivalente. A análise compara snapshot predecessor verificável e preflights estritamente locais, sem alterar histórico nem presumir bug remoto. Labels mantêm NOT NULL: ordenar pré-requisitos antigos não resolve o INSERT v2 após a limpeza de defaults. Engenheiro 1 detém Docker, harness, RED e lease.

Há precedente de auditoria de sistema v1: `20260827233000_superadmin_internal_auth_context.sql:493–503` preserva correlação e identifica como system evento sem pessoa. Isso permite estudar conclusão assíncrona correlacionada ao evento humano interno v2, sem fabricar sessão ou pessoa; não configura aprovação automática do futuro patch. O threat model de Avisos:23 exige recalcular autorização no comando e no worker.

- Banco: somente arquivos SQL lidos; nenhuma consulta SQL local ou de produção, DML, migration, Docker ou deploy executado por esta revisão.
- Testes: A01/N01/M02, MED-STALE e o follow-up NAV mantêm revisão estática nesta tarefa. D01-UI teve duas reproduções diagnósticas limitadas pelo Engenheiro 2, interrompidas após captura. GREEN de NAV é relatado pelo writer, sem nova execução aqui. Subagentes não executaram testes.
- Código/Git: nenhuma alteração de código, stage ou commit pelo Engenheiro 2; worktree A01 pertence à E2E5 e N01 à E2E3.
- Marcos 4–6: não concluídos por esta revisão. MED-STALE é um achado entregue, não uma correção validada.
- Memória de conhecimento: sem nova decisão durável aprovada; projeção `docs/knowledge` não alterada. Este arquivo registra evidência operacional, não substitui fonte canônica ou rastreador central.
- Continuidade: manter os recortes úteis até 2026-09-08 03:20 BRT, com parada segura e consolidação pelo Coordenador. Atualizar este plano conforme artefatos e evidências reais forem recebidos.
