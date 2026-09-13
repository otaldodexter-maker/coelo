---
source: R12 C0 — R12-44 invites.list owner correction
status: local-green; E2E pending
generated_at: 2026-09-13
---

# R12-44 — diretório de convites somente em tabela

Recorte: Etapa 2 → `apps/superadmin` → Convites → diretório → estado inicial e
estados vazio, sem resultados e falha → `invites.list`.

O diretório agora segue a decisão do Owner para a R12: renderiza somente a
tabela canônica, sem cards e sem o controle cards/tabela. Busca, filtros,
paginação, ação `Novo convite` e ações por linha foram preservados. O tamanho
inicial da página foi alinhado à opção de tabela; a composição responsiva
continua sendo responsabilidade da tabela compartilhada.

Mudança mínima: o componente compartilhado recebeu `showDisplayToggle`,
mantendo o toggle para diretórios que ainda precisam dele; somente Convites o
desativa. Nenhum contrato Supabase, RPC, RLS, envio ou reenvio real foi
alterado.

Provas locais, Windows, checkout `dev`:

- `flutter test test/features/invites/invite_directory_page_test.dart`: 24 PASS;
- teste TDD novo: `renders the owner-approved table-only invite directory`;
- casos existentes de carregamento, filtros, paginação, vazio, sem resultados
  e falha permanecem verdes.

O aceite fechado nesta fatia é FE `local-green` para a composição table-only.
Não há certificado novo de rota real, persistência/reload ou negativa
cross-tenant; o estado integrado permanece `pending-verification` e o backend
permanece inalterado. R12-45 (`invites.resend`) continua fora desta fatia e
não foi executado.

Próximo gate: abrir a rota normal com a sessão QA, conferir busca/filtros/
paginação e ações por linha, validar reload e negar acesso cross-tenant sem
usar fixture ou teste isolado como certificado de produção.
