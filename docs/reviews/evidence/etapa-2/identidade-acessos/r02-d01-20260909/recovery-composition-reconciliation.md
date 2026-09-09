---
title: "R02 D01 - composicao SDK, formulario e encerramento do reset"
source: "coelo_auth_recovery_composition_test.dart; logs locais desta pasta; SDK gotrue 2.26.0 instalado"
status: "local-composition-green; provider-and-e2e-open"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Etapa 2 -> apps/superadmin -> Auth -> Redefinir senha -> callback,
envio e retorno ao login -> auth.reset.

Dois IDs de teste novos no arquivo
`apps/superadmin/test/features/auth/domain/coelo_auth_recovery_composition_test.dart`:

- `success=true`: SDK consome callback recovery; scope nao libera contexto
  produtivo; router apresenta formulario normal; UI envia exatamente um PUT
  com a senha e token capturado; sucesso aguarda confirmacao do logout;
  retorno normal ao login nao repete PUT nem logout.
- `success=false`: PUT confirmado, logout HTTP500; nenhuma mensagem falsa de
  sucesso; feedback informa senha alterada e encerramento nao confirmado;
  SDK removeu sessao local, scope continua sem contexto produtivo; retorno ao
  login e contagens de requisicoes comprovados.

SDK, scope, actions, formulario e router reais; somente transporte HTTP
sintetico. Inicializador retorna cliente SDK controlado, sem Supabase remoto.
Nao prova SMTP, validade server-side do callback, senha persistida nem
revogacao real. Nao e prova de armazenamento browser. Nao reexecuta os 14
testes gerais de recovery/router nem os tres negativos OTP existentes.

## Resultado reconciliado

Plano: 2 IDs; P=2, F=0, B=0, S=0, U=0. Execucao aprovada P/E=2/2;
cobertura do plano 2/2. Isso mede testes, nao percentual de conclusao Auth.

O caso `success=true` passou integralmente, incluindo teardown concluido,
em `recovery-composition-sdk-lifecycle.txt` e novamente em
`recovery-composition-verified.txt`. Essa repeticao ocorreu no lote de correcao
da expectativa do caso false; conta um unico ID. Depois disso, somente false
foi repetido e o sucesso anterior foi reutilizado.
O caso `success=false` passou isoladamente em
`recovery-composition-cleanup-final.txt`: 1/1 PASS, 7s, exit0.
Analyzer final: `recovery-composition-analyze.txt`, sem issues, 16.1s, exit0.
Arquivo formatado com dart format antes da ultima execucao.

## Historico de diagnostico preservado

`recovery-composition.txt`, `recovery-composition-diagnostic.txt`,
`recovery-composition-diagnostic2.txt` e `recovery-composition-final.txt` sao
tentativas interrompidas sem resultado terminal de suite. Diagnostico2 chegou
a todas as assercoes de sucesso e unmount, mas parou no teardown do SDK.
A fixture criava o cliente no relogio fake de testWidgets; a inicializacao
e o encerramento do isolate JSON precisam do ciclo assincrono real.
Criacao e dispose do SDK passaram a usar tester.runAsync. Nenhum cleanup
foi removido e nenhuma alteracao de produto foi feita para contornar a espera.

`sdk-lifecycle` terminou 1PASS/1FAIL: a expectativa inicial de link invalido
na falha de logout estava incorreta. O router preserva a tela montada e o
feedback especifico de encerramento nao confirmado. O caso foi corrigido para
exigir esse feedback, mantendo as negativas e o retorno seguro.
`verified` terminou 1PASS/1FAIL porque uma substituicao via PowerShell com
encoding incorreto nao alterou a expectativa; a edicao foi corrigida via UTF8
e escape Unicode Dart. Somente o caso false foi reexecutado em seguida.
Resultados intermediarios pertencem aos mesmos dois IDs e nao sao somados.

Mensagens RTK sobre hook ausente aparecem como NativeCommandError no envelope
PowerShell dos logs, mas o status efetivo e o exit do comando Flutter indicado
acima. Nao representam falha de teste adicional.

Knowledge: nenhum comportamento de produto novo aprovado; no-op. A evidencia
fecha este aceite local de composicao e deixa qualificacao de provedor/E2E
na matriz nominal D01 sob responsabilidade do coordenador.

## Decisao de camada do principal — 13:33 BRT

Somando esta composicao aos14 casos de router,3 negativas SDK, telas/goldens,
matriz responsiva, teclado e estados de Redefinir ja aprovados e preservados,
D01 propoe **auth.reset verified FE** ao D00. A composicao normal e real; o
double e restrito ao transporte externo, permitido no gate FE da skill.
O gate cliente antes aberto foi fechado. BE/E2E continuam pendentes; nao se
afirma revogacao do provedor nem troca de senha real. Nao promover auth.logout
por este fluxo de recovery: sua saida normal e reload continuam B no browser.


Aceite D00 em 2026-09-09T13:57:12.098713-03:00: R02 D00: FE de redefinição certificado; composição SDK/scope/router/formulário real integrada 0f7b7cf83 e dois casos PASS na base conjunta. Sucesso aguarda logout; falha de cleanup informa resultado parcial seguro. Provas anteriores de estados, teclado, temas e responsividade reconciliadas. Critérios FE aprovados com transporte HTTP sintético fiel. SMTP, senha persistida e revogação real continuam pendentes em BE/E2E.
