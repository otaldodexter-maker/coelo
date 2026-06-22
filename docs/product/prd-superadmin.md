---
title: "Coelo PRD Superadmin Oficial v1"
source_file: "Coelo PRD Superadmin Oficial v1.docx"
source_copy: "docs/source/originals/docx/Coelo PRD Superadmin Oficial v1.docx"
original_path: "C:/Users/adrie/Desktop/Coelo/PRD/Coelo PRD Superadmin Oficial v1.docx"
status: "derived-from-official-docx"
version: "v1"
generated_at: "2026-06-22"
---

<!-- Documento derivado de fonte oficial. Edite a fonte DOCX ou registre uma decisao antes de alterar conteudo normativo. -->
| Coluna 1 | COELO<br>PRD Superadmin Oficial v1<br>superadmin.coelo.me · Operação interna da plataforma |
| --- | --- |

Versão: v1.0 | Data: 21/06/2026 | Status: Draft para validação

| O Superadmin controla instituições, planos, usuários internos, avisos, suporte e auditoria sem substituir o Admin da instituição. |
| --- |

Simples como Airbnb Visual como Instagram Confiável como escola

Documento derivado do Product Vision Oficial v1 e do PRD Master Oficial v1 do Coelo.

# Sumário executivo do documento

| # | Seção |
| --- | --- |
| 1 | Capa e controle de versão |
| 2 | Resumo executivo |
| 3 | Objetivos e princípios |
| 4 | Escopo do MVP |
| 5 | Fora de escopo |
| 6 | Atores e permissões |
| 7 | Módulos funcionais |
| 8 | Fluxos principais |
| 9 | Requisitos funcionais |
| 10 | Regras de negócio |
| 11 | Dados e integrações |
| 12 | Eventos e auditoria |
| 13 | Segurança e LGPD |
| 14 | Requisitos não funcionais |
| 15 | Critérios de aceite |
| 16 | Riscos e mitigação |
| 17 | Decisões oficiais |
| 18 | Perguntas em aberto |
| 19 | Próximas specs |
| 20 | Fontes e referências |

# 1. Capa e controle de versão

| Campo | Valor |
| --- | --- |
| Documento | PRD Superadmin Oficial v1 — Coelo |
| Owner | Fundador/Produto Coelo |
| Público interno | Produto, design, engenharia, dados, segurança, jurídico, operações e agentes de coding. |
| Status | Draft para revisão e versionamento. |
| Base interna | Product Vision Oficial v1; PRD Master Oficial v1; História da Logo e Marca Oficial v1; mapa competitivo e decisões do fundador. |
| Escopo | Gestão interna da plataforma Coelo, tenants, planos manuais, usuários internos, avisos, suporte autorizado, uso básico e auditoria. |

| Versão | Data | Mudança | Responsável |
| --- | --- | --- | --- |
| v1.0 | 21/06/2026 | Criação do PRD específico alinhado ao PRD Master e às decisões oficiais do fundador. | Produto Coelo |
| v1.1 | A definir | Revisão após specs técnicas, protótipo e validação do piloto. | Produto + Engenharia |
| v2.0 | A definir | Atualização após piloto real e priorização da próxima fase. | Produto + Negócio |

# 2. Resumo executivo

O Superadmin é o ambiente interno do Coelo. Ele deve permitir que a equipe própria crie e gerencie instituições, controle o status operacional, cadastre usuários internos, publique avisos globais ou segmentados, acompanhe indicadores básicos e mantenha rastreabilidade das ações sensíveis.

No MVP, planos e datas serão gerenciados manualmente para acelerar a entrega. A modelagem, entretanto, deve nascer preparada para cobrança, assinatura e aplicação automática de limites em versões futuras, sem implementar esse fluxo completo agora.

| Decisão central<br>Usuários internos autorizados poderão acessar dados privados conforme o cargo. Todo acesso sensível continuará dependente de permissão interna e deverá gerar registro de auditoria, conforme o PRD Master. |
| --- |

# 3. Objetivos e princípios

| Objetivo | Aplicação |
| --- | --- |
| Ativar instituições | Criar tenant, owner inicial, unidade inicial opcional, plano/status e convite de acesso. |
| Operar com segurança | Separar funções internas e registrar acessos, alterações e ações sensíveis. |
| Reduzir dependência técnica | Permitir ações operacionais comuns sem manipulação direta do banco. |
| Preparar monetização | Manter planos e limites modelados, mas operados manualmente no MVP. |
| Comunicar a base | Enviar avisos in-app e, quando crítico, push segmentado com prazo de exibição. |
| Evitar invasão de escopo | Não substituir o Admin da instituição nem editar rotina cotidiana sem necessidade de suporte. |

