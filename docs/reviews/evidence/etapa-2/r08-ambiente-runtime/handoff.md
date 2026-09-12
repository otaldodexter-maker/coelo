---
title: "R08 G0 — Ambiente e runtime"
source: "Execução local da R08 e docs/reviews/etapa-2-operacao/next-round/R08-prompts.md"
status: "handoff"
generated_at: "2026-09-12T11:08:00-03:00"
---

# R08 G0 — Ambiente e runtime

## Recorte e resultado

Recorte exclusivo de ambiente local, espelho Supabase preservado e scripts QA existentes. Nenhuma feature, router, composição, tracker central ou delta de estado foi alterado.

- Docker Desktop/WSL: recuperado sem factory reset, reinício do Windows, remoção de volume ou recriação de VHDX.
- Espelho `supabase_db_coelo_baseline`: saudável em `127.0.0.1:57322`, com volume nomeado preservado.
- Build QA: concluído em modo release a partir de `af99409cf5bb266b4be96647690abde44ace8f23`.
- Servidor: ativo em `127.0.0.1:3014`, PID `14724`.
- Navegador compartilhado: aba Chrome mantida aberta, mas a automação CUA não atualizou o controller dos campos Flutter. Login, leitura autorizada e persistência após reload **não foram comprovados**.

## Docker Desktop e WSL

Estado inicial:

- cliente Docker `29.7.2` disponível;
- named pipe `dockerDesktopLinuxEngine` ausente;
- distribuição `docker-desktop` parada;
- `WslService` ativa e serviço `com.docker.service` parado/manual;
- nenhum processo Docker Desktop ativo.

Os logs do backend registravam aborto de inicialização por processo residual: PID `6984` (`Docker Desktop.exe`). O próprio Docker tentou `taskkill`, recebeu que o processo não existia e terminou com `lingering processes detected at startup`.

Primeira tentativa preservadora:

```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden
```

O daemon respondeu aproximadamente 28 segundos depois. Estado medido em 2026-09-12 11:07 BRT:

```text
SERVER=29.7.2 CLIENT=29.7.2
supabase_db_coelo_baseline: running / healthy / restart unless-stopped
5432/tcp -> 0.0.0.0:57322
volume: supabase_db_coelo_baseline -> /var/lib/postgresql/data
```

Preservação observada:

```text
C:\Users\adrie\AppData\Local\Docker\wsl\disk\docker_data.vhdx
bytes: 34184626176
```

O VHDX continuou montado e sendo atualizado pelo daemon. Não houve segunda tentativa porque a primeira recuperou o serviço.

## Espelho baseline e ordem real

O ledger `supabase_migrations.schema_migrations` contém apenas `20260910000000 | baseline_producao`. Esse ledger não representa a sequência realmente carregada: o espelho preservado foi montado historicamente com migrations encaminhadas diretamente por `psql`, sem inclusão automática no ledger.

Uma tentativa inicial de replay cego reaplicou somente os dois primeiros arquivos idempotentes e parou no terceiro, corretamente, com `daily routine foundation already present`. Nenhum reset foi executado.

Depois da interrupção, a paridade foi conferida por objetos e corpos SQL representativos do fim da fila. O espelho contém:

- lote 52: correção de escopo HOT;
- lote 54: `canonical_handle` de atividades;
- lote 54: `next_version_number` de formulários;
- lote 54: `public.superadmin_people_identity_lookup_v1(text,text,uuid,uuid)`;
- lote 55: sincronização de papéis;
- lote 55: regra de escopo com `jsonb_typeof`;
- lote 55: função do worker de usuário interno.

Contagens observadas: `1232` funções e `335` tabelas nos schemas `public`, `app_private`, `audit` e `analytics`. A fonte serializada contém 156 migrations nos lotes 1–55, e todos os arquivos referenciados estavam presentes. Conclusão operacional: o espelho preservado está materializado até o lote 55; o ledger isolado não deve ser usado para decidir replay. O lote 56 continua reservado ao C0 e nenhum banco linked foi acessado ou resetado.

## Build QA e servidor

