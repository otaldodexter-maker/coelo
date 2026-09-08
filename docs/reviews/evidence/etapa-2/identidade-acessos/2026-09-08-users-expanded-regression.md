---
title: "Usuários internos — regressão ampliada e baseline visual aberta"
source: "Execução local Flutter sobre b11c3c3e; investigação systematic-debugging; índice Coelo UI; review account_review; orientação do Coordenador"
status: "functional-local-green; four-visual-tests-red"
generated_at: "2026-09-08"
---

## Resultado e correção mínima

A execução de `test/features/platform_users` com rotas internas de lista,
detalhe e preview produziu 76 PASS e 5 FAIL. Uma falha funcional estava em
`fake_platform_user_repository_test.dart`: exigia 12 instituições, enquanto
o catálogo compartilhado usa cinco desde `d9232a94`. O assert rígido veio de
`c0823f598`. A igualdade exata dos IDs do update já passava.

Mudança restrita ao teste: exigir catálogo não vazio e comparar o tamanho
efetivo, mantendo a igualdade exata com todos os IDs enviados. Não mudou o
repositório produtivo, a fixture compartilhada, Instituições ou autorização.
Review independente `account_review` aprovado: igualdade exata preservada e
catálogo vazio não pode tornar o caso artificialmente verde.

Verificações frescas:

- Repositório fake isolado: 16/16 PASS.
- Regressão funcional abaixo: 77/77 PASS.
- Analyzer do arquivo alterado: sem issues.
- Format com `--output=none --set-exit-if-changed`: zero mudanças.

```text
flutter test --no-pub
  test/features/platform_users/data
  test/features/platform_users/presentation/platform_user_directory_page_test.dart
  test/features/platform_users/presentation/platform_user_detail_page_test.dart
  test/features/platform_users/presentation/platform_user_pages_test.dart
  test/app/router/internal_user_routes_test.dart
  test/app/router/internal_user_detail_routes_test.dart
  test/app/router/platform_user_preview_routes_test.dart
```

## Quatro testes visuais continuam RED

- Diretório: geometria de cards/tabela, matriz de larguras/temas.
- Diretório: hover do card e flyout de filtros.
- Páginas: criar, visualizar e editar.
- Detalhe: flyout de ações do Owner protegido.

Os masters foram preservados. Comparação visual de diretório 375 light e
detalhe 1440 dark mostra alterações estruturais de shell/header, fixture,
ação de criação bloqueada e launcher/paginação, não apenas ruído de pixels.
O golden de diretório foi atualizado por último em `61636c33`; mudanças
posteriores de comportamento/fixture tornam a falha insuficiente para atribuir
regressão ao pacote atual. A origem de cada divergência visual ainda precisa
ser reconciliada, sem restaurar comportamento bloqueado para imitar um PNG.

O Coordenador confirmou que não há rebaseline global de Usuários aprovado.
Nenhum `--update-goldens`, edição de shell/router, substituição de master ou
declaração de conformidade visual foi feita. `failures/` contém somente
artefatos diagnósticos transitórios e não é baseline aprovada.

Os 77 testes funcionais não incluem os quatro testes visuais e não provam
backend remoto, persistência/reload real, Cloudflare ou E2E. O warning de mapa
do fixture de formulário foi observado; não houve mudança de provedor.
Gate de memória: no-op, apenas correção de teste e proveniência da evidência.
