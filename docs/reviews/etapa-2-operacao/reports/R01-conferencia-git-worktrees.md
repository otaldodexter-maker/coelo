---
title: "Conferência de commits e worktrees — R01"
source: "Git status, ls-remote, bundle verify; comparação independente C00; decisão Owner pendente para checkout original"
status: "R01-clean-and-published; original-checkout-reconciliation-pending"
generated_at: "2026-09-09T09:08:46-03:00"
---

# Conferência de commits e worktrees

C00 e C01–C07 tiveram HEADs conferidos contra os respectivos remotos e nenhum arquivo pendente no fechamento. C07-c04ro também estava limpo. O painel por tela foi publicado em dev/C00 `86eda2ec`; os recibos documentais posteriores avançam essa mesma entrega. Todas as novas alterações C00 deste pedido recebem commit e push antes de encerrar o turno.

**Isso não significa que todas as branches tenham o mesmo conteúdo.** Há WIP e candidatos com erros/dependências, preservados nos heads das frentes. As integrações seletivas usam outros SHAs; contagem de commits exclusivos por ancestralidade não mede trabalho faltante. `origin/dev` é a base operacional única da entrega; não forçar a incorporação de candidatos para zerar uma contagem.

Bundle atualizado de oito branches: `C:/Users/adrie/Documents/Coelo.preserved/e2-r01-close-20260909-c00/round-final-branches-0909-0908.bundle`, SHA256 `a7caa14d494b9196b8a4a944f4680e1db6eaa8511b99de5e817401e5754eb8b9`, verificação PASS/história completa. Inclui C06final `e3223e63` e C00 `86eda2ec`. ZIP4069 e seis locks preservados permanecem válidos; fontes não removidas.

## Exceção material: pasta original

`C:/Users/adrie/Documents/Coelo` continua na branch local dev `84985b54`, anterior à R01, com **37 arquivos rastreados alterados e140 não rastreados**. Nada staged. A branch remota dev avançou, mas isso não atualiza automaticamente o checkout original.

Comparação contra a entrega:28dos37arquivos equivalem (7byte a byte e21após normalizar CRLF/LF);9têm diferenças residuais, envolvendo Tutor, Design System, aprendizagem, perguntas, rastreadores e inventário.21caminhos não rastreados colidem com arquivos da entrega. Nenhum conteúdo foi apagado, sobrescrito, commitado indiscriminadamente ou enviado por este diagnóstico.

O histórico permite avanço direto da branch, mas os arquivos locais exigem preservação/reconciliação. C00 perguntou ao Owner se esse trabalho anterior entra na unificação ou se a pasta deve ficar intacta e C00/dev permanecer como base das novas conversas. A resposta continua pendente. **Não afirmar que todo o ambiente está limpo ou que tudo foi integrado enquanto essa exceção existir.**

A reconciliação não altera porcentagens do produto por si só. Painéis oficiais mantêm critérios de exame/conclusão e listas de faltas por ação, com38famílias e219ações.