O `.env.local` foi copiado mecanicamente do backup local autorizado e permaneceu ignorado pelo Git. O SHA-256 do arquivo foi comparado, sem imprimir valores: `24152d9c513447ed049a79c8d8ea78e40678be21b89d48aef2c8bcb8f79f5d5a`.

Comando executado em `apps/superadmin`:

```powershell
flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local
```

Resultado: exit code 0 em 74,1 s, Flutter `3.44.2`, Dart `3.12.2`.

```text
build/web/main.dart.js
bytes: 8339145
sha256: 4ca0e74024f379b451b78fb36daeca2a09a29445474eacf938266005845e4bf1
```

Servidor SPA existente reutilizado:

```powershell
python docs/reviews/evidence/etapa-2/r04-principal-chat-sistema/ferramentas/serve.py apps/superadmin/build/web 3014 127.0.0.1
```

Recursos entregues:

```text
PID: 14724
http://127.0.0.1:3014/login -> HTTP 200, 1020 bytes
http://127.0.0.1:3014/flutter_bootstrap.js -> HTTP 200, 9975 bytes
```

Esses HTTP 200 provam somente a entrega dos artefatos, não o login.

## Chrome e bloqueio de E2E

Foi criada uma única aba compartilhada pelo mecanismo documentado CUA:

```text
browser: Chrome por extensão
session name: 🧪 Coelo G0
provider tab id: 829822454
URL: http://127.0.0.1:3014/login
processo raiz Chrome reutilizado: 22592
renderers criados no intervalo: 41024 e 4624
```

A integração por extensão reutiliza o Chrome já aberto e não expõe um PID exclusivo por aba; por isso os renderers são candidatos observados, não uma associação afirmada.

Com a identidade QA autorizada carregada somente em memória, sem registrar valores, foram tentadas três formas documentadas e materialmente distintas:

1. `setValue` nos campos acessíveis;
2. foco do campo seguido de `paste`;
3. foco, `Control+A` e `typeText`.

Nas três, o submit retornou `Informe seu e-mail.`. Os campos visuais permaneceram vazios e nenhuma chamada de autenticação foi transmitida. A captura sanitizada está em [login-runtime-bloqueado.png](./login-runtime-bloqueado.png).

Por orientação do C0, não foi aberto caminho alternativo de CDP nem outro navegador. A aba foi marcada para handoff e não houve logout. Próximo gate: um executor com digitação Flutter funcional ou CDP já autorizado deve reutilizar o servidor 3014, executar o login, abrir uma leitura autorizada e provar que o estado permanece após reload.

## Estado de entrega

- Pronto para uso: Docker Desktop, baseline 57322, build QA e servidor 3014.
- Bloqueado com diagnóstico: login/leitura/reload pelo Chrome compartilhado CUA.
- Não executado: reset, factory reset, reboot, acesso destrutivo/linked, credenciais em log, testes Flutter ou deltas de estado.
- Recursos intencionalmente mantidos: daemon Docker, containers baseline, servidor PID `16248` e aba Chrome `829822454`.

## Gate adicional solicitado pelo C0: ACL compartilhada e lote 56

Depois da primeira entrega, o C0 atribuiu o gate SQL local adicional. G5 identificou as suítes e definições finais em `76aed97cb`; G0 executou no mesmo baseline, sem aplicar migrations e sem cleanup externo.

Ordem e resultado em [pgtap-acl-shared-20260912.log](./pgtap-acl-shared-20260912.log):

| Ordem | Suíte | Resultado | Exit nativo |
| ---: | --- | ---: | ---: |
| 1 | `principal_internal_actor_bridge_v1_test.sql` | 22/22 | 0 |
| 2 | `internal_actor_scope_root_v1_test.sql` | 46/46 | 0 |
| 3 | `internal_actor_scope_root_v1_hotfix_test.sql` | 4/4 | 0 |
| 4 | `internal_actor_institution_access_by_role_v1_test.sql` | 16/16 | 0 |

