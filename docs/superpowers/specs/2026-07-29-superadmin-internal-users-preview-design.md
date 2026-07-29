---
source: "Solicitação aprovada do fundador em 2026-07-29; docs/product/prd-superadmin.md; docs/data/data-model.md; packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql; Instituições e anexos fornecidos como baseline visual"
status: "approved"
generated_at: "2026-07-29"
---

# Usuários Internos — Preview UI do Superadmin

## Objetivo

Entregar somente em `/dev` o diretório e os fluxos Criar, Visualizar e Editar
de pessoas globais vinculadas à equipe própria Coelo por
`platform_memberships`. Usuário interno não é usuário institucional,
administrador de tenant ou responsável familiar.

## Escopo

- `/dev/internal-users`, `/new`, `/:internalUserId` e `/:internalUserId/edit`;
- repositório fake inicializado exclusivamente pelo wiring de preview;
- papéis Owner, Operations, Support, Content e Auditor;
- vínculo `invited`, `active`, `suspended` ou `revoked`;
- convite `pending`, `accepted`, `revoked` ou `expired`;
- escopo `platform` ou `institution`, exigindo instituição no segundo;
- permissões somente derivadas do catálogo confirmado do papel;
- e-mail mascarado e última revisão quando existente.

MFA, último acesso, banimento Auth, CPF, telefone completo, dados familiares e
mutações produtivas ficam fora. A toolbar oferece Arquivos com importação e
exportação estritamente demonstrativas: não há seleção real, parser, download,
persistência, convite ou alteração de identidade/papel.

## Referência visual obrigatória

Menu e tela de Instituições são a baseline direta. Cards, tabela, ação Criar,
toolbar, filtros, flyouts, hover/foco, espaçamentos e paginação sticky devem
preservar sua geometria e comportamento. Confirmações reutilizam
`CoeloAdminDialogShell` e a composição aprovada do popup de Bug; menus seguem
os flyouts de Perfil e Tour. Nenhum Design System paralelo é autorizado.
Arquivos reutiliza `CoeloAdminFileActions`; o diálogo demonstrativo de
importação usa `CoeloAdminDialogShell`.

## Comportamento

Cards usam 11 itens e tabela 8. Busca por nome e e-mail mascarado possui
debounce de 300 ms. Os únicos filtros são Papel e Status. Card, linha, Enter e
Espaço abrem Visualizar.

Criar possui Identidade e contato, Acesso interno e Revisão. O resultado local
é sempre `invited` com convite `pending` e aviso explícito de que nenhum
convite real foi enviado. Visualizar separa Identidade, Vínculo interno, Papel
e permissões, Convite e status. Editar mantém e-mail e permissões derivados
somente leitura; status muda apenas por ação contextual.

Owner pode criar, editar e demonstrar ações; Auditor visualiza; demais cenários
exibem sem permissão. Essas capabilities são somente apresentação local e não
substituem autorização server-side.

## Segurança

Não há rota `/internal-users`, injeção fake produtiva, segredo, `service_role`,
metadata mutável como autorização, alteração de Supabase, Auth, migrations,
RPCs, RLS ou policies. Reenvio/revogação/suspensão são explicitamente ações
locais de preview e nunca alegam sucesso produtivo.

## Aceite

- light/dark e 375/768/1024/1440;
- texto a 200%, teclado, foco, Escape, semântica e reduced motion;
- loading, vazio, sem resultados, erro/retry e sem permissão;
- goldens comparados visualmente com Instituições;
- testes de domínio local, busca, filtros, paginação, cards/tabela,
  criar/visualizar/editar e isolamento das rotas `/dev`.
