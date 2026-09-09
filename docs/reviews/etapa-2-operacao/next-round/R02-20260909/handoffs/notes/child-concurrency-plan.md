---
title: "R02 D03 — plano focal de concorrência do diretório CHILD"
source: "prompts/D03.md; assignment D00 revisão 8; migration 20260908051500; contrato CHILD de 2026-09-08"
status: "prepared-not-executed"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Concorrência do diretório CHILD

Etapa 2 → `apps/superadmin` → Acompanhamento → Acompanhamento de alunos →
lista autorizada → `students.list`.

## Recorte e ambiente

O harness `packages/coelo_database/scripts/Test-ChildDirectoryConcurrency.ps1`
foi preparado exclusivamente para um projeto Supabase local descartável criado
pelo replay seguro. Ele exige o marcador `.coelo-safe-replay`, o `ProjectId`
canônico e o contêiner `supabase_db_<ProjectId>` em execução. O script não lê
credenciais nem aceita um contêiner arbitrário.

O preflight rejeita qualquer identidade, fixture ou auditoria que use os IDs
reservados pelo harness. A base deve estar limpa e é estritamente one-shot: as
fixtures permanecem somente até o cleanup do runner que remove todo o projeto
descartável. O harness não tenta apagá-las nem contorna os guards de lifecycle
para permitir uma segunda execução in-place.

SQL concorrente não executado. O replay nominal de 49 migrations passou, mas o
TAP CHILD corrente parou depois de 21 assertivas aprovadas; portanto, este plano
não promove o backend a verde nem afirma prova E2E. A execução depende do TAP
nominal verde, de nova autorização de janela e da integração serializada pelo
executor D03.

## Fixtures e sinais determinísticos

O harness cria uma instituição, três crianças ordenadas como Alfa, Beta e Zulu,
três contextos ativos e dois atores Owner independentes. O primeiro ator existe
somente para a revogação. Sua membership avança `version = version + 1` e fica
terminalmente revogada. O segundo Owner permanece ativo e conduz a renomeação e
a expiração; assim a fixture respeita tanto o guard de versão quanto a proteção
do último Owner ativo.

Cada corrida usa processos `psql` separados. Um advisory lock controla o ponto
de liberação. O harness cruza `pg_blocking_pids` com `pg_stat_activity` e exige
os pares reader/blocker nominais antes de prosseguir; um wait genérico por lock
não satisfaz a prova. As contagens de auditoria também filtram a identidade
interna reservada de cada ator, evitando contaminação por eventos alheios.
Todos os waits têm timeout. A passagem do tempo na expiração é observada por
consultas de relógio; nenhum `pg_sleep` SQL mascara o estado de bloqueio. O
bloco `finally` encerra e descarta qualquer processo remanescente.

## Invariantes exercitadas

1. **Revogação durante a leitura.** O writer revoga a membership e espera no
   gate antes do commit. O reader fica bloqueado no `FOR SHARE`; depois da
   liberação deve retornar `SAI_MEMBERSHIP_REVOKED`, `data = null`, nenhuma
   auditoria de sucesso, exatamente uma negativa e nenhum `institution_id`
   derivado de input não confiável.
2. **Rename dentro de `limit + 1`.** Zulu é a terceira candidata para limite 2.
   O writer muda seu nome para Aaron antes de liberar o row lock. A resposta
   deve reordenar os valores efetivamente lidos como Aaron, Alfa e produzir o
   cursor `('alfa', context_id da Alfa)`.
3. **Expiração durante o append de auditoria.** O harness adquire e confirma o
   gate antes de definir a expiração. Depois grava um horizonte de 30 segundos,
   captura o deadline absoluto retornado pelo banco, inicia o reader com
   `statement_timeout = 60s` e `lock_timeout = 50s`, prova que ele está bloqueado
   pelo processo do gate e exige margem mínima de 20 segundos. Só então espera
   o relógio do banco alcançar o deadline, com timeout externo de 40 segundos.
   A chamada deve falhar com
   `SAI_SESSION_INVALID`, sem JSON de sucesso, e o insert de auditoria dessa
   instrução deve ser revertido. Ao final, o trigger e a função são removidos.

## Limites e integração pendente

O teste estrutural valida parse, isolamento, sinais, timeouts, cleanup e as
asserções essenciais sem abrir Docker ou banco. Ele não demonstra o
interleaving real. O comando concorrente só deve ser integrado ao runner comum
após a reserva específica do hunk compartilhado e executado em uma nova base
descartável limpa. Reload remoto e produção ficam fora deste harness.

Conhecimento: `no-op`; nenhuma regra durável nova de produto foi aprovada.

## Revisão e prova estrutural final — 14:33 BRT

A revisão independente encontrou e corrigiu três riscos do próprio harness:
expiração precoce antes da auditoria, aceitação de qualquer lock e contagem de
auditoria fora da fixture. O deadline agora é capturado no banco depois do gate
adquirido; cada reader comprova seu blocker exato por `pg_blocking_pids`.
Contagens usam a identidade interna sintética correspondente. O preflight
one-shot também rejeita o trigger/função preexistentes; a limpeza desses objetos
só é habilitada depois de confirmar sua ausência e iniciar sua criação própria.

Prova final nesta árvore: Pester **P8/F0/B0/S0/U0**, exit 0, sem Docker/psql.
XML `C:/Users/adrie/AppData/Local/Temp/d03-child-directory-concurrency-structural.xml`,
SHA256 `945309DD4B53B00E95DA06A17F910BC10A580F9CA1C1850777B82FC5AC06736F`.
Harness SHA256 `8433947DD908D106BB9B8E70994D1C87F1948ADD821C367822128B53C1BB203F`;
teste SHA256 `395D094723161A6C2C8F16DC6934E71643543E604CD41A902543CACCD9636810`.
Os reruns estruturais anteriores não são somados. SQL concorrente continua
planejado em três cenários e não executado.

## Integracao D00 - 2026-09-09T14:53:36-03:00

Harness integrado cc487008f e hook opt-in aplicado na raiz. Revisao independente conferiu causalidade e guard de modos. D00 acrescentou exigencia de TestPath unico do TAP CHILD nominal antes de recursos, impedindo concorrencia sem45assertivas anteriores. Infraestrutura atual20IDs PASS:8harness+12wrapper. XML child-concurrency-integrated-green registra19P1F (seletor AST de teste capturava dois guards); ajuste do seletor sem afrouxar produto e child-concurrency-wrapper-final registra12P0F. Reruns nao somados. RED inicial de11guards consta tool sessions11384/87582, sem arquivo bruto; REDnovo TAP0P1F em child-nominal-tap-guard-red.xml. SQL45+3 ainda nao executados nesta integracao; nao e aceite BE/E2E.