Wrapper: exit 0. Cada suíte abriu transação própria e terminou em rollback. Os 88 testes provam a ponte people-based, escopo platform/institution, negação cross-tenant, reativação restrita do hotfix, idempotência, troca/revogação de papéis, Owner → `institution_admin`, Operations → `institution_reader`, Auditor sem vínculo e ausência de EXECUTE direto para clientes.

O preflight somente leitura [preflight-lote56.sql](./preflight-lote56.sql) passou 20/20, com terminal em [preflight-lote56-20260912.log](./preflight-lote56-20260912.log), exits nativo e wrapper zero. Ele confirma:

- `has_platform_permission(text,uuid)` com o ramo final do lote 50;
- `scope_targets()` e o reativador na forma final do hotfix lote 52;
- sincronizador na forma final do lote 55, sobre `scope_targets`, com mapeamentos por papel;
- `security definer`, `search_path` fixado e ACLs restritas;
- `institution_reader` somente com permissões ativas `%.read`;
- `pg_cron`, `cron.job` e `sweep_expired_now_publications(uuid,integer)` disponíveis;
- zero jobs existentes com o nome/comando de expiração do Agora.

A primeira formulação local do check 2 procurava incorretamente `internal_actor.institution_id`; a função final usa o parâmetro `institution_id` junto de `not internal_actor.is_internal`, como definido pelo lote 50. A definição materializada foi inspecionada, a asserção foi corrigida sem alterar o banco e a execução registrada passou 20/20.

Com isso, o espelho está comprovado para o preflight do lote 56. O ledger de uma linha continua explicitamente não autoritativo; aplicação, backup e ledger do lote 56 permanecem sob posse exclusiva do C0.

## Driver suportado e reprodução

A investigação dos scripts existentes e do Dart MCP está em [runtime-driver-reproduction.md](./runtime-driver-reproduction.md). O build release estático não expõe DTD/VM Service; `dtd.listDtdUris` não encontrou app conectado. `qa_drive.dart` depende de CDP, enquanto `qa_login.dart` e `flutter_driver_command` dependem de app debug/VM Service. Também ficou registrado o bloqueio automático `blocked by policy` recebido antes de qualquer Chrome por shell, distinguindo-o de aprovação humana.

O C0 liberou a tentativa com `flutter run -d web-server` na mesma porta e na mesma aba. DTD e VM Service foram encontrados, mas `qa_login.dart` falhou no DWDS (`Unexpected null value`) e o Dart MCP informou que Flutter Driver não estava habilitado; o próprio Flutter avisou que o dispositivo web-server exige a extensão Dart Debug Chrome. O servidor debug foi encerrado limpo e o release foi restaurado no PID `33856`.

O probe CUA foi repetido com seletores e APIs exatos, usando apenas sentinelas: `getByRole("textbox", {name: "E-mail"}).fill(...)` + `press("Tab")`, além de `click(7)` + `pressKey("CTRL+A")` + `typeText(...)` + `pressKey("TAB")` e `setValue(7, ...)`. O Tab não transferiu o foco, o controller continuou vazio e o submit retornou as validações obrigatórias. Não houve chamada Auth. As duas rotas de driver suportadas foram, portanto, esgotadas sem CDP alternativo ou segundo navegador.

O último gate solicitado pelo C0 usou clique físico `[960, 434]` e instrumentação QA temporária, sanitizada, nos controllers/focus nodes. O clique atingiu e focou o e-mail; `Tab` moveu o foco para senha, mas `typeText` e uma tecla individual mantiveram DOM e controllers em comprimento zero. Isso isola o bloqueio no canal de inserção de texto da extensão, não no hit-testing. A instrumentação foi removida integralmente, o build original foi recompilado com exit 0 e recuperou o SHA-256 original `4ca0e74024f379b451b78fb36daeca2a09a29445474eacf938266005845e4bf1`; release ativo no PID `14724`.

A última alternativa permitida pela própria CUA, `pressSequentially`, também não ficou acionável: o locator por role expirou/destacou e o locator DOM contou dois inputs, mas expirou no actionability antes de inserir a sentinela. O diagnóstico de ferramenta está encerrado sem CDP por shell, bypass Auth ou segundo navegador.

## Suítes focais adicionais de G5

