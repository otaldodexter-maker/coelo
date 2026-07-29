---
title: "Perfis e Permissões no Superadmin"
source: "AGENTS.md; specs/002-auth-multitenant.md; specs/011-superadmin-database-rls.md; specs/012-superadmin-mvp.md; specs/015-contextual-people-access-attendance.md; docs/security/auth-multitenant-permissions.md; docs/data/data-model.md; inspeção read-only do Supabase em 2026-07-29; decisões aprovadas pelo usuário em 2026-07-29"
status: "approved-for-implementation"
generated_at: "2026-07-29"
---

# Perfis e Permissões no Superadmin

## Objetivo e problema

Entregar no Superadmin uma central administrativa para consultar e governar
perfis de plataforma, perfis institucionais e o impacto das capacidades do
Principal. O fluxo deve representar o modelo real de autorização, impedir
escalonamento de privilégio e preservar a linguagem visual aprovada de
Instituições.

## Terminologia canônica

- **Perfil de acesso** é o rótulo de UX para um papel reutilizável:
  `platform_roles` no Superadmin e `institution_roles` no Admin.
- **Membership** é o vínculo de uma pessoa a um contexto; não é perfil.
- **Escopo máximo** pertence ao perfil. **Escopo efetivo** pertence à
  membership ou atribuição e deve ser igual ou mais restrito.
- O Principal não possui perfil reutilizável. Suas capacidades pertencem ao
  vínculo responsável–criança–contexto e aparecem somente como catálogo e
  impacto nesta entrega.
- Permissão efetiva é calculada server-side. Negação explícita prevalece sobre
  allows de papel, grants diretos e overrides.

## Escopo

- central única no Superadmin com conjuntos separados para Superadmin, Admin e
  Principal;
- listagem em cards e tabela, busca, filtros, paginação e estados;
- detalhe de perfil, permissões configuradas, vínculos, escopos e auditoria
  autorizada;
- criação e edição de perfis Superadmin e Admin;
- revisão explícita antes da persistência;
- exclusão com realocação transacional;
- catálogo e impacto read-only das capacidades do Principal;
- RPCs autenticadas, versionamento otimista, idempotência e auditoria.

## Fora de escopo

- tela administrativa nova no Admin ou Principal;
- edição de grants familiares individuais;
- perfil transversal comum às três aplicações;
- novo componente público, token, variante ou Design System;
- uso de fixtures em produção.

## Superfícies e UX

O shell, toolbar, cards, tabela, espaçamentos, estados, paginação, hover, foco e
rodapé seguem Instituições. A composição não reutiliza modelos privados de
Instituições; usa os componentes públicos e os mesmos tokens.

O conjunto selecionado é o primeiro nível da central:

1. **Superadmin**: perfis de plataforma;
2. **Admin**: perfis institucionais;
3. **Principal**: capacidades contextuais e impacto, sem ação de criar.

Criar e editar usam página responsiva curta com identidade, status, escopo
máximo e permissões. O editor de permissões é privado à feature, usa checkbox
tematizado, agrupamento por domínio, busca e grupos empilhados no compacto.
Permissões não concedíveis permanecem desabilitadas e explicam o motivo.
`Switch` não representa seleção em rascunho.

A ação primária é **Revisar alterações**. A confirmação mostra permissões
adicionadas e removidas, mudança de escopo, vínculos impactados e exigências de
MFA. Conflitos preservam o rascunho.

## Entidades e contratos

- `platform_roles`: recebe escopo máximo e versão.
- `institution_roles`: recebe escopo máximo e versão.
  Perfis Admin criados nesta central são bases globais reutilizáveis
  (`institution_id` nulo e `is_system` derivado pelo servidor); a criação de
  perfis locais por instituição não faz parte desta entrega.
- `platform_role_permissions` e `institution_role_permissions`: configuração
  do perfil.
- `platform_memberships` e `institution_role_assignments`: vínculos e escopos
  efetivos.
- `guardian_permission_capabilities`: catálogo read-only do Principal.

Permissões novas:

- `platform.roles.manage`;
- `institution.roles.manage`.

Ambas nascem concedidas somente ao Owner.

RPCs públicas:

- `superadmin_access_profiles_list`;
- `superadmin_access_profile_detail`;
- `superadmin_access_profile_save`;
- `superadmin_access_profile_delete_and_reassign`;
- `superadmin_principal_capabilities_summary`.

As mutações recebem `request_id`, `expected_version`, motivo e rascunho
completo. O servidor deriva ator e tenant da sessão, nunca do cliente.

## Segurança, tenant e auditoria

- leitura exige `platform.read`;
- mutação de perfis de plataforma exige `platform.roles.manage`;
- mutação de perfis institucionais exige `institution.roles.manage`;
- auditoria detalhada exige `audit.read`;
- ações sensíveis exigem AAL2 e motivo;
- o operador só concede permissões que possui e pode delegar;
- escopo efetivo nunca excede o máximo do perfil nem o alcance do operador;
- perfis base podem ser editados e excluídos;
- excluir perfil em uso exige substituto e realoca todos os vínculos na mesma
  transação;
- a última autoridade total só pode ser substituída por membership ativa com
  todas as permissões vigentes e MFA obrigatório;
- `service_role`, secrets e `user_metadata` não participam do cliente nem da
  decisão de autorização;
- mudanças registram `platform_permission_changed`, `permission_changed` e
  `membership_changed` com diff minimizado.

## Estados

Loading, vazio inicial, nenhum resultado, erro com retry, conflito,
sem permissão, conteúdo e salvamento. O Principal não simula ações de escrita.

## Critérios de aceite

- os três conjuntos nunca misturam entidades incompatíveis na mesma tabela;
- cards, tabela, toolbar, espaçamento e paginação preservam o baseline de
  Instituições;
- nenhuma permissão real é inventada pelo Flutter;
- o servidor devolve permissões concedíveis e motivos de indisponibilidade;
- deny explícito vence allow;
- cross-tenant, unidade irmã, grupo incompatível e IDs adulterados falham;
- escopo efetivo respeita o teto do perfil;
- revisão antecede toda mutação;
- versão obsoleta retorna conflito sem sobrescrever;
- exclusão em uso exige realocação;
- o último Owner recuperável é preservado;
- Principal permanece read-only;
- nenhuma fixture alcança o caminho produtivo.

## Testes exigidos

- SQL para catálogos, deny, anti-escalation, contenção, tenant, último Owner,
  realocação, concorrência, idempotência, rollback e auditoria;
- unitários Dart para query, paginação, diff, estados e fixtures;
- widget tests para listagem, cards/tabela, filtros, detalhes, formulário,
  editor, revisão e estados;
- 375, 768, 1024 e 1440 px, light/dark, texto a 200%, teclado, semântica,
  reduced motion e ausência de overflow;
- goldens de mobile/desktop e regressão integral de Instituições.

## Riscos e perguntas abertas

- MFA dos demais papéis privilegiados continua regida por `OQ-006`.
- A migration local de Pessoas deve ser reconciliada antes de a central
  depender das permissões `people.*`.
- Os avisos atuais dos advisors sobre `person_auth_links` e proteção contra
  senhas vazadas não são resolvidos silenciosamente por esta spec.
