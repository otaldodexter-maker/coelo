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

## Reprodução do limite atual

1. Manter o servidor estático PID `16248` em `127.0.0.1:3014` e a aba Chrome `829822454` em `/login`.
2. Consultar `dtd.listDtdUris`: retorna que não existe processo debug/DTD.
3. Observar que `qa_drive.dart` exige como primeiro argumento o WebSocket CDP da página; a aba CUA não o expõe.
4. Focar `superadmin-login-email`, aplicar `setValue`, `paste` ou `typeText` e submeter.
5. Resultado atual: validação `Informe seu e-mail.`, campo vazio e nenhuma requisição Auth.

## Procedimento suportado para uma próxima sessão

Este procedimento exige posse nominal do runtime e substitui temporariamente o servidor; não foi executado nesta investigação:

1. Reutilizar a mesma aba Chrome, sem abrir outra.
2. Depois de o C0 liberar a troca, parar somente o servidor estático PID `16248`.
3. Iniciar o app sem lançar navegador, no mesmo host/porta, com o entrypoint QA e ambiente já ignorado pelo Git:

   ```powershell
   flutter run -d web-server -t test_driver/qa_main.dart --web-hostname=127.0.0.1 --web-port=3014 --dart-define-from-file=.env.local
   ```

4. Recarregar a mesma aba CUA em `http://127.0.0.1:3014/login`.
5. Consultar `dtd.listDtdUris`; somente se houver URI, executar `dtd.connect` e `dtd.listConnectedApps`.
6. Somente se o app aparecer, usar `flutter_driver_command` com `ByValueKey`: `superadmin-login-email`, `enter_text`, `superadmin-login-password`, `enter_text`, manter sessão e `Entrar`.
7. Provar URL fora de `/login`, leitura autorizada e reload na mesma aba.
8. Se o app web-server não aparecer no DTD, parar. Não abrir Chrome por shell, não usar CDP alternativo e não injetar sessão/localStorage.

Esse é um candidato suportado pelas ferramentas existentes; não há alegação de que funcionou até uma sessão futura completar os passos 3–7.