- `superadmin_assessments_internal_v2_test.sql` do commit `53b9c6d29`: **52/52**, native/wrapper 0 e rollback. Terminal: [pgtap-assessments-53b9c6d29.log](./pgtap-assessments-53b9c6d29.log).
- preview de cleanup `086a654c6`: falhou antes da consulta porque `CREATE TABLE AS` é proibido pela própria transação read-only; native 3 e nenhum DML persistente. G5 foi notificado e corrigiu o script, sem edição por G0. Terminal: [cleanup-manifest-preview-086a654c6.log](./cleanup-manifest-preview-086a654c6.log).
- preview corrigido `c9662b0ff`: native/wrapper 0, uma linha `ROLLBACK`, nove categorias com contagem zero, sem e-mails/IDs/segredos no output e sem mudança persistente. Terminal: [cleanup-manifest-preview-c9662b0ff.log](./cleanup-manifest-preview-c9662b0ff.log). Nenhuma limpeza foi executada.
- `superadmin_internal_invites_v2_test.sql` do commit `76aed97cb`: primeira execução **34 ok / 1 not ok**, native 0, wrapper 1 e rollback. A fixture expirada (casos 18–20) passou; apenas o caso 8 ainda exigia `requires_aal2`, incompatível com MFA adiado e contraditório com o caso 27 da mesma suíte. Terminal: [pgtap-invites-expired-76aed97cb.log](./pgtap-invites-expired-76aed97cb.log).
- G5 corrigiu somente essa expectativa em `95b501322`; rerun focal: **35/35**, native/wrapper 0 e rollback. Terminal: [pgtap-invites-expired-95b501322.log](./pgtap-invites-expired-95b501322.log). Nenhuma migration ou fixture persistente foi criada.

## H09 no espelho e consumidores de Chat

O C0 liberou nominalmente o baseline às 11:28 BRT. O candidato `20260912140545_now_publication_expiry_dispatch_v1.sql` de `76aed97cb` foi aplicado **somente** em `supabase_db_coelo_baseline`; produção permaneceu intocada.

- aplicação: native exit 0;
- estado materializado: um job `coelo-now-publications-expire`, agenda `*/5 * * * *`, comando limitado a `sweep_expired_now_publications(null::uuid, 500)`, ativo;
- pgTAP do H09: **6/6**, native/wrapper 0 e rollback;
- consumidor Chat attachments: **28/28**, native 0 e rollback;
- consumidor Chat worker claims: **3/3**, native 0 e rollback;
- wrapper agregado dos consumidores: 0.

Terminais: [h09-apply-baseline-76aed97cb.log](./h09-apply-baseline-76aed97cb.log), [pgtap-h09-expiry-dispatch-76aed97cb.log](./pgtap-h09-expiry-dispatch-76aed97cb.log) e [pgtap-chat-consumers-post-h09.log](./pgtap-chat-consumers-post-h09.log).

O primeiro probe após a aplicação teve somente erro de quoting do comando local (`column "coelo" does not exist`); o apply já havia encerrado com exit 0. O probe foi corrigido sem reaplicar o candidato e a linha nominal acima foi confirmada. O log preserva ambos os fatos. O slot SQL foi devolvido imediatamente ao C0, que mantém posse exclusiva de backup, produção e ledger do lote 56.

## Pacote focal de Formulários bloqueado

Com posse nominal do C0, o teste `forms_question_media_r2_v1_test.sql` de `444ac0246` foi executado RED: casos 1–18 passaram, 19/20 falharam e a suíte abortou em `forms.read required`, exits nativo/wrapper `3`; a transação foi revertida no fechamento da conexão e o probe confirmou zero fixtures persistidas. O candidato `20260912140546_forms_question_media_draft_bridge_v1.sql` foi aplicado somente ao baseline, COMMIT e exits `0/0`. O GREEN repetiu exatamente a falha RED e terminou `3/3`; nenhuma regressão foi empilhada.