# 4. Escopo do MVP

| Área | Entra no MVP | Definição |
| --- | --- | --- |
| Instituições | Sim | Criar, editar, ativar, inativar, suspender e consultar o tenant. |
| Owner inicial | Sim | Vincular pessoa responsável pela instituição e emitir convite. |
| Planos/status | Sim — manual | Registrar plano, datas, status e campos de limites; sem cobrança automática. |
| Usuários internos | Sim | Owner, operações, suporte, conteúdo e auditoria, com permissões internas. |
| Avisos | Sim | Globais ou segmentados por instituição, unidade, papel ou contexto, com vigência. |
| Perfis oficiais Coelo | Sim | Publicar dicas e comunicações oficiais sem transformar o app em publicidade infantil. |
| Uso básico | Sim | Contadores e eventos brutos; dashboard completo fica para depois. |
| Auditoria | Sim | Ações sensíveis, mudanças de permissão e acessos administrativos. |
| Suporte com acesso | Sim | Acesso conforme cargo interno e escopo autorizado, sempre auditado. |

# 5. Fora de escopo

| Fora do MVP | Motivo | Preparação |
| --- | --- | --- |
| Cobrança e assinatura automáticas | Aumenta integração financeira e operação. | Modelar plano, limites, datas, status e eventos de mudança. |
| Dashboard executivo completo | Os dados ainda serão validados no piloto. | Registrar analytics_events e contadores desde o início. |
| Impersonation invisível | Risco elevado de privacidade. | Qualquer suporte deve usar acesso identificado e auditado. |
| White label forte | Complexidade de lojas e builds. | Manter branding leve e campos de configuração. |
| Edição rotineira de dados escolares | Responsabilidade do Admin da instituição. | Superadmin atua somente por suporte ou governança. |

# 6. Atores e permissões

| Papel interno | Escopo | Permissões principais |
| --- | --- | --- |
| Owner Coelo | Plataforma | Configurações globais, usuários internos, tenants, planos, auditoria e permissões. |
| Operações | Plataforma/tenants | Criar e manter instituições, owner inicial, status e avisos operacionais. |
| Suporte | Tenants autorizados | Acessar contextos privados conforme cargo, diagnosticar e registrar atendimento. |
| Conteúdo | Perfis globais | Publicar conteúdo e avisos sem acesso desnecessário a dados infantis. |
| Auditor | Leitura controlada | Consultar logs, mudanças e evidências, sem editar dados operacionais. |

| Ação | Owner | Operações | Suporte | Conteúdo | Auditor |
| --- | --- | --- | --- | --- | --- |
| Criar instituição | Sim | Sim | Não | Não | Não |
| Alterar plano/status | Sim | Sim | Não | Não | Leitura |
| Gerir usuários internos | Sim | Não | Não | Não | Leitura |
| Publicar aviso global | Sim | Sim | Não | Sim, conforme permissão | Leitura |
| Acessar dados privados | Sim | Conforme cargo | Conforme cargo | Não | Conforme auditoria |
| Consultar audit logs | Sim | Limitado | Próprios/atendimentos | Não | Sim |

# 7. Módulos funcionais

## 7.1 Instituições

- Cadastro e edição dos dados institucionais mínimos.

- Status operacional, plano manual e datas relevantes.

- Vínculo com owner/diretor inicial.

- Acesso ao histórico de alterações e principais eventos.

- Busca e filtros por nome, domínio, status e identificadores internos, sem expor dados desnecessários.

## 7.2 Planos e limites

- Operação manual no MVP.

- Estrutura preparada para limites de usuários, responsáveis, storage e módulos.

- Cobrança adicional após dois responsáveis por criança deve ser apenas registrável/preparada, sem automação no MVP.

- Mudanças de plano e exceções devem ser auditadas.

## 7.3 Avisos e perfis Coelo

- Avisos para todos ou segmentados por tenant, unidade, papel e contexto.

- Data de início e término de exibição.

- Classificação entre aviso sistêmico obrigatório e conteúdo opcional.

- Conteúdo opcional poderá ser silenciado; avisos críticos não dependem de opt-in de marketing.

## 7.4 Suporte

- Acesso conforme cargo interno.

- Motivo do atendimento e instituição/contexto devem ser registrados.

- Ações de suporte devem aparecer na trilha de auditoria.

- Não usar credenciais do usuário final nem chaves secretas no navegador.

# 8. Fluxos principais

