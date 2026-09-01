---
source: "apps/superadmin/README.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Router

Rotas internas do Superadmin. Usa `go_router` e `MaterialApp.router` para
URLs/deep links previsiveis em Flutter Web e futuras superficies mobile.

Este diretorio deve conectar URLs/telas a features sem concentrar regra de
negocio.

Rotas sensiveis devem ser protegidas por guards e por autorizacao real no
backend ou banco quando houver dados reais.

Regras:

- Declare paths e names em `superadmin_routes.dart`.
- Configure a arvore em `superadmin_router.dart`.
- Rotas de produto `/dev` compartilham uma unica instancia de
  `SuperadminShell.host`; autenticacao e paginas de erro ficam sem shell. O
  menu lateral usa o dispatcher central e troca somente o conteudo hospedado,
  sem animacao entre paginas.
- O menu privado de pre-visualizacoes lista somente rotas-mae e exclui criar,
  editar, detalhes, previews especificos e erros.
- A composicao `/dev` usa dados determinísticos e exclusivamente locais. O
  contrato de escala inclui 12 instituições, 1–4 unidades por instituição,
  1–20 turmas por unidade, 30 atividades, 10 modelos de atividade, 400 pessoas
  com papéis e vínculos cruzados e 6 modelos de rotina diária. Instituições,
  unidades, turmas e pessoas compartilham os mesmos identificadores de
  hierarquia. A composição produtiva reutiliza as mesmas superfícies, mas nunca
  recebe esses fixtures e permanece fail-closed sem fonte autorizada.
- Use `redirect`/guards apenas para sessao, contexto ativo e disponibilidade
  local; permissao final continua server-side/RLS.
- Quando houver navegacao persistente por modulos, preferir
  `StatefulShellRoute` para preservar estado por branch.
