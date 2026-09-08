---
title: "Respostas — autosave local e revisão explícita"
source: "Prompt Owner E2E4 responder/autosave/enviar/editar; aprovação central explícita; plano homônimo; testes/review locais"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

# Resultado delimitado

Autosave após 800 ms de alteração efetiva na superfície de Respostas com API,
não na simulação DEV. Abertura/hidratação não salvam. Reaproveita a fila de
fd602806, mantendo comando e revisão enquanto aguarda receipt. Rascunho pode
estar incompleto; revisão e envio permanecem explícitos. Revisão suspende timer;
edição posterior exige nova revisão, exceto retry de envio já incerto.

Estados informam alterações, salvando, salvo e falha. Receipt antigo preserva
edições posteriores e agenda próximo debounce, sem falso salvo. Falha/conflito
pausam automático até ação manual; confirmação perdida usa o mesmo comando.
Negação oculta conteúdo e impede novas chamadas. Troca/dispose cancelam timer;
inputs e botões capturam geração, inclusive envio e reabertura de edição.

Entrada numérica inválida/não finita não é convertida em exclusão silenciosa
nem chega ao JSON. Preserva valor anterior e bloqueia novos comandos até
correção; campo oculto deixa a validação. Receipt que substitui respostas limpa
invalidez transitória, permitindo reabrir edição após submit confirmado;
receipt draft antigo conserva invalidez da edição local posterior.

# Evidências

- **18 testes novos**, arquivo de Respostas agora com **52 testes**.
- REDs de debounce ausente, rascunho incompleto, serialização, callbacks antigos
  de input, envio sem revisão atual, número inválido/NaN/Infinity e reabertura
  bloqueada por invalidez transitória após envio confirmado.
- Fake commit + confirmação perdida, conflito/negação sem loop, revisão sem
  autoenvio, contexto/dispose, ramo oculto e 375px/200% como controles.
- Dois testes anteriores passaram a controlar frames antes do debounce e logo
  após receipt; mesmas expectativas de preservação/replay, sem aguardar
  indiscriminadamente animações enquanto um novo autosave podia iniciar.
- Regressão conjunta final: **239/239** em nove suítes Forms, exit 0.
- Analyzer dos dois arquivos e validator visual canônico: sem achados.
- Review independente final: sem bloqueante. Nenhum golden atualizado.

# Limites e memória

Nenhuma rota, SQL, Docker, realm, mídia ou segredo anônimo alterado. Este pacote
não resolve elegibilidade nominal/remota nem abertura anônima com segredo.
Integração e E2E continuam abertos. A fonte do autosave respondente foi
confirmada pelo Coordenador no prompt específico, não inferida da cláusula do
construtor. Não surgiu nova política; nenhuma projeção por mera atividade.
Trackers/ledger e integração pertencem ao Coordenador. Escopo original mantido.
