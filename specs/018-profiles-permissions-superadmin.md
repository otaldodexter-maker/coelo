---
title: "Perfis e Permissões no Superadmin"
source: "AGENTS.md; specs/002-auth-multitenant.md; specs/011-superadmin-database-rls.md; specs/012-superadmin-mvp.md; specs/015-contextual-people-access-attendance.md; docs/security/auth-multitenant-permissions.md; docs/data/data-model.md; inspeção read-only do Supabase em 2026-07-29; decisões aprovadas pelo usuário em 2026-07-29, 2026-08-04, 2026-08-05 e 2026-09-01; docs/superpowers/specs/2026-09-01-superadmin-access-health-care-finalization-design.md"
status: "approved-for-implementation"
generated_at: "2026-09-01"
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
- importação ou exportação de perfis;
- convite ou remoção de pessoas vinculadas dentro do editor;
- criação de perfis reutilizáveis no Principal;
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

A listagem preserva tabs de domínio/origem para alternar entre Superadmin,
Admin e Principal. Dentro de cada domínio, não há tabs nem filtro de status.
Superadmin e Admin preservam busca e filtro de escopo; Principal mantém somente
busca e catálogo read-only, sem status, criação ou ações administrativas. As visões **Agrupado** e **Detalhado por
atribuições** permanecem disponíveis. A faixa de criação ocupa a largura útil,
enquanto a tabela usa sua largura natural centralizada quando houver sobra.
Não há ação de Arquivos enquanto importação e exportação não possuírem contrato
funcional.

Criar e editar usam a baseline responsiva de Criar/Editar Instituições, com
`SuperadminFormStepNavigation`, campos Coelo e
`SuperadminFormActionFooter`. Criar possui três etapas: **Perfil e escopo**,
**Permissões** e **Revisão**. Editar possui quatro etapas e inclui **Pessoas
vinculadas** antes da revisão. O contexto Superadmin/Admin vem da aba de origem
e não pode ser trocado dentro do formulário.

O editor de permissões permanece privado à feature. Ele agrupa módulo, tela e
ações reais recebidas do servidor. Em largura ampla, as ações formam colunas
derivadas do catálogo; em largura insuficiente, cada tela vira bloco empilhado
com suas ações abaixo, sem compressão nem scroll horizontal. Permissões não
concedíveis ou herdadas permanecem desabilitadas e explicam o motivo. Risco
crítico e exigência de MFA permanecem textuais e semânticos. `Switch` não
representa seleção em rascunho.

A revisão é a última etapa, não um dialog intermediário. Ela mostra permissões
adicionadas e removidas, mudança de escopo, vínculos impactados e exigências de
MFA, além de exigir motivo de auditoria. O rodapé oferece **Cancelar**,
**Anterior**, **Continuar** e, somente na revisão, **Criar perfil** ou **Salvar
alterações**. Conflitos preservam o rascunho.

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

`superadmin_access_profile_detail` devolve, para cada permissão, `screen_code`
e `action_code` separados de `module_code`. A ampliação é somente de leitura e
permite montar a matriz sem inferir hierarquia pelo código ou pela descrição.
As permissões são ordenadas por `module_code`, `screen_code`, `action_code` e
`code`; no ramo institucional, `scope_kind = group` é apresentado como **Turma**.
O payload de salvamento, autoridade, precedência deny/allow, auditoria e
versionamento permanecem inalterados.

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
- tabs de domínio/origem alternam Superadmin, Admin e Principal; dentro de cada
  domínio não há tabs nem filtro de status;
- a tabela nasce centralizada quando sua largura natural for menor que a área
  disponível e a scrollbar horizontal permanece visível sobre a coluna fixa;
- criar e editar usam a navegação e o rodapé compartilhados de Instituições;
- a revisão é a última etapa e exige motivo de auditoria;
- a matriz usa `screen_code` e `action_code` do servidor e empilha ações quando
  não houver largura suficiente;
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

## Aditivo 2026-09-01 — catálogo transversal e Modelos

Este aditivo substitui as regras anteriores desta spec quando houver conflito.
A central passa a ter um único destino de navegação, **Perfis de acesso**, com
as abas **Perfis** e **Modelos**, seguindo a relação entre Atividades e Modelos
de Atividade. Modelos iniciam perfis reutilizáveis e não são atribuídos
diretamente a pessoas.

O catálogo de permissões passa a abranger ações reais de Superadmin, Admin e
Principal, ordenadas por aplicativo, módulo, tela e ação. Principal deixa de
ser apenas um catálogo de impacto somente leitura. Essa ampliação não cria
vínculos familiares ou institucionais automaticamente: perfil define ações e
teto; atribuição define instituições, unidades, turmas, atividades, crianças e
demais contextos concretos.

O editor oferece seleção por aplicativo, módulo e tela. Importar e Exportar
entram no Admin e Superadmin nas telas de gestão em que existem contratos
aplicáveis. Ações específicas, risco, MFA, herança e delegabilidade são
metadados server-side; Flutter não inventa permissões nem infere autoridade por
rótulo.

Permissão efetiva continua exigindo aplicativo, ação, vínculo ativo, alcance
atribuído, tenant e ausência de negação explícita. Selecionar uma capacidade de
Admin ou Principal em um perfil não substitui membership institucional nem
relação responsável–criança.
