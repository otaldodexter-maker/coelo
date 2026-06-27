---
title: "Superadmin MVP"
source: "specs/003-superadmin-core.md; specs/010-superadmin-completo-v1-technical-spec.md; specs/011-superadmin-database-rls.md; docs/product/prd-superadmin.md; docs/security/auth-multitenant-permissions.md; docs/data/data-model.md; docs/architecture/macro-architecture.md"
status: "draft-for-review"
generated_at: "2026-06-27"
---

# Superadmin MVP

## Objetivo

Definir a primeira versao operavel do Superadmin do Coelo. O foco e entrar numa instituicao, editar o que for autorizado, gerir planos, perfis e usuarios internos, importar dados e salvar eventos no Supabase para consulta futura.

Este documento consolida o rascunho amplo do Superadmin v1 e deixa somente o que faz sentido para o MVP.

## O que entra

| Tela ou fluxo | O que faz |
| --- | --- |
| Login | Autenticacao basica via Supabase. |
| Lista de instituicoes | Mostra as instituicoes acessiveis ao usuario interno. |
| Detalhe da instituicao | Exibe resumo da instituicao, permite editar dados basicos e abre o contexto de apoio. |
| Modo de apoio da instituicao | Permite atuar dentro da instituicao selecionada, sempre limitado ao que o perfil autoriza. |
| Gestao da instituicao | Organiza unidades, grupos, perfis e ajustes estruturais permitidos. |
| Configuracoes basicas | Nome, dominio, contato, timezone, locale e branding simples da instituicao. |
| Planos | Lista, cria, edita e vincula planos, com suporte a modulos liberados e historico de alteracoes. |
| Usuarios internos | Lista, convida, revoga e troca o perfil das pessoas internas do Superadmin. |
| Perfis | Cria, edita, desativa ou exclui perfis padrao e customizados, com permissoes granulares por bloco e acao. |
| Importacao CSV/XLSX | Importa usuarios, unidades, grupos, turmas e outros cadastros por modelo padrao com previa antes de confirmar. |
| Eventos salvos | Persiste eventos importantes no banco para consulta futura, sem tela de eventos no MVP. |

## Fora de escopo

- Tela de auditoria.
- Mecanica de suporte como produto proprio.
- Avisos e popups.
- Dashboard executivo.
- Cobranca automatica.
- Integracao obrigatoria com Stripe ou Asaas.
- Chat, rotina, agenda e experiencia do Admin da instituicao.
- Site publico.

## Dados e regras

- O MVP reutiliza a fundacao ja existente no Supabase; esta spec nao pede redesign de schema.
- RLS continua deny-by-default para dados de tenant.
- Usuario interno do Superadmin opera por perfil e contexto da instituicao.
- O sistema pode nascer com perfis padrao seedados, como Owner, Operations, Support, Content e Auditor.
- No MVP, cada pessoa pode operar com um perfil ativo principal.
- Perfis padrao podem nascer prontos, mas podem ser customizados, desativados e excluidos com seguranca.
- A exclusao de um perfil deve ser bloqueada ou exigir realocacao quando houver pessoas vinculadas.
- Planos podem guardar campos opcionais para precificacao e provider futuro, mas o MVP nao executa pagamento.
- Eventos de mudanca e uso ficam salvos no banco para futura auditoria ou dashboard.
- `service_role` e segredos nunca entram no cliente.

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
- O usuario importa dados por CSV/XLSX com previa antes de confirmar.
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
- Criacao, edicao e exclusao de perfis.
- Importacao com previa, validacao e rejeicao de arquivo invalido.
- Persistencia de eventos no banco.

## Perguntas em aberto

- Quais templates de importacao entram primeiro: usuarios, unidades, grupos ou turmas?
- A tela de planos mostra apenas nome, status e modulos, ou tambem preco e referencia futura de cobranca?
- Perfis padrao podem ser excluidos diretamente quando vinculados a pessoas, ou o sistema deve exigir realocacao antes?
