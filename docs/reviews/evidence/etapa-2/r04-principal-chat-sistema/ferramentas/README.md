---
title: "Ferramentas da rota real do grupo principal-chat-sistema (R04)"
source: "scratchpad da sessao coelo-11, 11/09/2026, 02:00-04:00"
status: "referencia; sem credencial embutida"
generated_at: "2026-09-11"
---

# Ferramentas da rota real (R04, principal-chat-sistema)

Scripts usados para provar Cardapios, Principal e Chat pela tela real com a
sessao `qa-r03@coelo.me`. Nenhum deles contem credencial: o login le
`QA_EMAIL`/`QA_PASSWORD` do ambiente pelo `test_driver/qa_drive.dart` do app.

| Arquivo | Uso |
| --- | --- |
| `serve.py <build/web> <porta> [host]` | servidor estatico com fallback de SPA e `Cache-Control: no-store` para o build de `test_driver/qa_main.dart` |
| `cdp_eval.dart <ws> <js>...` | avalia expressoes JS na pagina (diagnostico: `typeof window.$flutterDriver`, `localStorage`) |
| `cdp_console.dart <ws> [segundos]` | recarrega a pagina e imprime console e excecoes (foi assim que apareceu o assert de `Supabase.instance`) |
| `cdp_net.dart <ws> <url ou -> [segundos]` | navega e imprime as respostas de `/rest/v1/` e `/functions/v1/` com corpo truncado, sem cabecalhos (foi assim que apareceu o PGRST202 de `list_my_principal_contexts`) |
| `cdp_sem.dart <ws> enable|dump|click|clickxy|type|key|goto|reload|shot|eval|texts` | dirige a pagina pela arvore de semantica e por `Input.dispatchMouseEvent`; `type` (Input.insertText) NAO entra em campo Flutter, usar `enter_text` do driver |
| `cdp_close.dart <ws do browser>` | `Browser.close` para fechar o Chrome dirigido |
| `qa.sh` | atalhos (`ws`, `drv`, `sem`, `go`, `shot`, `login_qa`, `texts`); ajustar `S`, `APP`, `EV`, `PORT` e `BASE` |

Sequencia que funcionou (ver JSON do grupo, rev 17, `mini_revisao_0400.ambiente`):

1. `flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local`
2. `python serve.py apps/superadmin/build/web 3009 127.0.0.1`
3. Chrome com `--remote-debugging-port=9409 --use-angle=swiftshader --user-data-dir=<perfil isolado>`
4. `qa_drive.dart <ws> goto http://127.0.0.1:3009/login` e `login` (credencial no ambiente)
5. cliques por `cdp_sem.dart clickxy`, texto por `qa_drive.dart cmd command=enter_text text=...`, capturas por `shot`
6. ao terminar: `cdp_close.dart` e parar o servidor
