---
title: "Diretório de Pessoas do Superadmin"
source: "pedido aprovado Pessoas do Superadmin; specs/003-superadmin-core.md; specs/011-superadmin-database-rls.md; specs/015-contextual-people-access-attendance.md; docs/product/prd-superadmin.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md"
status: "implemented-and-validated"
generated_at: "2026-07-29"
---

# Diretório de Pessoas do Superadmin

## Limite com Usuários Internos — 2026-08-05

Este diretório não é fonte de identidade, busca ou reaproveitamento para
Usuários Internos. Conforme ADR 0019 e spec 023, a equipe interna possui
identidade e credencial exclusivas do Superadmin; uma associação futura com
Pessoas será explícita, verificada e não compartilhará acesso.

## Objetivo e problema

Entregar listagem, criação draft e edição controlada de pessoas no
Superadmin, tomando Instituições como referência visual sem misturar a
identidade global com vínculos institucionais, familiares ou de plataforma.
A superfície precisa permitir operação interna legítima sem transformar uma
permissão genérica de plataforma em acesso amplo a PII.

## Escopo

- rotas `/people`, `/people/new` e `/people/:personId/edit`;
- listagem de adultos, crianças e serviços, com serviços somente leitura;
- cards, tabela, busca, filtros autorizados e paginação equivalente a
  Instituições;
- criação de adultos e crianças sempre em `draft`, sem Auth, convite ou login;
- edição concorrente dos campos globais aprovados e mudanças pontuais de
  memberships, papéis e contextos infantis;
- resumos somente leitura de Auth, membership de plataforma e vínculos de
  responsável;
- RPCs server-side, permissões granulares, RLS, grants explícitos e auditoria
  minimizada;
- `CoeloAvatar` e variante banner de `CoeloAdminCreateAction` como contratos
  públicos do Coelo UI.

## Fora de escopo

- importação, exportação, upload ou download de arquivos;
- criação ou convite de usuário Auth;
- login infantil;
- edição de tipo, status, CPF, nascimento, contatos, Auth, foto ou outros
  dados sensíveis enquanto suas regras não forem aprovadas;
- mutação de membership de plataforma ou vínculos de responsável;
- criação e edição de pessoas de serviço;
- decisão sobre CPF adulto e cardinalidade física definitiva de Auth;
- aplicação remota antes dos testes transacionais e da revisão de autorização.

## Superfícies afetadas

- `apps/superadmin`: diretório, formulário responsivo e rotas;
- `packages/coelo_ui`: avatar e variante banner da ação de criar;
- `packages/coelo_database`: catálogo de permissões, policies, índices e RPCs;
- documentação canônica, catálogo Coelo UI e memória de conhecimento interna.

## Entidades e dados

`people` permanece a identidade global. `person_auth_links` representa a
credencial opcional, sem ser criado por esta feature. Adultos usam
`institution_memberships` e papéis/escopos contextuais. Crianças usam
`child_contexts`, `child_unit_links` e `child_group_links`. Vínculos em
`guardian_links` e `platform_memberships` aparecem somente como resumos.

A API consumida pelo formulário aceita `first_name`, `last_name`,
`display_name`, `legal_name` opcional e contextos iniciais autorizados. A
edição usa patch desses mesmos campos globais e dos vínculos. Mudanças de
contexto são operações explícitas de adicionar, atualizar ou revogar;
vínculos ausentes do patch permanecem intactos. Os helpers de composição são
privados e não recebem grant ao cliente.

## Permissões e regras de tenant

- `people.read`: lista e detalhe minimizado;
- `people.create`: criação draft;
- `people.update`: campos globais aprovados;
- `people.memberships.manage`: memberships e papéis de adultos;
- `people.child_contexts.manage`: contextos institucionais de crianças.

As cinco permissões exigem sessão MFA em AAL2. Para adultos, cada mudança
contextual aponta para um `institution_role_assignment` e preserva os demais
papéis da mesma membership. Para crianças, cada mudança aponta para o
`child_context` e os links de unidade/grupo envolvidos, preservando contextos
não citados.

Somente `owner` recebe essas permissões inicialmente. O catálogo permanece
compatível com futuros perfis personalizados, sem grants automáticos.

As RPCs verificam usuário autenticado, sessão MFA AAL2 e permissão efetiva no
servidor por membership persistida; não usam `user_metadata`. Funções
privilegiadas fixam
`search_path`, revogam `EXECUTE` de `PUBLIC`/`anon` e concedem somente os
entrypoints necessários a `authenticated`. Instituição, unidade e grupo são
validados em conjunto antes de qualquer vínculo. FKs, constraints, transação e
testes cross-tenant impedem combinar escopos de tenants diferentes.

