---
title: "Deltas propostos às skills — R05 publicacoes-agenda"
source: "handoff.md desta pasta; comunicacao/publicacoes-agenda.json rev 31–36"
status: "proposta ao coordenador (escritor central das skills)"
generated_at: "2026-09-11"
---

## coelo-backend

- **Ponte de ator nas RPCs people-based que resolvem pessoa por `person_auth_links`**: qualquer helper que junte `person_auth_links` diretamente (caso `app_private.circular_actor`) ignora a pessoa de serviço de 220400 e nega o Superadmin com `active_membership_required`. Regra: resolver por `app_private.current_person_id()` e somar a capacidade interna v2 (`require_superadmin_internal_context` mapeado por código) à people-based, mantendo a exigência de membership ativa na instituição. Varrer os demais helpers (`*_actor`) antes de declarar uma família "aberta pela ponte".
- **"Presente em produção" mede objeto, não forma**: a migration histórica de R2 de Circulares constava como presente (funções existiam), mas `prepare_circular_media_upload` de produção não conhecia `storage_provider`. Ao afirmar presença, conferir também `pg_get_functiondef` pelo trecho que distingue a versão (ou rodar o pgTAP estrutural no espelho).
- **Gateways internos v2 podem ter bloqueios de desenho** (`CIRCULAR_MEDIA_BLOCKED`) que só aparecem na prova ponta a ponta; a prova por RPC precisa cobrir o caminho completo (upload + referência no rascunho + publicação), não só o upload.
- **pgTAP em transação**: `publish_at` gravado por `clock_timestamp()` fica à frente de `now()` congelado; a fixture recua a data (ou compara com `clock_timestamp()`), senão `circular_visible` nega sem motivo real.
- **Fixture idempotente com gatilhos de espelho** (lote 29): inserir membership com `not exists` e neutralizar as espelhadas dos usuários negativos, senão a suíte quebra na ordem real.
- Worker de Avisos: agendamento por RPC/tela para +2 min vira `active` com `reach>0` em até ~3 min (cron + `notice-publication-worker`); prova barata para "materializado pelo worker real".

## coelo-frontend

- **Referência iOS do calendário** (P33, aplicada em `agenda_calendar_page.dart`): grade sem contêiner por célula, linhas finas entre semanas, número menor no canto superior esquerdo com respiro, hoje em círculo cheio, pastilhas com ícone + título (clip, não reticências), cancelado hachurado com `CANCELADO:` e hora, toggle Calendário/Lista em 50/50 centralizado, botão Hoje no rodapé. A célula calcula quantas pastilhas cabem na altura fixa e mostra `+N`.
- **Detalhe usa o mesmo rodapé de formulário** (P34): `SuperadminFormActionFooter` sobre `ColoredBox(surface)`, destrutivo à esquerda e ação primária à direita; conteúdo em `SingleChildScrollView` + `Column` (não `ListView`) com respiro `space10` sob o rodapé.
- **Testes de estados remotos precisam simular as chamadas adicionais do detalhe** (`superadmin_agenda_contexts`), senão o `MockClient` devolve corpo nulo e o teste falha por cast.
- Rota real: o seletor Coelo de data/hora responde à semântica (`nodes` + click por coordenada); `Input.insertText` do CDP não entra em campos Flutter — usar `enter_text` do driver (`window.$flutterDriver`) com `set_frame_sync false` antes de qualquer `tap`.
- Memória da máquina: com dezenas de Chromes de outras frentes, o Chrome de CDP cai a 0,02 GB; guardar capturas a cada passo e ter a prova por RPC como reserva.

## coelo-frontend-backend

- Régua aplicada por action_id: `agenda.request` e `notices.schedule` chegaram a E2E com rota real + CRUD em produção + RLS (pgTAP) + reload; `circulars.attach` fica em BE até 190200/190300 e uma prova pela tela.
- Achados cruzados com dono definido: pastilha esticada em tabelas do composto (coelo-ui), balão de chat no compositor de Circular antes do frame (shell), testes históricos de Agenda desatualizados pelo lote 29 (G4/G5).
