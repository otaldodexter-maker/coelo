---
source: ".superpowers/sdd/superadmin-corrections-task-3c-brief.md"
status: "done_with_concerns"
generated_at: "2026-07-28"
---

# Task 3C — Supabase: perfil e representantes de instituição

## Resultado

`DONE_WITH_CONCERNS`

A migration `20260728172333_institution_profile_and_legal_representatives.sql`
foi criada pelo Supabase CLI e movida, preservando o timestamp, para o diretório
canônico `packages/coelo_database/migrations`.

## Schema implementado

- `institution_branding`
  - cor terciária;
  - cores secundária e terciária de texto;
  - bio limitada a 220 caracteres;
  - até três links HTTPS/HTTP, com rótulo e URL;
  - checks nomeados para as sete cores em hexadecimal.
- `institution_contacts`
  - site;
  - site limitado a 2048 caracteres;
  - WhatsApp em E.164;
  - `institution_contacts_has_value` atualizado para considerar os novos canais.
- `institution_legal_representatives`
  - relação normalizada com instituição, pessoa e membership;
  - FK composta que impede membership/pessoa de outro tenant;
  - validação de pessoa adulta, data de nascimento conhecida e membership ativo;
  - estado, vigência, representante principal e auditoria temporal;
  - índices de consultas e unicidade ativa.

Não foram criadas tabelas paralelas de pessoa, administrador, papel ou convite.
`people`, `institution_memberships`, `institution_roles`,
`institution_role_assignments` e `invitations` permanecem as fontes existentes.
Também não houve seed de novos papéis/permissões administrativos: o mapeamento
de permissões da UI ainda não é canônico e permanece como risco para a rodada
que conectar o formulário ao banco.

Nenhum byte, bucket ou nova FK de mídia foi criado. As referências existentes
de logo/capa continuam aguardando o gateway R2.

## Segurança

- RLS habilitada na nova tabela.
- Leitura autenticada exige `platform.read`.
- `anon` não recebe acesso.
- `authenticated` recebe somente `SELECT`.
- Escritas desta rodada ficam exclusivamente com `service_role`.
- Funções auxiliares são `SECURITY INVOKER`, têm `search_path` vazio e grants
  mínimos explícitos.
- Catálogos `schema_tables` e `schema_columns` são preenchidos para as três
  superfícies afetadas.

## TDD e verificações

- RED observado antes da implementação: a migration gerada estava vazia e a
  verificação falhou pela ausência do schema exigido.
- Segundo RED observado para os refinamentos de contato: os checks de limite do
  site e E.164 ainda não existiam antes da implementação.
- Adicionados:
  - teste SQL transacional de constraints, grants, RLS, catálogo, adulto e
    bloqueio cross-tenant;
  - suíte pgTAP para estrutura, policy, grants, constraint cross-tenant e
    catálogo.
- `Sync-SupabaseCliMigrations.ps1 -Mode Prepare`: passou, 20 migrations.
- `Sync-SupabaseCliMigrations.ps1 -Mode Verify`: passou, 20 migrations.
- verificações estáticas de requisitos/termos proibidos: passaram.
- `git diff --check`: passou.

O ambiente local não possui Docker nem Podman no `PATH`. Por isso `db reset`,
`test db`, `db lint` e advisors locais não puderam executar. A migration não foi
aplicada ao projeto remoto, conforme instrução.

## Gate de conhecimento

`no-op`. A fonte canônica da mudança é a própria migration versionada e a
decisão ainda depende da aprovação visual/final da rodada. Nenhuma projeção em
`docs/knowledge` foi criada.