A leitura direta de `people` e memberships permanece self-only, inclusive para
Owner com `people.read`; diretório e detalhe administrativo existem somente
pelas RPCs minimizadas. Tabelas pessoais auxiliares de perfil, dados
profissionais, educação, endereço e contatos também permanecem self-only.
Responsáveis só leem contexto, unidade e grupo de uma criança quando existe
`guardian_context_permissions` ativo, vigente, com `can_view` e apontando para
o mesmo `child_context`; a própria criança preserva seu caminho self.

## Estados e comportamento de UX

O diretório cobre loading, vazio, sem resultados, erro, sem permissão e
paginação. Cards exibem 11 itens e tabela 8 no encaixe inicial; o seletor de
paginação oferece 20, 50 e 100. Filtros autorizados: tipo, status, instituição,
unidade, grupo, papel contextual e presença de vínculo Auth.

O formulário é responsivo e dividido em:

1. identidade;
2. vínculos contextuais;
3. revisão.

Adultos e crianças são confirmados como drafts. Adultos não recebem acesso até
fluxo posterior de convite/validação. A edição exige o `expected_updated_at`
lido pelo cliente e retorna conflito quando a identidade ou qualquer vínculo
contextual mudou. Contextos infantis revogados são reativados pelo mesmo ID,
com upsert seguro dos links canônicos; detalhe retorna somente contextos e
links ativos. Teclado,
semântica,
restauração de foco, texto a 200%, toque, hover, reduced motion, launcher e
paginação sticky integram os critérios de UI.

## Eventos, logs e notificações

Criação e edição gravam `people.create_draft` e `people.update`; cada vínculo
criado também recebe evento individual minimizado. A evidência
contém ator, objeto, resultado, campos alterados e quantidade de operações de
contexto, sem nomes, contatos, CPF ou payload integral de PII.

Esta feature não envia convite, e-mail, push ou notificação e não cria evento
Auth. Mudanças futuras de acesso devem ter fluxo próprio.

## Critérios de aceite

- as três rotas funcionam conforme autorização;
- adultos, crianças e serviços aparecem na listagem; serviço não é mutável;
- busca, filtros e paginação preservam isolamento contextual;
- criação grava `draft` e não cria `auth.users` nem `person_auth_links`;
- edição aceita somente campos globais aprovados e patch de vínculos;
- vínculo não citado permanece inalterado;
- contexto com instituição/unidade/grupo incoerentes é rejeitado;
- edição com timestamp antigo retorna conflito;
- Auth, plataforma e responsáveis são somente leitura;
- `platform.read` ou `people.read` não enumeram tabelas de identidade por
  SELECT direto; administração ocorre pelas RPCs AAL2;
- auditoria não replica PII;
- não existem importação, exportação ou arquivos;
- os componentes públicos novos são catalogados e testados.

## Testes exigidos

- RED/GREEN de listagem, detalhe, busca, filtros e paginação;
- criação adulta e infantil em draft, sem Auth;
- rejeição de serviço em criar/editar;
- edição concorrente e campos proibidos;
- add/update/revoke de membership sem substituição integral;
- contextos infantis por instituição, unidade e grupo;
- autorização sem permissão e com permissões independentes;
- isolamento cross-tenant, cross-unit e cross-group;
- grants, RLS, policies, `search_path` e ausência de `EXECUTE` anônimo;
- auditoria minimizada;
- loading, vazio, sem resultados, erro e sem permissão;
- teclado, semântica, foco, 375/768/1024/1440 px, light/dark, 200%, touch,
  hover e reduced motion;
- goldens antes/depois sem atualização automática;
- validação de índices, catálogo, conhecimento e `git diff --check`.

## Riscos e perguntas abertas

- `person_auth_links` garante unicidade ativa por `auth_user_id`, mas não por
  `person_id`, enquanto as fontes conceituais descrevem vínculo opcional 1:1;
  a decisão permanece aberta em `docs/open-questions.md`.
- CPF adulto continua aberto e fora dos RPCs.
- a migration remota depende de reset/dry-run completo, teste transacional,
  advisors e inspeção final da autorização.
- perfis personalizados futuros precisarão de matriz explícita antes de
  receber qualquer permissão `people.*`.
