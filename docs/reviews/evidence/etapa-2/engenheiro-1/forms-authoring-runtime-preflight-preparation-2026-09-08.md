---
fonte:
  - "Autorização central de preparação F-AUTHOR encaminhada pelo Engenheiro 1 em 2026-09-08"
  - "Decisão central posterior: distinguir extensão disponível/not_installed de instalada, sem CREATE EXTENSION"
  - "19990960c1d4b6c0e223102fc0d8cd7c1d117d82: forms-authoring-nominal-closure-2026-09-08.md"
status: "preparação local; testes com mocks; execução Docker/SQL ainda não realizada por este pacote"
data_geracao: "2026-09-08"
---

# F-AUTHOR — preparação do preflight de runtime isolado

O pacote implementa somente a prova de startup vazio e de cron global desligado na mesma instância. Não copia nem aplica a closure de 64 SQLs. A referência aprovada permanece a [alternativa operacional da closure nominal](forms-authoring-nominal-closure-2026-09-08.md#alternativa-operacional-submetida--mesma-instância-aplicação-sem-reset), no commit `19990960c1d4b6c0e223102fc0d8cd7c1d117d82`; a decisão central posterior admite o estado explícito `not_installed` descrito abaixo.

Arquivos de autoria exclusiva:

- [Invoke-FormsAuthoringRuntimePreflight.ps1](../../../../../packages/coelo_database/scripts/Invoke-FormsAuthoringRuntimePreflight.ps1).
- [FormsAuthoringRuntimePreflight.Tests.ps1](../../../../../packages/coelo_database/scripts/tests/FormsAuthoringRuntimePreflight.Tests.ps1).
- Este documento de preparação.

Nenhum entrypoint de replay, perfil, migration ou fixture SQL existente é alterado. A documentação não constitui autorização de execução; o root é o operador único após os gates centrais.

## Sequência fechada e gates

1. Rejeitar variáveis herdadas `SUPABASE_*`, `PGDELTA_*` e overrides de endpoint/TLS Docker sem imprimir valores. Exigir o contexto Docker atual com endpoint local Windows `npipe`; fixar o nome desse contexto nas chamadas Docker e conferir novamente antes das operações CLI e do comando de configuração.
2. Criar identidade inédita `coelo_fauthor_<26 hex>`, como filho imediato do TEMP, fora do repositório; adquirir `Local\CoeloSafeSupabaseReplay`. Confirmar ausência anterior de diretório, containers, volumes e redes, por nome e label nominal.
3. Criar somente marcador de ownership, `supabase/config.toml` e `supabase/migrations` vazio. Não ler/copiar a configuração canônica. O texto TOML é fixo, salvo identidade e duas portas locais efêmeras; é comparado integralmente antes de start e cleanup. A árvore inicial aceita somente esses quatro caminhos, sem reparse points no arquivo, diretórios ou ancestrais.
4. Exigir CLI `2.116.0`. Iniciar DB-only com migrations e seeds desabilitados; Auth e Storage ficam habilitados apenas para bootstrap nativo, com seus serviços persistentes excluídos. API, Realtime e pooler ficam desabilitados. Não existe configuração Vault, pgdelta, `db.settings`, `.env`, `roles.sql`, seed ou functions no projeto criado.
5. Identificar container PostgreSQL 17 oficial, label de projeto/workdir, image ID, digests reais, volume e rede exclusivos. Exigir exatamente um container, um volume e uma rede nominais. Inspecionar catálogo como `postgres`, sem consultar dados pessoais, valores Vault, comandos de cron ou payloads HTTP. Exigir Auth/Storage reais, enum `auth.aal_level`, catálogo de aplicação vazio, ledger ausente ou efetivamente com zero linhas.
6. Exigir `pg_cron` em `shared_preload_libraries`, `cron.database_name=postgres` e o GUC real registrado com contexto `sighup`. Classificar as três extensões e, somente se instaladas, ler contagens reais das tabelas exigidas. Qualquer atividade prévia ou inconsistência interrompe antes de ALTER.
7. Executar **um único comando autônomo** `ALTER SYSTEM SET cron.launch_active_jobs = 'off';`, sem transação envolvente. Reiniciar **o mesmo ID** com `docker restart --time 10 <ID>`. Não chamar reset, push, migration up ou qualquer instalador de extensão.
8. Aguardar readiness, com até 60 tentativas, `pg_isready -t 1` e intervalo de um segundo. Comparar ID/nome/image ID/referência/digests/volume/rede, verificar novo `StartedAt` e novo `pg_postmaster_start_time()`. Exigir setting e reset_val `off`, source `configuration file`, pending_restart `false`, zero erros em `pg_file_settings` e exatamente uma entrada aplicada `off` de `postgresql.auto.conf`. Repetir catálogo, ledger e contagens disponíveis.
9. Executar cleanup nominal e devolver somente metadados selecionados. PASS exige ausência final dos recursos próprios e do diretório TEMP. Não existe KeepAlive.

O guard de arquivo é repetido imediatamente antes de start. A seleção não recebe caminhos SQL, target, imagem, nome de projeto, flags de reparo ou outros parâmetros livres.

## Extensões: ausência não é zero

| Estado observado | Tratamento |
| --- | --- |
| Versão disponível; extensão não instalada; schema e três estruturas nominais ausentes | `not_installed`; versão disponível preservada; versão instalada ausente; contagens `null`; nenhuma consulta às tabelas ausentes |
| Extensão instalada e todas as estruturas nominais presentes | `installed`; versão real preservada; cron jobs/runs e net requests/responses devem ser contagens observadas iguais a zero |
| Extensão indisponível, catálogo parcial, schema/estrutura presente sem instalação ou estrutura faltante após instalação | FAIL antes de alterar cron; diagnóstico da inconsistência |
| Campo de catálogo/contagem ausente ou inválido | FAIL; ausência nunca é convertida implicitamente em zero |

Estruturas verificadas:

| Extensão | Schema | Relações e função nominal |
| --- | --- | --- |
| `pg_cron` | `cron` | `job`, `job_run_details`, `schedule` |
| `pg_net` | `net` | `http_request_queue`, `_http_response`, `http_post` |
| `supabase_vault` | `vault` | `secrets`, `decrypted_secrets`, `create_secret` |

Vault é inspecionado apenas por catálogo; nenhuma contagem de segredos ou leitura de `decrypted_secret` ocorre. A presença estrutural, a versão disponível e a versão instalada são registradas separadamente. O preflight não chama funções de extensão.

A aceitação de `not_installed` vale apenas para a base vazia deste preflight. Um pacote futuro de 64 SQLs terá de reconferir o GUC global off antes do primeiro CREATE/schedule e verificar estruturas e contagens assim que as extensões existirem. Esse fluxo futuro não está implementado aqui.

## Proveniência técnica

A whitelist do [schema db do CLI 2.116.0](https://github.com/supabase/cli/blob/v2.116.0/packages/config/src/db.ts#L36-L65) não inclui `cron.launch_active_jobs`. Este pacote não inventa uma chave TOML para cron. Migrations e seeds são desabilitados pelas opções documentadas no mesmo schema.

O [bootstrap config pinado](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/bootstrap-config.ts#L168-L213) preserva os gates nativos de Auth/Storage independentemente do exclude dos serviços persistentes. O [setup nativo](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/db-setup.ts) utiliza jobs próprios de migração desses serviços no banco novo. Isso justifica habilitar os dois gates sem iniciar gotrue/storage-api persistentes; o harness ainda exige prova do catálogo resultante.

Os [IDs e labels locais](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-docker-ids.ts#L60-L101) e o [volume PostgreSQL](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/postgres.service.ts#L339-L405) fundamentam os guards nominais. Não há digest inicial inventado: o script exige uma referência oficial PostgreSQL 17, observa os digests da imagem real e exige igualdade após restart.

O [pg_cron upstream](https://github.com/citusdata/pg_cron#extension-settings) documenta preload e `cron.launch_active_jobs`. A versão instalada é observada no catálogo local, sem presumir igualdade com upstream. [ALTER SYSTEM no PostgreSQL 17](https://www.postgresql.org/docs/17/sql-altersystem.html) persiste em `postgresql.auto.conf` e não pode ser usado dentro de bloco transacional; [pg_file_settings](https://www.postgresql.org/docs/17/view-pg-file-settings.html) fornece a prova de configuração aplicada e sem erro.

O [restart Docker](https://docs.docker.com/reference/cli/docker/container/restart/) opera sobre o ID preservado. O [formato Docker em shells Windows](https://docs.docker.com/engine/cli/formatting/) exige tratamento das aspas internas; o script fixa argument passing Legacy na fronteira Docker e escapa essas aspas. O teste de transformação é isolado; o marshal real do executável ainda pertence ao gate de runtime.

## Evidências locais de preparação

RED inicial: **46/46 falhas, zero skips**, por ausência do script, em 1,1025674 s. A suíte evoluiu para **60 casos**: sucesso instalado, ausência explícita, estados mistos, catálogo incompleto, Auth/Storage faltante, versões/papel, filas/ledger não vazios, setting/source/pending_restart, digest/volume/rede/postmaster, falhas de start/restart/readiness/stop, contexto remoto, colisão de identidade, marcador/reparse/config alterados e quoting Windows.

A suíte corrigida usa Pester **3.4.0**, fronteira nativa integralmente mockada, identidade própria por caso e segundo bloqueio de funções `docker`/`npx.cmd` para impedir executáveis reais caso um mock falhe. Na suíte corrigida, só arquivos sob TestDrive são criados/removidos pelos casos. Mocks de metadados reparse não criam junctions. A prova do mutex usa objeto fake; não mantém lease operacional.

GREEN observado na suíte de 60 casos: **60 PASS, zero FAIL, zero skips**, em 8,9658774 s. A verificação final do snapshot é entregue ao root com parse e hashes; não foram executados Docker, SQL ou pgTAP reais nesta preparação.

Durante a primeira rodada após implementação, o dot-sourcing repetido no BeforeEach invalidou o isolamento de mocks do Pester 3.4. Os casos de orchestration afetados pararam no mutex já ocupado, antes da fronteira Docker; dois casos diretos de filesystem criaram fixtures fora de TestDrive em TEMP real, às 04:45:49 UTC. A definição do script foi movida para uma única carga; a suíte passou a usar identidade nova por caso, flags de metadata reinicializadas e a segunda barreira contra executáveis reais.

Os dois diretórios próprios eram `coelo_fauthor_9103e8e1ff2b4912a14b9ac69e` e `coelo_fauthor_feecda1f2ae9419296a0368d5d`. O root autorizou seu cleanup nominal. Foram conferidos caminho absoluto como filho imediato de TEMP, timestamp UTC, marker identidade/path/nonce, árvore sem reparse, allowlist de filhos, config literal, migrations vazias e, onde presente, somente a `.env` sintética exata do teste. Ambos foram removidos com `Remove-Item -LiteralPath`; a pós-condição individual `Absent=true` passou. Nenhum Docker/SQL foi chamado nessa recuperação. O episódio não é apresentado como isolamento perfeito desde a primeira rodada.

A revisão independente identificou um P2 no relato de cleanup antes de ownership: colisões preservadas eram rotuladas `zero` apesar de `Created=false`. Dois novos casos produziram RED preciso **60 PASS + 2 FAIL**, com `zero` observado e `not_owned` esperado, em 10,2228199 s. A correção alterou somente a expressão da saída FAIL: `not_owned` quando nenhum diretório próprio foi criado, `unproven` se houver falha de cleanup e `zero` após desmontagem própria comprovada. O fluxo operacional permaneceu igual. GREEN final: **62/62 PASS, zero FAIL, zero skips**, em 9,1099846 s.

O teste mock confirma a ordem start → catálogo/contagens → ALTER SYSTEM → restart do mesmo ID → novas verificações → stop nominal. Não comprova que a imagem disponível no ambiente fará bootstrap, que o CLI aceitará cada operação real, que extensões estejam instaladas nem que a closure64 passe.

## Execução futura e recuperação nominal

Após revisão independente e autorização central de execução, o root poderá executar o entrypoint sem argumentos:

```powershell
& 'C:\Users\adrie\Documents\Coelo\.worktrees\e1-replay-harness\packages\coelo_database\scripts\Invoke-FormsAuthoringRuntimePreflight.ps1' |
  ConvertTo-Json -Depth 14
```

A saída de start, stop, setup, psql e restart permanece em memória e não é reproduzida; apenas metadados permitidos chegam ao resultado. Falhas SQL expõem fase, não o texto devolvido pelo processo. O resultado FAIL inclui identidade, caminho TEMP nominal, tentativas e evidência obtida antes da falha, quando disponível.

O finally tenta `supabase@2.116.0 --agent no stop --workdir <TEMP próprio> --no-backup --yes` após conferir ownership, marcador, config e ausência de reparse. Se esses guards falharem, ele recusa selecionar recursos por uma identidade não comprovada. Se stop falhar ou os recursos não estiverem comprovadamente zerados, preserva o diretório nominal e retorna FAIL; não apaga evidência de recuperação nem remove recursos por prune ou filtros amplos. O mutex é sempre liberado/disposto quando adquirido.

A recuperação de um FAIL com cleanup não comprovado cabe ao root: usar o ID/TEMP devolvido, conferir novamente o marcador e os recursos nominais e solicitar o reparo mínimo específico se necessário. O pacote não autoriza reset, repair, repetição em volume sujo, remoção de recursos alheios, alterações de ACL ou instalação oportunista de extensões.

A espera de saúde possui limite de tentativas e o CLI recebe `health_timeout=2m`. Download/pull, daemon travado e encerramento do processo nativo não têm deadline global adicional no wrapper; esses tempos permanecem sujeitos ao CLI/Docker e ao controle do operador. A autorização operacional deverá considerar esse limite antes de executar.

Memória de conhecimento: nenhuma regra de produto ou permissão foi alterada. A evidência técnica permanece neste documento; o gate de memória não exige nova projeção em `docs/knowledge`.


## Revisão independente e verificação do operador

O reviewer replay_auth_rls leu o script integralmente e identificou o reporte indevido de Cleanup=zero na colisão anterior ao ownership. A correção mudou somente a expressão de relatório para not_owned nesse ramo; reverter essa expressão em memória reproduz o hash anterior ca392f9a..., preservando o fluxo operacional. O reviewer aprovou a correção e não encontrou outro bloqueador no recorte estático.

O root executou independentemente a suíte final Pester3.4.0: **62/62 PASS, zero falhas/skips**, 10,7489194s externos, sessão31895 encerrada, exit0. Os testes simulam a fronteira nativa; não iniciaram Docker ou SQL. Pins finais UTF-8/CRLF: script **f8cf0c3010671bce47f4fce6e4f17e336d474da417293d8acc25950b0819e8ab**; testes **22f2033d8b3b854f18db1116ddf4067f14b77dbef66952280b3fb9f8d9470325**. O gate solicitado continua sendo somente preflight de runtime vazio, zero migrations da aplicação e cleanup obrigatório.

O diff staged do operador detectou uma linha vazia excedente no fim do script; ela foi removida antes do commit. Somente whitespace final mudou após os62 testes; o pin acima já corresponde ao arquivo final.
