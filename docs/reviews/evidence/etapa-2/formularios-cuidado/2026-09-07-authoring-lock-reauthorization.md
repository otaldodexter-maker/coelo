---
title: "F-AUTHOR01 — reautorização após espera e protocolo concorrente"
source: "Revisão central do pacote 1ccae045; fechamento técnico do Coordenador; specs 011 e 042"
status: "prepared-not-executed"
generated_at: "2026-09-07"
---

# Recorte

Corrigir somente os dois endpoints nominais de rascunhos internos da migration
`20260908030000_superadmin_internal_form_drafts_v2.sql`. O contexto anterior ao
lock não prova autorização depois de uma espera. Nenhum helper Auth global,
corpo legado, política clínica, R2 ou produção é alterado neste delta.
Ordem: contrato negativo preparado, guard nominal, revisão estática, protocolo
de duas conexões para Eng1. Gate: replay e concorrência realmente executados.
Estimativa local: 30 minutos; execução permanece exclusiva Eng1.

# Mudança nominal

- Sessão/contexto continuam validados antes de parâmetros e recursos.
- Após autorização inicial, rejeitar isolamento diferente de `read committed`
  com `SAI_INVALID_ARGUMENT`, sem dados e com auditoria obrigatória. Isso não
  altera o default do banco nem o helper Auth global.
- Save revalida após advisory do request, antes do receipt, e novamente após
  advisory do formulário, `forms FOR UPDATE` e `institutions FOR SHARE`.
- Reader revalida após `forms FOR SHARE` e `institutions FOR SHARE`. Conserva
  a capability inicialmente selecionada: manage, ou read no fallback autorizado.
- Cada revalidação usa uma instrução SQL separada dentro da função `VOLATILE`.
  Com `READ COMMITTED`, a consulta pós-espera pode ver a revogação confirmada.
  O helper Auth continua `STABLE`; não reutilizamos o record obtido antes do lock.
- Comparar identidade, AuthLink, membership, auth user e sessão originais,
  além do escopo original. Validar AAL e escopo real atuais. Não migrar a
  operação em voo para outra membership/contexto válido.
- Não devolver receipt nem escrever antes da última revalidação. Auditoria
  obrigatória continua fora do catch de negócio, inclusive no replay.

# Instituição excluída

Spec 011 distingue soft delete de preservação de auditoria. A projeção
`institution_management_payload` efetiva exclui `deleted_at IS NOT NULL`.
Spec 042 permite replay após exclusão somente para ack histórico sem snapshot;
mantém detail negado. O receipt Forms contém definição, portanto não recebe
essa exceção. Save/create/edit/replay e reader nominal exigem instituição não
excluída e mantêm `FOR SHARE` até o fim da transação, bloqueando mudança
concorrente de `deleted_at`. `FOR KEY SHARE` não protegeria esse atributo.

Não exigir status active, nem inferir política nova para instituições suspensas
ou arquivadas, respostas, exportação ou outros históricos. O controle preparado
com status inactive confirma que ausência de exclusão não é confundida com status.

# Testes preparados, não executados

- Teste principal: instituição excluída nega create/edit/reader/replay; nenhuma
  definição, nova escrita ou receipt; instituição inactive continua legível.
- Dois arquivos independentes testam `REPEATABLE READ` e `SERIALIZABLE` com
  identidade interna/sessão válidas, chamada como authenticated, envelope
  seguro, auditoria e ausência de efeitos. Não alterar isolamento no meio de
  uma transação que já consultou dados.
- Testes sequenciais não provam a janela concorrente. Não há resultado SQL
  GREEN nesta branch. A revisão estática não substitui execução.

# Protocolo Eng1: duas conexões locais reais

Usar somente base nominal local descartável, perfil/hash aprovado e fixtures
sintéticas previamente confirmadas. As fixtures do teste principal são
rollback-only; precisam ser preparadas pelo executor em sua base isolada para
ficarem visíveis às duas conexões. Não remover o rollback do teste de regressão
nem apontar este protocolo a Supabase remoto. Preservar Owner reserva e os
triggers de integridade/last-owner.

Para cada cenário, restaurar fixtures e usar novo request. Registrar IDs de
conexão, isolamento, lock esperado, resposta minimizada e contagens antes/depois.

1. A/postgres: BEGIN READ COMMITTED; segurar o lock alvo da tabela abaixo.
2. B: BEGIN READ COMMITTED; `SET LOCAL ROLE authenticated`, claims sintéticas
   originais; iniciar a RPC assincronamente, sem wrapper que altere identidade.
3. A: confirmar `pg_blocking_pids(pid_B)` contém `pid_A`, além da consulta de B
   e recurso esperados. Timeout sem bloqueio observado é falha de preparação,
   não teste passado. Não depender apenas de sleep.
