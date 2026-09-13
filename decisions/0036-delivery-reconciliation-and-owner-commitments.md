---
source: "Owner, 13/09/2026: unificar worktrees/commits e impedir omissão de pendências e avanços"
status: Accepted
generated_at: 2026-09-13
---

# ADR 0036 — Entrega com compromissos e reconciliação verificáveis

## Problema

O fechamento da R10 publicou uma base sincronizada, mas não distinguiu com
clareza a integração da rodada, os patches históricos ainda não revisados,
as worktrees preservadas e as notas antigas nas skills. A comunicação permitiu
entender que a consolidação inteira estava pronta. O Owner determinou corrigir
o processo e consolidar o workspace sem perder trabalho.

## Decisão

1. Registrar todos os pedidos e correções do Owner, inclusive anexos e mensagens
   recebidas durante a execução. Cada item tem ID, tela/subtela/action_ids quando
   aplicáveis, estado FE/BE/E2E, evidência, responsável e primeiro gate se aberto.
   Uma nova mensagem amplia esse registro; não substitui silenciosamente pedidos anteriores.
2. Atualizar inventário, avanços e pendências dos três rastreadores no mesmo ciclo.
   Manter uma visão por tela/subtela. Pendência conhecida não desaparece porque a
   rodada acabou ou porque outro action_id da família foi aceito.
3. Conferir Git real: fetch, HEAD/remoto, alterações, stash, worktrees, branches e
   SHAs exclusivos. Classificar por conteúdo como integrado, equivalente,
   superado com sucessor, ou retido para revisão com responsável e primeiro gate.
   `git cherry` e ancestralidade são indícios, não prova de equivalência semântica.
4. Consolidar a base de entrega no checkout de destino autorizado. Commit/push
   das skills não significa que elas chegaram ao destino; conferir os arquivos
   ali. Em 13/09, o pedido posterior de não deixar nada à frente/atrás autoriza
   alinhar o checkout principal por fast-forward e torná-lo o checkout único,
   substituindo a proteção anterior para esta consolidação. Nunca sobrescrever
   alterações locais ou ignorados; abortar em divergência e preservar o trabalho.
5. Arquivar worktrees encerradas somente após preservar commits/referências e
   ignorados, verificar o backup, conferir ausência de escrita ativa e registrar
   como restaurar. Uma branch histórica preservada não é entrega funcional nem
   deve ser mesclada com `ours` para fabricar ancestralidade.
6. Executar o [gate de entrega](../.agents/skills/coelo-flutter-supabase-review/references/delivery-gate.md).
   `PASS DOCUMENTED_PARTIAL` permite informar a parte entregue e o que falta;
   nunca permite dizer que tudo está concluído. Falha no gate bloqueia a
   declaração de conclusão, não impede comunicar estado ou preservar WIP.
7. Separar implementação, teste local, UI real, integração Git e deploy. Prova
   documental não certifica produto. Corte de tempo/cota exige fechamento parcial
   explícito, sem esconder a pendência ou iniciar outra rodada automaticamente.

## Limites da automação

O validador detecta ausência de arquivos, itens, ações, referências, SHAs,
sincronismo e destino. Não interpreta toda a conversa, não verifica a verdade
de uma prova visual e não decide equivalência semântica de patches. O integrador
deve confrontar o registro com os pedidos do Owner e revisar conteúdo. Uma
exceção deve citar a instrução explícita que a autoriza; não pode ser inventada
para obter PASS. Não há garantia absoluta de execução futura, mas há critérios
objetivos para rejeitar um fechamento incompleto.
