---
source: R09-prompts.md; coordenação R09 revisão 91; SDK Flutter local; observação CUA
status: blocked-runtime-cause-identified
generated_at: 2026-09-12
---

# G0 — runtime R09

Checkpoint 15:25 BRT; base `d262eef09`, worktree/branch R08 preservadas e
atualizadas por fast-forward, sem WIP sobrescrito. Recorte: apps/superadmin →
entrada/login → entrada de texto; dependência compartilhada, sem novo action_id.
Objetivo: login, leitura autorizada e reload utilizáveis; depois espelho por
posse serializada. Janela inicial de diagnóstico até 15:47; estimativa da
correção depende do build/probe autorizado pelo C0.

## Medição e tentativas

Servidor `127.0.0.1:3014`, PID 7476, GET `/login` 200. Chrome raiz 22592,
aba 829822454. Baseline `supabase_db_coelo_baseline` running/healthy, porta
57322. RAM livre 2.065.644 KiB (~1,97 GiB); nenhum processo identificado como
Flutter test. Slot Flutter livre no JSON central, sujeito à posse C0.

Artefato R08 retido: source `e2769f7beff5215e9a3cc7988c15d1de6784b523`,
main.dart.js SHA256 `f3f2a3e8a0d563dfa9e1b640d458496d972e9ad7b4bbf2db236434ec70e278b3`
recalculado igual. Não houve rebuild, SQL ou novo processo.

Após Enable accessibility, semântica expõe E-mail, Senha, Entrar. Duas
tentativas usando texto sintético `runtime-probe`, sem credenciais/submissão:
1. `setValue(E-mail)` seguido de Tab: campo sem valor; foco muda para Senha.
2. `click(E-mail)` + `paste(text)` + Tab: campo continua sem valor.

Login/leitura/reload não comprovados. C0 recebeu causa e assumiu Chrome;
não repetir tentativas. APIs documentadas disponíveis: setValue, typeText,
pressKey, paste; locators fill/press/pressSequentially; clipboard read/write.
Evaluate do navegador é somente leitura. Nenhum bypass ou injeção de sessão.

## Causa provável no código e próximo gate

`apps/superadmin/test_driver/qa_main.dart:18` chama
`enableFlutterDriverExtension()` sem argumentos. O SDK instalado em
`C:/src/flutter/packages/flutter_driver/lib/src/extension/extension.dart:246`
define `enableTextEntryEmulation=true`; linhas 372–373 registram o mock.
As linhas 117–121 documentam explicitamente que false permite teclado real
e desabilita enterText do Driver. `flutter_test/lib/src/test_text_input.dart:64`
registra o mock em SystemChannels.textInput.

O login passa controllers normalmente: `login_text_field.dart:46` →
`packages/coelo_ui_core/lib/src/input/coelo_form_text_field.dart:94–96`
(`TextFormField`). Hipótese causal forte: o entrypoint QA substitui o canal
do teclado usado pela automação real. Confirmar com build QA sem emulação
de texto e probe pela mesma aba. Correção proposta restrita ao harness,
sem alterar Auth; C0 decide atribuição/build. Prova runtime pós-correção pendente.

Memória: no-op na projeção; causa ainda aguarda confirmação experimental.
Sem deltas de estado ou certificação funcional.
