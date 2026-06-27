---
title: "Superadmin MVP Technical Spec e SDD"
source: "docs/product/prd-superadmin.md; specs/003-superadmin-core.md; docs/architecture/macro-architecture.md; docs/security/auth-multitenant-permissions.md; docs/security/lgpd-security-media.md; docs/data/data-model.md"
status: "draft-for-review"
generated_at: "2026-06-23"
---

# Superadmin MVP Technical Spec e SDD

## Objetivo

Definir a primeira fatia implementavel do Coelo: Superadmin MVP. A ordem de execucao e banco primeiro, wireframe Figma depois e Flutter por ultimo.

O primeiro fluxo implementavel e ativacao de instituicao. O banco, porem, deve nascer preparado para planos/status, usuarios internos, avisos/popups, suporte auditado, logs e dashboard futuro.

## Decisoes De Produto Travadas

| Tema | Decisao |
| --- | --- |
| Superficie inicial | `apps/superadmin` em Flutter Web. |
| Primeira entrega | Fundacao de dados e permissoes do Superadmin MVP, incluindo importacao PT->EN e branding por instituicao/unidade. |
| Primeiro fluxo UI | Ativacao de instituicao. |
| Wireframe | Figma em baixa fidelidade, cobrindo desktop, tablet e mobile. |
| Dashboard | Fora da UI inicial, mas dados devem ser coletados desde o MVP. |
| Owner Coelo | Conta inicial unica do fundador; pode criar novos Owners por convite + MFA. |
| Owner e privilegio | Poder total por decisao de produto; excecao explicita ao menor privilegio, sempre auditada. |
| MFA | Obrigatoria para Owner no login e em acoes sensiveis. |
| Avisos/popups | Segmentacao avancada por regras desde o schema. |
| Importacao | CSV/XLSX com colunas em portugues mapeadas para colunas internas em ingles, com suporte a qualquer tabela permitida pelo sistema. |

## Modelo De Dados Conceitual

Nomes fisicos podem ser refinados antes da migration, mas a capacidade abaixo deve existir na primeira Technical Spec de banco.

| Area | Tabelas/objetos previstos | Observacao |
| --- | --- | --- |
| Instituicoes | `institutions`, `institution_settings`, `institution_branding` | Tenant, dados preparados, configuracoes e branding leve. |
| Planos | `plans`, `plan_entitlements`, `institution_subscriptions`, `usage_limits` | Operacao manual no MVP, preparada para cobranca futura. |
| Usuarios internos | `platform_memberships`, `platform_invites`, `platform_role_grants` | Owner, Operations, Support, Content e Auditor. |
| Avisos/popups | `platform_notices`, `notice_rules`, `notice_media`, `notice_receipts`, `analytics.notice_events` | Conteudo global/segmentado, popups, midia e entrega. |
| Suporte | `support_sessions`, `audit.support_session_actions` | Motivo, escopo, inicio/fim e acoes sensiveis. |
| Auditoria | `audit.audit_logs` | Ator, acao, objeto, tenant/contexto, resultado e resumo minimizado. |
| Analytics | `analytics.analytics_events`, `analytics.usage_counters`, `analytics.usage_snapshots` | Eventos brutos, agregados por periodo e snapshots para dashboard futuro. |

## Campos Preparados

`institutions` deve prever: nome publico, trade name, razao/legal name quando aplicavel, slug, dominio principal, status operacional, timezone, locale, contato principal, referencia de documento legal/CNPJ, tipo de documento, plano atual, datas operacionais, metadados de contrato, flags de preparacao comercial e timestamps de auditoria.

`institution_settings` deve prever: modulos habilitados, politicas basicas, limites de upload/midia, preferencias de comunicacao, parametros de convite e campos de crescimento futuro sem depender de alteracao estrutural imediata.

`institution_branding` deve prever: logo, cores de marca (accent, secondary, text, surface) opcionais, capa, nome de exibicao, assinatura institucional e estado de aprovacao. Branding leve e preparatorio; white label forte permanece fora do MVP.

`unit_branding` deve prever: override de marca por unidade, com heranca da instituicao por padrao e liberacao por politica do admin macro gestor.

`platform_notices` deve prever: tipo (`notice`, `critical_notice`, `popup`, `content_card`), prioridade, titulo opcional, corpo em texto opcional, CTA opcional, vigencia, status de publicacao, criador, aprovador quando aplicavel e politica de silenciamento. Popups visuais podem depender principalmente de midia.

`notice_rules` deve prever segmentacao avancada por `target_type`, `target_id`, papel, status, plano, unidade, grupo/turma, contexto, modulo habilitado e filtros versionados. Regras devem ser avaliadas server-side.

`notice_media` deve prever imagem/anexo de popup com tipo, dimensoes esperadas, tamanho maximo, variante/thumbnail, vinculo com R2 futuro e estado de processamento. Tamanhos finais entram na spec de midia/design.

`analytics.analytics_events`, `analytics.usage_counters` e `analytics.usage_snapshots` devem armazenar dados suficientes para dashboard futuro sem copiar conteudo sensivel. Eventos guardam fatos; contadores guardam agregados por periodo; snapshots guardam leituras consolidadas para telas futuras.

## Autorizacao E RLS

