---
source: "decisions/0004-auth-permissions.md; docs/security/environment-and-secrets.md; docs/superpowers/specs/2026-07-16-superadmin-supabase-auth-design.md"
status: "implemented-foundation"
generated_at: "2026-07-16"
---

# coelo_auth

Sessão, login e contratos compartilhados de autenticação para os apps privados do Coelo.

Escopo atual:

- adapter reutilizável para autenticação com `supabase_flutter`;
- login por `signInWithPassword`;
- stream de mudanças de autenticação para sincronizar sessão local do app;
- persistência condicional de sessão por meio de `LocalStorage` injetável;
- logout pelo contrato compartilhado;
- solicitação neutra de recuperação de senha por `resetPasswordForEmail`;
- fallback seguro quando o ambiente não está configurado.

Fora de escopo nesta etapa:

- contexto ativo e troca de papel;
- memberships, roles e permissões familiares;
- MFA, definição da nova senha, deep link de recuperação e convites;
- autorização contextual e auditoria server-side.

Esses pontos continuam dependentes de spec aprovada e das lacunas registradas em `docs/open-questions.md`.
