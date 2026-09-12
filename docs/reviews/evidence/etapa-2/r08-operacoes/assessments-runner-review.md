# Revisao G7 - executor de Avaliacoes

- Data: 2026-09-12
- Escopo: leitura de `9573aec0d` contra o contrato SQL e preflight G7 anterior.
- Fora do escopo: executar o runner, mutacao, Flutter, SQL e editar arquivos G1.

## Bloqueios encontrados

1. O periodo de `_execution_plan` usa `year`, `starts_at`, `ends_at` e
   `time_zone`. O contrato SQL exige `academic_year`, `starts_on`, `ends_on` e
   `timezone`. O save da configuracao e rejeitado como input invalido antes de
   qualquer verificacao de replay.
2. A recuperacao apos falha parcial nao e possivel. O manifest e escrito antes
   do save, mas uma nova invocacao recusa manifest existente; se o save tiver
   persistido e a ativacao falhar, a tentativa seguinte tambem para em
   `configuration_already_exists`. Ao final, o runner ainda sobrescreve o plano
   e estado de executor com um resumo `enabled: false`.
3. O dry-run aceita apenas `len(assignments) == 1`; nao valida o
   `assignment-id` alvo. Um segundo vinculo visivel invalida o preflight mesmo
   se o alvo QA correto existir. O ACK tambem apenas testa que um caminho foi
   fornecido, sem validar seu conteudo ou autoridade.

## Condicao de retomada

Antes de executar, corrigir os nomes do payload e introduzir resume seguro:
manifest redigido preserva plano/request IDs; rele o alvo exato; reconcilia
configuracao, versao e estado autoritativos antes de retomar. Sem isso, o
replay do mesmo request ID nao cobre a falha entre comandos distintos.
