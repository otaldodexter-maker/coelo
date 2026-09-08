---
title: "Cabeçalho mobile — contexto correto do relato"
source: "reserva nominal shell:209; catálogo de navegação; review e testes Flutter"
status: "local-green-delta; visual-baseline-open; not-e2e"
generated_at: "2026-09-07"
---

# Resultado

O host passava currentDestination (ID inglês) ao popup, cujo contrato resolve
menu/tela por label. O popup caía em Outros e exigia assunto adicional mesmo em
Instituições. O host agora resolve ID pelo catálogo existente, preservando
fallback quando não encontrado. Nenhuma alteração no popup, catálogo ou DS.

- RED dois casos (preview/normal): campo Outros indevido.
- GREEN **3/3** focal e **69/69** com shell; seleção Instituições e payload
  Estrutura/Instituições confirmados. Não prova todos os destinos.
- Analyzer dois arquivos, formatter, diff-check e validador visual sem erro.
- Review crosswalk_media: sem bloqueante no delta nominal.

Baseline principal: popup de Bug aprovado, sem redesign. Golden de overlays
integrado a Turmas: um teste com três comparações falhou, reproduzido com os
mesmos resultados ao remover temporariamente somente este hunk:

| Comparação | Diferença com e sem hunk |
| --- | --- |
| bug_open light1440 | 6,57%; 85.194 pixels |
| profile_open light1440 | 8,07%; 104.626 pixels |
| tour_open light1440 | 7,54%; 97.690 pixels |

Hunk restaurado. Inspeção do golden aprovado e imagem atual de bug_open mostrou
popup visualmente equivalente e alterações de dados/cards/paginação no diretório
ao fundo. Isso não aprova a suíte visual inteira nem autoriza substituir PNGs.
Nenhum arquivo Turmas modificado; dívida visual comunicada ao Coordenador.

Nenhum segredo/backend/remoto tocado. A ação de suporte ainda usa controller
em memória nesta base. Gate de memória no-op; nenhuma decisão nova de produto.
