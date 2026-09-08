---
title: "E2E5 — plano vivo por tela, subtela e backend"
source: "prompts-etapa-2-e2e.md; coordenação do Owner; evidências locais E2E5"
status: "em execução; sem promoção E2E"
generated_at: "2026-09-07"
updated_at: "2026-09-08"
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
| Auditoria | Leituras, debounce e contexto | 6/6 local `4eee73f` | Controller/adapter simulados; nenhum BD | root + `agenda_ui_contract` | 6RED;8novos testes e42regressões PASS; analyzer limpo | Runtime autorizado, auditoria server-side e reload reais |
| Assiduidade | Exportação / `attendance.export` | 6/6 pacote local commit `d8281432` | Cliente; nenhum BD | root + review `activities_contract_read` | 4 testes responsivos; overflow preexistente da Chamada separado | Visual restante; sem exportação real no MVP |
| Agenda | Calendário/Lista e detalhe / `agenda.detail` | 6/6 pacote local de estados; integração aberta | Cliente; `public.superadmin_agenda_list/get` somente simuladas | root; `activities_contract_read` e `agenda_ui_contract` review | 113 regressões; 14 estados; 34 repository; analyzer limpo; 12 novos goldens | BD real autorizado; 14 goldens antigos divergentes também com calendário HEAD |
| Agenda | Criar/editar/lifecycle / `agenda.create`, `agenda.edit` | 6/6 cache e parser de recorrência local | Cliente; RPCs simuladas, nenhum BD | root + `activities_contract_read` | Cache `e86f275`; parser com 8 REDs e regressão 96/96 verde | Estados UI; validação e persistência reais no backend |
| Agenda | Formulário/contexto/continuações | 6/6 local; evidência agenda-form-context | Cliente; repository fake | root + `agenda_ui_contract` | 2REDcontexto+1REDtema intermediário;35regressões PASS e1sentinela final PASS | Persistência/reload/autorização reais e protocolo de resultados parciais |
| Agenda | Continuação não confirmada após save | 6/6 local `e92a345` | Cliente; sem BD | root + `agenda_ui_contract` | 4RED;31regressões e4adversariais finais PASS; sem sucesso/retry cego | Atomicidade backend da spec050 continua aberta |
| Agenda | Readers list/get/contexts 039 | 2/6 fixture RED candidata `a3b76f5` | Fixture SQL não executada e crosswalk refinado | root + `activities_sql_review` | Negativas, projeção fechada, audiência pessoal omitida, audit14 e grants sintéticos revisados | Manifesto e replay nominal Eng1; nenhum reader novo implementado |
| Agenda | Contexto e acesso / `agenda.permissions` | 6/6 pacote local do parser | Cliente; `public.superadmin_agenda_contexts` código lido, RPC simulada | root + `activities_contract_read` review | 9 REDs; 46 repository finais; 124 regressões antes dois negativos finais | Autorização/persistência reais; construtor injetado fora deste parser |
| Agenda | Solicitações e Aprovações | 6/6 pacotes `374da66`, `871e262`, `bc4432b` | Cliente; duas RPCs simuladas; guards de contexto e rota | root + reviews read-only | Estados de leitura; 7 RED lifecycle/navegação, 9 testes novos e 68 regressões finais PASS | Decisões, autorização e reload reais |
| Atividades | Busca/filtros/diretório / `activities.list` | 6/6 negação imediata `d309d62` | Cliente ViewModel; nenhum BD | root + reviews read-only | 39 testes verdes; negação não espera RPC irmão pendente | BD/E2E abertos |
| Atividades | Projeção/filtros v2 / `activities.list` | 2/6 SQL local GREEN97 | Dois RPCs nominais; root autor, Eng1 operador serial | root + activities_sql_review; Coordenador | Evidência5ef2fc4e lida integralmente:97TAP PASS audit-v2, mesmafixture97; cleanup independente zero | Integração Flutter autorizada, reload e remoto pendentes. Foundation67 suspenso |
| Atividades | Harness v2 e formulário compacto | 6/6 local `f298e32`, `0558fd5` | Testes apenas; nenhum código produtivo | root + review read-only | 64data/router e16form PASS; tap compacto antes fora viewport agora com scroll/hit test | Coordenação reportou9goldens divergentes, não rebaselineados; não comprovam E2E |
| Atividades | Runtime Flutter/PostgREST A01 | 3/6 harness candidato `f5b0e5b` + `f0be734` | Test-only; zero HTTP/SQL nesta preparação | root + reviews cliente/base; Eng1 operador futuro | 23 guards PASS e 1 runtime SKIP forçado; analyzer/review PASS | Lease nominal base55, seed COMMIT isolado, platform.read explícito, JWT sintéticos e audit independente |
| Assiduidade | Chamada compacta | 6/6 local `696fb73` | Cliente; nenhum BD | root + `agenda_ui_contract` | RED overflow11px; 38 testes, 4 novos goldens; 1 golden antigo de outro fluxo divergente | Autorização, persistência e reload reais |
| Rotina diária | Diretório/filtros | 6/6 local `edb58b8`; READ01 proposta `bd94602` | Cliente; proveniência SQL apenas leitura de arquivos | root + `activities_sql_review` | 4 REDs; 10 focados verdes; proposta de reader interno revisada | Confirmar base nominal; não restaurar migrations históricas em bloco |
| Avaliações | Erros de leitura | 6/6 local `dd9cc25` | Adapter; contrato SQL lido, não executado | root + `activities_contract_read` | 1 RED; 12 testes verdes; erro500 não vira unauthorized | Composição nominal e BD real |
| Avaliações | Fila, detalhe e decisões de fechamento | 6/6 local; evidência assessment-closing-context | Cliente; nenhum BD | root + `agenda_ui_contract` | 4RED;7novos casos e25regressões PASS; descarte de contexto e comandos tardios | Guards de produção preservados; persistência e publicação reais pendentes |
| Planos/assinaturas | Formulário/contexto | 6/6 local `7a9d2f6` | Cliente; nenhum BD | root + `agenda_ui_contract` | 4 REDs; 35 testes incluindo goldens verdes | Helper SQL people-based requer compatibilidade nominal interna |
| Planos/assinaturas | PLANS-READ01 list/get | 1/6 proposta `5f238de` | Inventário SQL estático e matriz RED; nenhum SQL executável | root + `activities_sql_review` | Reader separado, platform.read + scopeplatform; divergência051/039 explícita | Aceite da transição de ator; base/grants/audit; DTO de overrides sem zero fictício |
| Erros globais | Ação/navegação E01 | 6/6 local `e79da15` + extensão `9754a1c` | Router reservado e componente; nenhum BD | root + `activities_contract_read` | 5+3 REDs;33testes incluindo8goldens verdes; default retry preservado | Runtime das dependências; studentManage builder ainda guardado, apenas review estático desse callsite |
| Cardápios/modelos | Transporte e publicação | 6/6 local `57cd72b` | Adapter; sem BD | root + review read-only | 2REDtransport;29regressões e6adapter finais PASS; sem retry automático de publicação | Autorização, publicação, persistência e reload reais |
| Cardápios | Nova tentativa após conflito confirmado | 6/6 local; evidência meal-plan-conflict-retry | Wizard; repository DEV em teste | root + `activities_contract_read` | 1RED IDnull duplicaria criação;32regressões PASS; ID/revisão/chave nova e zero publicação | Protocolo das demais falhas parciais e E2E reais ainda abertos |
| Cardápios | Comando único, estado publicado e rejeição posterior | 6/6 local `a1b5116`, `b94011e`, `896ce0f` | Wizard; repository fake; nenhum BD | root + reviews read-only | 2RED concorrência +4RED sucesso indevido +6RED retry;48regressões PASS;3controles de indisponibilidade preservam chave | Upload/modelos, reconciliação de resposta perdida e autorização/persistência/reload reais |
| Cardápios/modelos | Status da lista e confirmação de publicação | 6/6 local `502cb01`, `ba0fc80` | Domínio e wizard; respostas simuladas | root + reviews read-only | 1RED projeção +2RED publicação;52regressões projeção,28wizard e4focados finais PASS | Upload, retry de modelo, backend interno e persistência/reload reais |
| Cardápios/modelos | Origem paginada e versão histórica | 6/6 local `a5ad81d` | Estado do wizard; nenhum BD | root + review read-only | 4RED:2StateError+2versões incorretas;60regressões PASS; conteúdo e versão preservados | FK/autorização e salvamento/reload reais; seleção posterior revisada estaticamente |
| Cardápios/modelos | Rota e seleção institucional | 6/6 contrato local revisado | Testes de rota + adapter HTTP simulado; produção intacta | root + `agenda_ui_contract` | 4 novos controles; 13 arquivos/61 testes PASS; expectativa de guard antigo reconciliada com b0c250fc | Backend People legado e autorização039 não comprovados; sem persistência real |
| Cardápios/modelos | Metadados list/get/save | 6/6 correção local | Parser do contrato RPC; HTTP simulado | root + `activities_contract_read` | 3 RED camelCase e 3 controles snake_case; 66 regressões PASS; 12 finais de serialização com precedência de aliases | Contrato já existente preservado; autorização e persistência039 reais abertas |
| Auditoria | DTO de sessão autenticada sem papel inventado | 6/6 local `eb78262` | Adapter, DTO e widgets; resposta simulada | root + review read-only | 2RED;50testes PASS com2novosgoldens375/200%;analyzer e visualvalidator PASS | Wrappers legados ainda People-based; composição interna nominal pendente |
| Suporte | Toolbar, paginação, teclado | 6/6 pacote local `0db70be` | Protótipo cliente; sem BD | root + `agenda_ui_contract` | RED overflow/overlay/trapTab;70funcionais Suporte+Catálogo PASS;8goldens novos PASS | OQ028 Owner e backend interno nominal;24masters antigos divergentes preservados, não rebaselineados |
| Catálogo técnico | Preview e proteção de rotas | 6/6 harness `0db70be` | Testes de router/host; produção inalterada | root + review read-only | Preview opt-in explícito e defaultfalse protegido; regressões incluídas nos70 | Origem privada configurada e execução real de runtime; não promover preview a E2E |
| Locais | `locations.schedule`, `activities.location`, `agenda.location` | 1/6 dependência contratual | Base de Locais owned E2E2; nenhuma escrita | root, coordenação E2E2 via Coordenador | Contrato de reserva opcional preservado | Consumir base liberada; não criar schema paralelo |