- RLS deve negar por padrao em todas as tabelas expostas.
- Cliente Flutter usa somente chave publica/JWT do usuario; `service_role` nunca aparece no cliente.
- Acoes privilegiadas do Superadmin passam por RPC/Edge Function ou camada server-side equivalente.
- Owner Coelo pode executar acoes globais, mas a decisao deve ser registrada em `audit.audit_logs` com MFA recente, motivo e resultado.
- Operations opera instituicoes, planos/status e ativacao conforme grants.
- Support acessa dados privados apenas dentro de `support_sessions` ativas e auditadas.
- Content publica avisos/popups e perfis oficiais sem acesso desnecessario a dados infantis.
- Auditor consulta logs/evidencias sem editar operacao.
- Testes devem incluir dois tenants, multiplos papeis, tentativa por ID direto, tentativa cross-tenant e tentativa sem MFA recente.

## Fluxos Funcionais

O fluxo 1, ativacao de instituicao, e o primeiro a virar wireframe e implementacao:

1. Criar instituicao preparada.
2. Definir status operacional e plano manual.
3. Vincular owner institucional.
4. Emitir convite seguro.
5. Registrar `institution_created`, `institution_plan_changed`, `invite_created` e audit logs.
6. Confirmar que o owner institucional acessa apenas o proprio tenant.

Fluxos posteriores no mesmo Superadmin MVP:

- Criar e delegar usuarios internos por convite.
- Publicar aviso/popup com regras de audiencia e midia opcional.
- Abrir e encerrar sessao de suporte com motivo.
- Consultar auditoria e evidencias.
- Registrar eventos, contadores e snapshots para dashboard futuro.

## Wireframe Figma

O Figma deve ser wireframe de baixa fidelidade, sem prototipo visual final. Ele deve cobrir:

- Desktop: layout principal com navegacao lateral, tabela/lista, detalhe e painel de acao.
- Tablet: navegacao compacta, tabelas simplificadas e detalhe em tela/painel.
- Mobile: cards/listas, acoes primarias claras e formularios em etapas.
- Estados: loading, vazio, erro, sem permissao, sucesso, confirmacao sensivel e MFA exigida.
- Primeiro fluxo: ativacao de instituicao.

## Ordem De Implementacao SDD

1. Technical Spec de banco: tabelas, constraints, enums, indices, eventos e auditoria, detalhada em `specs/011-superadmin-database-rls.md`.
2. Technical Spec de RLS/RPC: policies, funcoes seguras, MFA recente e testes cross-tenant.
3. Wireframe Figma do fluxo de ativacao em desktop/tablet/mobile.
4. Componentes Flutter reutilizaveis em `packages/coelo_ui_admin`.
5. Telas do fluxo de ativacao em `apps/superadmin`.
6. Fluxos de usuarios internos, avisos/popups, suporte e auditoria.

## Criterios De Aceite

- Ativacao cria instituicao, plano/status manual, owner institucional, convite e audit log.
- Owner Coelo exige MFA e consegue delegar novo Owner somente por convite + MFA.
- Acesso cross-tenant falha em consultas diretas e via comandos.
- Aviso/popup segmentado nao aparece fora da audiencia calculada.
- Dados de analytics sao minimizados e suficientes para contadores/snapshots futuros.
- Suporte exige sessao com motivo e registra acoes sensiveis.
- Nenhuma chave secreta ou `service_role` aparece em app Flutter ou site publico.
- Wireframes cobrem desktop, tablet e mobile antes da implementacao Flutter.

## Test Plan

- RLS: dois tenants, Owner, Operations, Support, Content, Auditor e usuario sem plataforma.
- MFA: Owner sem MFA recente nao executa acao sensivel.
- Convites: novo Owner exige convite aceito + MFA configurada.
- Instituicoes: Operations cria tenant, status/plano e owner institucional; usuario externo nao acessa.
- Avisos/popups: regras por instituicao, unidade, turma/grupo, papel e filtro composto.
- Suporte: acesso privado sem sessao ativa falha; com sessao ativa registra audit log.
- Analytics: evento bruto gera contador e snapshot sem conteudo sensivel.
- UI futura: golden/responsivo para desktop, tablet e mobile quando Flutter existir.

## Riscos E Guardrails

| Risco | Guardrail |
| --- | --- |
| Owner total virar bypass invisivel | MFA obrigatoria, motivo, audit log e revisao periodica. |
| Banco superflexivel demais virar bagunca | Campos preparados, mas regras versionadas e validacao server-side. |
| Avisos virarem publicidade infantil | Separar aviso critico, popup operacional e conteudo opcional silenciavel. |
| Dashboard dirigir schema cedo demais | Guardar eventos/contadores/snapshots, sem construir UI ou BI pesado agora. |
| Support expor dados privados sem motivo | Sessao de suporte obrigatoria, escopo declarado e logs minimizados. |

## Pendencias Antes De Migration

- Validar limites juridicos do Owner total conforme `docs/open-questions.md`.
- Fechar nomes fisicos finais, enums, soft delete, schemas e particionamento.
- Confirmar estrategia de documento legal de instituicao sem conflitar com CPF adulto.
- Definir dimensoes/tamanho final de imagem para popup junto ao design system e spec de midia.
- Definir formato de snapshots para dashboard futuro sem criar dependencia de BI agora.
