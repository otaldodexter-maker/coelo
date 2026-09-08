---
source:
  - "Coordenador Etapa2: preparação nominal de janela A01, 2026-09-08"
  - "f5b0e5bff1a9b9ba5a11f7c01f2fe8c2d91652b0: roteiro e testeFlutter cliente"
  - "Invoke-SafeLocalMigrationReplay.ps1 e Test-LocalAuthLifecycle.ps1 existentes"
status: integrado_em_preparacao_aguarda_gate_de_runtime
generated_at: "2026-09-08"
---

A janela proposta conecta somente o teste Flutter A01 ao PostgREST da stack local descartável **A01DirectoryAuditGreen55**, cujo SQL já passou97TAP. O recorte é leitura do diretório, opções, escopo institucional e auditoria. Inclui preparar um helper nominal, registrar pins do seed/cliente, testar seus guards e timeout, revisar antes da execução. Critério de parada desta proposta: direção de integração concreta e gates explícitos; não representa HTTP executado. Estimativa de implementação e revisão:25–40min após o seed estabilizar.

A integração mínima usa uma flag literal **RunA01LocalRuntime**, válida somente com NominalProfile **A01DirectoryAuditGreen** e target **20260907222911**. Não permite AuthOnly/FoundationOnly/AdditionalMigration, RunAuthLifecycle, RunActivityV2Concurrency, perfilRED ou target diferente. O wrapper valida o helper, seed e checkout cliente antes de staging/Docker. A flag seleciona os serviços locais já usados pelo AuthLifecycle, incluindo Kong/PostgREST; os outros perfis preservam o startDB-only e seus guards. Não há callback, endpoint externo fornecido pelo cliente ou keepalive.

Após reset55 bem-sucedido, o helper específico é chamado dentro do try existente, antes de finally. Ele confirma identidade/container/volume/TEMP, URL API127.0.0.1 e mapeamento nominal, configuração PostgREST dirigida ao banco da identidade, ledger55 exato e hashes das fontes já validadas. Falha impede seed e HTTP. O helper não altera cleanup: ao retornar, falhar ou atingir timeout, o wrapper desmonta os recursos próprios e verifica ausência de staging/container/volume/rede pelo mecanismo atual. Não existe saída que retenha a stack.

O seed **a01_local_http_seed.sql** é extraído semanticamente da fixture97 ee212cb56e9dc18400a8d105aeeba3a5f77bbbf4 e está pinado após revisão independente. Tem guards de ambiente; colisões nos IDs sintéticos abortam a transação pelas escritas/constraints, com Auth/users/sessions reais, leitores039 sem pessoa global, estados102/104/106, constraints imediatas antesCOMMIT, claims e markers limpos. Somente a concessão sintética adicional platform.read para Operations102/Content106 foi autorizada centralmente. Não altera grants remotos ou escolhe fonte por intervalo de linhas. Seed confirmado é condição necessária para HTTP, que não enxerga uma transação revertida.

A fonte cliente é f5b0e5bff1a9b9ba5a11f7c01f2fe8c2d91652b0 e suas dependências produtivas. A worktree do operador E1 ainda contém adapterActivities fail-closed, portanto executar Flutter nela não provaria a integração pretendida. O checkout cliente foi fechado em f0be734ac3210c84523a61700f73feaba5150368, com árvore íntegra e limpa, incluindo teste, parser, adapter, gateway e composição/rota pertinentes. O helper não pode alterar esse checkout nem substituir os adapters. O caminho final e a verificação do cliente estão registrados abaixo.

As credenciais são exclusivas da stack sintética. O segredo de assinatura local permanece na memória do operador, nunca no processo cliente. JWTs authenticated para102/202,104/204 e106/206 contêm role, aal2 e expiração curta; o parser cliente aceita no máximo uma hora, e a proposta operacional usa10min. Anon key local e esses três tokens são entregues somente pelo ambiente do processo Flutter filho. Nenhuma gravação emGit, dotenv, assets, dart-define, log, URL ou argumentos do processo. Output potencialmente sensível de statusCLI é capturado em memória e não ecoado.

O processo Flutter executa apenas **flutter test --no-pub test/features/activities/a01_local_runtime_test.dart**, no checkout nominal. A janela do filho tem timeout fixo de180s; o helper encerra a árvore do processo ao vencer e lança falha para que finally limpe a stack. Testes de preparação devem usar executores simulados para demonstrar encerramento/propagação e recuperação de recursos; não iniciam SQL/Docker ou servidorHTTP. Não há retries silenciosos do teste real, alteração de timeout para ocultar travamento, espera indefinida por outro agente ou comando livre.

O transporte pinado permite somente POST para superadmin_auth_bootstrap_context, superadmin_activity_directory_v2 e superadmin_activity_filter_options_v2 na origem127.0.0.1 com porta explícita. Rejeita redirects/query/fragmento/userinfo e outras RPCs. O teste usa o bootstrap real, rota normal /activities, adapter real, reentrada de rota, filtroB adulterado e tokens revogado/negado. Não usa signInForTesting. Compilar ou saircomSKIP não certifica execução: o helper deve exigir opt-in aplicado, exit0, teste efetivamente executado e o relatório nominal de correlações não vazio.

