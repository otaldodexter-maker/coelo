---
title: "Perguntas abertas e conflitos"
status: "open"
generated_at: "2026-06-22"
---

# Perguntas abertas e conflitos

Este arquivo registra conflitos, lacunas e decisoes que nao devem ser resolvidas silenciosamente.

| ID | Tema | Questao | Fonte/Contexto | Decisao necessaria |
| --- | --- | --- | --- | --- |
| OQ-001 | Dominio | `coelo.com.br` fica como alias futuro ou dominio secundario? | Plano aprovado define `coelo.me` como primario; documentos podem mencionar outros caminhos. | Confirmar estrategia de dominios e redirecionamentos. |
| OQ-002 | Midia privada | PRD Master fala em Supabase Storage/R2 futuro, enquanto Arquitetura Macro recomenda R2 desde o MVP. | Decisao atual: R2 como destino unico, com spike obrigatorio antes de implementar. | Aprovar resultado do spike e ADR final de midia. |
| OQ-003 | LGPD juridico | Papel juridico Coelo/instituicao, DPO, bases legais, DPA/RIPD e retencao seguem pendentes. | PRD LGPD/Seguranca/Midia e requisitos de operacao. | Revisao juridica antes de producao. |
| OQ-004 | CPF adulto | CPF adulto e obrigatorio, mas armazenamento cifrado/tokenizado/hash auxiliar ainda precisa de decisao. | PRD Auth e Modelo de Dados. | Definir estrategia tecnica e juridica para CPF. |
| OQ-005 | Permissoes familiares | Flags de permissao familiar ainda precisam de granularidade final. | PRD App, Auth e Modelo de Dados. | Fechar matriz de permissoes por contexto. |
| OQ-006 | MFA | Obrigatoriedade, perfis exigidos e fluxo de recuperacao de MFA seguem abertos. | PRD Auth e Seguranca. | Definir politica por papel e risco. |
| OQ-007 | Username infantil | Prova para pesquisa de username infantil e edicao de username infantil seguem abertas. | PRD App/Auth. | Definir regra de seguranca e UX. |
| OQ-008 | Push | Provider de push ainda nao definido. | Modulos de notificacao. | Avaliar provider em spec tecnica. |
| OQ-009 | Midia | Limites de midia, transformacoes, expurgo e limpeza de orfaos precisam de spec. | R2 e PRD LGPD/Midia. | Fechar limites operacionais e custos. |
| OQ-010 | Reacoes | Escopo de reacoes simples em posts/mensagens precisa de definicao. | PRD App e comunicacao. | Definir MVP e moderacao. |
| OQ-011 | Moments | Navegacao de Moments precisa de especificacao de UX. | PRD App. | Criar spec de UX antes da implementacao. |
| OQ-012 | Chat/Admin | Politica de acesso do Admin a chats precisa de regra explicita. | PRD Admin, App e LGPD. | Definir acesso, auditoria e limites. |
| OQ-013 | Postgres fisico | Schemas, prefixes, soft delete e particionamento ficam para Technical Spec. | Modelo de Dados e Arquitetura Macro. | Fechar antes de migrations. |
