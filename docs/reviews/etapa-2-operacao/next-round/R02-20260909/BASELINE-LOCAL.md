---
title: "E2 R02 — delta local herdado de Auth"
source: "Git local; turno de Auth interrompido pelo Owner; baseline-local-manifest.json"
status: "prepared-not-started"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Delta local herdado — preservar antes da execução

Este pacote documental não alterou o aplicativo. Já havia uma correção local
do turno que o Owner interrompeu para manter a conversa no planejamento.
Ela permanece sem commit; não faz parte de dev/origin-dev
fb2d07d34a74c91ec1f65aff361048393e590729 e não certifica Auth.

## Conteúdo identificado

- apps/superadmin/lib/app/router/superadmin_router.dart:
  exibir o erro de revogação ao tentar voltar ao login durante recuperação,
  preservando a recuperação confinada e verificando context.mounted.
- apps/superadmin/test/app/router/superadmin_router_test.dart:
  exigir a mensagem de falha no caso já existente de revogação negada.
- Oito PNGs rastreados de comparação de login dark/light em
  apps/superadmin/test/features/auth/presentation/screens/failures/.
  Comparações mobile também existem nessa pasta, mas não aparecem como
  alterações rastreadas. Identificar e preservar os arquivos reais ao transferir.

[Patch dos dois arquivos fonte](baseline-local-auth.patch) é uma cópia do delta,
não uma aprovação para aplicá-lo duas vezes.
[Manifesto de hashes](baseline-local-manifest.json) identifica os dez arquivos
rastreados alterados; hashes não substituem backup dos PNGs.

## Evidência histórica desse turno

| Verificação | Resultado observado | Limite |
| --- | --- | --- |
| Caso de falha ao retornar ao login | RED antes da correção; passou depois | Prova focal, não nova tela E2E |
| Recorte recovery do roteador | 14 aprovados | Não cobre todo login/reset nem provedor real |
| Comparações visuais de login | 3 falharam: claro, escuro e mobile | Diferenças ainda não reconciliadas com a fonte visual |

Diferenças registradas: desktop claro2,58% (33445 pixels), escuro3,01%
(39054 pixels), mobile9,31% (29467 pixels). Não são percentual de avanço.
O controle “manter sessão” mudou depois da baseline visual antiga; isso é
uma pista para análise, não autorização para substituir todas as referências.
Não houve análise estática final nem prova E2E desse delta. Nenhum desses
lotes foi reexecutado para preparar os prompts.

## Transferência futura D00 → D01

Ao iniciar a execução, D00 confere a árvore real, preserva patch e arquivos
gerados em destino explícito com hashes, e confirma que D01 recebeu.
D01 avalia e incorpora somente o delta válido; não refaz silenciosamente
o trabalho anterior e não muda goldens para esconder falha.

D00 reconcilia somente esses paths na raiz de forma reversível após preservar
e confirmar a transferência. Até isso ocorrer, qualquer execução na raiz
tem árvore modificada: não atribuir seu resultado a um HEAD limpo.
Revalidar hashes se outros colaboradores tiverem mudado os arquivos.

Não adicionar todos os arquivos de trabalho ao commit documental.
Não executar reset/clean genérico, apagar evidências ou perder mudanças novas
para satisfazer um indicador de worktree limpa.