| Fluxo | Passos essenciais | Critério de aceite |
| --- | --- | --- |
| Ativar instituição | Criar instituição → definir plano/status → vincular owner → emitir convite → confirmar acesso. | Owner acessa somente a própria instituição e vê checklist inicial. |
| Suspender instituição | Selecionar tenant → informar motivo → confirmar ação → registrar log. | Acesso é bloqueado conforme regra sem apagar dados. |
| Criar usuário interno | Cadastrar pessoa/contato → definir cargo → atribuir escopo → enviar convite. | Usuário recebe somente permissões do cargo e escopo. |
| Publicar aviso | Definir tipo → audiência → vigência → conteúdo → revisar → publicar. | Aviso aparece apenas para audiência autorizada e expira conforme vigência. |
| Atendimento de suporte | Abrir instituição/contexto → registrar motivo → consultar/agir conforme cargo → encerrar. | Acesso e ações aparecem na auditoria com ator, tempo e objeto. |
| Alterar plano manual | Selecionar instituição → alterar plano/status/datas → registrar justificativa. | Mudança é persistida sem iniciar cobrança automática. |

# 9. Requisitos funcionais

| ID | Área | Requisito |
| --- | --- | --- |
| SA-RF-001 | Instituições | Criar, editar, ativar, inativar e suspender instituições. |
| SA-RF-002 | Owner | Vincular owner inicial e emitir convite seguro. |
| SA-RF-003 | Planos | Registrar plano, datas, status e limites de forma manual. |
| SA-RF-004 | Preparação futura | Manter estrutura compatível com assinatura, cobrança e limites automáticos futuros. |
| SA-RF-005 | Usuários internos | Cadastrar e gerenciar cargos internos e seus escopos. |
| SA-RF-006 | Avisos | Criar avisos globais ou segmentados com período de exibição. |
| SA-RF-007 | Conteúdo oficial | Gerenciar perfis oficiais Coelo e preferências de silenciamento. |
| SA-RF-008 | Suporte | Permitir acesso privado conforme cargo e registrar a sessão de suporte. |
| SA-RF-009 | Auditoria | Registrar mudanças de status, plano, permissões, acessos e conteúdo. |
| SA-RF-010 | Uso básico | Exibir contadores básicos derivados dos eventos do MVP. |

# 10. Regras de negócio

- Uma instituição é um tenant e deve possuir identificador estável independente de nome ou domínio.

- A inativação ou suspensão não deve excluir dados automaticamente.

- Planos do MVP são controlados manualmente; qualquer bloqueio automático depende de versão futura.

- Acesso privado por usuários internos depende de cargo e escopo cadastrados.

- Avisos sistêmicos críticos podem ser obrigatórios; conteúdo editorial opcional deve poder ser silenciado.

- O Superadmin não substitui os fluxos cotidianos do Admin da instituição.

- A regra comercial de responsáveis adicionais deve ficar preparada em dados de plano/uso, sem cobrança automática.

# 11. Dados e integrações

| Domínio de dados | Entidades/objetos relacionados | Observação |
| --- | --- | --- |
| Tenants | institutions, units, institution_settings | Superadmin cria e mantém o tenant; dados internos continuam isolados. |
| Planos | plans, institution_subscriptions, usage_limits | Operação manual no MVP; nomes físicos finais no Modelo de Dados Master. |
| Equipe Coelo | people, auth.users, platform_memberships | Pessoa global com vínculo interno contextual. |
| Avisos | platform_notices, notice_audiences, notice_receipts | Segmentação e vigência. |
| Suporte | support_sessions, audit_logs | Motivo, ator, tenant, escopo e ações. |
| Analytics | analytics_events, usage_counters | Dados brutos para dashboards futuros. |

# 12. Eventos e auditoria

| Evento | Quando dispara | Uso |
| --- | --- | --- |
| institution_created | Instituição criada. | Ativação e operação. |
| institution_status_changed | Status alterado. | Auditoria e bloqueios. |
| institution_plan_changed | Plano/datas/limites alterados. | Histórico comercial. |
| platform_user_invited | Usuário interno convidado. | Governança interna. |
| platform_permission_changed | Cargo ou escopo alterado. | Segurança. |
| platform_notice_published | Aviso publicado. | Entrega e alcance. |
| support_session_opened/closed | Atendimento iniciado/encerrado. | Auditoria de acesso privado. |
| support_sensitive_action | Ação sensível realizada. | Evidência e investigação. |

# 13. Segurança e LGPD

- RLS obrigatória em todas as tabelas expostas ao cliente; acesso administrativo sensível deve ser implementado por funções seguras ou backend controlado.

- Chaves secretas/service role nunca podem ser incorporadas ao app web ou mobile.

- Acesso de suporte deve ser identificado, limitado pelo cargo e registrado.

- Dados infantis só podem ser consultados quando necessários à operação ou suporte autorizado.

- A definição jurídica de controlador/operador permanece pendente de validação jurídica.

