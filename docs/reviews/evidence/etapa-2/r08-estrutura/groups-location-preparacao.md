---
fonte: apps/superadmin/lib/features/groups e contrato superadmin_group_location_create_v2
status: teste focal verde; rota real pendente de Chrome
data: 2026-09-12
rodada: E2-R08-20260912
---

## Revisão de retry

O parecer independente sobre `0fcd66dc4`, `caebaf6f9`, `34aa368c9` e `988038de8` não encontrou defeito concreto. O teste cobre troca real de Unidade B para A depois de falha parcial, preservando Unidade/Local B, uma única criação, `group_id`/versão do recibo e nome atualizado. A execução Flutter alcançou o último caso, mas não encerrou o processo; permanece inconclusiva, não certificada como PASS.

## Checkpoint de retry

Em 12/09, `flutter test test/features/groups/presentation/group_form_page_test.dart --concurrency=1` passou 28/28, exit 0. O novo cenário cobre criação atômica bem-sucedida, falha parcial de `saveComposition`, edição do nome, tentativa bloqueada de troca de unidade e retry com o mesmo `group_id`/versão e apenas uma chamada de criação. `dart analyze` focal passou sem issues. Chrome/rota real permanecem pendentes.

# Turmas — Local catalogado

O formulário de criação de Turma agora oferece seleção de Local do catálogo da unidade. Quando há seleção, ele cria a Turma pelo RPC atômico autorizado e continua o `saveComposition` com o mesmo `group_id` e versão devolvidos. O recibo e o `request_id` são retidos por fingerprint do formulário para que retry não duplique a criação, inclusive quando uma falha ocorre antes da resposta; trocar/remover a seleção ou mudar o formulário invalida ambos e o request pendente.

Guardas no cliente são apenas composição e consistência: criação somente, catálogo da unidade selecionada e repositório habilitado. Tenant, unidade, hierarquia, autorização e a transação continuam validados no RPC.

Verificação realizada: `dart analyze` focal de `group_form_page.dart`, router, `SuperadminApp` e `main.dart` — PASS, sem issues. `flutter test test/features/groups/presentation/group_form_page_test.dart --concurrency=1` — 27/27 PASS, PID 26092, exit 0. A primeira expectativa do novo teste assumia contexto vazio; a fixture já seleciona instituição/unidade e renderiza corretamente o seletor, então a expectativa foi corrigida e o rerun focal passou. Rota real/Chrome ainda aguarda recurso; nenhum action_id foi promovido.
