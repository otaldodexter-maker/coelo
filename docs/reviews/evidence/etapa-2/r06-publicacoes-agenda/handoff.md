---
title: "Handoff R06 — publicacoes-agenda (Agenda, Avisos, Circulares)"
source: "comunicacao/publicacoes-agenda.json rev 44–49; branch work/etapa2-r06-publicacoes-agenda; capturas ui/"
status: "entrega da frente ao coordenador; nada aqui certifica producao"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# O que fechou (por action_id, com prova)

| action_id | Camada | Prova |
| --- | --- | --- |
| `agenda.location` | FE + E2E | `/agenda/events/new` na família Publicação; Contexto = Unidade → "Qual Unidade" lista as duas unidades reais; escolhida a segunda (Unidade QA R05 Transferencia); Local "Patio central R06"; Publicar → detalhe `c7cf7370` com o contexto e o local; recarga completa mantém (`ui-04`..`ui-08`). BE done desde a R05 (pgTAP 200300). |
| `circulars.respond` | FE + E2E | P50 = B: Responder no detalhe → tela de resposta no Superadmin (leitor do Principal hospedado) → "Estou ciente" → Enviar (`save_circular_response_draft` partial v1 → `submit_circular_response` submitted v2) → recarga: diretório mostra Respostas 1 (`ui-12`..`ui-15`). BE done (190000, pgTAP 18/18). |
| `circulars.create` / `circulars.edit` | FE (família) | Compositor reconstruído sobre a família Publicação (`41a4b4dcf`); circular `[R06-QA UI]` publicada pela tela nova com "Confirmar ciência" (`ui-10`, `ui-11`); goldens `circular_composer_{light,dark}_{375,1440}`. Já eram verified/E2E. |
| `agenda.create` / `agenda.edit` | FE (família) | Formulário reconstruído sobre a família Publicação (`0322e511d`), sem wizard; evento publicado pela tela nova; goldens `agenda_create_*` regravados. Já eram verified/E2E. |
| `agenda.view` | FE (V-8) | Toggle Calendário/Lista do R restaurado no web (≥ 840); mobile mantém o 50/50 (`87c449d93`); goldens 1440 regravados. |
| sino do shell | FE + BE (sem action_id) | `ContextNotificationFeed` lê `context_notification_recipients` + `events` do ator e grava `read_at` ao abrir o centro (`7420dc323`); teste 1/1; rota real ver JSON rev 49. |

# Aberto, com o primeiro gate

- `circulars.attach` FE/E2E: **deploy da Edge Function `circular-media`** (`b2e61a22e`: `Access-Control-Allow-Headers` + `x-client-info`). Sem ele o POST do navegador falha no preflight (`net::ERR_FAILED` após OPTIONS 200, `ui-09`). O router agora passa `mediaRepository` aos hosts do compositor (antes: "Envio de anexos indisponível", `ui-02`). Com o deploy, a prova pela tela é: `/circulars/new` → Continuar → título/texto/Famílias → `+` (gancho do `qa_main` entrega o PNG) → chip do anexo → Publicar → detalhe → recarga.
- Aprovação visual do Owner: `duvidas-visuais-publicacao.html` (R referência 17:19 / A golden atual).

# Achados fora do recorte

- `chat-media`, `moments-media`, `happens-media`, `now-media`: mesma lista de `Allow-Headers` sem `x-client-info` → provável mesmo sintoma no navegador (G4/G5, uma linha cada).
- `*_MEDIA_ALLOWED_ORIGINS` só têm as portas locais 3000/3009/3014/3020.
- `PublicationSurface` (shared) está pronta para G3 (Lançar chamada) e G4 (Agora/Acontece/Momentos).

# Dados sintéticos deixados em produção

Evento `[R06-QA UI] Evento na unidade pela familia Publicacao` (`c7cf7370`, published, Unidade QA R05 Transferencia); circulares `[R06-QA UI] Circular com anexo pela tela` (3 rascunhos: `bd439ba5`, `5f8d2aee`, `cb77ed7f`) e `[R06-QA UI] Circular publicada pela familia Publicacao` (published, 1 resposta submetida pela pessoa de serviço do `qa-r06-publicacoes`). Chaves criadas: nenhuma. Limpeza no fim da Etapa 2 (P25/P42).
