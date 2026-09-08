---
title: "Respostas — retry após confirmação perdida"
source: "Spec Forms aprovada; FormResponsePage; revisão read-only e testes locais de receipt"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Correção delimitada

Salvar, enviar e reabrir edição criavam um request novo em cada tentativa.
Quando o servidor persistia e a confirmação se perdia, retry usava request novo
com versão antiga, produzindo conflito em vez do replay do receipt.

Agora a superfície retém operação, comando e revisão local originais até obter
confirmação. Outra operação fica bloqueada durante a incerteza; chamadas
concorrentes são bloqueadas também no handler. Validação/conflito definitivos
liberam a intenção. Troca de API/ocorrência limpa o contexto e callbacks antigos
não aplicam estado. Erro de reabertura é visível também no estado enviado.

Save confirmado preserva alterações locais posteriores e informa que ainda não
foram salvas. A próxima intenção usa request novo e versão confirmada. Envio
continua mostrando o snapshot efetivamente confirmado, não a edição em trânsito.

# Evidências

- Fake confirma versão/receipt e lança unavailable: três RED, um por operação.
- Após correção, os três retries reutilizam o mesmo comando; controle adicional
  preserva respostas posteriores, bloqueia outra operação e usa a nova versão.
- Arquivo de Respostas: **34/34**.
- Regressão conjunta de nove suítes Forms: **202/202**, exit 0.
- Analyzer dos dois arquivos Dart e validator visual canônico: sem achados.
- Review independente estático sem bloqueante. Nenhum golden atualizado.

# Limites e memória

Nenhum backend, rota, realm, contrato anônimo, mídia, SQL, Docker ou recurso
remoto foi alterado/executado. A prova é local e não torna o fluxo nominal de
Respostas integrado. Abertura inicial de draft é fluxo separado, não coberto
pela retenção dos três comandos desta correção.

TDD e revisão orientaram o fake de commit seguido de falha, evitando teste que
simula apenas erro antes da persistência. O contrato durável de idempotência já
existia; nenhuma projeção de conhecimento foi criada por mera atividade.
Trackers/ledger continuam com o Coordenador; escopo E2E original permanece.
