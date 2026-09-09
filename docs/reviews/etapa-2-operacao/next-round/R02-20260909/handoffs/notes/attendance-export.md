---
title: "R02 D03 — aceite informativo de exportação de Assiduidade"
source: "AGENTS.md; prompts/D03.md; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/evidence/etapa-2/agenda-operacoes/2026-09-07-deferred-exports.md"
status: "proposed-fe-verified-deferred; awaiting-d00-promotion"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Assiduidade — `attendance.export`

## Critério nominal

`attendance.export` está classificada como `deferred-post-mvp`. Nesta rodada,
seu aceite de Front-end exige somente controles CSV/XLSX visíveis, acessíveis e
responsivos, o aviso honesto `Disponível depois do MVP` e nenhuma solicitação,
poll, download, arquivo ou job. A operação real não deve ser implementada.

## Verificação atual

Base observada no início da prova: `14def90d3d2f7adbaf7289406183d3982a4580bf`.
A UI de `AttendanceDashboardPage` contém dois controles informativos e zero
referência a `requestExport`, `fetchExportJob`, RPC ou Edge Function. O
repository de teste contabiliza solicitações e polls; os dois contadores
permaneceram em zero depois do toque real em CSV e XLSX.

O lote focal nominal aprovou 5/5 casos únicos, 0 falhos:

- quatro configurações do dashboard: 375 px com texto 200%, 768 px escuro,
  1024 px claro e 1440 px escuro;
- controle visível, alvo mínimo de toque, mensagem correta e ausência da antiga
  ação `Solicitar exportação` em cada configuração;
- negativa existente do adapter bloqueando escopo amplo não autorizado antes
  da requisição HTTP.

Evidências:

- `C:/Users/adrie/AppData/Local/Temp/d03-attendance-export-five-focals.log`
  — SHA-256 `4991EF72EF68B628D2B36534DCDE9CBC6C85591AC7720D922ADCCD2B16EBC854`;
- `C:/Users/adrie/AppData/Local/Temp/d03-attendance-export-static.log`
  — SHA-256 `DD6E1DCD97BABF463E921AC68B2E3D4E0BC3BCD1E5BF40EB9A0DC198C41D7702`.

Os cinco casos são provas de uma única ação, não cinco ações. A evidência
histórica de 07/09 permanece coerente e não foi contada novamente.

## Proposta ao D00

Promover exclusivamente o Front-end de `attendance.export` para 1/1 no recorte
adiado. O adapter legado de exportação real permanece congelado e desconectado
da UI; este aceite não autoriza sua chamada, remoção ou alteração. Backend,
remoto e E2E não recebem promoção nesta prova.

Gate de conhecimento: `no-op`; a classificação pós-MVP e o comportamento
informativo já estavam registrados nas fontes canônicas.
