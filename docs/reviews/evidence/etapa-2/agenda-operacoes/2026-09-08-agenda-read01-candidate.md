---
title: "AG-READ01 — candidata forward-only após RED53"
source: "contrato crosswalk AG-READ01; reserva nominal do Coordenador; RED Eng1 3c644398c1ddcaf38dc146cb0b30e6546afd6120; fixture a3b76f5"
status: "review estático concluído; aguardando GREEN nominal; não executada pelo root"
generated_at: "2026-09-08"
---

## Pacote

Migration nova `20260908045531_superadmin_agenda_read_v2.sql`, 20249 bytes LF.
SHA256 LF `b26487cb3d3ffbf483ba3f6ff7b94e7f6d4e95d3309dd9c96640b37532287cab`;
SHA256 UTF-8/CRLF `15a490013e556d4a271dc2e026dc564737f0bf078c25a9916e5276c3db57f4a9`.
Nenhum arquivo SQL histórico ou fixture modificado. Fixture original a3b:
blob `e8ea4a9322dfa94c6a75e0e65756639fc79f9569`, LF
`9d2df04630933638123ff5841aa65a5c49bb2198cc78db33bb849c68b9cb3418`.

O contrato foi fechado no crosswalk antes da implementação. Candidata adiciona
três wrappers públicos list/get/contexts e três helpers privados exclusivos de
leitura/projeção/envelope. Os wrappers são VOLATILE SECURITY DEFINER, owner
postgres, search_path vazio, EXECUTE somente authenticated. Helpers são invoker
sem EXECUTE para PUBLIC/anon/authenticated/service_role. Não concede nenhuma
capability/papel, não muda RLS/tabelas/comandos nem helpers039/Activities.

Cada entrada revalida `agenda.read` pelo039 vigente, aplica scope institucional
ou plataforma e valida relações reais antes de projetar. Lista: interseção
temporal, trim/busca literal em título ou descrição, limites e paginação estável,
total independente. Get: não encontrado/B/contexto incoerente indistinguíveis,
histórico somente evento+instituição. Audience exclui detalhes pessoais com flag
false; não fabrica array vazio de pessoas. JSON é reconstruído por allowlists.
Contexts usa hierarquia ativa e sete capabilities efetivas, com integração de
mutação explicitamente indisponível.

Audit14 de sucesso fica fora do catch, com identidade/sessão/correlação039,
instituição do scope e somente row_count. Negativas não recebem instituição
enviada pelo cliente ou de recurso recusado. Não se devolve SQLERRM ou dado
parcial em erro. Falha de append não retorna sucesso.

## Evidência disponível

Root leu integralmente o relatório e JSON de catálogo Eng1 em `3c644398`:
base53 aplicada, catálogo10 PASS, contrato114 TAP com21 PASS/93 FAIL sem aborto;
primeiras três falhas por readers ausentes, não93bugs independentes. PostgreSQL
170006, enum Auth e audit14 confirmados. Cleanup independente04:48:47UTC zero
recursos próprios e staging ausente. Não houve inspeção separada de ledger;
SQLSTATE das capturas ausentes não foi impresso e não é reivindicado.

Review independente `activities_sql_review` pediu corrigir busca de descrição/
trim e datas PostgreSQL mais amplas que Dart. Ajustes feitos antes do pin final:
strpos em ambos os campos e datas de recurrence/exceptions emitidas por
timestamptz em JSON. Re-review confirmou hash LF e nenhum blocker estático,
favorável **somente ao handoff para GREEN**. `git diff --check` e gate de memória
com Root explícito: PASS. Nenhum SQL, Docker ou conexão de rede pelo root.

## Próximo gate e limites

Coordenador/Eng1 devem fechar perfil nominal com base53 e esta adição, preservar
catálogo10 e fixture114, revisar/preparar antes do replay serial. Não declarar
54 entradas efetivamente aplicadas antes da prova do operador. Qualquer falha
de closure, catálogo ou contrato volta para diagnóstico; não alterar fixture
para fazer o teste passar.

Busca por descrição/trim e dates não vazias foram revisadas estaticamente, mas
não possuem casos separados na fixture114 congelada. Novos testes suplementares
precisam de pacote nominal próprio, sem editar o RED já aprovado. Nenhuma
alegação de GREEN, cliente integrado, escrita, reserva de local, R2, produção
remota ou E2E. O adapter legado ainda perde a distinção de audiência pessoal
omitida; próxima integração exige DTO parcial explícito, não fallback People.
