---
source: "Spec Forms 2026-08-13:180–192; reserva explícita do Coordenador em 2026-09-08"
status: "approved-implementation-plan"
generated_at: "2026-09-08"
---

# Ramos por opção — round-trip local

Objetivo: corrigir filhos de escolha única/múltipla que aparecem no editor,
mas desaparecem no payload. Root é o único writer; revisão independente read-only.

Desenho aprovado: campo canônico seleciona explicitamente o ID opaco da opção
para o próximo filho. Nenhuma opção é inferida. O filho recebe uma condição
choice com essa opção e usa os mesmos cards/árvore dos ramos Sim. Hidratação
somente para condição simples contígua com uma opção válida do ancestral.
Grafos não representáveis continuam planos, intactos e sujeitos ao validador.
Trocar o seletor afeta somente novos filhos; rótulo de cada filho identifica
seu gatilho real. Toggle não exclui conteúdo. Cópias remapeiam IDs da subárvore.

Alternativas descartadas: inferir primeira opção não expressa intenção; novo
editor de grafos amplia desnecessariamente a fatia. Reusar árvore mantém o
contrato plano existente sem introduzir uma segunda linguagem de condições.

1. RED de criação explícita, save/reload, cópia, reorder, toggle e autosave.
2. Implementar seleção/árvore/hidratação/serialização no editor Superadmin.
3. Testar limite de quatro níveis, ciclos/referências inválidas e união de
   múltipla escolha/remoção de valores ocultos usando contratos existentes.
4. Regressão Forms, analyze, validador visual e revisão read-only; registrar
   evidência e commit para integração central.

Fora desta fatia: SQL, endpoints, rotas, publicação, autorização, mídia e
decisões clínicas. Não substitui validação server-side nem comprova E2E.
Parada da fatia: testes/review locais e handoff; o escopo integral permanece ativo.
Estimativa: 30–50 minutos, condicionada aos achados de regressão.

Self-review: não muda regras de produto; preserva condições complexas, IDs,
limites e fila de recibos. Não cria novo conhecimento durável de atividade.
