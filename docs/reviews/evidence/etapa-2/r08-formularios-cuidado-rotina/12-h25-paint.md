---
source: "C0 integrado c729; review G4; goldens aprovados de Instituições/Atividades; pacote H25 54c892ebc"
status: "local-green; referências visuais preservadas"
generated_at: "2026-09-12"
---

# H25: preservar pintura e separar interação

C0 mediu411PASS/4FAIL/1SKIP no conjunto integrado: quatro casos falhos nos arquivos de golden de Atividades e Instituições. Não são quatro defeitos independentes nem quatro PNGs: cada caso percorre várias larguras. G3 leu readonly o maskedDiff Instituições claro1024 na worktree C0; os títulos de colunas estavam truncados antes do ponto aprovado, pois a faixa48 havia reduzido em36px a largura de pintura anterior.

A correção mantém a camada de conteúdo com largura integral e IgnorePointer, independente do sort limitado até a faixa48. Quando o botão de ordenar já fornece nome/direção acessíveis, a camada visual exclui sua semântica duplicada. A alça permanece a camada interativa final, com largura48; coluna fixa segue sem ajuste. Não foram atualizados PNGs nem larguras de consumidores.

Teste novo mede136px de pintura para título longo em coluna160 (padding24), junto de48px de resize. RED0PASS/1FAIL em `12-h25-paint-red.log`; tabela completa GREEN21PASS/0FAIL em `12-h25-paint-green.log`. Esse é um caso novo além dos20 do pacote H25; não somar reruns.

Os dois arquivos de golden foram executados contra as referências existentes, sem `--update-goldens`:16PASS/0FAIL, exit0, `12-h25-goldens.log`. Análise dos dois arquivos da tabela:exit0, sem problemas, `12-h25-analyze.log`. São37 casos únicos nesta execução focal (21tabela+16goldens), um novo; não somar os casos já contados em outros pacotes ou no conjunto C0. Slot Flutter liberado.

Residual32/42px do botão sort em colunas80/90 permanece explícito; preservar a pintura não aumenta o alvo interativo e não certifica AA global. O fallback visual do ícone continua defensivo, mas o texto voltou a usar a largura integral anterior, portanto não fica reduzido por causa da faixa de interação.
