---
fonte: apps/superadmin/lib/features/groups e contrato superadmin_group_location_create_v2
status: implementado localmente; teste Flutter pendente de slot
data: 2026-09-12
rodada: E2-R08-20260912
---

# Turmas — Local catalogado

O formulário de criação de Turma agora oferece seleção de Local do catálogo da unidade. Quando há seleção, ele cria a Turma pelo RPC atômico autorizado e continua o `saveComposition` com o mesmo `group_id` e versão devolvidos. O recibo é retido no estado para que retry não duplique a criação; trocar/remover a seleção invalida o recibo e o request pendente.

Guardas no cliente são apenas composição e consistência: criação somente, catálogo da unidade selecionada e repositório habilitado. Tenant, unidade, hierarquia, autorização e a transação continuam validados no RPC.

Verificação realizada: `dart analyze` focal de `group_form_page.dart`, router, `SuperadminApp` e `main.dart` — PASS, sem issues. Teste de widget e rota real aguardam a fila Flutter/Chrome; nenhum action_id foi promovido.