A causa é objetiva: `has_platform_permission(text)` delega ao overload `(text,uuid)` com instituição nula, que nega membership institucional ao ator interno. O candidato usa a forma sem instituição tanto no prepare people-based quanto no editor/`require_forms_actor`. A revisão G3 posterior também bloqueou `ON DELETE RESTRICT DEFERRABLE` — materializado como `confdeltype=r` — e exige `NO ACTION DEFERRABLE`, além de `media_context` JSON null quando não há working version. O STOP chegou depois do COMMIT local; por segurança não houve rollback/reset destrutivo. Produção permaneceu intocada e o baseline aguarda correção forward do autor. Recibo sanitizado: [pgtap-forms-question-media-444ac024.log](./pgtap-forms-question-media-444ac024.log).

O autor publicou o forward fix `20260912140547` em `28625efaf`, e o C0 devolveu posse exclusiva do baseline ao G0. O apply local terminou em COMMIT, exits `0/0`; a suíte focal passou **33/33**, rollback, `0/0`; `forms_behavioral_rpc_test.sql` passou **17/17**, rollback, `0/0`. A regressão `superadmin_internal_form_drafts_v2_test.sql` passou os testes 1–59 e então abortou em `internal auth link version mismatch`, exits `3/3`, porque a fixture altera `status/revoked_at` do auth link sem incrementar sua versão. O forward fix não altera auth links; a falha foi classificada como fixture incompatível com o guard de lifecycle vigente. O ciclo parou imediatamente, sem rerun ou suíte adicional, e a transação abortada foi revertida no fechamento da conexão. Recibo: [pgtap-forms-question-media-28625efaf.log](./pgtap-forms-question-media-28625efaf.log).

O rerun único autorizado com a fixture `0d52d5dbf` confirmou o próximo invariante: o version bump permite revogar o link, mas a tentativa seguinte de reativar a mesma linha falha corretamente com `revoked internal access is terminal`. Novamente houve 59 testes aprovados antes do abort, exits `3/3` e rollback pelo fechamento da conexão. Não houve novo rerun; o autor precisa separar os cenários sem reviver acesso revogado.

A fixture final `afcebccd0` isolou revogações em identidades independentes e passou **159/159**, `finish 1..159`, rollback e exits `0/0`. Nenhuma migration/WIP adicional foi aplicada. O slot SQL foi solto imediatamente. O histórico RED e as duas correções de fixture permanecem no mesmo recibo.

O inventário objetivo das capacidades já presentes está em [runtime-capabilities.md](./runtime-capabilities.md). CUA oferece AX/DOM, locators, ações de ponteiro/teclado e logs, mas não expõe CDP e não injeta texto consumível nesta superfície Flutter. Dart MCP oferece DTD/Driver/Inspector/runtime apenas com DTD ativo; o release não tem DTD, e o Chrome compartilhado não possui Dart Debug. Nenhuma ferramenta/extensão foi instalada ou reconfigurada.

## Fechamento terminal de question-image

Com revisão G7 e posse C0, o baseline recebeu sequencialmente `140548` e `140549` sobre `140547`, ambos COMMIT e exits `0/0`; produção ficou intocada. Antes do apply, os REDs foram **4 ok / 5 not ok** no plano 9 e **3 ok / 4 not ok** no plano 7, ambos rollback, native `0`/wrapper `1`. Depois, as focais passaram **9/9** e **7/7**, rollback e `0/0`.

A primeira regressão de 33 testes ficou **32 ok / 1 not ok**: o caso 17 ainda espera ticket inválido no segundo finalize idêntico, enquanto 140548 passou a reconciliar resposta perdida com sucesso idempotente. Native `0`, wrapper `1`, rollback. O ciclo parou antes das regressões 17/159 e aguarda ajuste autoral da expectativa sem enfraquecer o mismatch fail-closed. Recibo: [pgtap-forms-question-media-3f494eb51.log](./pgtap-forms-question-media-3f494eb51.log).

A expectativa foi alinhada no commit `684eea023`: replay idêntico exige sucesso, mesmo asset, status `ready`, `replayed=true`, uma única variante e medidas preservadas; mismatch alterado continua fail-closed no plano 9. O rerun final passou **33/33**, **17/17** e **159/159**, todos com `finish`, rollback e exits `0/0`. A falha 32/33 permanece apenas como histórico do ciclo anterior. Slot SQL liberado; produção continua exclusiva do C0 e intocada pelo G0.

