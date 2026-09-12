---
source: R08-prompts.md common contract and G6; spec 037; ADR 0034 decision 20
status: em-andamento
generated_at: 2026-09-12
---

# R08 G6 — Publicacoes e Agenda

## Contrato inicial

- Objetivo: fechar os gates autorizados de Circulares e Agenda, preservando as provas R06 validas e recertificando somente o codigo afetado.
- Incluido: `circulars`, `agenda`, `principal_circulars`, `circular-media` e notificacoes do shell sob posse confirmada.
- Fora de escopo: inventario/rastreadores, deploy (C0), `publication_surface.dart` reservado a G3 e qualquer decisao visual ausente.
- Ordem: host produtivo versus legado; blocos ordenados; P50; attach no runtime 3014; comparacao dos seis R web/A+; sino e 4.000 versus 10.000.
- Criterio de parada: T0+4h ou ordem do C0; handoff final ate T0+4h10; ajustes ate T0+4h30.
- Evidencias: testes focais vermelho/verde, analise estatica, comparacoes visuais sem sobrescrever R, rota real quando o slot for concedido, commits e push a cada checkpoint.
- Estimativa inicial: o delta de implementacao concentra-se no compositor produtivo e sua previa; o leitor do Principal ja percorre `detail.blocks` em ordem. A prova remota de attach depende do slot Chrome/runtime 3014.

## Abertura

- Base incorporada: `origin/dev` em `0e7042bab`.
- Compositor produtivo: `SuperadminCircularComposerPage`, composto por `ProductionCircularComposerHost` na rota real.
- Compositor legado: `PrincipalCircularComposerPage`, mantido apenas por testes/compatibilidade e fora do host produtivo.
- Limite canonico: `CircularLimits.bodyCharacters = 10000`, coerente com spec 037; a indicacao visual de 4.000 nao altera o contrato.
- Leitor: `PrincipalCircularReader` ja renderiza cada item de `detail.blocks` sequencialmente.
- Primeiro gate: a autoria e a previa produtivas ainda agrupam o primeiro texto, um bloco de midia e as perguntas por tipo.
