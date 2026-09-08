---
title: "Cabeçalho mobile — isolamento do suporte demonstrativo"
source: "reserva router do Coordenador; review crosswalk_media; testes Flutter"
status: "local-green-delta; baseline-failures-open; not-e2e"
generated_at: "2026-09-07"
---

# Causa e correção

O host persistente recebia sempre productionSupportController?.submitReport,
mesmo em /dev. O desktop já usava callback demonstrativo da página, mas mobile
escrevia no controller fornecido para rotas normais ou perdia o botão quando
ele era ausente. A seleção do callback agora segue developmentPreview.

Precisão: o tipo atual é SupportPrototypeController em memória, não backend de
suporte real. Nenhum relato remoto foi enviado. Testes usam dados sintéticos.

- RED correto: /dev/institutions confirmado por URI, preview explicitamente
  habilitado; um ticket indevido no controller fornecido e botão ausente sem
  controller. O caminho normal já passava.
- GREEN **3/3**: envio preview isolado, envio normal preservado e botão preview
  disponível sem controller produtivo; **69/69** ampliado com shell funcional.
- Suite router/persistent/wiring: **19 passes, 2 falhas** preexistentes.
  persistent_shell_routes_test:296 espera sidebar em /dev/principal-happens;
  :343 espera shell mobile na mesma rota, hoje standalone. Mesmas duas falhas
  reproduzidas removendo temporariamente apenas o hunk desta correção e
  executando os dois testes; hunk restaurado. Não alterar baseline por inferência.
- Analyzer dos dois arquivos sem apontamentos; formatter/diff-check/validador
  visual exit 0. Review independente: nenhum bloqueante nominal.

A primeira fixture não habilitava preview e redirecionava a Home/login; seu
resultado não é RED válido. Corrigido com allowDevelopmentPreview:true e assert
URI. Para testes históricos usar COELO_APP_ENV=local; uma execução ampliada com
define inexistente foi descartada. Não remover guards para fazer teste passar.

Sem alterações em F-READ, auth/session, shell, banco, provider ou PNGs. A prova
não conclui suporte produtivo nem cabeçalho em todas as rotas. Lacuna adicional
identificada: host passa ID inglês como currentScreen; popup resolve labels e
cai em Outros. Reserva separada solicitada. Memória no-op, sem regra nova.
