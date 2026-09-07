---
source: "docs/superpowers/specs/2026-07-29-superadmin-internal-users-preview-design.md; docs/product/prd-superadmin.md"
status: "partial-runtime-integration"
generated_at: "2026-07-29"
updated_at: "2026-09-07"
---

# Platform Users

Usuário interno possui identidade e credencial próprias, exclusivas do
Superadmin. Não reutiliza Pessoas, `@`, conta, sessão, recuperação, perfil ou
escopo de Admin e Principal.

As rotas `/dev` mantêm um preview local de diretório, criação, visualização e
edição. Owner possui ações de apresentação; Auditor visualiza; os demais
cenários demonstram sem permissão. Isso não representa autorização produtiva.

A rota normal `/internal-users` recebe `SupabasePlatformUserRepository` pelo
escopo de autenticação, `main`, app e router. A lista exige
`platform.member.read` no contexto previamente validado antes de solicitar
dados; cada RPC continua responsável por reautorizar a sessão e o ator no
servidor. Repositório ausente ou demo resulta em 503. Esta composição expõe
somente leitura; criação e edição normais permanecem bloqueadas nesta fatia.
Os testes locais usam transporte HTTP simulado e não comprovam produção nem
E2E. Troca de contexto, limpeza de cache e estados remotos ainda exigem provas.

O repositório fake mantém identidade, credencial, vínculo, convite e histórico
independentes, valida CPF/e-mail únicos, compatibilidade entre perfil e escopo,
revogação terminal e proteção do último Owner. Toda ação informa que é uma
demonstração local. MFA, Auth, Supabase, RLS, RPCs e auditoria produtiva ficam
fora.

Instituições é a baseline visual direta para menu, toolbar, filtros, cards,
tabela, ações Criar, hover/foco e paginação sticky.