4. A: revogar membership/AuthLink, ou alterar escopo A→B; COMMIT confirma a
   revogação e libera o lock. B deve continuar com claims originais.
5. B: recolher envelope e COMMIT. A verifica efeitos após esse commit, não
   apenas dentro da transação de B. Em falha, registrar erro e fazer rollback.

| Lock segurado por A | Operação de B |
| --- | --- |
| advisory `hashtextextended(request_id::text,6404)` | Create e replay existente |
| advisory `hashtextextended(form_id::text,0)` | Edit, replay e create com ID explícito inexistente |
| linha forms `FOR UPDATE`, sem advisory | Edit bloqueado no `FOR UPDATE` |
| linha forms `FOR UPDATE` | Reader bloqueado no `FOR SHARE` |
| linha institutions `FOR UPDATE`, sem alterar forms | Create/edit/replay/reader bloqueados no `FOR SHARE` institucional |

Repetir os pontos com membership revogada, AuthLink revogado e perda de escopo.
Adicionar substituição por outra membership válida: comparação das âncoras deve
negar migração silenciosa. Reader manage que perde manage não troca para read;
reader inicialmente read-only conserva read. Testar perda da capability efetiva.

Esperado: erro de autorização nominal (`SAI_MEMBERSHIP_REVOKED`,
`SAI_INTERNAL_CONTEXT_DENIED` ou capability negada conforme a mutação), data null,
nenhuma nova mutação/receipt, nenhum audit success, uma negativa correlacionada
quando identificável. Snapshot antigo não pode aparecer em corpo ou log.

Para exclusão concorrente, A mantém `institutions FOR UPDATE`, B deve chegar ao
lock institucional; A define deleted_at e COMMIT. B nega com
`SAI_PERMISSION_DENIED`, sem snapshot/efeito. Controle: A só libera o lock sem
revogação/exclusão, e B prossegue normalmente. Depois que B obtém SHARE, um
UPDATE institucional de A deve esperar B terminar; isso protege a elegibilidade
até a devolução do snapshot/transação, não muda políticas de histórico.

# Races de idempotência/versão

1. A executa save e mantém transação aberta; B chama mesmo request/payload.
   Após commit A, B recebe snapshot original: uma mutação, um receipt e um
   sucesso auditado por chamada.
2. Mesmo request com payload diferente: B recebe INVALID_ARGUMENT; A intacto.
3. Requests distintos, mesma versão/form: B recebe CONCURRENT_CHANGE após A;
   incremento único e nenhum receipt da tentativa perdedora.
4. A executa e faz rollback: B prossegue como primeira execução, sem resíduo A.
5. Replay antigo após revisão nova: B devolve receipt original autorizado,
   não substitui por reload recente.

Reautorização pós-espera fecha a janela testada, não serializa toda revogação
futura contra cada instrução da transação. O ponto de autorização e os locks
observados devem constar da evidência do executor.

O helper compartilhado preservado valida `auth.sessions.not_after` usando
`now()` (início da transação). Após a ressalva, o Coordenador autorizou fechar
temporalidade **nominalmente**: as três reautorizações pós-espera agora consultam
também a sessão original, vinculada ao auth_user original, e exigem
`not_after IS NULL OR not_after > clock_timestamp()`. Ausência ou expiração
produz SESSION_INVALID, sem mudar Auth global nem a semântica NULL vigente.

RED sequencial preparado usa not_after entre início da transação e relógio
corrente. Assim o helper antigo aceitaria, mas reader/create/edit/replay nominais
devem negar; verifica ausência de snapshot/efeitos e auditoria por correlação.
Controle NULL permite leitura. Nenhum SQL foi executado nesta preparação.

Protocolo temporal adicional Eng1: publicar fixture com not_after curto, porém
futuro; A segura cada lock da matriz, B inicia antes de not_after e fica
comprovadamente bloqueado. A consulta clock_timestamp/not_after até ultrapassar
o limite, sem alterar a sessão e sem usar apenas sleep como prova, então libera
o lock. B deve negar SESSION_INVALID, com mesmas asserções de ausência de
snapshot, escrita, receipt e sucesso auditado. Repetir reader/create/edit/replay
nos locks aplicáveis. Controle libera antes da expiração e deve passar; controle
not_after NULL também passa. Registrar relógio antes/depois e isolamento de B.

Revisões independentes do código e dos testes não encontraram novo bloqueante
estático. Os arquivos de isolamento reutilizam fixtures rollback-only e devem
executar serialmente. Isso não altera o status prepared-not-executed.

# Memória

Correção de invariantes já aprovadas, sem nova regra de produto. Fontes canônicas
da política foram preservadas. O delta e hashes seguem ao Coordenador; nenhuma
projeção de conhecimento é criada apenas para registrar atividade.
