---
source: "AGENTS.md"
status: "accepted-for-planning"
generated_at: "2026-06-22"
---

# Coelo Constitution

Esta constituicao resume as regras de trabalho que o Spec Kit deve preservar ao criar specs, planos e tarefas para o Coelo. Em caso de conflito, prevalece a prioridade documental definida em `AGENTS.md`.

## Core Principles

### I. Crianca, familia e instituicao primeiro

Coelo e um superapp privado de rotina, comunicacao e cuidado entre instituicoes, familias, responsaveis e alunos. O produto nao deve virar rede social aberta, ERP completo ou substituto generico de WhatsApp. Decisoes de produto devem preservar o melhor interesse da crianca, clareza para a familia e auditabilidade institucional.

### II. Multi-tenant por desenho

Toda funcionalidade sensivel deve respeitar `tenant_id`, `institution_id`, membership, papel contextual, permissao familiar e policies/RLS quando aplicavel. Identidade global e papel contextual devem permanecer separados. Autorizacao nunca deve depender apenas do cliente ou de metadados mutaveis pelo usuario.

### III. Privacidade, LGPD e midia privada

Dados pessoais, dados de criancas, CPF, midias, mensagens e logs exigem minimizacao, base legal, retencao, rastreabilidade e seguranca. `service_role` e segredos equivalentes nunca podem aparecer no cliente. Midia privada deve usar Cloudflare R2 desde o MVP, com Postgres/Supabase guardando metadados, permissoes, ownership e auditoria.

### IV. Specs pequenas antes de produto

Cada implementacao nasce de uma spec pequena, revisada e aprovada. Specs devem declarar objetivo, escopo, fora de escopo, superficies afetadas, entidades, permissoes, regras de tenant, estados de UX, eventos/logs/notificacoes, criterios de aceite, testes exigidos, riscos e perguntas abertas.

### V. Arquitetura modular e superficies separadas

O monorepo separa `apps/site` em Astro de `apps/superadmin`, `apps/admin` e `apps/principal` em Flutter. Apps privados podem compartilhar dominio, auth, API e tokens, mas nao devem importar telas entre si. Contratos e dominio nao dependem de Flutter; regras de banco, RLS e migrations pertencem a `packages/coelo_database`.

## Documentation And Decisions

Documentos oficiais originais ficam preservados em `docs/source/originals/`. Markdown derivado deve ter frontmatter com fonte, status e data de geracao. Decisoes persistentes ficam em `decisions/` como ADRs. Conflitos, lacunas e decisoes pendentes ficam em `docs/open-questions.md` e nao devem ser resolvidos silenciosamente.

## Quality Gates

Antes de liberar funcionalidades sensiveis, testar acesso cruzado entre tenants, permissoes familiares, rotas server-side, trilhas de auditoria e ausencia de segredos no cliente. Design deve seguir `docs/design/design-system.md`, usar tokens semanticos, Nunito Sans, laranja `#D63C00`, grafite `#3F4549` e acessibilidade WCAG 2.2 AA quando aplicavel.

## Governance

Esta constituicao orienta specs, planos e tarefas, mas nao substitui os documentos oficiais. Mudancas persistentes de arquitetura ou produto exigem ADR ou atualizacao de spec aprovada. Lacunas juridicas, LGPD, CPF, MFA, push, midia, chat/admin e permissoes familiares permanecem abertas ate decisao formal registrada.

**Version**: 0.1.0 | **Ratified**: 2026-06-22 | **Last Amended**: 2026-06-22
