---
title: "Handoff 1 — Estrutura: fila SQL destravada e defeito de Instituições corrigido"
source: "worktree e2-r03-estrutura, branch work/etapa2-r03-estrutura"
status: "entregue ao coordenador"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Handoff 1 — grupo estrutura

**Base:** `bb15db748` (dev no HEAD dos prompts da R03). **HEAD entregue:** `33c159af9`,
publicado em `origin/work/etapa2-r03-estrutura`, árvore limpa, sem WIP retido.
A Fase 0 ainda não publicou `base.fase0Head`, então nada de UI de diretório foi
tocado; o rebase acontece quando a base sair.

## O que fechou

**Os três pacotes SQL retidos desde a rodada anterior estão verdes.** Eles
existiam escritos e nunca tinham sido executados. Escrevi o perfil de replay que
faltava — `StructureLocationConsumersV1` — e rodei: 3 arquivos, **109 asserções,
Result PASS**, zero recurso Docker residual. A entrega para a fila está em
`sql-package-handoff.json`, com ordem, objetos criados, chave de composição e
`action_id` por pacote.

O motivo de eles nunca terem rodado ficou claro na execução: a migration de
Atividades declara no cabeçalho que só se aplica sobre a **união** revisada
`ActivityAggregateConcurrencyClock` + reservas. Sobre o perfil de reservas
sozinho ela aborta com `SQLSTATE 55000`. **Isso vale igual para produção**: a
fila precisa garantir o agregado de Atividades v2 aplicado antes de
`20260909200000`.

**O defeito confirmado de Instituições foi corrigido, com prova causal.** O
diálogo de sair sem salvar é assíncrono; entre abrir e responder, o formulário
podia ter sido recarregado para outra instituição. `_requestExit` e
`_selectDestination` agora guardam controller e sequência de carga antes do
`await` — o mesmo padrão `isCurrent` que `_save` já usava. Dois casos novos
falham sem a correção e passam com ela.

Varri o mesmo padrão nas seis famílias e corrigi mais três ocorrências (duas em
Unidades, duas na assinatura de Instituições). Essas são endurecimento: não têm
caso reprodutor, e isso está escrito no teste e no commit.

## O que ficou aberto, e o primeiro gate de cada um

| Aberto | Primeiro gate |
| --- | --- |
| Aplicar os três pacotes em produção e ligar as chaves | Coordenador: fila SQL, na ordem, com o agregado de Atividades antes do segundo pacote |
| `units.*` e `groups.*` fail-closed | **Treze** RPCs de Unidades sem migration (não cinco): leitura de `pg_proc` em `public` e `app_private`. Duas delas sustentam também o diretório de Turmas |
| `units.*` e `groups.*` mesmo com as RPCs | `superadmin_auth_scope.dart` compõe os dois diretórios como `Unavailable*` e fixa `structureMutationsEnabled: false`. Conferir `pg_proc` responde metade da pergunta |
| Telas de diretório das seis famílias | Base da Fase 0 |
| E2E na régua do MVP | Sem `COELO_SUPABASE_URL`/`PUBLISHABLE_KEY` nesta máquina não consigo abrir a rota normal contra produção |
| 10 goldens vermelhos (8 Instituições, 2 Unidades) | Marcados R/A na lista de decisões: quem regrava é a Fase 0, depois da observação. Nenhum foi regravado aqui |

## Próximo passo

Auditar o caminho de composição de Turmas, Atividades, Locais e Avaliações,
como fiz em Unidades, para que a fila do coordenador já saiba o que está
fail-closed antes de a base da Fase 0 sair.
