---
title: "Editor nominal — autosave local verificado"
source: "Spec Forms aprovada; plano 2026-09-08-authoring-autosave; revisão central e independente; testes locais"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Resultado delimitado

`FormsEditorPage.authoring` salva automaticamente após 800 ms sem nova edição.
Usa o mesmo save, mutex, expectedVersion e comando/receipt do botão manual.
Hidratação, seleção de cursor de texto e mera navegação não geram save.
Notificações explícitas cobrem título, perguntas e mutações da estrutura;
rebuilds não são tratados como intenções de escrita.

Alteração em trânsito espera confirmação e novo debounce. Não informa salvo
para edição posterior ou confirmação perdida. Falha/conflito pausam o
automático; retry manual preserva comando incerto. Negação impede novas ações.
Contexto/dispose invalidam timers. Busca institucional lenta retoma o dirty
autorizado; não concede capacidade. Backend continua autoridade de cada save.
Enquete incompleta usa validação de rascunho, não gate de publicação.

Descarte suspende timer enquanto o diálogo está aberto; continuar retoma,
confirmar restaura conteúdo confirmado e limpa dirty. Exclusão/movimentação
fazem toda mutação dentro do guard atual, inclusive remoção e dispose.

# Evidências

- 17 testes novos com relógio fake; suíte nominal agora **31 testes**.
- REDs: debounce ausente, serialização ausente, estrutura sem notificação,
  autosave durante descarte, timer perdido em catálogo lento e exclusão após
  negação durante modal. Todos corrigidos e com controles positivos.
- Fake adicional persiste receipt/versão e perde confirmação: retry é o mesmo
  comando; edição posterior segue em novo request com versão confirmada.
- Regressão inicial detectou sete casos de ramificação por falta de rebuild no
  callback compartilhado. Correção preservou o rebuild explícito; 14 testes
  de ramificação passaram isoladamente, sem alterar suas expectativas.
- Regressão conjunta final: **221/221**, nove suítes Forms, exit 0.
- Validator visual canônico: exit 0. Nenhum golden atualizado.
- Analyzer dos dois arquivos Dart: sem achados.
- Revisão independente estática do delta final: sem bloqueante.

# Limites e memória

Nenhum SQL, Docker, rota, deploy ou recurso remoto alterado/executado. A prova
não estabelece autosave integrado ou E2E. Preserva o requisito já aprovado;
nenhuma projeção de conhecimento criada para registrar atividade. Plano e
evidência são da frente, trackers/ledger continuam com o Coordenador.
Locais internos, Cuidado, Respostas, publicação/distribuição e XLSX por
formulário permanecem no escopo original e com seus gates próprios.