## Smoke API de Formulários preparado

Por solicitação do C0, foi preparado — sem execução remota — um smoke autenticado do editor normal identificado com `question-image`. O roteiro completo está em [forms-question-image-api-smoke-manifest.md](./forms-question-image-api-smoke-manifest.md) e o runner fail-safe em [forms-question-image-api-smoke.py](./forms-question-image-api-smoke.py).

O fluxo usa somente Auth, `form_save_draft`, `form_get_editor` e a Edge Function `form-media`: cria uma fixture institucional sem PII, prepara e envia um PNG válido de 1×1 pixel, finaliza, resolve e confere o SHA-256 baixado, e repete o editor para provar o binding `ready`. Por correção expressa do C0, formulário e asset sintéticos permanecem para inspeção até o fechamento formal da Etapa 2; o `finally` encerra somente a própria sessão Auth com `scope=local`. JWT, ticket, chave de objeto e URLs assinadas ficam somente em memória. Sem `--execute`, o runner encerra com `READY_NO_MUTATION`; dry-run, parse sintático e `git diff --check` passaram.

O C0 recebeu antecipadamente a instituição medida, a fixture, a sequência e os critérios de parada. A execução aguarda liberação nominal após backup/lote 57 e confirmação de `140546..140549` e da Edge Function compatível em produção. Nenhuma chamada remota, migration, deploy ou mutação foi feita neste preparo.

O preflight remoto somente leitura posterior confirmou `form-media` ativa na versão 16, `verify_jwt=true`, bundle `04f20933...`. A fonte implantada foi baixada temporariamente pela API de gestão e os quatro arquivos de runtime (`index.ts`, `media_contract.ts`, `question_image.ts`, `_shared/r2_s3.ts`) são byte a byte iguais à fonte local inspecionada. G5 confirmou que seu delta de replay é apenas de teste: a Edge v16 já executa authorize, HEAD, GET/medição e finalize também na reconciliação `ready/replayed`. A cópia temporária foi removida após a comparação.

Após autorização nominal do C0, o smoke foi executado uma única vez e passou com exit `0`: Auth/save/editor/prepare/PUT/finalize/replay/resolve/GET/reload ficaram verdes, o conteúdo baixado preservou os 68 bytes e o SHA-256 esperado, e a própria sessão terminou por logout local `204`. O formulário `f88005ab-af5e-4aa2-8cf7-f35de4ded376` e o asset `d25b8baa-efb5-4702-b5e6-ac3084610605` permanecem íntegros para o fechamento formal; não houve DELETE nem cleanup. Recibo: [forms-question-image-api-smoke-20260912.log](./forms-question-image-api-smoke-20260912.log).

## Rebuild na base integrada

Depois de incorporar `origin/dev` `2441725d5` por merge, o build QA foi refeito sobre `615aaa6f` para não manter no servidor o artefato anterior às mudanças integradas de Formulários. O comando `flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local` terminou com exit `0` em 84,3 s.

```text
apps/superadmin/build/web/main.dart.js
bytes: 8399330
sha256: 8a1ac51d89d77b8ed04e157ede4838d25e0ec71c8797d6fe104baaa9df663285
```

O servidor foi restaurado em `127.0.0.1:3014`, PID `44404`; `/login` respondeu `200`/1020 bytes e `flutter_bootstrap.js`, `200`/9975 bytes. O baseline `1abbc4f2cd13` continuou healthy na porta 57322. A mesma aba Chrome `829822454` foi recarregada; nenhum segundo navegador foi aberto e o diagnóstico de inserção de texto não foi repetido. Após o reload, a ponte CUA voltou ao botão `Enable accessibility`, o que não promove o gate visual a concluído.

## Lote 58 — RED comportamental de Moments

O C0 concedeu posse exclusiva do baseline apenas para o RED, proibindo o apply até novo ACK. Após G5 publicar a prova ampliada em `e9a3dc18d`, foi executado um único `moments_withdraw_permission_behavior_v1_test.sql`: plano 11, **4 ok / 7 not ok**, `finish` com sete falhas, rollback, native exit `0` e wrapper lógico `1`.

