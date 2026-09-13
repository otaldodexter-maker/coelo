---
source: Owner 2026-09-13 — preparar disparo independente e supervisionar retomada em Luna reserva médio; CLI 0.154.0 e testes locais reais
status: preparado e testado; R12 e R13 ainda não iniciadas
generated_at: 2026-09-13
---

# Disparo independente R12 → R13 e reserva Luna

## Retomada autorizada após o primeiro fechamento

Pedido posterior do Owner: mesmo thread visível na interface, normal até99% e
depois reserva Luna. Executar `arm --resume-thread 01a09bd2-3ba1-7761-96a5-0ef1c4a33eba --normal-threshold 99`
e o release habitual após publicação/gate. O histórico desta primeira espera
fica preservado; novo run tem estado próprio. Quinze testes PASS. A reserva da
execução anterior foi antecipada por needs_reserve com normal95%, não por
esgotamento; retry.reason agora distingue limite real, threshold e pedido de
checkpoint. Fonte vigente: R13-retomada-cota-owner.md, incluindo reserva até99%, extensão Etapa2 e preparação R14 Claude Opus médio.

O Owner autorizou a passagem automática após o fechamento da R12 e a retomada
da sessão Luna na reserva se parar por consumo. Esta instrução específica
substitui a proibição histórica de iniciar R13 automaticamente; não muda
autorizações remotas, escopo de produto ou a proibição de iniciar Etapa 3.

## Funcionamento

`r12-luna-dispatch.py` cria um processo Python independente e sem janela.
Espera por até 12h sem chamar modelo; não é uma tarefa agendada recorrente.
O estado privado fica fora do Git em
`C:/Users/adrie/Documents/Coelo-backups/r12-luna-dispatch/`.
`current.json` aponta a execução real; `test-current.json` aponta somente o teste.
Cada execução recebe UUID, PID, sinal próprio e claim exclusivo.

Espera real armada nesta preparação: run 32e2492208434a1dac9aa6adeae1ca04,
Python PID 11180, status waiting confirmado. Expira em 14/09/2026 às 01:40:50
de Brasília (04:40:50 UTC). Esses dados são um snapshot: consultar status e
processo na abertura; não presumir que continuem vivos após reinício.

Na abertura da R12, verificar `status`. `arm` reaproveita espera ativa, mas não
rearma uma execução concluída automaticamente. Se expirar, cancelá-la/armar
uma nova espera conscientemente antes de trabalhar. Não aceitar status antigo
como prova de processo vivo: conferir o PID. Uma parada do computador ou do
supervisor não dispara recuperação de posse por suposição.

Ao fechar R12, seu último comando é `release --release-writer`. O script exige
fechamento com status encerrada, recibo da transferência R13, dev limpo,
HEAD=origin/dev após fetch e delivery_gate.py aprovado. O watcher confere tudo
novamente e só então executa o prompt R13-luna-continuacao.md em Luna médio.
C0 R12 não pode escrever nem deixar comandos de escrita/testes pendentes após
essa liberação explícita. O controle não bloqueia um humano que escreva fora
desse protocolo: respeitar a posse publicada.

O supervisor acompanha os eventos até o processo terminar e registra heartbeat
durante períodos sem eventos. Não interpreta silêncio como fim e não inicia
outro escritor enquanto o CLI está vivo. O prazo global da R13 é de 3h de
execução +30min de fechamento, compartilhado pelas duas fases. O agente recebe
o prazo; o supervisor sinaliza extrapolação no heartbeat, sem matar comandos
de banco ou descartar WIP automaticamente.

Se houver falha classificada como limite de uso, ou encerramento voluntário
com `continuation.json` em needs_reserve, consulta
`account/rateLimits/read` com `supportsLunaReserve: true`. Só permite UMA retomada
do mesmo thread com `gpt-reserve`, esforço medium, quando o serviço retornar
esse alias associado a gpt-5.6-luna e todos os seus windows estiverem abaixo
de 95% usados. A reserva usa o teto conservador específico do prompt R13.
Outro erro, bloqueio externo ou fechamento normal não dispara repetição.
Se a retomada também falhar, preservar estado e parar. Não comprar créditos,
resgatar reset de cota, trocar para API paga nem repetir indefinidamente.

## Operação

Todos os comandos partem do repositório e usam este prefixo:

```text
rtk proxy python docs/reviews/etapa-2-operacao/next-round/r12-luna-dispatch.py
```

Acrescentar `status`, `quota`, `arm` ou `cancel`. `cancel` cancela somente a
espera pendente, não mata uma execução ativa. `release --release-writer` é
exclusivo do C0 que acabou de fechar R12. Nunca usá-lo nesta preparação.

`status` informa diretório/estado. Dentro dele: config.json (prazo de espera),
status.json (PID/resultado), child.json (PID/modelo do CLI), heartbeat.json,
events.jsonl (somente tipos, thread ID e consumo), retry.json e leituras de
cota. Não guardar respostas completas, stderr, credenciais ou links de Auth.
`finished` significa que o processo terminou, não certifica o produto: conferir
exitCode, turnCompleted, failure e os documentos de fechamento do agente.

Para interromper trabalho já iniciado: identificar seu PID em child.json e
encaminhar uma interrupção ao processo correto, preservando checkpoint e
identificando seus comandos em andamento. Não matar todos os Python, Chrome,
Dart ou Codex do computador. Nenhum supervisor continua se o computador for
desligado; manter energia, conexão e suspensão desativada durante a execução.

## Evidências e limites

- CLI atualizado de 0.141.0 para 0.154.0 pelo atualizador oficial.
- Luna médio: LUNA_HANDOFF_OK; retomada por ID/contexto: LUNA_RESUME_OK.
- Reserva real: serviço retornou limitName=gpt-reserve,
  normalModelSlug=gpt-5.6-luna, 17% usados na leitura de preparação; cota normal
  93%. São leituras históricas, não saldo prometido para a execução.
- Chamada real `gpt-reserve` médio: LUNA_RESERVE_OK, exit 0.
- Watcher separado recebeu sinal de teste, disparou Luna e terminou exit 0,
  turnCompleted=true, testPassed=true. Run de teste:
  d85d021bee2b46a68bda3ffec660d639; thread 01a09ba2-2317-79d1-abae-ec57b8bff6a8.
- O mesmo thread foi retomado pelo comando do supervisor com gpt-reserve
  médio: exit 0, turnCompleted=true, testPassed=true.
- Nove testes unitários passaram: sinal/mode, gate, cancelamento, claim único,
  fim normal, outra falha, reserva ausente, limite e pedido voluntário.
- Não foi provocado esgotamento real da cota. A classificação/retomada por
  limite passou em fixture; chamadas normal/reserva e retomada passaram reais.
- Nenhuma correção de produto, SQL, deploy ou aceite FE/BE/E2E nesta preparação.
  Inventário e três rastreadores preservam seus 231 IDs e estados.

Memória: no-op de projeção. Esta automação específica de rodada fica na fonte
operacional; não altera regra permanente de produto, segurança ou autorização
remota. R12/R13 continuam pendentes até execução e provas reais.
