---
title: "Propostas de delta para as skills — R06 · Estrutura"
source: "comunicacao/estrutura.json revs 54–62; handoff.md; candidatos/estrutura 20260912180000/180100/180200"
status: "proposta ao coordenador (escritor central das skills)"
generated_at: "2026-09-11"
---

# Deltas propostos às skills (R06 · Estrutura)

## `coelo-frontend` (`.agents/skills/coelo-flutter-review/SKILL.md`)

- **Rota real pelo Flutter Driver web**: o build de `test_driver/qa_main.dart`
  expõe `window.$flutterDriver(json)` e devolve em `window.$flutterDriverResult`;
  chamar via CDP (`Runtime.evaluate` + poll) dispensa VM Service. Mandar
  `set_frame_sync` com `enabled:'false'` logo após abrir a página, senão o
  caret piscando impede qualquer comando de terminar. `enter_text` vai para o
  campo focado no momento: dar `tap` no campo e esperar ~1 s antes de digitar
  (na R06 a senha foi parar no campo de e-mail). Taps por Key/texto em botões
  logo após digitar falham de forma intermitente; clique por coordenada via
  `Input.dispatchMouseEvent` resolve.
- **Servidor estático da prova**: um processo iniciado com `&` numa chamada
  do Bash morre com a chamada; usar a tarefa em segundo plano da ferramenta.
- **Regra do @ implementada (Decisão 16)**: Unidades (`unit_form_page`),
  Turmas (`group_form_page`, campo `group-handle-field` na etapa Identidade)
  e Atividades (`activity_form_controller.changeHandle`) usam
  `StructureHandleSetter` (auth scope → app → router) sobre
  `superadmin_structure_handle_set_v1`; mensagens de `SAI_HANDLE_COOLDOWN`,
  `SAI_HANDLE_TAKEN`, `SAI_INVALID_ARGUMENT` e `SAI_CONCURRENT_CHANGE` vivem
  em `StructureHandleChange.message`. Identificador de Unidade valida com a
  regra do @ (sem hífen) só quando muda; valor legado com hífen continua
  aceito na edição.
- **Assistente de Atividades e avaliação**: o salvar agregado (`save_v2`)
  não carrega a configuração avaliativa; com "Habilitar avaliação" ligado o
  cliente recusa antes do HTTP e explica que a configuração vive em
  `/activities/:id/assessment-settings`. A configuração avaliativa é a rota
  para criar períodos (o "Nenhum período avaliativo" de `assessments.entry`).

## `coelo-backend` (`.agents/skills/coelo-supabase/SKILL.md`)

- **Ambiguidade variável × coluna em plpgsql**: além de
  `assessment_v2_save_configuration` (R04), `superadmin_assessment_configuration_read`
  respondia `SAI_INTERNAL_ERROR` em produção por `c.institution_id = institution_id`
  (42702). Regra: toda função de 180350 (e qualquer nova) que declare variável
  com nome de coluna usa `#variable_conflict use_variable`; o envelope de
  negativa esconde o SQLSTATE, então a reprodução é no espelho com o corpo
  chamado fora do `begin … exception`.
- **Lista fechada de códigos**: `activity_v2_normalize_error` só deixa passar
  os códigos da lista; um código novo (`SAI_HANDLE_USE_SET`) vira
  `SAI_INTERNAL_ERROR`. Pacote que precisa de código novo em Atividades
  altera a lista (função compartilhada) ou usa `ACTIVITY_INVALID_INPUT`.
- **Chave aditiva em detail_v2**: `superadmin_activity_detail_v2` passa a
  devolver `handle_stem`, `canonical_handle` e `handle_last_changed_at`
  (candidato 180200); o parser do cliente tolera chaves novas desde a R05.
- **Credencial exposta em captura**: senha de `qa-r06-estrutura@coelo.me`
  apareceu numa captura temporária (apagada) às 20:10 por `enter_text` no
  campo errado. Pendência de rotação ao fim da rodada: painel Supabase →
  Authentication → Users → `qa-r06-estrutura@coelo.me` → *Reset password*
  (ou `auth.admin.updateUserById` pela Admin API com a service key só no
  ambiente do processo); gravar o valor novo apenas em
  `Coelo-backups/qa-r06-estrutura.env`.

## `coelo-frontend-backend` (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

- **Prova do @ na régua do MVP**: troca do @ conta como verificada quando a
  rota abre, `set_v1` persiste (versão avança), a segunda troca responde a
  mensagem honesta do servidor e o reload mostra o @ novo; para Atividades o
  reload do campo depende do detail_v2 devolver o @ (candidato 180200).
- **Diretório como prova de persistência**: quando o detalhe não expõe um
  campo, capturar a RPC do diretório (`superadmin_activity_directory_v2`)
  pela aba Network do CDP e registrar o trecho em `.txt` na evidência
  (`activities-directory-handles.txt`), sem cabeçalhos nem tokens.
