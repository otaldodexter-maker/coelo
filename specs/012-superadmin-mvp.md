---
title: "Superadmin MVP"
source: "specs/003-superadmin-core.md; specs/010-superadmin-completo-v1-technical-spec.md; specs/011-superadmin-database-rls.md; docs/product/prd-superadmin.md; docs/security/auth-multitenant-permissions.md; docs/data/data-model.md; docs/architecture/macro-architecture.md"
status: "approved-for-planning"
generated_at: "2026-06-27"
---

# Superadmin MVP

## Objetivo

Definir a primeira versao operavel do Superadmin do Coelo. O foco e entrar numa instituicao, editar o que for autorizado, gerir planos, perfis e usuarios internos, emitir convites seguros, publicar avisos/popups simples, importar dados e salvar eventos no Supabase para consulta futura.

Este documento consolida o rascunho amplo do Superadmin v1 e deixa somente o que faz sentido para o MVP.

## Clarifications

### Session 2026-06-27

- Q: Quais templates de importacao entram primeiro: usuarios, unidades, grupos ou turmas? -> A: Instituicao, unidades e grupos entram primeiro; grupos sao o termo canonico para turmas; pessoas e vinculos entram depois da hierarquia, com templates separados e validacao forte.

## O que entra

| Tela ou fluxo | O que faz |
| --- | --- |
| Login | Autenticacao basica via Supabase. |
| Lista de instituicoes | Mostra as instituicoes acessiveis ao usuario interno. |
| Detalhe da instituicao | Exibe resumo da instituicao, permite editar dados basicos e abre o contexto de apoio. |
| Modo de apoio da instituicao | Permite atuar dentro da instituicao selecionada, sempre limitado ao que o perfil autoriza. |
| Gestao da instituicao | Organiza unidades, grupos/turmas, perfis e ajustes estruturais permitidos. |
| Configuracoes basicas | Nome, dominio, contato, timezone, locale e branding simples da instituicao. |
| Planos | Lista, cria, edita e vincula planos, com suporte a modulos liberados e historico de alteracoes. |
| Usuarios internos | Lista, envia convites seguros, revoga e troca o perfil das pessoas internas do Superadmin. |
| Perfis | Cria, edita, desativa ou exclui perfis padrao e customizados, com permissoes granulares por bloco e acao. |
| Avisos/popups | Cria e publica avisos simples da plataforma, com audiencia limitada e periodo de exibicao. |
| Importacao CSV/XLSX | Importa primeiro instituicoes, unidades e grupos/turmas por modelo padrao, com previa antes de confirmar. |
| Eventos salvos | Persiste eventos importantes no banco para consulta futura, sem tela de eventos no MVP. |

## Importacao MVP

A primeira onda de importacao deve montar a hierarquia operacional antes de cadastrar pessoas. Isso reduz erro de vinculo e deixa claro onde cada registro pertence.

| Ordem | Template | Regra |
| --- | --- | --- |
| 1 | Instituicoes | Operado pelo Superadmin; cria ou atualiza o tenant, dados legais/basicos, contato principal, timezone, locale, status e plano/manual quando aplicavel. |
| 2 | Unidades | Pertencem obrigatoriamente a uma instituicao existente ou criada no mesmo lote validado. |
| 3 | Grupos | Termo canonico para turmas, equipes ou atendimentos; pertencem obrigatoriamente a uma unidade, que pertence a uma instituicao. |

Nao existe template separado chamado `turmas` no banco. A UI pode usar "turma" quando fizer sentido para escola, mas a entidade canonica continua sendo `groups`.

Pessoas nao entram como um template unico de "usuarios". Quando a importacao de pessoas entrar, ela deve ser dividida em templates com responsabilidades separadas:

| Template futuro | Uso | Regra de seguranca |
| --- | --- | --- |
| Adultos | Responsaveis, professores, coordenadores, diretores, equipe e admins institucionais. | CPF pode ficar ausente no rascunho inicial, mas e obrigatorio antes da ativacao real no MVP; e-mail/celular e `@username` ajudam matching e convite; resultados de matching entre tenants devem ser mascarados. |
| Criancas | Participantes/alunos como pessoa global com contexto institucional. | CPF infantil nao e obrigatorio no MVP; usar dados minimos, data de nascimento quando aplicavel, identificador interno da instituicao e `@username` infantil apenas em busca autorizada. |
| Vinculos | Crianca-grupo, responsavel-crianca, responsavel-contexto e pessoa-papel. | Nenhum vinculo sensivel deve ser gravado sem previa, validacao de hierarquia e confirmacao explicita. |

## Fora de escopo

