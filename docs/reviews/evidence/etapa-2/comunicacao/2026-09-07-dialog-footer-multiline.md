---
title: "Diálogo canônico — ações multiline com altura equivalente"
source: "Coelo UI pattern.dialog-actions; reserva aditiva do Coordenador; inspeção dos candidatos de imagem Chat"
status: "local-verified; no-e2e-claim"
generated_at: "2026-09-07"
---

## Recorte e evidência

Objetivo: preservar a altura equivalente das duas ações em linha quando uma
quebra texto. Incluído somente `CoeloAdminDialogShell` e teste do componente;
fora tokens, cópias, roteamento, backend e baselines históricas. Ordem: RED,
correção canônica, regressões e inspeção; parada no gate local. Estimativa
inicial 15–25 minutos. Reserva explícita recebida do Coordenador neste turno.

Seis REDs reproduziram desigualdade a 768/1024/1440, texto 100/200%, no harness
sem fontes reais. A inspeção com Nunito Sans também reproduziu 104 versus
64 px em texto 200%. `IntrinsicHeight` envolve apenas a Row de duas ações e
`CrossAxisAlignment.stretch` iguala sua altura pelo maior conteúdo. Não fixa
altura, não reduz fonte e não modifica a variante compacta empilhada.

- 11/11 testes do shell de diálogo (seis novos) passaram.
- 22/22 testes consumidores: Bug, agendamento de Formulários, preview Avisos,
  crop de capa e avatar; incluem teclado, texto 200% e conteúdo rolável.
- 68/68 testes de shell global e seletor avançado de cor passaram, incluindo
  os goldens já existentes nessa suíte, sem atualização.
- Analyzer focal, formatação, diff-check e validador visual passaram. O pacote
  estava sem resolução local: `pub get --offline` restabeleceu seu cache de
  dependências existente, sem nova dependência ou arquivo versionado alterado.
- Revisão independente read-only aprovou o recorte e a contenção do custo
  intrínseco às duas ações, sem bloqueante adicional.
- Candidatos novos do Chat gerados separadamente: quatro estados, dois temas,
  quatro larguras, texto 200% e reduced motion. Imagens pós-correção de
  expired/unavailable foram inspecionadas; ações em linha têm alturas iguais.

O pacote não prova todos os diálogos de todas as verticais. A correção também
não certifica Chat E2E, transporte de mídia, Auth ou R2. Nenhuma migration,
mutation remota ou baseline histórica alterada. A variante empilhada conserva
largura integral e altura natural de cada ação.

Memória: no-op; restaura regra canônica já aprovada, não cria política ou UX
nova. Rastreadores oficiais pertencem ao Coordenador e recebem este handoff.
