---
title: "Avisos — divergências visuais anteriores às correções N01"
source: "golden tests locais; comparação temporária com 6e7bc23; histórico d4374e39 e 2d193ba1; review read-only"
status: "diagnosed; visual-gate-open; not-e2e-complete"
generated_at: "2026-09-07"
---

# Reprodução e limite

Os arquivos `notice_directory_golden_test.dart` e
`notice_form_golden_test.dart` produziram um grupo verde e três grupos com
falha. Quatro comparações reportaram diferenças antes da interrupção dos
loops; não inferir resultado dos demais breakpoints.

| Imagem | Diferença |
| --- | --- |
| notice_form_initial_mobile_light_375 | 37,69%; 127188 pixels |
| communication_directory_light_375 | 0,20%; 680 pixels |
| communication_directory_dark_375 | 0,20%; 680 pixels |
| communication_directory_text_200_375 | 0,47%; 1933 pixels |

Para separar a causa, foram aplicadas temporariamente as versões do commit
6e7bc23 de `notice_form_page.dart`, `notice_form_controller.dart`,
`development_notice_repository.dart` e `support/fake_notice_repository.dart`.
O diff desses quatro arquivos contra essa base ficou vazio. O mesmo comando
reproduziu os mesmos quatro resultados. As versões correntes foram restauradas
integralmente antes de prosseguir; nenhuma mudança experimental ficou no Git.

## Causas identificadas

- Formulário: o footer compacto atual acompanha o conteúdo dentro da rolagem;
  a referência mantém o footer junto ao fundo da tela. O commit
  `d4374e399b5b02c4d03fd02df7b6dd290e289d09` alterou explicitamente
  `SuperadminFormFrame` para manter ações compactas acessíveis. Não é efeito
  das correções de receipt/versionamento/feedback desta frente.
- Diretório: o commit `2d193ba1a13aa5b7ff6ec7f48ae5a628f41eaa51`
  passou os quatro argumentos compactos ao rodapé de paginação compartilhado.
  Os goldens anteriores não acompanharam a troca: labelLarge, setas
  arredondadas e cor disabled explicam as diferenças inferiores. Busca,
  filtros, tabs e cards permanecem iguais nas comparações inspecionadas.
- Review independente `review_chat_receipt` confirmou o histórico e a
  localização da diferença do diretório. O writer também inspecionou as
  imagens mobile light e o diff dos componentes no histórico.

Nenhum PNG, layout, shell ou estilo foi alterado. `failures/` foi usado para
diagnosticar diferença, não como nova referência aprovada. Atualização de
baseline exige decisão visual explícita e regressão da matriz completa;
o diagnóstico não promove Front-end ou E2E.

Gate de memória: no-op, sem decisão visual nova.
