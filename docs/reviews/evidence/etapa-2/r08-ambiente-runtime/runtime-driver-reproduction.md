---
title: "R08 G0 — limite do driver no Chrome compartilhado"
source: "apps/superadmin/test_driver; Dart MCP; bloqueio automático da execução G0"
status: "diagnóstico e reprodução"
generated_at: "2026-09-12T11:20:00-03:00"
---

# Limite do driver no Chrome compartilhado

## Resultado

O build release estático entregue em `127.0.0.1:3014` não tem uma conexão DTD/VM Service ativa. O Dart MCP oferece comandos de Flutter Driver, mas eles exigem um app conectado. A consulta suportada `dtd.listDtdUris` respondeu literalmente:

```text
No running debug processes or DTD process were found, try starting up your app from your IDE, `flutter run`, `dart run`, or connecting to it with `flutter attach`.
```

Logo, o Dart MCP não consegue dirigir a aba release atual. Isso é uma limitação de topologia da sessão, não uma negativa de autorização do Owner.

## Caminhos existentes no repositório

- `test_driver/qa_main.dart` liga `enableFlutterDriverExtension()` e usa a mesma composição do app.
- `test_driver/qa_drive.dart` conecta obrigatoriamente a um WebSocket CDP, chama `Runtime.evaluate` e então usa `window.$flutterDriver`. Sem endpoint CDP ele não inicia.
- `test_driver/qa_login.dart` conecta diretamente ao VM Service e chama `ext.flutter.driver`; requer URI `ws://.../ws` de um app debug ativo.
- O comando Dart MCP `flutter_driver_command` implementa `enter_text`, `tap`, `waitFor`, `get_text`, screenshot e demais operações, mas também requer app conectado por DTD/VM Service.

A documentação histórica confirma que `Input.insertText`/digitação CDP comum não entra em campo Flutter quando a extensão emula entrada. O texto deve chegar por `enter_text` do Flutter Driver. Isso explica por que `setValue`, `paste` e `typeText` da aba CUA mantiveram o controller vazio.

## Bloqueio automático inicial

Origem: retorno do `exec_command` do Codex ao tentar iniciar Chrome com `Start-Process` e `--remote-debugging-port=9414`. Texto útil literal do retorno:

```text
exec_command failed: CreateProcess { message: "Rejected(... rejected: blocked by policy)" }
```

Foi uma rejeição automática da política da ferramenta antes da criação do processo. Não foi pedido de aprovação, negativa do Owner, falha do Chrome ou porta ocupada. Depois dela, nenhum browser foi iniciado por shell e o fluxo seguiu apenas pela integração CUA autorizada.

## Reprodução do limite no build release

1. Manter o servidor estático em `127.0.0.1:3014` e a aba Chrome `829822454` em `/login`.
2. Consultar `dtd.listDtdUris`: retorna que não existe processo debug/DTD.
3. Observar que `qa_drive.dart` exige como primeiro argumento o WebSocket CDP da página; a aba CUA não o expõe.
4. Focar `superadmin-login-email`, aplicar `setValue`, `paste` ou `typeText` e submeter.
5. Resultado atual: validação `Informe seu e-mail.`, campo vazio e nenhuma requisição Auth.

## Tentativa autorizada com app debug

O C0 liberou nominalmente a troca temporária do servidor. O procedimento foi executado sem abrir outro navegador:

1. Reutilizar a mesma aba Chrome, sem abrir outra.
2. Parar somente o servidor estático PID `16248`.
3. Iniciar o app sem lançar navegador, no mesmo host/porta, com o entrypoint QA e ambiente já ignorado pelo Git:

   ```powershell
   flutter run -d web-server -t test_driver/qa_main.dart --web-hostname=127.0.0.1 --web-port=3014 --dart-define-from-file=.env.local --no-pub
   ```

