---
source: "Review focal G4 sobre d3d3d5d63; slot e correção autorizados C0; base a7b081674"
status: "local-green; sem certificação de navegador"
generated_at: "2026-09-12"
---

# Foto: descarte do formulário com diálogo aberto

`apps/superadmin -> Formulários -> resposta -> Foto -> forms.upload`.

O descarte do proprietário da MediaSession durante finalizeTree preservando o Navigator e o diálogo de câmera reproduziu a exceção de purge: setState era chamado enquanto a árvore estava bloqueada. O teste mantém captura pendente, remove o formulário subjacente e depois entrega bytes tardios.

A correção fecha o controlador e limpa o estado imediatamente. Somente o repaint é postergado para o pós-frame quando o scheduler está em persistentCallbacks, conferindo mounted antes de atualizar. A captura tardia continua sendo zerada e não retorna imagem ao formulário descartado.

RED: 0 aprovados, 1 falho, exit 1 (`09-camera-purge-red.log`). GREEN: todos os 9 testes de câmera aprovados, 0 falhos, exit 0 (`09-camera-purge-green.log`), concurrency 1. Um caso novo; oito já pertencem ao pacote de 182 e não devem ser somados novamente. Análise dos dois arquivos: exit 0, sem problemas (`09-camera-purge-analyze.log`). Não foi repetida a suíte ampla. Slot Flutter liberado a C0 antes de 13:36 BRT.

Nenhuma nova regra de produto ou conhecimento canônico; trata-se de correção de lifecycle da implementação. Nenhuma operação remota, câmera física ou E2E UI executado.