Todo o recorte permanece sem promoção E2E. Cardápios, Suporte e Catálogo técnico
continuam no inventário, assim como as ações não cobertas pelas correções locais
acima. O escopo original não foi reduzido a Agenda/Atividades.

## Ambiente e limites

- BD pelo root: **nenhum acesso local ou de produção executado**. Eng1 executou
  o RED e GREEN nominais A01, com cleanup confirmado. Mocks HTTP não são persistência/reload
  real. Docker permanece reservado ao Eng1, sob grant explícito do Coordenador.
- Migration A01: `20260907222911_superadmin_activity_directory_v2_client_contract.sql`,
  v1 commit2fd8227 executada RED55:91PASS6FAILaudit. Candidato audit-v2 local
  hash e4b02a2100030c36a0895d04036685cafae623326872f3141902d00043fe66f2;
  append fora do catch, fixture97 intacta; GREEN serial97PASS em03:15:37UTC.
  Evidência formal5ef2fc4e, cleanup independente03:18:51UTCzero recursos próprios;
  não houve leitura independente tardia do marcador. E2E/remoto não demonstrados.
- Mídia nova MVP: R2 privado (`coelo-media-prod`, `coelo-documents-prod`,
  `coelo-transient-prod`); Supabase guarda catálogo/permissões/auditoria.
  Nenhum novo Supabase Storage, bucket ou lease é criado por este plano.
- Os três rastreadores centrais são atualizados exclusivamente pelo Coordenador.
- Assiduidade/Chamada: OQ040 e spec048 draft bloqueiam contrato funcional SQL;
  depende decisão Owner sobre capacidades/AAL/escopo/DTO/cutover. Não restaurar
  cadeia histórica nem criar ponte people para o ator interno.
- Próxima fatia SQL: AG-READ01 depende manifesto fechado e autorização de replay Eng1.
  Demais superfícies originais continuam em execução; sem ETA remoto fictício.
  AG-READ01 contém fixture candidata, não reader implementado nem teste SQL executado.

Evidências dos commits: `2026-09-07-deferred-exports.md` e
`2026-09-07-agenda-cache-safety.md` neste diretório.
