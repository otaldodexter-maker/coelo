---
title: "Agora — ownership dos editores de publicação"
source: "Reprodução TDD, suíte de publicação e revisão independente read-only"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Falha e correção

Quatro REDs reproduziram Texto/Cortar com outra rota acima e com a página
de origem descartada: Concluir antigo fechava a outra rota; descarte tentava
alterar Navigator durante árvore bloqueada e consultar ancestral desativado.

Remoção pós-frame apenas das rotas próprias capturadas; builders obsoletos
ficam vazios. Callbacks exigem página e contexto montados, geração/controller
atuais e rota própria no topo antes de alterar estado ou fechar. O slider
verifica antes de escrever no notifier. Texto, áudio e botão X compartilham
a proteção. Não muda contrato de publicação, layout nem autorização backend.

# Evidência

- Dez testes de callbacks capturados: Texto/Cortar/fechar X/confirmar áudio/
  remover áudio, cada um com sobreposição e descarte. Preservam a outra rota
  e a mesma instância do rascunho; retorno após descarte não deixa editor.
- 91/91 testes da feature, incluindo goldens existentes, sem atualizar PNG.
- Analyzer dos dois arquivos, format, diff check e validador visual passaram.
- Revisão independente read-only sem P1/P2 no recorte; execução feita pelo root.

# Limites

Teste local com mídia sintética inválida e repository em memória para isolar
ciclo de vida. Não demonstra upload, áudio real, R2, Stream, persistência,
produção ou E2E. Sem mutation remota, migration, novo contrato ou conhecimento
de produto durável; memória reutilizável permanece sem alteração.