Após o teste, o helper verifica separadamente audit.audit_logs pelas correlações saneadas: ações, outcomes, ator/link/membership internos, scope/instituição, hash de sessão e minimização after_json=row_count nos sucessos. Deve conferir a ausência de alterações do domínio comparando snapshot sintético antes/depois, sem apagar auditoria. JWTs, headers e valores de sessão não entram na evidência. Correlações impressas pelo Flutter não substituem a consulta real de audit nem a comparação de estado.

Os artefatos executáveis e seus pins foram implementados; os resultados da integração e do smoke estão registrados abaixo. A coordenação aceitou esta direção para preparação; HTTP/SQL exige gate nominal posterior. Esta proposta não prova E2E geral, CRUD, mídia, modelo deAtividades, reautenticação, todos os caminhos IDOR, app mobile ou produção. Nenhuma regra de produto foi alterada.

## Cliente nominal preparado pelo operador

O checkout separado está em **C:/Users/adrie/Documents/Coelo/.worktrees/e1-a01-client**, branch **codex/e1-a01-client-20260908**, HEAD **f0be734ac3210c84523a61700f73feaba5150368**. A verificação de isolamento confirmou o diretório .worktrees ignorado antes da criação. O checkout do harness permanece em e1-replay-harness; nenhum adapter foi copiado ou modificado.

O comando flutter pub get --offline concluiu usando as dependências disponíveis. A validação local executou o teste de configuração/transporte e compilou o teste de runtime com **COELO_A01_LOCAL_RUNTIME=0**: **23 guards PASS e 1 runtime SKIP**, exit0, processo59702 encerrado. Git status permaneceu limpo. Isso valida a preparação do cliente e seus guards; não é prova de HTTP, autorização no backend, auditoria ou UI integrada.

O seed ganhou um guard nominal adicional do root antes de qualquer escrita: exige coelo.local_replay='a01-http-green55' fornecido pelo operador na mesma conexão já validada. Hash UTF-8/CRLF do seed: **758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99**. O guard não se autoconcede opt-in. O helper foi revisado; configurar esse GUC e executar o seed continuam dependentes do gate de runtime.

A coordenação confirmou que activities.taxonomy.manage herdado de Operations deve permanecer. A prova fica limitada aos três RPCs de leitura e às ações da UI verificadas; não se exige nem se declara uma matriz global sem capacidades de escrita. Nenhuma revogação adicional foi incluída.

## Verificação final de preparação pelo root

O wrapper implementa **RunA01LocalRuntime** com **A01ClientRoot**, somente A01DirectoryAuditGreen/20260907222911. Rejeita também TestPath e RunLint na janela HTTP fechada. Antes do mutex/staging, verifica o pin do helper, importa suas funções sem executar runtime e valida cliente, inputs55 e seed. Após reset55 bem-sucedido chama o helper dentro do try existente; finally, limpeza e mutex permanecem sob o wrapper. Os demais perfis mantêm os serviços anteriores.

Pester de integração executado pelo root: **31/31 PASS, zero skips**, 4,0373177s externos, exit0. Helper final pinado no wrapper: **ab8947303545c311d644b62dcee2a04daefcfa535ee6f433259ed5daafd8172b**; testes do helper **d0bc7658dd266742149d28a57a3ba5583f3a3978a34c2d95d1f5bf5fc2d6b21b**, autor44/44 PASS. A regressão compartilhada independente passou597/597, zero falhas/skips, em451,6866725s; os33arquivos preservaram hashes raw eCRLF antes/depois. Evidência em shared-ag54-a01-regression-2026-09-08.md.

O smoke Windows real do helper final passou: transferiu **65.536 caracteres ASCII sintéticos** por stdin, capturou stdout/stderr exatos e retornou exit0. Um pai que iniciou descendente e saiu deixou os pipes abertos; o prazo de2s foi aplicado ao conjunto, encerrando o Job Object em **2,0485704s**. O PID próprio45584 estava ausente e o marcador TEMP nominal foi removido. Em seguida **Assert-A01Client** verificou novamente o checkout f0be734a limpo usando o launcher final. Nenhum Docker, SQL, HTTP, token da stack ou Flutter runtime foi executado nesse smoke.

O primeiro smoke falhou no construtor com Win32ERROR87: o binding PowerShell converteu null em string vazia e produziu um bloco de ambiente inválido. A correção C# IsNullOrEmpty foi primeiro comprovada em memória com exit0 e depois no helper final pelo smoke acima. O daemon é fixado pelo npipe validado em --host; statusCLI recebe esse host em ambiente exclusivo do filho, sem alterar o ambiente do pai. Isso não afirma que portas do banco estejam exclusivamente em loopback; o helper verifica a URL API127.0.0.1 e seu mapeamento nominal.

A primeira janela contra serviços depende de gate central próprio. Os testes de preparação não demonstram que o layout CLI/Kong observado em runtime corresponderá ao parser fechado, nem substituem seed confirmado, auditoria real ou a comparação de estado.