Passaram a ausência de grant no reader, o hint antigo `true` para admin autor e as duas negações de comando para reader/outro escopo. Falharam exatamente os comportamentos-alvo: grant admin ausente; withdraw/replay do autor negados; publicação ainda visível; auditoria success ausente; outro admin barrado pela falta de permissão antes da autoria; reader autor ainda recebe hint incorreto. Recibo: [pgtap-moments-withdraw-lote58.log](./pgtap-moments-withdraw-lote58.log). Nenhuma migration foi aplicada e produção permaneceu intocada.

Após revisão G7 e ACK nominal do C0, `140550` (SHA-256 `9356F5E52C8D14B0C628540ECEEE35231C6BAF0044EFEE04AC71C6F23D69A996`) foi aplicado somente no espelho: COMMIT, native/wrapper `0/0`. O GREEN passou `4/4` estrutural e `11/11` comportamental; as regressões passaram `23/23` em `moments_feed_and_withdrawal_test.sql` e `30/30` em `moments_publication_mvp_test.sql`. Total único: **68/68**, todos com `finish`, rollback e exits `0/0`.

Uma tentativa de iniciar a regressão 23 com redirecionamento `<` foi recusada pelo parser PowerShell antes de abrir o psql; nenhum SQL/teste executou. O comando foi corrigido para pipeline e a suíte rodou uma única vez. Produção e ledger ficaram intocados, fixtures comportamentais voltaram por rollback e o slot foi devolvido ao C0.

## Smoke API de imagem de resposta preparado

O próximo gate focal solicitado pelo C0 foi preparado sem rede nem mutação. O
runner fail-safe está em [forms-answer-image-api-smoke.py](./forms-answer-image-api-smoke.py)
e o contrato completo em
[forms-answer-image-api-smoke-manifest.md](./forms-answer-image-api-smoke-manifest.md).
Sem `--execute`, ele retorna somente `READY_NO_MUTATION`; com `--execute` sem
fixture válida, para antes da autenticação com `INVALID_RUNTIME_FIXTURE`.

O roteiro não cria formulário, aplicação, ocorrência, participação ou pergunta:
exige uma `occurrence_id` autorizada já existente e seleciona uma única pergunta
`photo/gallery`, ou o `--item-id` explícito. Ele abre/reutiliza o rascunho pelo
contrato normal, preserva respostas existentes, faz prepare/PUT/finalize e replay
do mesmo finalize, anexa o asset por `form_save_response_draft`, autoriza o
download e reabre o mesmo rascunho para comprovar persistência. O ramo de resposta
não envia `purpose=question-image`, `form_id` nem `form_version_id`.

Para formulário anônimo, o runner exige o segredo correto em variável de ambiente
indicada por `--edit-secret-env`, passa-o em open/prepare/finalize/save/download e
nunca imprime ou persiste o valor. Ele não inventa segredo anônimo, evitando criar
resposta concorrente. Não há discard, DELETE ou cleanup em qualquer caminho;
asset e resposta são preservados inclusive em falha.

G3 informou a correção final `f0c7269fd` sobre `dfe013cc5`, revisada por G5, com
53 testes Deno PASS / 0 FAIL: o finalize inicial e o replay retornam
`id/item_id/mime_type/byte_length`, usando bytes medidos e negando fonte nula ou
divergente. O C0 integrou o fix, obteve 54 PASS na base conjunta e concluiu o
deploy por CLI. A execução remota ainda aguarda uma ocorrência real reutilizável;
G3 confirmou que não criou fixture remota nesta R08.

O runner local passou parse AST, dry-run e guard de fixture inválida. Build,
servidor, Chrome e baseline foram apenas conferidos: PID `44404` e PID raiz
`22592` respondendo, `/login` 200, container `1abbc4f2cd13` healthy na porta
57322. Não houve rebuild, novo Chrome ou nova execução do diagnóstico de texto.

## Fixture identificada de answer-image

