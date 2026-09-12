# Correcao G7 - snapshot de Local da Turma

- Data: 2026-09-12
- Escopo: `groups.location`, posse temporaria de `group_form_page.dart` e seu
  teste de apresentacao.
- Fora do escopo: SQL, Chrome, nova fixture, alteracao de recibo e rastreadores.

## Defeito e correcao

Ao remontar o seletor com outra fonte, o mesmo ID e escopo podiam retornar com
`label` ou `kind` atualizados. O formulario tratava toda essa combinacao como
no-op e retinha o snapshot antigo. Agora, para a mesma identidade, ele atualiza
somente o snapshot quando esses metadados mudam. Nao limpa o recibo de create,
request ID, fingerprint, save pendente ou contexto; identidade e metadados
iguais continuam no-op.

## Prova focal

O teste atomico existente agora substitui o leitor durante uma composicao
pendente, devolve o mesmo local/escopo com label e tipo novos, muda de etapa e
exige o snapshot renovado. Ele tambem preserva a afirmacao de apenas uma chamada
de create no retry.

- RED: falhou como esperado, esperando `Patio atualizado` e recebendo
  `Sala de leitura`.
- GREEN: `flutter test test/features/groups/presentation/group_form_page_test.dart --concurrency=1 --plain-name "keeps the atomic group receipt through a failed composition retry"` — 1/1 PASS, exit 0.
