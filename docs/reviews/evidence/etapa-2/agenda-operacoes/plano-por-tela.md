---
title: "E2E5 — plano vivo por tela, subtela e backend"
source: "prompts-etapa-2-e2e.md; coordenação do Owner; evidências locais E2E5"
status: "em execução; sem promoção E2E"
generated_at: "2026-09-07"
---

# Plano vivo — Agenda, Eventos e Operações

Somente Superadmin. Writer: root, branch `codex/e2e-agenda-operacoes`.
Parada operacional: **08/09 às 03:20 BRT**, sem encerrar a execução a cada commit.
Este arquivo aparece no painel direito; não substitui o contador nativo de
arquivos alterados. Não há ferramenta nativa de plano exposta nesta sessão.

## Seis passos por tela

1. Contrato e inventário.
2. Backend, segurança e negativas.
3. Cliente e estados.
4. Integração real, persistência e reload.
5. Regressão, visual e negativas.
6. Review, evidências e commit.

Os passos podem avançar em paralelo em fatias independentes. Um pacote no
passo 6 não significa que a tela chegou ao fim dos seis passos. Nenhum novo
`verified`, `done` ou `verified-e2e` foi atribuído nesta frente.

| Tela | Subtela / action_id | Passo da fatia | Camada / BD efetivamente trabalhado | Subagente / dono | Teste ou evidência | Próximo gate |
| --- | --- | --- | --- | --- | --- | --- |
| Auditoria | Exportação / `audit.export` | 6/6 pacote local commit `d8281432` | Cliente; nenhum BD; não chama RPC/job/arquivo | root + review `activities_contract_read` | 15 testes locais; goldens antigos ainda divergentes | Visual restante; sem exportação real no MVP |
| Assiduidade | Exportação / `attendance.export` | 6/6 pacote local commit `d8281432` | Cliente; nenhum BD | root + review `activities_contract_read` | 4 testes responsivos; overflow preexistente da Chamada separado | Visual restante; sem exportação real no MVP |
| Agenda | Calendário/Lista e detalhe / `agenda.detail` | 6/6 pacote local de estados; integração aberta | Cliente; `public.superadmin_agenda_list/get` somente simuladas | root; `activities_contract_read` e `agenda_ui_contract` review | 113 regressões; 14 estados; 34 repository; analyzer limpo; 12 novos goldens | BD real autorizado; 14 goldens antigos divergentes também com calendário HEAD |
| Agenda | Criar/editar/lifecycle / `agenda.create`, `agenda.edit` | 6/6 cache e parser de recorrência local | Cliente; RPCs simuladas, nenhum BD | root + `activities_contract_read` | Cache `e86f275`; parser com 8 REDs e regressão 96/96 verde | Estados UI; validação e persistência reais no backend |
| Agenda | Contexto e acesso / `agenda.permissions` | 6/6 pacote local do parser | Cliente; `public.superadmin_agenda_contexts` código lido, RPC simulada | root + `activities_contract_read` review | 9 REDs; 46 repository finais; 124 regressões antes dois negativos finais | Autorização/persistência reais; construtor injetado fora deste parser |
| Agenda | Solicitações e Aprovações | 6/6 negação imediata `374da66` | Cliente; duas RPCs simuladas | root + `activities_contract_read` | 7 novos casos, 79 testes verdes; negação prevalece sobre falha concorrente | Decisões, autorização e reload reais |
| Atividades | Busca/filtros/diretório / `activities.list` | 6/6 negação imediata `d309d62` | Cliente ViewModel; nenhum BD | root + reviews read-only | 39 testes verdes; negação não espera RPC irmão pendente | BD/E2E abertos |
| Atividades | Projeção/filtros v2 / `activities.list` | 2/6 contrato RED `142bfbec` + correção pgTAP `cdbcb46` | `public.superadmin_activity_directory_v2`, nova `superadmin_activity_filter_options_v2`; SQL preparado não executado | root; Eng1 operador serial via Coordenador | Adapter 37 testes; assertions sob authenticated; migration nominal vazia fora do commit | Base nominal Eng1 pendente; antigo FoundationOnly SUSPENSO por dependência chat_attachment_metadata ausente |
| Assiduidade | Chamada compacta | 6/6 local `696fb73` | Cliente; nenhum BD | root + `agenda_ui_contract` | RED overflow11px; 38 testes, 4 novos goldens; 1 golden antigo de outro fluxo divergente | Autorização, persistência e reload reais |
| Rotina diária | Diretório/filtros | 6/6 local `edb58b8`; READ01 proposta `bd94602` | Cliente; proveniência SQL apenas leitura de arquivos | root + `activities_sql_review` | 4 REDs; 10 focados verdes; proposta de reader interno revisada | Confirmar base nominal; não restaurar migrations históricas em bloco |
| Avaliações | Erros de leitura | 6/6 local `dd9cc25` | Adapter; contrato SQL lido, não executado | root + `activities_contract_read` | 1 RED; 12 testes verdes; erro500 não vira unauthorized | Composição nominal e BD real |
| Planos/assinaturas | Formulário/contexto | 6/6 local `7a9d2f6` | Cliente; nenhum BD | root + `agenda_ui_contract` | 4 REDs; 35 testes incluindo goldens verdes | Helper SQL people-based requer compatibilidade nominal interna |
| Erros globais | Ação/navegação E01 | 6/6 local `e79da15` | Router reservado e componente; nenhum BD | root + `activities_contract_read` | 5 REDs; 29 testes incluindo8goldens verdes; default retry preservado | Extensão de reserva para quatro callsites similares pendente |
| Locais | `locations.schedule`, `activities.location`, `agenda.location` | 1/6 dependência contratual | Base de Locais owned E2E2; nenhuma escrita | root, coordenação E2E2 via Coordenador | Contrato de reserva opcional preservado | Consumir base liberada; não criar schema paralelo |

Todo o recorte permanece sem promoção E2E. Cardápios, Suporte e Catálogo técnico
continuam no inventário, assim como as ações não cobertas pelas correções locais
acima. O escopo original não foi reduzido a Agenda/Atividades.

## Ambiente e limites

- BD desta rodada: **nenhum acesso local ou de produção executado**. Mocks HTTP
  não são persistência/reload real. Docker permanece reservado ao Eng1 até
  janela explícita do Coordenador.
- Migration A01: `20260907222911_superadmin_activity_directory_v2_client_contract.sql`,
  criada nominalmente via CLI e ainda vazia; não aplicada nem declarada pronta.
- Mídia nova MVP: R2 privado (`coelo-media-prod`, `coelo-documents-prod`,
  `coelo-transient-prod`); Supabase guarda catálogo/permissões/auditoria.
  Nenhum novo Supabase Storage, bucket ou lease é criado por este plano.
- Os três rastreadores centrais são atualizados exclusivamente pelo Coordenador.
- Próxima fatia: estados de falha em Cardápios e revisão nominal de Suporte.
  SQL A01 depende da fila serial Eng1; sem ETA remoto fictício. READ01 é proposta,
  não contém migration implementada nem testes comportamentais executados.

Evidências dos commits: `2026-09-07-deferred-exports.md` e
`2026-09-07-agenda-cache-safety.md` neste diretório.
