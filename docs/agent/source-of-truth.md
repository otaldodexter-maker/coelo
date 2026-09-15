---
title: "Autoridade e ciclo de vida dos documentos Coelo"
source: "AGENTS.md; decisions/0034-mvp-remote-application-and-acceptance-bar.md; decisions/0038-owner-decisions-etapa2-backlog-20260914.md; decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
audience: "team"
---

# Autoridade documental

## Ordem de decisão

1. Instrução direta do Owner na tarefa atual.
2. [Estado atual](current-state.md) e o índice operacional que ele aponta.
3. ADR aprovada mais recente, especialmente quando marca uma decisão anterior
   como `superseded`.
4. Fonte canônica de produto, arquitetura, dados, segurança ou design.
5. Spec ativa aprovada para a superfície da tarefa.
6. Rastreador corrente, apenas para estado, ação, evidência e primeiro gate.
7. Histórico, handoff, checkpoint, prompt e artefato, somente como
   proveniência quando apontados por uma fonte atual.

Uma fonte posterior não deve ser “combinada” silenciosamente com uma anterior.
Se houver conflito, registrar os caminhos em `docs/open-questions.md` e seguir
o documento explicitamente marcado como corrente para a fila de trabalho.

## Mapa canônico por tema

Estes arquivos são baselines de produto e arquitetura. Antes de transformar uma
seção em requisito executável, conferir as ADRs atuais e a spec da superfície;
um baseline pode conter uma proposta antiga dentro de uma seção “MVP”.

- Produto: `docs/product/product-vision.md`, `prd-master.md`,
  `prd-superadmin.md`, `prd-admin.md`, `prd-app.md`.
- Arquitetura: `docs/architecture/macro-architecture.md`, `domain-map.md` e
  `activity-domain-addendum.md`.
- Dados: `docs/data/data-model.md`.
- Segurança: `docs/security/auth-multitenant-permissions.md`,
  `lgpd-security-media.md` e `environment-and-secrets.md`.
- Design: `docs/design/design-system.md`; referências de owner e evidências
  visuais só valem quando houver aceite explícito apontado pela fonte atual.
- Originais: `docs/source/originals/`; preservam proveniência e não substituem
  overlays aprovados.

Overlays operacionais prioritários nesta fase: ADR 0031 (importação/exportação),
ADR 0032 (mídia privada), ADR 0034 (aplicação remota e régua de aceite), ADR
0037 (host/contexto do Principal), ADR 0038 (decisões do Owner da Etapa 2,
registradas no fechamento da R13), ADR 0039 (escopo de Planos comerciais e
Auth) e ADR 0040 (remoção imediata do Agora). `docs/knowledge` é índice
projetado e não sobe nessa precedência.

Os baselines canônicos agora exibem um overlay datado no topo; esse overlay
reconcilia a leitura operacional sem apagar o texto derivado do DOCX. O
relatório de entrega corrente é regenerado por
`docs/reviews/generate-delivery-report.py` e não deve virar uma segunda fila.

## Ciclo de vida

- `current`: pode orientar o trabalho atual.
- `future`: aprovado ou planejado, mas ainda não disponível nem executável.
- `historical`: preservado para proveniência; não orienta nova implementação.
- `superseded`: substituído por outra fonte indicada.

Qualidade e atualidade são dimensões diferentes. Em `docs/knowledge`,
`status: validated` significa que o artigo passou pela validação estrutural e
de conteúdo permitida; não significa que ele seja a regra atual. O campo
`lifecycle` controla a busca operacional.

## Rodadas

Uma rodada nova recebe a fila não terminal da rodada anterior. O registro atual
é a única fila executável. A rodada anterior permanece como histórico de origem.
Itens resolvidos não voltam, IDs não são duplicados e a abertura da próxima
rodada exige decisão explícita do Owner.
