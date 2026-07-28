---
title: "Redesenho Local Do Chat Institucional Do Superadmin"
source: "Referências visuais fornecidas pelo usuário; diagnóstico aprovado em 2026-07-28; docs/design/design-system.md; decisions/0012-contextual-experiences-and-conversation-history.md"
status: "approved-for-local-prototype"
generated_at: "2026-07-28"
---

# Redesenho Local Do Chat Institucional Do Superadmin

## Objetivo

Substituir a composição visual rejeitada do chat institucional por um protótipo
local, leve e responsivo no Superadmin. A entrega usa somente dados simulados e
não constitui padrão, componente ou contrato público do Coelo UI.

## Direção Visual Aprovada

A experiência usa três áreas contínuas quando houver espaço: inbox à esquerda,
conversa como foco central e contexto institucional à direita. Divisores ficam
restritos às fronteiras funcionais; busca e filtros pertencem à inbox; o fio
mantém cabeçalho enxuto, mensagens com largura controlada e composer fixo; o
contexto é secundário, recolhível e granular.

As medidas locais são derivadas de tokens existentes:

- inbox: `7 × CoeloSize.touchMin` (336 px);
- centro: mínimo de `10 × CoeloSize.touchMin` (480 px);
- contexto: `6 × CoeloSize.touchMin` (288 px);
- rail: `CoeloSize.touchMin + CoeloSpacing.space4` (64 px);
- foto contextual: `CoeloSize.touchMin + CoeloSpacing.space4` (64 px).

Em 1440 px as três áreas ficam visíveis. Em 1024 px a conversa é priorizada,
com rail local e contexto sobreposto. Em 768 px lista e contexto abrem sob
demanda. Em 375 px inbox, conversa e contexto formam telas ou sheets separados.
As decisões usam as constraints disponíveis e os breakpoints oficiais.

## Interações Simuladas

- busca, Contextos/Pessoas, filtro avançado, até dois chips e Limpar;
- seções Grupos/Pessoas recolhíveis, seleção múltipla e criação/exclusão;
- nova mensagem e envio em massa por UF, instituição, unidade, grupo ou pessoa;
- mensagem, emoji, áudio e imagem com feedback explícito de demonstração local;
- Enter envia, Shift+Enter cria nova linha;
- contexto e exclusões usam painel/menu e confirmação acessíveis.

## Launcher

O launcher pertence ao shell autenticado, não aparece na rota Conversas e não
depende de flags de páginas individuais. Em repouso é neutro; hover e foco usam
`primary/onPrimary`. Seu conteúdo é uma experiência compacta própria, aberta em
painel ancorado a partir do breakpoint expanded e em modal ou sheet abaixo dele.

## Fronteira Do Design System

O pacote público, catálogo, memória e seção administrativa criados para o chat
anterior serão retirados. Nenhum substituto será promovido nesta fase. Após a
avaliação visual do protótipo, qualquer proposta pública será pequena,
reutilizável e dependerá de nova aprovação explícita.

## Critérios De Aceite

- goldens light/dark em 375, 768, 1024 e 1440 px;
- teclado, foco, semântica, alvos de 48 px e texto a 200%;
- análise estática e testes focados sem falhas;
- nenhuma persistência, entrega, auditoria ou autorização real sugerida;
- screenshots e localhost apresentados antes de qualquer promoção.