- Tela de auditoria.
- Mecanica de suporte como produto proprio.
- Avisos/popups avancados, campanhas e segmentacao complexa.
- Dashboard executivo.
- Cobranca automatica.
- Integracao obrigatoria com Stripe ou Asaas.
- Chat, rotina, agenda e experiencia do Admin da instituicao.
- Site publico.

## Dados e regras

- O MVP reutiliza a fundacao ja existente no Supabase; esta spec nao pede redesign de schema.
- RLS continua deny-by-default para dados de tenant.
- Usuario interno do Superadmin opera por `platform_membership`, perfil e contexto autorizado.
- O sistema pode nascer com perfis padrao seedados, como Owner, Operations, Support, Content e Auditor.
- No Superadmin MVP, cada pessoa interna Coelo pode operar com um perfil ativo principal de plataforma; isso nao elimina multiplos papeis institucionais ou familiares em outras superficies.
- Perfis padrao podem nascer prontos, mas podem ser customizados, desativados e excluidos com seguranca.
- A exclusao de um perfil deve ser bloqueada ou exigir realocacao quando houver pessoas vinculadas.
- Convites usam link ou token unico, expiram, podem ser reenviados e revogados.
- Avisos/popups do MVP podem ser simples: globais ou por instituicao, com periodo de exibicao e sem campanha avancada.
- Planos podem guardar campos opcionais para precificacao e provider futuro, mas o MVP nao executa pagamento.
- Eventos de mudanca e uso ficam salvos no banco para futura auditoria ou dashboard.
- `service_role` e segredos nunca entram no cliente.

## Modelo de identidade e papeis

- A raiz de identidade e `people`: adulto ou crianca, com ou sem login ativo.
- Login fica em `auth.users`, ligado a `people` por `person_auth_links`; crianca pode existir sem login.
- Nao criar tabelas separadas de "usuarios" para Superadmin, instituicao, pais, professores ou alunos.
- Pessoas internas Coelo usam `platform_memberships`.
- Equipe da instituicao usa `institution_memberships`, com papel e escopo por instituicao, unidade ou grupo.
- Criancas usam `child_contexts` por instituicao e `child_group_links` por grupo/turma.
- Responsaveis usam `guardian_links` para relacao familiar global e `guardian_context_permissions` para acesso ao contexto institucional da crianca.
- A mesma pessoa pode ser responsavel em uma unidade, professor em outra, coordenador na mesma instituicao e usuario interno Coelo se tiver memberships validos para cada contexto.
- O app diario deve continuar sendo `apps/principal`, com troca de contexto/papel; o Admin permanece como painel de gestao em `apps/admin`.

## UX states

- Loading.
- Empty.
- Error.
- Unauthorized.
- Success.
- Desktop e mobile, com tablet quando a tela exigir.

## Criterios de aceite

- O usuario faz login e ve apenas as instituicoes que pode acessar.
- O usuario abre uma instituicao, edita seus dados e entra no modo de apoio.
- O usuario ajusta somente o que seu perfil autoriza dentro da instituicao.
- O usuario cria, edita e vincula planos, perfis e usuarios internos.
- O usuario emite, reenvia e revoga convites seguros.
- O usuario cria e publica avisos/popups simples para a audiencia certa.
- O usuario importa instituicoes, unidades e grupos/turmas por CSV/XLSX com previa antes de confirmar.
- A importacao bloqueia grupo sem unidade valida e unidade sem instituicao valida.
- Templates de pessoas, quando habilitados, separam adultos, criancas e vinculos em vez de tratar tudo como "usuarios".
- Mudancas importantes ficam persistidas no banco.
- Nao existe tela de auditoria ou suporte no MVP.
- Tentativas cross-tenant falham.

## Testes

- Login e sessao.
- Isolamento entre tenants.
- Edicao de instituicao.
- Troca de contexto de apoio.
- Permissoes por perfil.
- Cadastro e revogacao de usuarios internos.
- Emissao, reenvio e revogacao de convites seguros.
- Criacao, edicao e exclusao de perfis.
- Criacao e publicacao de avisos/popups simples.
- Importacao com previa, validacao e rejeicao de arquivo invalido.
- Importacao respeitando a ordem instituicao -> unidade -> grupo.
- Deduplicacao de adultos por CPF/contato com resposta mascarada entre tenants.
- Crianca sem CPF obrigatorio no MVP, sem duplicar `people` quando houver vinculo autorizado.
- Vinculos familiares e profissionais validados por instituicao, unidade, grupo e permissao.
- Persistencia de eventos no banco.

## Perguntas em aberto

Nenhuma pergunta aberta especifica desta spec apos esta revisao. Perguntas transversais continuam em `docs/open-questions.md`.
