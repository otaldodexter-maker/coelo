---
title: "LOC-STATUSA11Y01 — acessibilidade de status compartilhado"
source: "reserva nominal da coordenação; docs/superpowers/plans/2026-09-08-location-shared-status-accessibility.md"
status: "local-verified-not-e2e"
generated_at: "2026-09-08"
---

# Recorte e resultado

Correção nominal de CoeloAdminExpandableStatusIndicator, sem alterar API,
tokens, cores semânticas ou círculo visual recolhido de 24 px. Alvo mínimo
48 px, medição real com TextScaler e negrito de acessibilidade, quebra de
rótulo longo quando limitada a largura e ativação por Enter/Espaço. Hover,
foco, toque persistente e reduced motion preservados. A caixa interativa
maior muda a ocupação vertical dos cards; não se ocultou esse efeito.

Locais também corrige a contagem singular para `1 local`. Não houve ligação
de reader a RPC, rota ou DI, nem implementação de create/edit, mapas, vínculos,
grupos ou autorização remota nesta fatia. O escopo original E2E permanece aberto.

## Testes executados pelo root

- REDs diretos: alvo 24 menor que 48; três rótulos cortados em 200%; Enter/
  Espaço não persistiam expansão; rótulo longo cortado em largura 240; medição
  não acompanhava o negrito solicitado. Correção seguida por 16 testes PASS.
- Pacote coelo_ui_admin completo: 123 PASS. Após substituir somente a API
  deprecated do teste semântico por performSemanticsAction, 16 diretos PASS
  novamente, analyzer dos dois arquivos sem issues.
- `flutter test --no-pub test/features/locations
  test/features/activities/presentation/activity_directory_page_test.dart
  test/features/platform_users/presentation/platform_user_directory_page_test.dart
  test/features/units/presentation/unit_directory_page_test.dart`: 112 PASS,
  incluindo 61 Locais e os consumidores nominais. Goldens Locais verificados
  sem update nessa execução final.
- Analyzer de lib/features/locations e test/features/locations: zero issues.
- Gate visual administrativo: exit 0. Ambos os gates de memória: PASS.
- Revisão estática independente final: nenhum P1/P2 novo; sem execução Flutter
  pelo revisor. Cobertura inclui ação semântica, teclado dentro de card
  clicável sem acionar ancestral, toque fora do dot, foco visível, contraste
  de erro claro/escuro, escala 200%, negrito e reduced motion.

## Evidência visual e limites

Preservados os 30 candidatos anteriores em goldens/. Os 30 candidatos desta
correção ficam em goldens/status_a11y/, não como baseline global aprovada.
Dezoito são byte-idênticos aos anteriores já inspecionados; os doze alterados
foram inspecionados pelo root: cards claro 375/768/1024/1440, escuro 375/1440,
card hover/foco, busca focada, Arquivos aberto, status expandido e status
Suspenso em 375 com texto 200%. Rótulo Suspenso integral e composição sem
overflow visível nesses candidatos; rodapé permanece fora da rolagem.

As duas suítes históricas activity_golden_test.dart e
platform_user_directory_page_golden_test.dart produziram 11 casos FAIL sem
atualização. Controle removendo somente o delta do componente compartilhado
(diff do arquivo vazio) reproduziu os mesmos 11 casos FAIL. O delta foi
restaurado depois. Isso prova falhas anteriores por caso, não equivalência
de pixels: cards light 375, por exemplo, variaram de 24,50%/82683 pixels no
controle para 24,54%/82833 com a mudança. Há impacto incremental esperado de
layout, portanto não se declara aprovação visual integral dos consumidores.
Nenhum golden histórico de Atividades/Users foi sobrescrito.

## Memória e handoff

Sob reserva central dos dois documentos nominais, primeiro a fonte
docs/design/design-system.md e depois a projeção
docs/knowledge/team/coelo-admin-interaction-hierarchy.md foram reconciliadas:
24 visual versus 48 interativo, escala/teclado/reduced motion. Não houve nova
variante visual, edição de SKILL, índice ou benchmark. O conhecimento durável
capturado é essa distinção já exigida no Design System, não uma certificação
E2E. Rastreadores centrais e integração pertencem à coordenação.
