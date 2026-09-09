---
source: "D00 R16; auth-password-transport-review.md; Supabase CLI v2.116.0 official source"
status: "proposal only; canonical patch not applied; local qualification not executed; remote blocked"
generated_at: "2026-09-09"
---

# Atomicidade SQL e ledger: proposta subordinada a D00

O transporte atual não oferece atomicidade entre DDL e ledger. A CLI 2.116.0
detecta controle transacional no arquivo e executa seus statements
sequencialmente; o COMMIT autoral ocorre antes do INSERT do histórico.
Sem esse controle, a CLI prepara SQL e INSERT no mesmo batch. Essa diferença
está na [fonte oficial fixada, linhas 630–748](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-migration-apply.ts#L630).
O driver usa um Sync para esse batch; atomicidade por arquivo ainda exige
qualificação local discriminante, conforme a
[implementação do driver](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-db-connection.sql-pg.layer.ts#L297).

Direção ativa: revisar os dois arquivos canônicos ainda não implantados,
retirando somente seus BEGIN/COMMIT externos. O patch
`proposed-cli-atomic-boundaries.patch` contém quatro remoções, sem alterações
nos guards, corpos, SET LOCAL, advisory locks ou nomes. Está somente em
evidência: não foi aplicado durante a execução SQL de D00.

| Versão | SHA256 atual no WT (LF) | SHA256 proposto (LF) |
| --- | --- | --- |
| 20260909173000 | a57e3f85c3906f2e83f28ae90bfbfd58e10bed6a25afa8352019df0210342bd8 | 0b52cbd9b189076333356a83f2aea23cea3038d3fde1b867a0aec24589fadd92 |
| 20260909173100 | f47f96d4f1c7cab124a2a7608c50bf5cfbcc11e4fd502ab90c8893657166f863 | e53626a08ca558353bcbc3adc217ec14974176288efc18535275830ddd48f1a2 |

É uma revisão de payload, portanto os bytes anteriores não são preservados.
Não remover os delimitadores apenas no staging. Após reserva explícita,
atualizar a fonte canônica, hashes RAW/LF, commit e provas correspondentes.
Dois arquivos continuam sendo duas transações: 173000 aplicada e registrada
com 173100 falha/ausente é um estado parcial possível, a reconciliar
forward-only. Não afirmar atomicidade conjunta.

A ideia anterior de preservar bytes com adaptador próprio que inserisse
ledger antes do COMMIT foi **rejeitada como direção ativa**, pois D00 exige
reutilizar a CLI existente e não criar plataforma de deploy paralela. Não há
adaptador implementado, qualificado ou proposto para execução.

## Qualificação local preparada, ainda não executada

`Test-ProposedCliLedgerAtomicity.ps1` é uma proposta focal para D00 revisar.
Exige slot local explícito, raiz TEMP coelo_safe exata, marcador de conteúdo
idêntico, ausência de reparse points, identidade config correspondente,
ausência de vínculo remoto e diretório de migrations vazio. Exige também
container exato e ledger já inicializado e vazio. Não pode ser apontado ao
replay de produto ativo nem inicializa/para containers.

O dono do slot deve fornecer um stack descartável exclusivo inicializado
pela CLI 2.116.0, sem migrations de produto, e garantir stop sem backup e
verificação zero recursos no finally externo. Só nesse contexto:

```powershell
& ./Test-ProposedCliLedgerAtomicity.ps1 `
  -ProjectRoot $ownedDisposableRoot -ProjectId $ownedDisposableId `
  -ExecuteInAuthorizedLocalSlot
```

O script usa a CLI existente `db push --local --skip-vault`, com fixture
nominal 20990909000100 contendo SET LOCAL, advisory lock e DO com DDL,
sem controle transacional externo. Um trigger local rejeita exclusivamente
o INSERT dessa versão com erro sentinela. Gate 1 exige esse erro específico,
DDL ausente e ledger ausente. Em seguida remove o trigger e repete o mesmo
payload; gate 2 exige DDL e exatamente uma linha version/name/statements.
Saídas brutas ficam em memória. O finally remove trigger/função próprios;
fixture, DDL e ledger de controle ficam juntos para descarte integral pelo
dono do stack, sem migration repair ou exclusão avulsa do ledger.

Esses dois gates são ferramentas de transporte, separados dos 46 gates de
produto. O script ainda requer revisão de D00 e execução no slot autorizado;
parse estático não certifica atomicidade. A prova com fixture qualifica a
forma do executor; a revisão canônica também precisa verificar ausência de
diretivas não transacionais e comandos incompatíveis com batch nos payloads
finais, além das provas de produto na base revisada.

## Pré-condições remotas futuras

O staging nominal deve conter histórico reconciliado e conjunto pendente
exato das duas versões, ambas posteriores ao máximo remoto, sem include-all,
roles, seed ou Vault. A CLI deve permanecer fixada em 2.116.0. Exigir senha
de banco já provisionada em `SUPABASE_DB_PASSWORD`, via secret store e sem
argumento/log, antes de link/fetch/list/dry-run/push. Na ausência da senha,
parar sem fallback: a
[resolução oficial de conexão](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-db-config.layer.ts#L102)
pode criar login role e remover bloqueios de rede no outro caminho.
Nenhuma credencial foi consultada nesta preparação.

## Guards anteriores a recursos, execução local testemunhada

Após a revisão de isolamento, o candidato também nega overrides de conexão
e arquivos `.env*`, exige seção `[db]` e porta explícitas, contexto Docker
Windows por named pipe local e exatamente um binding IPv4 na porta da configuração
no container nominal (127.0.0.1 ou 0.0.0.0, com no máximo um companheiro IPv6
::/::1 na mesma porta). O cliente continua em 127.0.0.1; não aceita IPv6
isolado ou outro endereço. O motivo é que a CLI deriva o host também do contexto
Docker ativo, conforme a
[fonte oficial de hostname 2.116.0](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-hostname.ts).
Esses checks posteriores de contexto/binding ainda não foram executados.
O wildcard IPv4 é aceito porque publica em todos os endereços do host,
incluindo loopback, conforme a
[documentação Docker](https://docs.docker.com/engine/network/port-publishing/#setting-the-default-bind-address-for-containers).

O harness reproduzível `Test-ProposedCliLedgerAtomicityGuards.ps1` executou
26 casos negativos, todos com mensagem exata e contador de fronteira externa
zero, registrados em `transport-atomicity-guards.txt`: ausência do switch,
identidade TEMP errada, marcador trocado, junction física na raiz e no
marcador, migrations ausente/não vazio, 16 overrides de ambiente,
`.env.local`, seção db ausente e porta fora da faixa. O hash do sujeito
testado está no recibo textual. Docker, CLI e SQL: zero chamadas.

As fixtures foram criadas apenas em `%TEMP%/coelo_safe_<guid29>` e seu
irmão próprio `_guard_target`, ambos verificados ausentes antes do teste.
O mecanismo físico foi `New-Item -ItemType Junction`; o marcador testado
era uma junction de diretório, não um symlink de arquivo. Cada link foi
removido por `[IO.Directory]::Delete(link)` sem recursão nem seguir o alvo.
Somente depois de confirmar contenção e ausência de reparse points, o
harness usou `Remove-Item -LiteralPath ... -Recurse` nas duas raízes próprias.
O finally restaurou os valores originais dos overrides de ambiente; não
imprimiu esses valores. Resultado: zero caminhos próprios residuais.

A primeira execução de sete guards precedeu a correção material dos checks
de conexão; a execução atual de 26 substitui as anteriores para o candidato revisado.
Não somar as duas rodadas como cobertura adicional ou resultado de produto.
Após os 26 guards, somente o predicado posterior de binding foi ampliado
conforme revisão e direção do coordenador. O hash testemunhado no log é o
anterior a esse delta; não houve rerun dos guards sem mudança neles. O hash
final deve identificar o candidato entregue, com binding ainda aguardando
qualificação local de D00.

Qualquer resposta ambígua exige reconciliação somente leitura de corpos,
ACLs e versões antes de decidir nova ação. Nenhum repair, retry cego ou
aplicação remota está autorizado por este documento. Bloqueio atual:
reserva da revisão canônica, qualificação local e revisão/aprovação nominal
do pacote final. Knowledge: no-op; não muda política de produto.
