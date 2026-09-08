---
title: "Respostas — navegação por seções verificada localmente"
source: "Spec Forms 2026-08-13:201; aprovação central; plano response-sections; testes e revisão locais"
status: "local-verified-integration-and-e2e-open"
generated_at: "2026-09-08"
---

Uma seção por página com anterior/próxima e progresso textual/visual acessível.
Identidade por seção/item; Offstage preserva campos, ExcludeFocus exclui seções
inativas da navegação de teclado. Ramos completamente ocultos não contam no
progresso. Seção removida do conjunto ativo escolhe destino válido sem restaurar
respostas ocultas. Navegação não escreve nem altera a fila de autosave.

Revisão percorre todas as seções e leva foco ao cabeçalho da primeira com erro
visível, independentemente da categoria do erro. Tab segue para o campo da
seção ativa. Conteúdo transitório inválido permanece ao voltar; revisão e envio
continuam distintos. Foco tardio confere geração/seção e nodes são descartados
com contexto/controller visual.

Evidências: **10 novos testes**, **62** no arquivo de Respostas; REDs de página,
progresso e ordem global de erros antes das correções. Controles de texto
numérico transitório, autosave em trânsito, receipt ocultando seção atual,
contexto/API, resumo global, teclado e375px/200%. O teste de scroll aguarda
redesenho antes do hit-test; não se suprimiu warning ou overflow.

Regressão final **249/249**, nove suítes Forms, exit0. Analyzer dos dois arquivos
e validator visual canônico sem achados; revisão independente estática sem
bloqueante. Nenhum golden atualizado e nenhuma equivalência pixel a pixel.

Sem endpoint, SQL, Docker, produção, realm, mídia ou anonimato novo. Fonte
canônica já exigia esse comportamento; nenhuma projeção por atividade. Plano
aprovado documenta escolha de apresentação; trackers/ledger são do Coordenador.
E2E e restante do escopo original permanecem com seus gates próprios.