- Logs não devem copiar conteúdo sensível completo quando um identificador e resumo forem suficientes.

# 14. Requisitos não funcionais

| Categoria | Requisito |
| --- | --- |
| Segurança | Autorização server-side/RLS, segregação de cargos internos e trilha de auditoria. |
| Usabilidade | Operações críticas com confirmação e linguagem clara. |
| Performance | Listagens paginadas e filtros sem carregar dados privados desnecessários. |
| Auditabilidade | Ator, contexto, ação, objeto e timestamp em operações sensíveis. |
| Disponibilidade | Backups, monitoramento e recuperação compatíveis com o estágio do MVP. |
| Manutenibilidade | Flutter web em monorepo, design system compartilhado e migrations versionadas. |
| Privacidade | Minimização de dados nas telas, exports e logs. |

# 15. Critérios de aceite

- Operações cria uma instituição e o owner convidado acessa somente o próprio tenant.

- Plano e status podem ser alterados manualmente sem executar cobrança.

- Usuário de conteúdo não consegue acessar dados privados de crianças.

- Usuário de suporte acessa dados conforme o cargo e a sessão fica auditada.

- Aviso segmentado não aparece para usuários fora da audiência.

- Suspensão bloqueia acesso conforme regra sem apagar registros.

- Toda mudança de permissão, plano, status e acesso sensível gera audit log.

- Nenhuma chave de serviço fica disponível no cliente.

# 16. Riscos e mitigação

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| Acesso interno excessivo | Crítico | Cargos, escopos, logs, revisão periódica e minimização de dados. |
| Superadmin virar Admin da escola | Alto | Separar responsabilidades e limitar edição cotidiana. |
| Planos manuais gerarem erro | Médio | Histórico, validação e justificativa de mudanças. |
| Avisos parecerem publicidade | Médio | Separar conteúdo crítico de conteúdo opcional e permitir silenciar. |
| Dashboard atrasar o MVP | Médio | Exibir apenas contadores básicos e registrar eventos completos. |

# 17. Decisões oficiais

| Decisão | Valor oficial v1 |
| --- | --- |
| Acesso de suporte | Permitido conforme o cargo interno; ações sensíveis auditadas. |
| Planos no MVP | Cadastro e operação manual. |
| Preparação futura | Estrutura pronta para assinatura, cobrança e limites automáticos. |
| Impersonation invisível | Não adotada. |
| Dashboard | Básico no MVP; completo futuramente. |
| Avisos | Globais/segmentados, com vigência e separação entre crítico e opcional. |

# 18. Perguntas em aberto

- Quais campos mínimos serão obrigatórios para criação de uma instituição?

- Quais cargos internos poderão realizar cada tipo de acesso privado?

- Quais limites de plano serão apenas informativos no MVP?

- Quais contadores básicos serão exibidos na primeira versão?

- Qual fluxo humano aprovará mudanças de plano e suspensão?

# 19. Próximas specs

- Functional Spec: ativação de instituição e convite do owner.

- Functional Spec: sessão de suporte e auditoria.

- Technical Spec: schema de tenants, planos, platform memberships e notices.

- Technical Spec: RLS e funções administrativas.

- Test Plan: isolamento entre tenants e cargos internos.

# Fontes e referências

## Fontes internas

- Coelo — Product Vision Oficial v1.

- Coelo — PRD Master Oficial v1.

- Coelo — História da Logo e Marca Oficial v1.

- Mapa competitivo de apps de agenda e comunicação escolar no Brasil.

- Decisões do fundador registradas em 21/06/2026 para os seis PRDs.

## Fontes externas oficiais

- Supabase — Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security

- Supabase — Auth: https://supabase.com/docs/guides/auth

- Supabase — Storage Access Control: https://supabase.com/docs/guides/storage/security/access-control

- Supabase — Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization

- Supabase — Edge Functions e secrets: https://supabase.com/docs/guides/functions e https://supabase.com/docs/guides/functions/secrets

- Flutter — App architecture: https://docs.flutter.dev/app-architecture

- ANPD — Enunciado sobre dados de crianças e adolescentes: https://www.gov.br/anpd/pt-br/assuntos/noticias/anpd-divulga-enunciado-sobre-o-tratamento-de-dados-pessoais-de-criancas-e-adolescentes

- ANPD — Comunicação de incidentes de segurança: https://www.gov.br/anpd/pt-br/assuntos/comunicacao-de-incidentes-de-seguranca-cis

- OWASP — ASVS: https://owasp.org/www-project-application-security-verification-standard/

- OWASP — MASVS: https://mas.owasp.org/MASVS/

Acesso às fontes externas: 21/06/2026. As referências jurídicas não substituem revisão por profissional habilitado.
