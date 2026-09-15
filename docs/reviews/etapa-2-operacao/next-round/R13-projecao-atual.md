---
source: R13-pendencias.md; R13-checkpoint-20260914-1620.md; inventario-etapa-2.json; ETAPA-2-estado-atual.md
status: historical; projeção da R13 encerrada; não executar; fila vigente R14
lifecycle: "historical"
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# R13 — Projeção histórica do corte

A R13 recebeu 50 compromissos, preservando os IDs `owner.r12-*`; os três
concluídos antes da transferência ficaram fora. Na execução de 14/09, mais
`owner.r12-48`, `owner.r12-50` e `owner.r12-51` foram concluídos. Portanto,
47/53 Owner items permanecem não terminais. Este arquivo é uma projeção de
contexto; o checkpoint final da R13 registra o detalhe histórico da prova.

A fila operacional atual é [`R14-pendencias.md`](R14-pendencias.md), formada
pelos 44 Owner items não terminais e pelos resíduos H02–H28 incorporados de
R01–R07. R01–R13 são fontes históricas; não se somam itens duplicados nem se
criam novos action IDs.

## Percentuais canônicos na revisão atual

Base: `docs/reviews/inventario-etapa-2.json`, 231 action IDs únicos, revisão em
2026-09-14, checkout `dev`; confira o SHA no checkpoint mais recente antes de
usar os números como aceite.
BE usa 224 ações aplicáveis e E2E usa 199 ações integradas ativas.

| Métrica | Concluídos | Base | Percentual |
|---|---:|---:|---:|
| Front-end verificado | 157 | 231 | 67,97% |
| Back-end concluído/verificado | 164 | 224 | 73,21% |
| E2E verificado | 130 | 199 | 65,33% |
| E2E + flutter-only | 137 | 231 | 59,31% |
| Front-end local-green | 37 | 231 | 16,02% |
| Back-end local-green | 16 | 224 | 7,14% |
| Owner items done | 6 | 53 | 11,32% |
| Owner items não terminais | 47 | 53 | 88,68% |

Não somar camadas nem usar item de Owner como denominador de action ID.
`137/231` é a métrica combinada de E2E + flutter-only; não substitui o aceite
integrado `130/199`. Validação estrutural e checks locais não certificam
runtime.

## Ordem histórica da R13

1. Saúde/Cuidado: provar as rotas reais de criação, detalhe, edição e medicação
   conforme o checkpoint mais recente.
2. Cardápios: provar as rotas reais e os contratos de remoção/sobreposição.
3. SQL restante: catálogos de tipo, Duplicar Aviso, readers e contratos de
   Formulários, sem reabrir lotes já concluídos.
4. Auth e mídia: retomar redirect, Gateway/R2 e foto somente com o ambiente e
   as autorizações reais disponíveis.
5. FE/E2E: Avisos, Circular, Formulários, Principal, Perfis, Segurança infantil
   e `assessments.close/reopen`, sempre pelos gates específicos.
6. Demais H e Owner items não terminais, mantendo bloqueios e aditamentos
   explícitos; não abrir Etapa 3.

Os bloqueios externos permanecem registrados nos MDs de camada, neste arquivo
e no `R13-owner-items-atual.json`. Eles pertenciam à fila R13 e não devem ser
recontados como itens independentes ou duplicados por origem histórica.
