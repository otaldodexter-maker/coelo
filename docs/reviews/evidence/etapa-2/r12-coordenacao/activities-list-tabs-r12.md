---
source: R12 C0 — R12-03 activities.list tab naming
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-03 — abas do diretório de Atividades

Recorte: Etapa 2 → `apps/superadmin` → Estrutura → Atividades → diretório →
abas de conteúdo → `activities.list`.

A aba de modelos foi alinhada à decisão do Owner e agora se chama
`Modelos de atividade`; a aba operacional permanece `Atividades`. A posição
abaixo dos filtros, o componente canônico de underline tabs, busca, filtros,
modos cards/tabela, paginação e ações existentes foram preservados. Nenhum
filtro novo, contrato Supabase ou mutação foi inventado.

Provas locais, Windows, checkout `dev`:

- TDD: a asserção `Modelos de atividade` falhou com o label antigo `Modelos`;
- `flutter test test/features/activities/presentation/activity_directory_page_test.dart`:
  23 PASS;
- `dart format` confirmou os dois arquivos sem alterações adicionais.

O aceite fechado nesta fatia é FE `local-green` para o nome e composição das
abas. Como a superfície certificada foi alterada, o integrado permanece
`pending-verification` até nova prova pela rota normal, com reload, filtros e
escopo autorizado. Backend inalterado.

Próximo gate: conferir a rota normal do Superadmin, os dois estados de aba,
filtros/paginação, reload e negativa cross-tenant sem usar apenas fixture como
certificado.