Como a descoberta read-only não encontrou ocorrência reutilizável, C0 autorizou
uma única fixture mínima identificada e delegou sua revisão focal ao G5. O
executor fail-closed está em
[forms-answer-image-fixture.py](./forms-answer-image-fixture.py), o estado
retomável em
[forms-answer-image-fixture-manifest.json](./forms-answer-image-fixture-manifest.json)
e o recibo sanitizado em
[forms-answer-image-fixture-execution-20260912.log](./forms-answer-image-fixture-execution-20260912.log).

O preflight confirmou por RPC normal a pessoa QA elegível no tenant e zero
formulário com o marcador exato. A única criação materializou o form
`afa8f922-b27d-4258-9322-8b3f96ee7df9` e o publicou. A assertion seguinte
parou porque comparava IDs enviados pelo cliente; a leitura normal mostrou que
`form_replace_working_definition` gera IDs server-side. Não houve segunda
fixture. Após dois reviews do G5, `--resume` fixou o mesmo form, exigiu
`editor.application == null`, capturou section/item server-side e pré-persistiu
os request IDs idempotentes.

A continuação única terminou com HTTP 200 para application
`c87a7e84-cbd4-43f8-9135-74efa0711edb` e schedule ativo
`5af5a32f-5ab0-4cf5-94a7-f618793becba`. Projeção read-only confirmou form
version 2, application version 1 e schedule version 1; o item `photo` efetivo é
`95cdf8cf-d993-4325-ac7c-941f041210cc`. G0 parou antes do worker, como exigido.
C0 confirmou a ocorrência aberta `5762fe8f-2d58-48ef-b410-30bfd0fe6703` e a
participação elegível `095d0236-334b-460b-aaa2-e1fce7914d8f`, ambas únicas.

O primeiro smoke answer-image parou antes de qualquer mutação: Auth 200, mas
`form_get_occurrence_for_response` devolveu HTTP 500/P0002; response e asset
permaneceram nulos e o logout local foi 204. A função exige que o ator atual
seja a pessoa da participação ou responder autorizado. A participação é da
pessoa `007a4ca5-31bd-4a77-956f-ce879695042e`, enquanto o runner usou a
credencial privada `qa-r06-principal.env`, provavelmente vinculada a outra
pessoa. Não houve retry. Recibo:
[forms-answer-image-api-first-attempt-20260912.log](./forms-answer-image-api-first-attempt-20260912.log).

Todos os sintéticos foram preservados; não houve cleanup, SQL direto, grants,
usuário novo ou logout global. O próximo gate é C0 confirmar o ator efetivo e
autorizar o uso da credencial QA correspondente à pessoa da participação, sem
criar outra fixture.

C0 confirmou depois a causa exata do segundo bloqueio: esse usuário de realm
interno tem zero vínculo ativo em `public.person_auth_links`; o mapeamento
válido fica em `app_private.superadmin_internal_auth_links/actor_people`. O ramo
answer-image da Edge v17 ainda consulta somente a tabela pública, portanto
retorna 401 antes de R2. Question-image não passa por esse ramo. G5 assumiu a
correção focal de ator canônico.

A retomada não repetirá criação nem usará IDs novos. O draft preservado
`bb1f3443-76a6-4049-b364-6215545625c8` e os request IDs de open, prepare,
finalize, save e download estão em
[forms-answer-image-response-resume-manifest.json](./forms-answer-image-response-resume-manifest.json).
O runner valida occurrence/participation/item e reutiliza esses IDs após o
deploy; asset permanece nulo até um prepare efetivamente aceito.

G0 revisou o fix G5 `49bd4c83d` sem achar bloqueio: o RPC
`list_my_principal_contexts` retorna diretamente linhas com `person_id`; o
resolver mantém precedência do vínculo People e só usa o fallback autenticado
quando ele não existe. Erro no lookup People, contexto vazio, UUID inválido ou
pessoas divergentes continuam negados. Múltiplos contextos da mesma pessoa são
deduplicados, e as RPCs de prepare/finalize mantêm a validação de ownership no
backend. Integração, suíte Deno e deploy continuam sob posse do C0.
