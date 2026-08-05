---
source: "Plano aprovado pelo Owner Coelo em 2026-08-05; decisions/0019-superadmin-internal-identity.md; specs/018-profiles-permissions-superadmin.md; baselines aprovadas de Pessoas e Instituições"
status: "approved-for-local-preview"
generated_at: "2026-08-05"
---

# Usuários Internos do Superadmin — preview local

## Objetivo

Reconstruir Diretório, Criar, Visualizar e Editar Usuários Internos com
identidade exclusiva do Superadmin e comandos inteiramente fake.

## Escopo

- Rotas `/dev/internal-users`, `/new`, `/:id` e `/:id/edit`.
- Diretório em Cards ou Tabela, busca, três filtros e paginação.
- Formulário em Identidade; Contato, trabalho e endereço; Acesso ao
  Superadmin; Revisão e convite.
- Perfis ativos do catálogo Superadmin, incluindo personalizados.
- Vínculo, convite e credencial apresentados como estados independentes.
- Criar, editar, reenviar/revogar convite, suspender/reativar, revogar vínculo
  e criar novo vínculo após revogação.
- Histórico demonstrativo e proteção do último Owner no repositório fake.

## Fora de escopo

- `people`, `@`, busca de Pessoas ou associação entre identidades.
- Supabase, Auth, banco, migrations, RPCs, RLS, policies e serviços externos.
- MFA, senha, sessão, recuperação real, convite ou e-mail real.
- Editor individual de permissões, importação ou exportação.

## Contrato de domínio

- Identidade interna guarda dados cadastrais próprios e nunca concede acesso.
- Credencial é apenas um snapshot demonstrativo, sem segredos.
- Vínculo guarda perfil, alcance e escopos efetivos.
- Perfil define permissões derivadas e o alcance máximo.
- Convite é dirigido apenas ao e-mail profissional e nunca declara envio real.
- CPF e e-mail são únicos somente dentro do repositório local.
- Revogação do vínculo é terminal; novo vínculo preserva o histórico anterior.

## UX e acessibilidade

- Pessoas orienta a apresentação; Instituições define cards, diretório, tabela,
  toolbar, estados e paginação.
- Criar/Editar Instituição define step navigation, campos e footer.
- Mobile e tablet claros usam `colorScheme.surface` como base; cinza fica
  restrito a superfícies secundárias com função explícita.
- Alvos mínimos de 48 px, foco visível, teclado, toque, mouse, trackpad,
  semântica, texto a 200% e reduced motion.
- Toda confirmação usa “Demonstração local” e declara ausência de persistência.

## Critérios de aceite

- Busca cobre nome, sobrenome, e-mail/celular/CPF mascarados e cargo.
- Filtros cobrem perfil, vínculo e alcance.
- Perfil incompatível bloqueia alcance global; alcance limitado exige escopo.
- Último Owner é protegido na UI e nos comandos fake.
- Cards/Tabela, estados, fluxo em quatro etapas, detalhe, ações e histórico
  possuem testes e evidências visuais proporcionais.
- Validar 375, 768, 1024 e 1440 px, light/dark e texto a 200%.