4. Recarregar a mesma aba CUA em `http://127.0.0.1:3014/login`.
5. O DTD foi encontrado no PID `33640`, e o app apareceu conectado em um VM Service local na porta `65121`; os tokens efêmeros das URIs não são registrados.
6. Tentativa material 1: `qa_login.dart` conectou ao VM Service, mas `ext.flutter.driver waitFor` terminou com `Unexpected DWDS error ... Unexpected null value`, exit `255`. Nenhuma chamada Auth foi emitida.
7. Tentativa material 2: o Dart MCP conectou ao mesmo app, mas `flutter_driver_command get_health` respondeu que a extensão Flutter Driver não estava habilitada. O próprio `flutter run -d web-server` avisou que esse dispositivo exige a extensão Dart Debug Chrome para depuração; ela não existe no Chrome compartilhado.
8. O servidor debug foi encerrado de forma limpa. O build release foi restaurado no mesmo endereço, agora no PID `33856`, e a mesma aba foi recarregada.

Também foi repetido um probe sanitizado pelo locator semântico nativo da integração CUA: `getByRole("textbox", {name: "E-mail"}).fill(...)`, seguido de `press("Tab")`. O foco permaneceu no campo de e-mail e o submit exibiu `Informe seu e-mail.` e `Informe sua senha.`. Os equivalentes `click(7)` + `pressKey("CTRL+A")` + `typeText(...)` + `pressKey("TAB")` e `setValue(7, ...)` tiveram o mesmo resultado: a camada semântica recebe a ação, mas o controller Flutter não recebe o valor. Foram usados apenas valores sentinela sem credenciais nesse probe.

Conclusão: as duas rotas suportadas disponíveis foram esgotadas. Para concluir login/leitura/reload é necessário reutilizar a aba em um Chrome que já tenha a extensão Dart Debug, ou um endpoint CDP nominalmente permitido. Não abrir outro navegador, não injetar sessão/localStorage e não confundir HTTP 200 com prova E2E.

## Isolamento por instrumentação QA temporária

Por solicitação do C0, um último probe diferenciou hit-testing/foco de entrada de texto. Foram adicionados temporariamente listeners aos dois `TextEditingController` e `FocusNode`, ativos somente pelo `test_driver/qa_main.dart`. A telemetria registrou apenas nome do campo, foco, `nonEmpty` e comprimento; nenhum conteúdo ou segredo.

Na captura de 1920 x 1032, `click([960, 434])` atingiu fisicamente o centro do campo de e-mail. A sequência `pressKey("CTRL+A")`, `typeText(sentinela)` e `pressKey("TAB")` produziu:

```text
QA_INPUT field=email focused=true nonEmpty=false length=0
QA_INPUT field=email focused=false nonEmpty=false length=0
QA_INPUT field=password focused=true nonEmpty=false length=0
DOM email length=0; password length=0
```

Uma tecla individual `pressKey("A")` no campo de senha também manteve DOM e controller em comprimento zero, sem novo evento de mudança. Assim, o clique por pixel e a navegação de foco funcionam; o canal de inserção de texto da extensão CUA não gera entrada consumível pelo input/engine Flutter. Não é falha de coordenada, locator ou controller específico do formulário.

A instrumentação temporária foi removida por completo. O build original foi recompilado com exit `0` e voltou exatamente a `8339145` bytes e SHA-256 `4ca0e74024f379b451b78fb36daeca2a09a29445474eacf938266005845e4bf1`. O servidor release foi restaurado na porta 3014, PID `14724`, e a mesma aba `829822454` foi recarregada em `/login`.

Como alternativa final restrita à própria API CUA, foi testado `pressSequentially` pelo locator. `getByRole("textbox", {name: "E-mail"})` alternou entre elemento destacado e timeout; `locator("input")` contou os dois inputs, mas `first().pressSequentially(...)` expirou no gate de actionability. Isso confirma que nem o caminho semântico nem o locator DOM da extensão oferecem um canal de texto acionável para esta superfície Flutter. Não houve repetição adicional, CDP por shell, segundo navegador ou bypass de Auth.
