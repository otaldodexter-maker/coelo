---
title: "Pendências Coelo — Flutter por tela e ação"
source: "AGENTS.md; .agents/skills/coelo-flutter-review/SKILL.md; .agents/skills/coelo-ui/SKILL.md; .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md; .agents/skills/coelo-ui/references/interactive-state-evidence-matrix.md; .agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md; docs/design/design-system.md; specs/013-ui-packages-componentization.md; docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md; decisions/0022-superadmin-activities-and-identity-storage.md; docs/open-questions.md; docs/reviews/2026-08-25-coelo-ui-code-review-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md; apps/superadmin/lib/app/router/superadmin_routes.dart; Git HEAD cd1ea97c76695e4be72cd91882d65c9c235704a4"
status: "open"
generated_at: "2026-08-26"
updated_at: "2026-09-01"
action_count: 207
family_count: 37
visual_program_count: 31
visual_program_accepted_count: 0
---

# Pendências Coelo — Flutter por tela e ação

## 0. Etapa 2 — resumo recuperável do que foi feito e do que falta

> **Regra do MVP aprovada em 2026-09-01:** importação e exportação reais estão
> fora do recorte. Os botões permanecem visíveis e devem informar
> honestamente que a função ficará disponível depois do MVP. Não são exigidos
> picker, arquivo, parser, job, RPC, Edge Function, persistência ou E2E para
> fechar o lado Flutter; permanecem exigidos layout, responsividade,
> acessibilidade, acionamento e mensagem correta. Ver ADR 0031.

O denominador Flutter permanece em 207 porque os controles visuais continuam
no MVP. A decisão não promove automaticamente nenhum `action_id`: botões
ocultos ou removidos devem ser restaurados e só podem atingir `verified` após
prova de visibilidade, responsividade, acessibilidade e mensagem explícita de
disponibilidade depois do MVP. No encerramento formal do MVP, o coordenador
deve perguntar ao Owner se deseja implementar os fluxos reais.

**Auditoria do código consolidado:** Turmas (`groups.import/export`) e
Unidade/Pessoas (`units.people-export`) já exibem os controles. Pessoas oculta
import/export na rota produtiva; Assiduidade não possui `attendance.export`;
Formulários/Respostas desabilita ou substitui `forms.export`; Usuários internos
e Perfis/Modelos exibem controles desabilitados. Nenhuma superfície usa ainda
a frase normativa “Disponível depois do MVP”. O próximo pacote Flutter deve
restaurar/habilitar somente o clique informativo e seus testes, sem conectar
qualquer fluxo real.

### ETA Flutter supersedente — execução líquida

Esta tabela substitui todas as estimativas Flutter anteriores para planejamento
da Etapa 2. Ela mede somente trabalho do cliente Flutter, agrupa setup, testes,
goldens e regressões compartilhados e exclui espera, Supabase, remoto, E2E, R2
e import/export real. Valores antigos permanecem abaixo apenas como histórico.

| Família | Pendência Flutter restante | ETA líquida |
| --- | --- | ---: |
| Auth | MFA e gates finais do cliente | 1–2 h |
| Shell | Contexto, navegação, reload e regressão | 1–2 h |
| Instituições | Estados finais, arquivos no cliente e botões informativos | 2–4 h |
| Unidades | Estados do cliente, reload e botões informativos | 1,5–3 h |
| Turmas | Membros, estados finais e mensagem pós-MVP | 1–2 h |
| Pessoas | Fluxos locais, mapa, fixtures e goldens | 3–5 h |
| Perfis de acesso | Detalhe, atribuição/exclusão, UX e goldens | 3–5 h |
| Modelos de acesso | Filtros, detalhe, duplicação e goldens | 2,5–4 h |
| Convites | Confirmações, erros e regressão | 1–2 h |
| Atividades | Wizard, detalhe e estados do cliente | 2–4 h |
| Avaliações | Páginas, conflitos e regressão local | 2–4 h |
| Alunos | Ações e estados locais após decisão | 2–3 h |
| Assiduidade | Marcação, correção, conclusão e botão Exportar | 2–4 h |
| Rotina diária | Estados e regressão | 1,5–3 h |
| Agenda | Estados, localização visual e regressão | 2–4 h |
| Chat | Editar, anexar, recibos, revogar e retry no cliente | 2–4 h |
| Avisos | Estados de lifecycle no cliente | 2–3 h |
| Formulários — autoria | Editor, estados e testes finais | 3–5 h |
| Formulários — respostas | Monitor, resposta, detalhe e botão Exportar | 2–3 h |
| Formulários — arquivos | Estados Flutter via contrato de mídia | 1,5–3 h |
| Acontece | Feed e publicador Flutter | 2–4 h |
| Agora | Viewer e publicador Flutter | 1,5–3 h |
| Momentos | Golden do viewer e publicador Flutter | 1–2,5 h |
| Menu Coelo (Principal) — perfil | Preview, perfil e edição dentro do Superadmin | 1,5–3 h |
| Segurança infantil | Estados sensíveis e suspensão no cliente | 2–4 h |
| Perfis de cuidado | Detalhe, estados e goldens | 2–4 h |
| Medicação | Superfícies Flutter após decisões | 2–4 h |
| Importações | Somente botões, mensagem e testes | 0,5–1 h |
| Arquivos de perfil | Somente controles diferidos e mensagem | 0,5–1 h |
| Auditoria | Estados, detalhe e botão Exportar | 1,5–2,5 h |
| Suporte | Detalhe, resposta e encerramento | 2–3 h |
| Conta | Configurações, MFA, sessões e regressão | 2–3 h |
| Catálogo | Reconciliação técnica final | 0,5–1,5 h |
| Planos | Estados Flutter e ações permitidas | 1,5–3 h |
| Cardápios | CRUD, modelos e publicação no cliente | 2–4 h |
| Usuários internos | Estados, suspensão e MFA no cliente | 2–4 h |
| Páginas de erro | Lote 403/404/409/500/503/retry | 1–2 h |

**Total sequencial externo:** 63,5–118,5 h. **Faixa mais provável de
planejamento:** **78–96 h líquidas**. Com três frentes independentes, o tempo de
calendário estimado é **30–48 h**; com quatro, **24–38 h**. O caminho crítico é
fundação compartilhada (3–5 h), identidade/permissões/segurança (14–22 h) e
regressão/reconciliação final dos IDs (4–7 h). Decisões externas suspendem a
família afetada, mas não são somadas como horas de execução.

### Checkpoint final de consolidação — 2026-09-01

As implementações recebidas foram reunidas no mesmo histórico Git e a árvore
consolidada passou `flutter analyze` sem achados. Este checkpoint substitui as
instruções antigas desta seção que ainda dizem “integrar branch”: o código já
está integrado; o que continua aberto é a promoção funcional de cada ação pelos
gates exclusivos do Flutter. Integração física de código não altera, sozinha, o
estado do `action_id`.

| Tela / subtela | Entregue e consolidado na Etapa 2 | O que ficou aberto no Flutter | Evidência central |
| --- | --- | --- | --- |
| Auth — login, recovery, reset e logout | Sessão, guards, recuperação confinada, limpeza e adiamento explícito de MFA interno até o gate do MVP. | Smoke humano em navegador, goldens remanescentes e conciliação por `action_id` antes de promover de `local-green`. | 51/51 testes Auth; analyzer global verde. |
| Pessoas, Segurança da criança, Usuários internos, Perfis, Modelos, Saúde e Medicação | Diretórios, wizards, detalhe produtivo de Pessoa, estados fail-closed e contratos locais foram preservados. | 19/31 ações do recorte ainda abertas; corrigir realm/lookup/autorização dos perfis, dívida visual e decisões de cuidado/medicação. | 73 testes verdes; 7 grupos visuais/golden ainda vermelhos ou obsoletos. |
| Instituições, Unidades, Turmas, Atividades e Avaliações | Gateways e adapters locais, composição de Instituições e superfícies de Estruturas incorporados. | Avaliações são candidatas a até 5 promoções locais, mas exigem revisão por ID; hierarquia de Unidade e backend produtivo seguem abertos. | 449/449 testes funcionais; clipping mobile visual ainda aberto. |
| Planos, Cardápios, Formulários, Importações e Agenda | Diretórios, editores, rotas e leituras produtivas de Formulários consolidados. Os botões de importar/exportar permanecem visíveis com indisponibilidade honesta. | Commands produtivos que não sejam import/export, arquivos próprios de Formulários, mapas e regressão visual por ação; nenhuma promoção em bloco. Import/export real está `deferred-post-mvp`. | 344/344 testes no repasse da frente. |
| Chat, Avisos, Convites e Circulares | Chat com ownership único, rotas/composer, avisos, convites e CRUD local de Circulares consolidados no Superadmin. O botão visível “Mensagens” do Coelo (Principal) abre Chat em prévia e produção e retorna à origem correta. | Estados remotos, anexos, erros/retry e prova visual/manual das ações ainda não certificadas. | 301/301 no repasse; Chat+Circulares 18/18 após o merge. |
| Menu Coelo (Principal) — Para Você, Acontece, Agora, Momentos e Perfil | Rotas reais e de prévia, runtime context e viewer de Momentos preservados dentro do Superadmin. | Publicadores, regressão visual conjunta, estados negativos e aprovação por `action_id`. | 17/17 testes focados; analyzer global verde. |
| Macro — cabeçalho mobile, shell e navegação | Composição única do shell, capabilities combinadas e cabeçalho compartilhado incorporados no Superadmin inteiro. | Executar aprovação visual manual/goldens no conjunto final de larguras, temas e texto ampliado. | Analyzer global verde; sem alteração em Admin, Site ou app Principal. |

**Contagem oficial após a consolidação:** 105/207 `local-green` = **50,72%**
de avanço técnico Flutter; 0/207 `verified` = **0,00%** de conclusão estrita do
lado Flutter. Há código e testes adicionais integrados, porém eles permanecem
como candidatos até a reconciliação ação a ação. O maior incremento já
delimitado é Avaliações: até +5 ações, que levaria o avanço local a 110/207 =
53,14%, somente depois dos gates correspondentes.

Esta seção é o ponto de retomada obrigatório da **Etapa 2** para a skill
`coelo-flutter-review`. Ela deve ser atualizada a cada handoff, regressão,
integração ou mudança de ETA. O histórico detalhado e as matrizes por
`action_id` permanecem abaixo.

**Estado geral Flutter em 2026-09-01:** 105/207 ações `local-green` (50,72%) e
0/207 `verified`. Portanto 102/207 ações (49,28%) ainda não atingiram sequer o
estado local exigido e nenhuma ação foi ainda certificada em todos os gates
exclusivos do lado Flutter. A ausência de Supabase/E2E não participa desse gate.

| Percentual Flutter da Etapa 2 | Concluído | Restante | Interpretação |
| --- | ---: | ---: | --- |
| Progresso técnico local | 50,72% (105/207) | 49,28% (102/207) | Passou localmente; não significa produção. |
| Conclusão do lado Flutter `verified` | 0,00% (0/207) | 100,00% (207/207) | Reauditoria conservadora dos 207 IDs; faltam gates do próprio cliente, não Supabase/E2E. |

> **Leitura correta:** o avanço Flutter mensurável da Etapa 2 é **50,72% no
> estágio técnico local**. A reauditoria manteve `verified` em 0,00% porque ainda
> há gates próprios do cliente — composição/rota normal, estados, matriz visual,
> acessibilidade ou regressão — e não por falta de Supabase/E2E. As 105 ações
> `local-green` não podem ser promovidas em bloco.

**Geral conhecido e Etapa 2:** ambos usam atualmente os mesmos 207 `action_id`,
pois o rastreador ainda não possui um subdenominador menor para as seis frentes
da Etapa 2. Relatos novos de camada serão registrados como candidatos até review
central por ID: Acessos/Saúde declarou 19 e Agenda declarou pelo menos 7; eles
não entram no numerador oficial antes da conferência das evidências e da
reconciliação sem duplicidade.

### Telas, subtelas e ações Flutter

| Tela / subtela | `action_id` | Feito na Etapa 2 | Pendente / passo seguinte | Estado |
| --- | --- | --- | --- | --- |
| Auth — Login | `auth.login` | Formulário, erro neutro, sessão/contexto e guards locais; Catalog fail-closed corrigido em `5e8d2655`. | Integrar branch; três goldens Login e E2E remoto. | `local-green` |
| Auth — Recuperar senha | `auth.recover` | Recovery confinada ao reset; Home, Instituições e `/dev` negados. | Link/redirect/SMTP produtivos e E2E. | `local-green` |
| Auth — Redefinir senha | `auth.reset` | Sessão recovery distinta, revogação/limpeza e retorno fail-closed. | Token remoto expirado/reutilizado, auto-refresh e E2E. | `local-green` |
| Auth — Sair | `auth.logout` | Logout e limpeza local cobertos. | Revogação/deep link/voltar no ambiente remoto. | `local-green` |
| Chat — Diretório/busca/paginação | `chat.list` | Cinco conversas `/dev`, busca, cursor, leitura e launcher sem duplicação integrados. | `total/has_more`, loading/empty/error produtivos e reload remoto. | `local-green` |
| Chat — Conversa aberta | `chat.open` | Ordem multi-message e retorno pelo menu Coelo (Principal) corrigidos. | Membership revogada, link adulterado, persistência e reload remoto. | `local-green` |
| Chat — Composer/envio | `chat.send` | Ordem pós-envio/idempotência local corrigidas. | Falha/retry, autorização, auditoria e persistência remota. | `local-green` |
| Chat — Editar/anexar/recibos/revogar | `chat.edit`, `chat.attach`, `chat.receipts`, `chat.revoke` | Gateway interno Supabase v2, adapter e contrato local implementados em `68d1217d`; conjunto Flutter relacionado passou 54/54. | Executar pgTAP local, compor o wiring de auth scope e ainda provar cada ação de UI, membership revogada, mídia, persistência/reload e E2E; produção continua sem promoção. | `audited`; backend local técnico |
| Convites — Lista/detalhe/criar/reenviar/revogar | `invites.list`, `invites.detail`, `invites.create`, `invites.resend`, `invites.revoke` | Diretório, detalhe, wizard e escopo de fixtures corrigidos; goldens locais verdes. | Repository produtivo, confirmação/erros reais, lifecycle e regressão pós-merge. | `local-green` `/dev` |
| Avisos — Diretório | `notices.list` | Cards/tabela, filtros, preview, paginação, responsividade e goldens locais. | Repository produtivo e reload. | `local-green` |
| Avisos — Criar/editar/agendar/publicar/arquivar | `notices.create`, `notices.edit`, `notices.schedule`, `notices.publish`, `notices.archive` | Frame/wizard local parcial; `c5085746` falha fechado em status publicado/arquivado/desconhecido; gate Notices 96/96, adapter 5/5 e analyzer verdes. | OQ-038, commands/lifecycle, dirty state, timezone, duplo envio, replay Docker e reload. | `audited`/fail-closed |
| Instituições — Diretório/busca/filtros/paginação/detalhe/editar | `institutions.list`, `institutions.search_filter`, `institutions.read`, `institutions.edit` | `d864f19a` usa gateways internos v2 para diretório/opções/detalhe/edit core; paginação 500→lotes 100, idempotência/reload autoritativo; 6/6. | Integrar/retestar; replay pgTAP, regressão, remoto e E2E. | composição local; promoção retida |
| Instituições — Criar/status/arquivos | `institutions.create` e ações correlatas | UI local/fail-closed; botões de importar/exportar devem permanecer visíveis e honestamente indisponíveis. | Gateway interno aprovado para create/status e todos os estados. Import/export real está `deferred-post-mvp`. | fail-closed |
| Unidades — Diretório/detalhe/criar/editar/arquivos | `units.*` | UI `/dev` e adapter candidato. | Gateway interno nominal; ações produtivas e reload. | local/fail-closed |
| Turmas — Diretório/detalhe/criar/editar/membros/arquivos | `groups.*` | UI `/dev`, paginação, métricas e edição local; botões de importar/exportar visíveis com mensagem futura. | Gateway interno nominal, membros produtivos e reload. Import/export real está `deferred-post-mvp`. | local/fail-closed |
| Atividades/Modelos — Diretórios/criar/editar/duplicar | `activities.*`, `activity_templates.*` | UI local, validações temporais e duplicação candidata. | Integrar/retestar; replay do escopo por Unidade e composição produtiva. | local/static-review |
| Avaliações — Configurar/lançar/diário/fechar/reabrir | `assessments.*`, `activities.assessment` | UI `/dev` e rotas locais. | Doze RPCs ausentes, estados produtivos, conflitos/reload e regressão. | local/fail-closed |
| Planos | `plans.*` | Diretório, filtros, paginação e CRUD fake locais; botões de import/export mantidos. | Revisar regressão e repository produtivo. Fluxo real de import/export está `deferred-post-mvp`. | `local-green` `/dev` |
| Cardápios/Modelos | `meal-plans.*` | Diretório, vínculos, período, recorrência, revisão/publicação fake. | Integrar; conflitos, upload/publicação e repository produtivos. | `local-green` `/dev` |
| Formulários — Diretório/editor/criar/editar/publicar/testar/responder | `forms.list`, `forms.create`, `forms.edit`, `forms.publish`, `forms.test`, `forms.respond` | Diretório/editor/agendamento locais. | Commands seguem fail-closed: trocar `local-preview` por `institution_id` autorizado, versão/request ID, occurrence/participation e segredo anônimo. | local/fail-closed |
| Formulários — Monitor/respostas/detalhe/arquivos | `forms.monitor`, `forms.responses`, `forms.response-detail`, `forms.files` | `236f12cd` remove conteúdo estático e conecta rotas produtivas a `getMonitor`, `listResponses`, `getResponseDetail` e `listFileJobs`; 7/7. | Integrar branch; sessão real, estados remotos, reload e E2E. | backend-read composto localmente |
| Importações | `imports.*` | Hub, paginação e botões locais com indisponibilidade honesta. | Validar apenas UI, responsividade, acessibilidade e mensagem. Jobs, arquivos e integração produtiva estão `deferred-post-mvp` e não bloqueiam o MVP. | `local-green` `/dev`; backend diferido |
| Agenda — Calendário/lista/detalhe/criar/editar | `agenda.view`, `agenda.detail`, `agenda.create`, `agenda.edit` | Calendário/lista/wizard, recorrência, perguntas e localização visual locais. | Integrar; mapa/geocodificação real, persistência e estados produtivos. | `local-green` `/dev` |
| Agenda — Solicitações/aprovações/permissões | `agenda.request`, `agenda.permissions` | Fluxos locais; Permissões redirecionada para Perfis. | Elegibilidade, autorização produtiva, notificações e reload. | `local-green` `/dev` |
| Pessoas — Lista/criar/editar | `people.list`, `people.create`, `people.edit` | Diretório e wizard locais com dataset vinculado. | Produção continua no legado people-based; dois testes produtivos, dez goldens, mapa/provider e fixture que perde escopo. | `create/edit` locais; `list` audited |
| Pessoas — Vínculos/detalhe/reload | `people.links`, `people.reload` | Commit `d4a87af8` compõe detalhe produtivo com `superadmin_person_detail_v2`, envelope estrito e mapeamento fail-closed; 16/16 testes. | Replay pgTAP fresco, daemon Docker, permitido/negado/MFA/sessão, remoto, persistência e E2E. | composição local; promoção retida |
| Segurança da criança — Lista/criança/criar/editar/suspender | `child-safety.list`, `child-safety.child`, `child-safety.create`, `child-safety.edit`, `child-safety.suspend` | Quatro primeiras ações locais; cards/tabela/wizard e um golden verdes. | `suspend`, lifecycle/revogação, regressão e integração seletiva. | 4 locais; 1 `audited` |
| Usuários internos — Lista/criar/editar/suspender/MFA | `internal-users.list`, `internal-users.create`, `internal-users.edit`, `internal-users.suspend`, `internal-users.mfa` | Diretório/wizard `/dev`; produção falha fechada em vez de 404. | Decisões de realm, Auth/Convites, suspend/MFA e 23 goldens. Import/export real está `deferred-post-mvp`. | `blocked-decision` |
| Perfis e permissões — Lista/criar/detalhe/editar/atribuir/excluir | `access-profiles.list`, `access-profiles.create`, `access-profiles.detail`, `access-profiles.edit`, `access-profiles.assign`, `access-profiles.delete` | Central visual e wizard local. | Detalhe só por deep link, realm produtivo incorreto, OQ-044, atribuir/excluir e goldens. | parcial/bloqueado |
| Modelos de perfil — Lista/filtro/criar/detalhe/editar/duplicar | `access-models.list`, `access-models.filter`, `access-models.create`, `access-models.detail`, `access-models.edit`, `access-models.duplicate` | UI/adapter candidatos. | Multi-escopo, `totalCount`, detalhe, duplicar/import/export, P0 backend e goldens. | parcial/bloqueado |
| Perfis de cuidado — Lista/criar/detalhe/editar | `health-care.list`, `health-care.create`, `health-care.detail`, `health-care.edit` | Diretório e wizard `/dev` responsivos. | Produção, import/export, goldens e decisões de cuidado. | local/fail-closed |
| Medicação — Lista/criar/detalhe/editar/evidência | `medication.list`, `medication.create`, `medication.detail`, `medication.edit`, `medication.evidence` | Diretório/wizard e CRUD fake locais. | Todos os cinco IDs permanecem bloqueados para produção por decisão e segurança. | `blocked-decision` |
| Acontece/Para Você/Agora/Perfil | `acontece.*`, `principal.for-you`, `agora.*`, `account.profile` | Rotas do menu isoladas; trabalho visual histórico preservado. | Revisão tela/subtela, publicadores, regressão conjunta e integração seletiva. | em revisão futura |
| Momentos — Viewer | `momentos.view` | Fullscreen sem shell, retorno/foco e estados inválido/loading/failure/unauthorized/empty; 38/38. | Golden/manual conjunta e integração da branch. | `local-green` |
| Momentos — Criar/publicar/remover | `momentos.create`, `momentos.publish`, `momentos.remove` | Contratos/UX históricos inventariados. | Decisões, implementação produtiva e todos os estados. | `blocked-decision` |
| Circulares — Diretório/menu/arquivos | `circulars.view` | Hierarquia no menu correto, diretório, busca/paginação e botões Importar/Exportar locais; o lote `5e714c16` consolidou 14 registros `/dev`, responsividade e goldens. | Validar a indisponibilidade honesta dos botões. Callbacks produtivos, backend/RLS e E2E de import/export estão `deferred-post-mvp`. | `local-green` Flutter `/dev` |
| Circulares — Criar/editar/detalhe/publicar | `circulars.create` e ações correlatas | `5e714c16` implementou no `/dev` criar, detalhe, editar, salvar e publicar, com dados mutáveis coerentes e testes/goldens locais. | Repository produtivo permanece fail-closed; faltam autorização, persistência/reload, estados remotos negativos e E2E. | `local-green` Flutter `/dev` |

### Macroajustes Flutter da Etapa 2

| Macroajuste | Feito | Pendente |
| --- | --- | --- |
| Cabeçalho mobile e shell | Implementação compartilhada no `SuperadminShell`; matrizes locais de largura/tema/texto. | Integração seletiva sem hunks Chat e regressão de todas as rotas após merges. |
| Navegação e ownership | Chat centralizado; Coelo (Principal) definido como menu do Superadmin; apps externos preservados. | Resolver conflitos lógicos de router/navigation durante cherry-picks. |
| Responsividade e acessibilidade | Diversas telas cobrem 375–1440 e texto 200%; Momentos cobre foco/Escape. | Treze suítes golden de Acessos RED; validação manual e aprovação deliberada. |
| Componentes compartilhados | `SuperadminFormFrame` e `CoeloStatePanel` receberam correções candidatas. | Regressão conjunta Auth/Comunicação/Estruturas/Acessos antes de integrar. |
| Mapa/localização | Prévia municipal local criada. | Remover dependência direta de tiles OSM até provider/cache/privacidade aprovados. |
| Referências visuais | Manifestos preservam Comunicação, Operações, Estruturas, Acessos/Saúde, Principal e Coordenador. | Manter SHA/origem/tela e pedir reenvio de qualquer anexo não recuperável. |

### Instituições — gateways internos v2 — `bd611d02`/`d864f19a`

- Diretório/busca/filtros/paginação usam `superadmin_institution_directory_v2`;
  opções usam `filter_options_v2`; detalhe usa `detail_v2`; edição core usa
  `edit_core_v2` com envelope estrito, idempotência e reload autoritativo.
- Evidência Flutter 6/6. `institutions.create` e status permanecem fail-closed
  porque não existe gateway interno aprovado; nenhum RPC legacy foi reutilizado.
- pgTAP novo declara 20 asserts para seis gateways/contexto interno e ausência
  explícita de endpoints não aprovados; Docker não respondeu, então somente
  `static-reviewed`.

### Primeiro próximo passo Flutter da Etapa 2

1. Receber os dois verdicts independentes de Acessos/Saúde e corrigir qualquer
   achado antes do cherry-pick. Verdicts recebidos: banco P0 e Flutter P1/P2;
   correções ainda não iniciadas.
2. Fechar Circulares na frente Coelo (Principal), integrando apenas o trabalho
   válido e excluindo `393fc7ff`.
3. Integrar seletivamente Estruturas, Operações, Coelo (Principal) e
   Acessos/Saúde, sempre com regressão pós-merge e sem duplicar Chat/cabeçalho.
4. Auth/Catalog foi corrigido localmente em `5e8d2655`; falta integrar e tratar
   ledger/infra/E2E remoto.

**Tempo usado:** não calculável com precisão porque as frentes não
registraram duração homogênea. **ETA Flutter local restante revisado:**
**78–96 h líquidas mais prováveis**, ou 30–48 h de calendário com três frentes;
ver a tabela supersedente no início deste documento.

## 1. Finalidade e leitura obrigatória

Este é o rastreador vivo das pendências de **Flutter e Dart** do Coelo. Ele deve
ser lido integralmente quando o pedido envolver revisão profunda, auditoria,
correção, componentização, responsividade, acessibilidade, Design System,
navegação, estados de tela ou confirmação de que uma tela Flutter está pronta.

Ele não comprova Supabase nem conclusão ponta a ponta. Para isso, ler também:

- `docs/reviews/coelo-supabase-pendencias.md` para banco, Auth, RLS, RPCs, Edge,
  Storage, migrations e segurança;
- `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md` para o fluxo real
  entre cliente e backend.

### Passagem em andamento — Operações — 2026-09-01

- `meal_plans.list/models`: `in-progress`; Modelos passou a preceder Cardápios,
  arquivos indisponíveis são explícitos, paginação canônica foi preservada e o
  `/dev` ganhou 12 cardápios, 5 modelos e vínculos coerentes. Evidência local:
  16 testes focados executados; todos passaram.
- `plans.list`, `forms_authoring.list`, `imports.hub` e `agenda.list`:
  `in-progress`; menu compartilhado de importar/CSV/XLSX inserido sem callback
  enganoso. Planos e Eventos usam o rodapé canônico de paginação.
- `forms_authoring.edit`: `in-progress`; bloco informativo ganhou detalhes,
  campos numéricos ganharam mínimo/máximo e seções, perguntas e opções passaram
  a ser reordenáveis, preservando setas acessíveis. Evidência local: 20 testes
  do editor executados; todos passaram.
- `agenda.request/approvals`: `in-progress`; arquivos e paginação foram
  adicionados às duas superfícies. A entrada Agenda/Permissões foi removida e
  as URLs legadas redirecionam para `profiles`, que segue como fonte de verdade.
- `agenda.create/edit`: `in-progress`; o wizard passou a usar toggle canônico
  para dia inteiro, exibe mini-mapa associado ao local, permite adicionar e
  tipar perguntas contextuais persistidas no modelo local e removeu a promessa
  prematura de canais de lembrete. Evidência local: 11 testes focados
  executados; todos passaram, e o analyzer focado não encontrou issues.
- Regressão ampliada da Agenda: 93 testes funcionais executados; todos os 93
  passaram após alinhar as URLs legadas de Permissões ao redirecionamento para
  Perfis. Vinte comparações visuais continuam RED por mudanças intencionais nas
  superfícies; nenhum golden foi atualizado sem inspeção/aprovação.
- Continuam abertas: wizard e vínculos de Cardápios, periodicidade compartilhada,
  separação Criar/Respostas de Formulários, UI responsiva final da Agenda,
  mini-mapa, code review final e gates visuais globais.
- Gate do checkpoint: 115 testes focados executados; todos passaram. O
  validador administrativo passou sem ampliar a allowlist, o analyzer focado do
  editor não encontrou issues e `git diff --check` deve permanecer obrigatório
  antes do commit.

### Contrato de abertura da atividade

Antes de corrigir, listar as pendências conhecidas e registrar o recorte:

| Campo | Preenchimento obrigatório |
|---|---|
| Modalidade | Todas as pendências; todas as telas; macrotema; macrotema + telas; telas específicas; ou ações específicas. |
| Objetivo | Resultado concreto esperado nesta atividade. |
| Incluído | Telas, subtelas, `screen_id`, `action_id` e macrotemas trabalhados. |
| Fora de escopo | Pendências conhecidas que não serão tratadas agora. |
| Ordem | Sequência de execução e dependências. |
| Critério de parada | Condição verificável para encerrar ou pausar o recorte. |
| Evidências | Análises, testes, interações, tamanhos, escalas e comparações esperadas. |
| Estimativa | Tempo por fatia e total, com premissas e bloqueios. |

Se o pedido já informar o recorte, confirmá-lo e prosseguir. Se não informar,
fazer somente a inspeção necessária, apresentar as pendências e pedir a escolha
antes de modificar código. Concluir o recorte não significa que as demais
pendências, telas ou ações foram concluídas.

## 2. O que significa “Flutter 100%”

Uma **ação**, não apenas a rota, só recebe `verified` quando todos os itens
aplicáveis abaixo têm evidência atual:

1. A rota produtiva abre pelo menu, link direto, voltar/avançar e recarregamento.
2. Carregamento, vazio, sem resultado, sucesso, erro, nova tentativa, sem
   permissão e indisponível estão tratados sem dados falsos.
3. Lista, Cards, tabela, filtros, flyout, diálogos, calendário, wizard e
   formulários usam os componentes e tokens canônicos da skill `coelo-ui`.
4. A página usa o contêiner macro do shell e mantém hierarquia, espaçamento,
   tipografia, foco, hover e ações iguais às baselines aprovadas.
5. Componentes repetidos foram extraídos; widgets gigantes, regras de negócio
   no `build` e duplicação relevante têm pendência explícita ou foram corrigidos.
6. A experiência funciona em larguras representativas de celular, tablet e web,
   com texto em 100%, 150% e 200%, sem corte, sobreposição ou perda de ação.
7. Teclado, foco, Escape, semântica, contraste e alvos de toque foram verificados.
8. Criar, editar, publicar, arquivar, excluir, enviar, importar ou qualquer outra
   ação aplicável possui feedback, prevenção de duplo envio e tratamento de erro.
9. `dart analyze`, testes unitários, de widget, de navegação e regressões visuais
   aplicáveis passam no estado atual, sem apenas atualizar uma imagem de referência.
10. A evidência contém arquivo/rota, comando, resultado e data. “Abriu aqui” não
    é evidência suficiente.

Uma tela com apenas mock, fixture, repository fake, rota `/dev`, estado
`fail-closed`, teste isolado ou aparência correta continua aberta.

## 3. Estados permitidos

| Estado | Significado simples |
|---|---|
| `not-reviewed` | Ainda não houve verificação atual. |
| `audited` | Foi inspecionada; ainda existem pendências ou falta prova. |
| `in-progress` | Há correção Flutter em andamento. |
| `local-green` | Testes locais passaram, mas faltam gates ou revisão final. |
| `blocked-decision` | Uma decisão de produto, jurídica ou arquitetural impede avanço seguro. |
| `verified` | Todos os itens aplicáveis de “Flutter 100%” foram comprovados. |
| `regressed` | Já esteve verde, mas uma mudança posterior quebrou a evidência. |

Somente `verified` fecha o lado Flutter. O estado geral integrado continua no
rastreador ponta a ponta.

### Glossário em linguagem simples

| Termo | O que significa aqui |
|---|---|
| `screen_id` | Nome curto e estável de uma família de telas. |
| `action_id` | Nome curto de uma ação específica, como criar ou editar. |
| baseline | Referência aprovada usada para comparar o que está sendo revisado. |
| golden | Imagem aprovada que um teste compara com a tela atual. |
| smoke test | Verificação rápida de que a tela abre e o essencial responde. |
| `54/54` | Foram executados 54 testes e todos os 54 passaram; não significa que todos os testes possíveis existem. |
| texto 200% | Simulação da fonte com o dobro do tamanho normal para verificar acessibilidade. |
| `verified` | O lado Flutter dessa ação cumpriu todos os critérios aplicáveis e possui evidência atual. |

## 4. Orçamento e níveis de correção

Se o tempo total ainda não foi informado, perguntar primeiro: **“Quanto tempo
total você quer investir nesta atividade?”**. Depois da resposta, reler as
pendências, recalcular as estimativas e recomendar um pacote. Nenhuma correção
começa antes da confirmação do usuário.

| Nível | O que inclui | O que não promete | Evidência esperada | ETA inicial |
|---|---|---|---|---:|
| Básica | Ajuste pequeno, local e de baixo risco. | Não fecha arquitetura, regressão nem tela. | Teste focado e diff revisado. | 30–90 min por ação simples |
| Intermediária | Básica + problemas principais, contratos Coelo e testes proporcionais. | Pode deixar ações e estados secundários abertos. | Testes da ação, analyzer proporcional e inspeção do fluxo. | 2–6 h por ação ou tela simples |
| Avançada | Anteriores + ações aplicáveis, arquitetura, estados, acessibilidade, responsividade e regressões. | Não conclui se restar qualquer pendência aplicável. | Matriz funcional, visual e técnica atual. | 1–2 dias por tela |
| Completa | Todas as pendências aplicáveis do recorte e evidências finais. | Não certifica Supabase; isso pertence ao rastreador integrado. | Todos os critérios de “Flutter 100%” verdes. | 2–5 dias por tela |

**Intermediária é o MÍNIMO RECOMENDADO.** Risco pode elevar o mínimo. Auth,
permissões, segurança e dados sensíveis não recebem recomendação Básica.
Somente Completa pode sustentar que uma tela Flutter foi integralmente concluída.
Executar Básica, Intermediária ou Avançada não muda automaticamente o estado
para “verified”.

### Tabela geral obrigatória

Os níveis são cumulativos: Intermediária inclui Básica; Avançada inclui
Intermediária; Completa inclui Avançada. As faixas são referências iniciais por
ação ou tela simples e devem ser recalculadas pelo número de ações, dependências,
complexidade, decisões, riscos e regressões do recorte.

| Nível | O que corrige | O que pode continuar pendente | Estimativa inicial | Quando aconselhar |
| --- | --- | --- | ---: | --- |
| Básica | Falha pequena, reprodução e teste focado. | Demais ações, arquitetura, acessibilidade, responsividade e regressão. | 30–90 min | Somente item pequeno e de baixo risco. |
| Intermediária | Básica + problemas principais, componentes canônicos e testes proporcionais. | Ações secundárias, estados amplos e regressão completa. | 2–6 h | Mínimo aconselhado para correção relevante. |
| Avançada | Intermediária + ações relacionadas, arquitetura, estados, acessibilidade e responsividade. | Pendências finais ou itens fora do recorte. | 1–2 dias | Telas complexas e problemas compartilhados. |
| Completa | Avançada + todas as pendências aplicáveis e evidências finais. | Apenas bloqueios externos e Supabase. | 2–5 dias | Obrigatória para declarar a tela Flutter concluída. |

### Aplicação dos quatro níveis a cada ação

Na matriz por ação, as colunas usam os códigos abaixo. O código sempre se aplica
à pendência concreta daquela linha; não é uma autorização genérica para alterar
outras ações da mesma tela.

| Código | Entrega aplicada à ação | O que continua aberto |
|---|---|---|
| `B` | Reproduzir; corrigir uma falha pequena e de baixo risco; executar o menor teste local que falharia sem a correção. | A própria ação não fica `verified`; permanecem contratos amplos, estados, acessibilidade, responsividade e regressão. |
| `I` | `B` + corrigir os problemas principais; aplicar componentes/contratos Coelo UI existentes; testar sucesso e falha proporcionais. | Podem restar ações relacionadas, estados secundários, matriz visual completa e regressão global. |
| `A` | `I` + fechar estados alcançáveis e arquitetura da ação; validar 375/768/1024/1440, texto 100%/150%/200%, light/dark, teclado, foco, `Esc`, semântica e regressões relevantes. | Podem restar pendências finais da tela, goldens específicos ou decisões externas. |
| `C` | `A` + resolver todas as pendências Flutter aplicáveis da ação e reunir evidência final atual. | Somente bloqueio externo/Supabase; a tela só pode ser concluída se todas as suas ações aplicáveis também estiverem em `C` e `verified`. |

**Regra de decisão:** a célula `B`, `I`, `A` ou `C` não afirma que o trabalho foi
executado; descreve o pacote que seria contratado. A coluna “Nível aconselhado”
é a recomendação mínima para atacar a causa com segurança. Básica nunca conclui
uma ação ou tela. Completa pode concluir uma ação Flutter; só conclui a tela
quando todas as linhas aplicáveis da tela cumprirem a definição de `verified`.

### Temas gerais e nível mínimo aconselhado

| ID | Tema | Mínimo | ETA inicial | Motivo |
|---|---|---|---:|---|
| FLU-GEN-001 | Rotas, menus e links diretos | Intermediária | 8 h | Abrange navegação compartilhada e regressão. |
| FLU-GEN-002 | Fakes, fixtures e composição produtiva | Avançada | 12 h | Pode mascarar ausência de implementação real. |
| FLU-GEN-003 | Shell, componentes e padrões Coelo UI | Avançada | 24 h | Afeta todas as famílias e a baseline Instituição. |
| FLU-GEN-004 | Hover, tokens, tipografia e superfícies | Intermediária | 16 h | Exige correção visual sistemática, não pontual. |
| FLU-GEN-005 | Widgets grandes, estado e arquitetura | Avançada | 24 h | Envolve causa raiz e concorrência. |
| FLU-GEN-006 | Responsividade e escala de texto | Avançada | 48 h | Precisa provar larguras e texto até 200%. |
| FLU-GEN-007 | Teclado, foco e acessibilidade | Avançada | 36 h | Falhas podem impedir uso da aplicação. |
| FLU-GEN-008 | Imagens de referência visual | Avançada | 40 h | Cada divergência precisa de decisão consciente. |
| FLU-GEN-009 | Erros, nova tentativa e duplo envio | Avançada | 32 h | Pode gerar comandos repetidos ou feedback falso. |
| FLU-GEN-010 | Analyzer e regressão global | Intermediária | 8 h | É o gate técnico mínimo do recorte. |
| FLU-GEN-011 | Catálogo e fingerprints | Intermediária | 6 h | Há regressão conhecida e decisão pendente. |
| FLU-GEN-012 | Contratos ainda não decididos | Avançada após decisão | Externo | Não se deve inventar comportamento de produto. |

### Nível mínimo por família e ações

O mínimo abaixo serve para atacar o risco principal. Se o objetivo declarado for
“concluir a tela”, o pacote exigido é **Completa**, mesmo quando a coluna diga
Intermediária ou Avançada.

| screen_id | Ações abrangidas | Mínimo aconselhado | ETA inicial atual | Motivo principal |
|---|---|---|---:|---|
| auth | login, recuperar, redefinir, sair, MFA | Avançada | 6 h | Sessão, segurança, teclado e erros. |
| shell | carregar, navegar, trocar contexto, negar, recarregar | Avançada | 6 h | Estrutura compartilhada por todas as telas. |
| institutions | listar, filtrar, detalhe, criar, editar, status, arquivos, importar, exportar, erro/retry, acesso negado e recarregar | Avançada | 16 h | Baseline visual e funcional administrativa; doze ações independentes. |
| units | listar, filtrar, criar, editar, status, importar, exportar, erro, acesso negado e recarregar | Avançada | 13 h | Diretório local está verde; commands, arquivos produtivos e regressão visual continuam abertos. |
| groups | listar, criar, editar, membros, importar, exportar | Avançada | 8 h | CRUD, membros e arquivos precisam regressão. |
| people | listar, criar, editar, vínculos, recarregar | Avançada | 12 h | Identidade produtiva e oito imagens abertas. |
| access_profiles | listar, criar, detalhe, editar, atribuir, excluir | Avançada após decisão | 16 h | Permissões e contrato estendido. |
| access_models | listar, filtrar, criar, detalhe, editar, duplicar | Avançada após decisão | 11 h | Capabilities, filtros e CRUD estão bloqueados; excluir existe apenas no contrato futuro. |
| invites | listar, criar, detalhe, reenviar, revogar | Intermediária | 8 h | UI existe; faltam estados e confirmações. |
| activities | listar, wizard, detalhe, editar, publicar, avaliar | Avançada | 12 h | Wizard, calendário e commands reais. |
| assessments | lançar, diário, fechar, reabrir, detalhe | Avançada | 10 h | Contrato existe; páginas e regressões faltam. |
| students | listar, vincular, transferir, editar, revogar | Avançada após decisão | 8 h | Produção ainda é somente leitura. |
| attendance | painel, criar, marcar, corrigir, concluir, exportar | Avançada | 12 h | Commands, relógio, erros e exportação. |
| daily_routine | listar, criar, editar, aplicar, publicar | Avançada | 8 h | Produção indisponível e regressão visual. |
| agenda | calendário, criar, detalhe, editar, solicitar, permissões | Avançada após decisão | 16 h | Spec e permissões ainda não fechadas. |
| chat | conversas, abrir, enviar, editar, anexar, recibos, revogar | Avançada | 16 h | Mídia, foco, erros e ciclo completo. |
| notices | listar, criar, editar, agendar, publicar, arquivar | Avançada | 10 h | Só a composição de rota foi conhecida. |
| forms_authoring | listar, criar, overview, editar, publicar, testar | Completa | 16 h | Editor, publicação e catálogo bloqueados. |
| forms_responses | monitorar, responder, listar, detalhe, exportar | Completa | 12 h | Fluxo real e autorização ainda faltam. |
| forms_files | upload, resolver, baixar, expirar, excluir | Completa | 12 h | Ciclo protegido de arquivo é indivisível. |
| acontece | feed, criar, publicar, remover | Avançada após decisão | 10 h | Preview não prova publicação e mídia reais. |
| agora | visualizar, criar, publicar, expirar | Avançada após decisão | 8 h | Entrada e ciclo real permanecem abertos. |
| momentos | visualizar, criar, publicar, remover | Avançada após decisão | 8 h | Origem, mídia e publicação reais faltam. |
| principal_profile | Para Você, perfil, editar | Avançada após decisão | 8 h | Preview estático não conclui edição real. |
| child_safety | listar, criança, criar, editar, suspender | Completa | 10 h | Dados de criança e lifecycle sensível. |
| health_care | listar, criar, detalhe, editar | Completa | 12 h | Dados sensíveis e contrato de detalhe. |
| medication | listar, criar, detalhe, editar, evidência | Completa após decisão | 12 h | Segurança e decisão jurídica/produto. |
| imports | hub, criar, upload, preview, confirmar, status, baixar | Avançada | 16 h | Proveniência, arquivos e backend amplo. |
| profile_files | importar, preview, confirmar, status, exportar, baixar | Completa | 12 h | Arquivos privados e lifecycle completo. |
| audit | listar, filtrar, detalhe, exportar | Avançada | 8 h | Dados sanitizados e exportação. |
| support | criar, tabela, kanban, detalhe, responder, encerrar | Avançada | 8 h | Ações negativas e detalhe permanecem. |
| account | perfil, configurações, tema, MFA, sessões, sair | Avançada | 8 h | Sessões, MFA e segurança da conta. |
| catalog | listar, validar, sincronizar, publicar | Intermediária | 6 h | Regressão técnica conhecida. |
| plans | listar, criar, editar, ativar, atribuir | Avançada após decisão | 10 h | Ativação e atribuição não foram definidas. |
| meal_plans | listar, criar, editar, modelos, publicar | Avançada após decisão | 12 h | Lifecycle e publicação estão abertos. |
| internal_users | listar, criar, editar, suspender, MFA | Completa | 10 h | Usuários privilegiados, suspensão e MFA. |
| error_pages | 403, 404, 409, 500, 503, tentar novamente | Intermediária | 6 h | Fluxos transversais e recuperação. |

## 5. Matriz decisória por tela, subtela e ação

Cada linha é uma ação independente. `B`, `I`, `A` e `C` têm o significado
definido na seção anterior. A estimativa é a parcela incremental da família no
nível aconselhado e inclui os testes proporcionais; itens que compartilham
setup, componente ou regressão devem ser contratados em pacote para evitar soma
duplicada. A soma preliminar por família continua na tabela anterior.

### 5.1 Identidade, shell e cadastros estruturais

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 1.1 | Auth / Login | `auth.login` | Fluxo local, erros e matriz responsiva revalidados; integração Auth remota e rota global continuam fora da prova. | `local-green` | B | I | A | C | Avançada | 1 h | Login válido/inválido, 375/768/1024/1440, 200%, foco e erro; E2E remoto separado. |
| 1.2 | Auth / Recuperar senha | `auth.recover` | O commit `f280e291` confina recovery ao reset, limpa contexto e bloqueia Home/rotas protegidas; produção/link remoto continuam fora da prova. | `local-green` | B | I | A | C | Avançada | 1 h remoto separado | Recovery→Home, Instituições, `/dev`, login/startup e evento runtime negados ou redirecionados; auto-refresh, teclado, foco e link remoto permanecem gates posteriores. |
| 1.3 | Auth / Redefinir senha | `auth.reset` | Recovery é estado distinto, nunca autenticação do shell; voltar para login revoga/limpa a sessão e falha fechado se logout falhar. | `local-green` | B | I | A | C | Avançada | 1 h remoto separado | 66/66 Auth/guards/router e 21/21 `coelo_auth`; depois token remoto inválido/expirado/reutilizado, auto-refresh, produção e E2E. |
| 1.4 | Auth / Sair | `auth.logout` | Provar sessão revogada e navegação segura. | `local-green` | B | I | A | C | Avançada | 1 h | Logout, voltar/link direto sem dado anterior e foco correto. |
| 1.5 | Auth / MFA | `auth.mfa` | Fluxo sensível e recuperação não têm prova atual. | `audited` | B | I | A | C | Avançada | 2 h | Desafio, erro, cancelamento, sessão revogada e acessibilidade. |
| 2.1 | Shell / Carregamento | `shell.load` | Revalidar sessão, loading e ausência de dado pré-auth. | `local-green` | B | I | A | C | Avançada | 1 h | Loading/sucesso/erro sem vazamento, 375–1440 e 200%. |
| 2.2 | Shell / Navegação | `shell.navigate` | Reconciliar menu, deep link, voltar e foco. | `local-green` | B | I | A | C | Avançada | 1 h | Menu/link direto/voltar/avançar/teclado com rota correta. |
| 2.3 | Shell / Troca de contexto | `shell.switch-context` | Limpeza de estado/cache e foco não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Contextos A/B, loading novo, sem dado residual e anúncio. |
| 2.4 | Shell / Acesso negado | `shell.unauthorized` | Revalidar rota direta e retorno seguro. | `local-green` | B | I | A | C | Avançada | 1 h | 403 sem conteúdo prévio, teclado e navegação de saída. |
| 2.5 | Shell / Recarregar | `shell.reload` | Retry/reload idempotente e sessão revogada abertos. | `audited` | B | I | A | C | Avançada | 1 h | Reload de sucesso/erro/revogação sem duplicar comandos. |
| 3.1 | Instituições / Diretório | `institutions.list` | Revalidar Cards/tabela, estados e baselines alteradas. | `local-green` | B | I | A | C | Avançada | 2 h | Loading/empty/error/unauthorized, Cards/tabela e goldens exatos. |
| 3.2 | Instituições / Filtros | `institutions.filter` | Revalidar busca, tabs, filtros e sem resultados. | `local-green` | B | I | A | C | Avançada | 1 h | Busca/filtros/tabs, rascunho, limpar/aplicar, teclado e 200%. |
| 3.3 | Instituições / Detalhe | `institutions.detail` | Link direto, not-found e conteúdo autorizado não têm prova Flutter própria. | `audited` | B | I | A | C | Avançada | 1 h | Abrir por Card/tabela/link, not-found, acesso negado, 375–1440 e 200%. |
| 3.4 | Criar Instituição | `institutions.create` | Revalidar wizard, campos, mídia, erros e rodapé. | `local-green` | B | I | A | C | Avançada | 1,5 h | Fluxo completo, validação, duplo envio, 375 light e 1440 dark. |
| 3.5 | Editar Instituição | `institutions.edit` | Revalidar carga, dirty state, mídia e salvamento. | `local-green` | B | I | A | C | Avançada | 1,5 h | Carga/edição/erro/abandono, 375–1440, 200% e golden exato. |
| 3.6 | Instituições / Ativar-desativar | `institutions.status` | Confirmação, ação negativa e feedback precisam rerun. | `local-green` | B | I | A | C | Avançada | 1 h | Ativar/desativar, cancelar, erro, foco devolvido e estado atualizado. |
| 3.7 | Instituições / Arquivos | `institutions.files` | Abertura, foco, autorização e ciclo dos arquivos não têm prova Flutter isolada. | `audited` | B | I | A | C | Avançada | 1,5 h | Flyout canônico, estados, teclado, `Esc`, erro e ausência de path interno. |
| 3.8 | Instituições / Importar | `institutions.import` | Upload, preview, confirmação, falha e retry continuam abertos. | `audited` | B | I | A | C | Avançada | 2 h | Selecionar, validar, prever, confirmar/cancelar, falhar e recarregar. |
| 3.9 | Instituições / Exportar | `institutions.export` | Progresso, falha e download protegido não têm prova Flutter própria. | `audited` | B | I | A | C | Avançada | 1,5 h | Solicitar, aguardar, falhar/repetir e baixar sem expor localização interna. |
| 3.10 | Instituições / Erro e retry | `institutions.error` | Estado de erro existe no conjunto da lista, mas não foi fechado como ação. | `audited` | B | I | A | C | Avançada | 1 h | Erro real, mensagem segura, retry idempotente, foco e ação Criar preservada quando autorizada. |
| 3.11 | Instituições / Acesso negado | `institutions.access-denied` | A negação precisa de prova por rota direta e sem conteúdo anterior. | `audited` | B | I | A | C | Avançada | 1 h | 403, deep link, zero dado residual, teclado/foco e ausência de criação. |
| 3.12 | Instituições / Recarregar | `institutions.reload` | Erro/retry e preservação de filtros não comprovados. | `audited` | B | I | A | C | Avançada | 1 h | Falha, retry, filtros/página preservados e sem duplicação. |
| 4.1 | Unidades / Diretório | `units.list` | `SupabaseUnitDirectoryRepository` candidato cobre listagem, paginação, ordenação e filtros, mas produção permanece `fail-closed`: RPCs legados são people-based e OQ-043 não os aprova para o ator interno. | `local-green` | B | I | A | C | Avançada | 2 h | Diretório canônico, Cards/tabela, 375–1440, 200%, teclado; depois gateway nominal por realm e tenant A/B. |
| 4.2 | Unidades / Filtrar | `units.filter` | Busca/status/no-results e mapeamento server-side passaram localmente; adapter não é injetado em produção até gateway nominal e tenant A/B. | `local-green` | B | I | A | C | Avançada | 1 h | Buscar/limpar/status/sem resultados/reload, foco e prova remota autorizada. |
| 4.3 | Criar Unidade | `units.create` | Adapter/formulário candidato mapeia tipo, plano UUID e criação; rota produtiva continua bloqueada por OQ-043. | `local-green` | B | I | A | C | Avançada | 2 h | Wizard/goldens locais; depois RPC interno nominal, erro, duplo envio e reload remoto. |
| 4.4 | Editar Unidade | `units.edit` | Adapter candidato cobre carga, `management_version`, herança, tipo e plano; produção permanece `fail-closed` até contrato nominal, negativos e reload. | `local-green` | B | I | A | C | Avançada | 2 h | Herdar/personalizar local; depois conflito, salvar/falhar/abandonar e reload remoto. |
| 4.5 | Unidades / Status | `units.status` | Confirmação local permanece verde; comandos legados people-based não podem ser usados pelo ator interno. | `local-green` | B | I | A | C | Avançada | 1 h | Ativar/desativar local; depois gateway nominal, confirmação negativa, erro e reload. |
| 4.6 | Unidades / Importar | `units.import` | Adapter cobre template, upload/preview, confirmação e retry, mas produção injeta `UnavailableUnitDirectoryRepository` e `UnavailableUnitBackendCommandsGateway`; composição aguarda handoff Supabase. | `blocked-supabase` | B | I | A | C | Avançada após handoff | 1.5 h + decisão | Composição produtiva aprovada; seleção/validação/preview/confirmar/retry/erro/cancelamento acessíveis. |
| 4.7 | Unidades / Exportar | `units.export` | Flutter em `audited/local-hardening`: gateway exige hub trifásico `request_export` → `status` → `download`, correlaciona o job em cada resposta, valida DTO/colunas/estado/URL HTTPS/TTL e a UI impede duplo clique, preserva idempotência controlada, revalida expiração, injeta opener e apresenta busy/erros acessíveis. A UI também revalida o snapshot após o `await` e não abre artefato produzido para filtros/view antigos. Produção continua com gateway `Unavailable`; escopo autoritativo, remoto, cleanup/cache, remint e E2E seguem bloqueados. O worker local reutiliza replay `SUCESSO`, preserva o artefato pós-conclusão, reautoriza antes da URL e exige delegação interna do hub. | `blocked-supabase` | B | I | A | C | Avançada após decisão e handoff | pacote principal local executado; 5–9 h Flutter/composição residual + decisão/backend/remoto | Flutter 45/45; analyzer focado sem issues. Supabase unit-export 41/47, com 6 REDs explícitos. Ainda exige configuração coordenada do segredo, composição aprovada, tenant A/B, grants legados, retenção/remint, cleanup/purge, remoto e E2E sem expor caminho. |
| 4.8 | Unidades / Erro | `units.error` | Estado de falha e ação criar foram cobertos localmente; erros reais de gateway e telemetria continuam fora. | `local-green` | B | I | A | C | Avançada | 0.5 h | Falhar sem sucesso falso, mensagem clara, criar quando permitido e retry acessível. |
| 4.9 | Unidades / Acesso negado | `units.access-denied` | UI local esconde toolbar, busca, filtros, tabs, alternância Cards/Tabela, arquivos, criar, Cards/tabela e paginação depois que o diretório entra em `unauthorized`; autorização pré-resposta, cache anterior, sessão/vínculo revogado, tenant A/B, deep link e backend real não foram certificados. | `local-green` | B | I | A | C | Avançada | 0.5 h executada; 2–4 h residuais + integração | Estado final negado em 375 px/200% sem dados ou ações, mensagem semântica e bounds válidos; ainda exigir pré-resposta, success→revogação, foco/teclado, 768–1440, tenant A/B, link direto e E2E. |
| 4.10 | Unidades / Recarregar | `units.reload` | Retry local alterna falha e acesso negado, mas preservação completa de filtros/paginação e rede real seguem abertas. | `local-green` | B | I | A | C | Avançada | 1 h | Repetir carga sem duplicar, preservar consulta/página e tratar nova falha. |
| 4.11 | Unidade / Pessoas / Exportar | `units.people-export` | O botão produtivo e o SnackBar de sucesso falso foram removidos: não existe job, arquivo, URL, capability nem contrato de colunas/escopo. A ação permanece ausente até decisão e backend próprios; não confundir com `units.export` nem `people.export`. | `blocked-decision` | B | I | A | C | Completa após decisão | 0,5 h fail-closed executada; 18–32 h para funcional real | RED encontrou o botão; após 10 deleções no widget e 1 expectativa negativa, o teste focado passou e `unit_form_page_test.dart` passou 24/24. Analyzer 0 erros/0 warnings/45 infos; visual e catálogo verdes. Para concluir: capability `people.export` com `unit_id` server-side, AAL2, minimização, tenant A/B, revogação, job/Storage privado, auditoria, cleanup, remoto e E2E. |
| 5.1 | Turmas / Diretório | `groups.list` | `SupabaseGroupDirectoryRepository` candidato cobre paginação, filtros e erros tipados; produção permanece `fail-closed` porque os RPCs legados são people-based e não cobertos pela OQ-043. | `local-green` | B | I | A | C | Avançada | 1.5 h local; gateway nominal/remoto/E2E residual | Cards/tabela e estados locais verdes; depois gateway nominal por realm, negativos e tenant A/B. |
| 5.2 | Criar Turma | `groups.create` | Adapter candidato mapeia save, mas mutação produtiva continua bloqueada até autorização interna nominal. | `local-green` | B | I | A | C | Avançada | 1.5 h local; escrita produtiva bloqueada | Criar/validar/salvar local provado; não declarar CRUD produtivo/remoto. |
| 5.3 | Turmas / Detalhe-editar | `groups.edit` | Adapter candidato cobre get/save, versão otimista e retorno tipado; deep link `/dev` passou, mas conflito, negação e reload remoto seguem abertos. | `local-green` | B | I | A | C | Avançada | 1.5 h local; detail/reload residual | Abrir/editar/cancelar local; depois gateway nominal e prova remota classificada. |
| 5.4 | Turmas / Membros | `groups.members` | Adapter candidato mapeia pessoas, profissionais, convites e atividades; `/dev` preserva bindings, produção segue bloqueada por OQ-043. | `local-green` | B | I | A | C | Avançada | 1.5 h local; backend/remoto/E2E bloqueados | Negar/conflito/tenant/teclado e persistência dependem de gateway nominal e prova remota. |
| 5.5 | Turmas / Importar | `groups.import` | Botão e SnackBar de sucesso falso foram removidos do formulário; a ação real de arquivo continua ausente, sem picker, gateway, job, upload ou preview. | `audited` / `fail-closed` | B | I | A | C | Avançada | 0,5 h fail-closed executada; 6–12 h + remoto/E2E | RED→GREEN focado 1/1 e suíte do formulário 8/8 em 375 px/200%; analyzer 0 erros/0 warnings. Para concluir: seleção, preview, validação, confirmação, retry/reload, autorização, tenant A/B, remoto e E2E. |
| 5.6 | Turmas / Exportar | `groups.export` | Botão e SnackBar de sucesso falso foram removidos do formulário; a ação real continua ausente, sem gateway, job, arquivo, status, URL ou download. | `audited` / `fail-closed` | B | I | A | C | Avançada | 0,5 h fail-closed executada; 6–12 h + remoto/E2E | RED→GREEN focado 1/1 e suíte do formulário 8/8 em 375 px/200%; analyzer 0 erros/0 warnings. Para concluir: request/status/download, URL expirada, retry/reload, autorização, tenant A/B, remoto e E2E. |
| 6.1 | Pessoas / Diretório | `people.list` | Identidade produtiva fail-closed; oito goldens abertos. | `audited` | B | I | A | C | Avançada | 3 h | Cards/tabela/tabs/filtros/estados, 375–1440 e goldens. |
| 6.2 | Criar Pessoa | `people.create` | Revalidar formulário e resultado sem fingir persistência. | `local-green` | B | I | A | C | Avançada | 2.5 h | Criar/validar/falhar, 200%, teclado e baseline administrativa. |
| 6.3 | Editar Pessoa | `people.edit` | Carga, vínculos, erro e dirty state ainda abertos. | `local-green` | B | I | A | C | Avançada | 2.5 h | Abrir/editar/salvar/falhar/abandonar, 375–1440. |
| 6.4 | Pessoas / Vínculos | `people.links` | Atividade e vínculos dependem de contrato; estados parciais. | `audited` | B | I | A | C | Avançada após decisão | 2 h + decisão | Fluxos permitidos/indisponíveis claros, foco, erro e reload. |
| 6.5 | Pessoas / Recarregar | `people.reload` | Retry, paginação e filtros não têm prova atual. | `audited` | B | I | A | C | Avançada | 2 h | Erro/retry preservando consulta, página e sem duplicação. |
| 7.1 | Perfis de acesso / Lista | `access-profiles.list` | Lifecycle A→B, callbacks reais, limpeza de PII, estado unauthorized e matriz responsiva passaram localmente; capability produtiva e E2E permanecem fora. | `local-green` | B | I | A | C | Avançada | 2 h | Integrar capability/repository produtivos, executar cross-tenant, goldens autorizados e evidência E2E. |
| 7.2 | Criar perfil de acesso | `access-profiles.create` | Access Extended e Imports bloqueiam contrato. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Fluxo aprovado, validação, erro, capacidade e regressão visual. |
| 7.3 | Perfil de acesso / Detalhe | `access-profiles.detail` | Detalhe e acesso direto ainda parciais. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/link direto/not-found/unauthorized e 200%. |
| 7.4 | Editar perfil de acesso | `access-profiles.edit` | Contrato estendido e permissões bloqueados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Carga/edição/conflito/erro sem ampliar permissão pela UI. |
| 7.5 | Perfis de acesso / Atribuir | `access-profiles.assign` | Autoridade e efeitos da atribuição não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Atribuir/negar/revogar/reload com capability explícita. |
| 7.6 | Perfis de acesso / Excluir | `access-profiles.delete` | Regra destrutiva e dependências não decididas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Confirmação, bloqueios, erro, foco e ausência após reload. |
| 8.1 | Modelos de acesso / Lista | `access-models.list` | Capability, composição produtiva e estados precisam revisão; rota canônica está fail-closed. | `audited` | B | I | A | C | Avançada após decisão | 2 h + decisão | Diretório/loading/empty/error/negação, Cards/tabela, 375–1440 e 200%. |
| 8.2 | Modelos de acesso / Filtrar | `access-models.filter` | Busca, domínio, status e preservação da consulta não têm prova isolada. | `audited` | B | I | A | C | Avançada após decisão | 1 h + decisão | Buscar/limpar/sem resultados/reload, teclado, foco e 200%. |
| 8.3 | Criar modelo de acesso | `access-models.create` | CRUD bloqueado por decisão de capabilities. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar e autorização explícita. |
| 8.4 | Modelo de acesso / Detalhe | `access-models.detail` | Composition root permanece 503; teste concorrente incompatível foi preservado fora da árvore. Teste router canônico está bloqueado pelo erro externo de Unidades. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Abrir/not-found/unauthorized, teclado, responsividade e 503 enquanto bloqueado. |
| 8.5 | Editar modelo de acesso | `access-models.edit` | CRUD e impacto nas atribuições não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Editar/conflito/erro/reload sem permissão inferida. |
| 8.6 | Duplicar modelo de acesso | `access-models.duplicate` | Composition root permanece 503; teste concorrente incompatível foi preservado fora da árvore e a capability real segue bloqueada. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Duplicar/cancelar/falhar ou provar 503, conforme decisão de capability/backend. |
| 9.1 | Convites / Lista | `invites.list` | Produção unavailable; estados e goldens abertos. | `local-green` | B | I | A | C | Intermediária | 2 h | Loading/empty/error, filtros, 375–1440 e 200%. |
| 9.2 | Criar Convite | `invites.create` | Email/backend ausente; UI não pode fingir envio. | `local-green` | B | I | A | C | Intermediária | 2 h | Formulário, validação, indisponível/erro e sem sucesso falso. |
| 9.3 | Convite / Detalhe | `invites.detail` | Link direto, expirado e erro precisam prova. | `local-green` | B | I | A | C | Intermediária | 1 h | Abrir/not-found/expirado/unauthorized e responsividade. |
| 9.4 | Convite / Reenviar | `invites.resend` | Feedback, duplo envio e erro não comprovados. | `local-green` | B | I | A | C | Intermediária | 1.5 h | Reenviar/progresso/erro/bloqueio e foco. |
| 9.5 | Convite / Revogar | `invites.revoke` | Confirmação negativa e estados finais abertos. | `local-green` | B | I | A | C | Intermediária | 1.5 h | Confirmar/cancelar/falhar, `Esc`, foco e item revogado. |
| 10.1 | Atividades / Diretório | `activities.list` | Produção usa repository Supabase e o domínio Flutter representa modelos `platform`, `institution` e `unit`; diretório/duplicação foram revalidados localmente. Remoto permanece aberto. | `local-green` | B | I | A | C | Avançada | 2 h | Diretório/estados/filtros, 375–1440, 200%, visual e prova remota. |
| 10.2 | Criar Atividade / Wizard | `activities.create` | Criação/duplicação aceita instituição ou unidade compatível, preserva nome incremental e envia `unit_id`; migration tem 31 asserts estáticos, sem replay. | `local-green` | B | I | A | C | Avançada | 2 h | Seis etapas/goldens; depois replay pgTAP, erro antes do command e E2E remoto. |
| 10.3 | Atividade / Detalhe | `activities.detail` | Link direto, estados e conteúdo não revalidados. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/not-found/unauthorized, teclado e 200%. |
| 10.4 | Editar Atividade | `activities.edit` | Carga, dirty state e falha parcial continuam abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Editar/salvar/falhar/abandonar sem sucesso parcial. |
| 10.5 | Atividade / Publicar | `activities.publish` | Confirmação, duplo envio e erro precisam prova. | `local-green` | B | I | A | C | Avançada | 2 h | Publicar/cancelar/falhar/repetir e estado após reload. |
| 10.6 | Atividade / Avaliar | `activities.assessment` | Fluxo e navegação com Avaliações ainda parciais. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/lançar/erro/retornar, foco e responsividade. |

### 5.2 Operação, agenda, comunicação e formulários

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 11.1 | Avaliações / Lançamento | `assessments.entry` | Página, estados e comparadores precisam rerun. | `audited` | B | I | A | C | Avançada | 2 h | Lançar/validar/falhar, timezone e 375–1440. |
| 11.2 | Avaliações / Diário | `assessments.gradebook` | Gradebook e navegação não têm prova atual. | `audited` | B | I | A | C | Avançada | 2 h | Lista/edição/empty/error, teclado, 200% e reload. |
| 11.3 | Avaliações / Fechar | `assessments.close` | Confirmação, conflito e feedback abertos. | `audited` | B | I | A | C | Avançada | 2 h | Fechar/cancelar/conflito/erro e estado após reload. |
| 11.4 | Avaliações / Reabrir | `assessments.reopen` | Regra, motivo e conflito não comprovados na UI. | `audited` | B | I | A | C | Avançada | 2 h | Reabrir/cancelar/falhar, motivo, foco e reload. |
| 11.5 | Avaliação / Detalhe | `assessments.detail` | Link direto e estados não revalidados. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/not-found/unauthorized e responsividade. |
| 12.1 | Alunos / Acompanhamento | `students.list` | Versão read-only canônica está verde; 24 legados de gerenciamento foram preservados externamente e retirados do analyzer sem alterar o contrato produtivo. | `local-green` | B | I | A | C | Avançada | 2 h | 22 testes passam em 375–1440, 200%, teclado, offline/unavailable e sem ação falsa; gerenciamento e E2E continuam separados. |
| 12.2 | Alunos / Vincular | `students.link` | Contrato produtivo não aprovado. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Vínculo permitido/negado/erro e reload conforme contrato. |
| 12.3 | Alunos / Transferir | `students.transfer` | Escopo, confirmação e autoridade não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Transferir/cancelar/negar/falhar sem perda de contexto. |
| 12.4 | Alunos / Editar | `students.edit` | Campos e autoridade ainda não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Editar/validar/falhar e retorno ao detalhe. |
| 12.5 | Alunos / Revogar | `students.revoke` | Ação sensível e efeitos não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Confirmar/cancelar/negar/falhar, foco e reload. |
| 13.1 | Assiduidade / Dashboard | `attendance.dashboard` | Dashboard Flutter local revalidado com clock determinístico; 55 testes funcionais da família e dois goldens Windows passaram. Produção, reload remoto e E2E continuam abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Estados, clock determinístico e dois goldens reais; ainda exigir backend, remoto, tenant A/B e E2E. |
| 13.2 | Assiduidade / Nova chamada | `attendance.create` | Contexto, duplo envio e erros precisam prova. | `local-green` | B | I | A | C | Avançada | 2 h | Criar/cancelar/falhar, contexto correto e foco. |
| 13.3 | Assiduidade / Marcar | `attendance.mark` | Interações e concorrência ainda parciais. | `local-green` | B | I | A | C | Avançada | 2 h | Marcar/desmarcar, teclado/toque, erro e snapshot preservado. |
| 13.4 | Assiduidade / Corrigir | `attendance.correct` | Motivo, conflito e erro precisam evidência. | `local-green` | B | I | A | C | Avançada | 2 h | Corrigir/validar/conflito/falhar e reload. |
| 13.5 | Assiduidade / Concluir | `attendance.finish` | Confirmação e command guard não têm fechamento final. | `local-green` | B | I | A | C | Avançada | 2 h | Concluir/cancelar/duplo envio/erro e estado final. |
| 13.6 | Assiduidade / Exportar | `attendance.export` | Worker/download continuam separados. | `audited` | B | I | A | C | Avançada | 2 h | Solicitar/progresso/falha/retry/download acessível. |
| 14.1 | Rotina diária / Diretório | `daily-routine.list` | Diretório Flutter local revalidado; a família passou 48 testes, manteve 4 skips justificados e teve 9 goldens atualizados e inspecionados. Produção continua unavailable. | `local-green` | B | I | A | C | Avançada | 1.5 h | Diretório/estados/filtros e matriz visual local provados; backend, remoto e E2E permanecem abertos. |
| 14.2 | Criar Rotina | `daily-routine.create` | Fluxo visual/local revalidado com o formulário e estados da família; command produtivo e persistência remota continuam indisponíveis. | `local-green` | B | I | A | C | Avançada | 1.5 h | Criar/validar/falhar local e baseline de formulário; ainda exigir command autorizado, reload remoto e E2E. |
| 14.3 | Editar Rotina | `daily-routine.edit` | Dirty state, seções e erro abertos. | `local-green` | B | I | A | C | Avançada | 1.5 h | Editar/salvar/falhar/abandonar e 200%. |
| 14.4 | Rotina / Aplicar | `daily-routine.apply` | Escopo, confirmação e feedback precisam prova. | `local-green` | B | I | A | C | Avançada | 1.5 h | Aplicar/cancelar/falhar e resultado após reload. |
| 14.5 | Rotina / Publicar | `daily-routine.publish` | Duplo envio, erro e estado final não comprovados. | `local-green` | B | I | A | C | Avançada | 2 h | Publicar/cancelar/falhar/repetir e reload. |
| 15.1 | Agenda / Calendário | `agenda.view` | Calendário e estados possuem implementação visual/local consolidada em `/dev`; produção permanece fail-closed sem origem autoritativa. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Agenda passou 112/112 testes e a família Forms/Agenda preserva matriz responsiva/goldens; backend, autorização, remoto e E2E pendentes. |
| 15.2 | Agenda / Criar evento | `agenda.create` | Criação funciona somente com estado local injetado; produção não simula persistência, audiência ou autorização. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Criar/validar/falhar local e controles canônicos testados; command, autorização e reload produtivos pendentes. |
| 15.3 | Agenda / Detalhe | `agenda.detail` | Detalhe e estados locais são alcançáveis e responsivos; rota produtiva preserva indisponibilidade honesta. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Abrir/estados/responsividade local testados; origem autorizada, acesso direto produtivo e E2E pendentes. |
| 15.4 | Agenda / Editar | `agenda.edit` | Edição visual/local cobre o lifecycle aprovado sem declarar command remoto; produção permanece fail-closed. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Editar/validar/conflito local testados; autoridade, persistência, reload remoto e E2E pendentes. |
| 15.5 | Agenda / Solicitar | `agenda.request` | Solicitação possui comportamento visual/local comprovado; nenhuma entrega, autoridade ou persistência remota foi simulada. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Solicitar/cancelar/falhar local testados; capability, efeitos remotos e E2E pendentes. |
| 15.6 | Agenda / Permissões | `agenda.permissions` | Superfície de permissões foi revalidada localmente; o frontend não concede capacidade e produção permanece indisponível sem backend autoritativo. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Permitido/negado e matriz local testados; modelo autoritativo, RLS, cross-tenant, remoto e E2E pendentes. |
| 16.1 | Chat / Conversas | `chat.list` | Cinco conversas `/dev`, busca, cursor, mark-read, launcher Principal sem duplicação e 14 goldens passaram; paginação total aguarda `total/has_more` no RPC. | `local-green` | B | I | A | C | Avançada | local executado; backend separado | Loading/empty/error, 375–1440/200%; não inventar Página X/Y sem contrato remoto. |
| 16.2 | Chat / Abrir conversa | `chat.open` | Thread `/dev` usa ordem oldest→newest na tela a partir do contrato newest-first; teste cobre 2+ mensagens e retorno pelo menu Principal. | `local-green` | B | I | A | C | Avançada | local executado; remoto separado | Abrir/voltar/foco e ordem local verdes; membership revogada, link adulterado e reload remoto continuam abertos. |
| 16.3 | Chat / Enviar mensagem | `chat.send` | Envio idempotente local insere a nova mensagem na posição coerente; teste pós-envio impede dupla inversão. | `local-green` | B | I | A | C | Avançada | local executado; remoto separado | Enviar/ordem/sem duplicação local; falha/retry, autorização, persistência e E2E remoto ainda pendentes. |
| 16.4 | Chat / Editar mensagem | `chat.edit` | Janela, confirmação e erro não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Editar/cancelar/falhar e estado atualizado. |
| 16.5 | Chat / Anexar arquivo | `chat.attach` | Mídia, upload e falha parcial continuam abertos. | `audited` | B | I | A | C | Avançada | 3 h | Escolher/validar/enviar/cancelar/falhar e foco. |
| 16.6 | Chat / Recibos | `chat.receipts` | Leitura/entrega e semântica não revalidadas. | `audited` | B | I | A | C | Avançada | 2 h | Estados textualizados, teclado e sem depender só de cor. |
| 16.7 | Chat / Revogar-remover | `chat.revoke` | Ação negativa, membership e reload abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Confirmar/cancelar/negar/falhar, foco e desaparecimento correto. |
| 17.1 | Avisos / Diretório | `notices.list` | Diretório visual e funcional local cobre responsividade automática, criação canônica, tabela 56/64, tipos/status, preview desktop, estados, 375–1440, light/dark e 200%; composição produtiva, reload remoto e E2E seguem abertos. | `local-green` | B | I | A | C | Completa | 2 h | Evidência local em `notice_directory_page_test.dart` e `notice_directory_golden_test.dart`; ainda exigir repository produtivo, autorização, remoto e E2E para `verified`. |
| 17.2 | Criar Aviso | `notices.create` | Formulário e command não revalidados. | `audited` | B | I | A | C | Avançada | 2 h | Criar/validar/falhar e baseline administrativa. |
| 17.3 | Editar Aviso | `notices.edit` | Carga, dirty state e erro abertos. | `audited` | B | I | A | C | Avançada | 1.5 h | Editar/salvar/falhar/abandonar e 200%. |
| 17.4 | Avisos / Agendar | `notices.schedule` | Calendário, timezone e erro precisam prova. | `audited` | B | I | A | C | Avançada | 1.5 h | Agendar/alterar/cancelar/falhar com picker canônico. |
| 17.5 | Avisos / Publicar | `notices.publish` | Confirmação e duplo envio não comprovados. | `audited` | B | I | A | C | Avançada | 1.5 h | Publicar/cancelar/falhar e estado após reload. |
| 17.6 | Avisos / Arquivar | `notices.archive` | Ação negativa e recuperação não comprovadas. | `audited` | B | I | A | C | Avançada | 1.5 h | Arquivar/cancelar/falhar, foco e filtros atualizados. |
| 18.1 | Formulários / Diretório | `forms.list` | `/dev` usa 30 fixtures determinísticas, filtros, Cards/Tabela e cursor opaco; produção mantém API autorizada/fail-closed. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Diretório e matriz 375–1440/200% testados; E2E pendente. |
| 18.2 | Criar Formulário | `forms.create` | Editor/wizard funciona no `/dev`; produção mantém a mesma moldura com valores neutros e ações desabilitadas. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Matriz 375–1440/200%; persistência remota pendente. |
| 18.3 | Formulário / Visão geral | `forms.overview` | Métricas, distribuição, audiência, agenda, versões e atalhos operacionais funcionam localmente; produção explicita indisponibilidade. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Ações navegam às superfícies fail-closed; dados remotos pendentes. |
| 18.4 | Formulário / Editar | `forms.edit` | Editor modular cobre autosave, seções, perguntas, mídia e estados responsivos; produção preserva moldura neutra bloqueada. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Persistência, autorização e E2E pendentes. |
| 18.5 | Formulário / Publicar | `forms.publish` | Publicar agora/agendar funciona somente no `/dev`, com data/hora canônica e feedback sem persistência remota; produção não oferece sucesso falso. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Capability, command e reload produtivos pendentes. |
| 18.6 | Formulário / Testar | `forms.test` | Fluxo local identificado/anônimo cobre validação, revisão, retorno e reinício; produção preserva composição fail-closed. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Autorização e E2E produtivos pendentes. |
| 19.1 | Respostas / Monitor | `forms.monitor` | Hierarquia, elegíveis, responderam, pendentes e perda de elegibilidade têm composição responsiva e drill-down local funcional. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Navegação/estado local testados; fonte autorizada, reload remoto e E2E pendentes. |
| 19.2 | Responder Formulário | `forms.respond` | Retomada, revisão, anonimato, autosave e cancelamento de upload funcionam na fixture local sem persistência remota. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Preservação/falha e golden revalidados; autorização, Storage e E2E pendentes. |
| 19.3 | Respostas / Lista | `forms.responses` | Lista identificada/anônima, filtro e paginação por cursor alteram a coleção local determinística. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Ida/volta e estados locais testados; cursor autoritativo remoto pendente. |
| 19.4 | Resposta / Detalhe | `forms.response-detail` | Seleção abre detalhe identificado/anônimo, segredo perdido e mídia protegida sem expor caminho permanente. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Fluxo selecionado e estados seguros testados; autorização/E2E pendentes. |
| 19.5 | Respostas / Exportar | `forms.export` | CSV, XLSX e ZIP possuem jobs locais determinísticos, fila, conclusão, falha, retry e feedback de download. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Worker, arquivo autorizado, expiração remota e E2E pendentes. |
| 20.1 | Arquivos de Formulários / Upload | `forms.upload` | Progresso, cancelamento, falha e indisponibilidade preservam estado verificável na fixture local. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Storage, autorização, retomada remota e E2E pendentes. |
| 20.2 | Arquivos de Formulários / Resolver | `forms.resolve-file` | Rota por `assetId`/`formId`, not-found, unavailable e acesso temporário funcionam localmente sem URL permanente. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Resolução autorizada/assinada e E2E pendentes. |
| 20.3 | Arquivos de Formulários / Baixar | `forms.download` | Preparação e feedback de download local cobrem permitido, expirado e falha sem renderizar endereço permanente. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Download autorizado real, expiração e E2E pendentes. |
| 20.4 | Arquivos de Formulários / Expirar | `forms.expire-file` | Expirar, cancelar e falhar atualizam o store local injetável e sobrevivem à reconstrução coberta pelo teste. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Comando autoritativo, auditoria remota e E2E pendentes. |
| 20.5 | Arquivos de Formulários / Excluir | `forms.delete-file` | Confirmação negativa, falha e exclusão persistem no store local após reconstrução/reload simulado. | `local-green` | B | I | A | C | Completa visual/Flutter | bloqueado no backend | Exclusão autoritativa, auditoria, retenção e E2E pendentes. |

### 5.3 Principal, cuidado e operações de plataforma

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 21.1 | Acontece / Feed | `acontece.feed` | Feed visual local cobre cabeçalho Principal, Agora no topo, criação, carrossel, feed misto, dock global, contexto desktop, estados e galeria; origem produtiva, autorização, remoto e E2E seguem abertos. | `local-green` | B | I | A | C | Completa | 2 h | Evidência local em testes/goldens 375–1440, light/dark, 200%, hover, foco e galeria; ainda exigir composição produtiva e E2E para `verified`. |
| 21.2 | Acontece / Criar | `acontece.create` | Audiência, mídia e contrato produtivo não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Criar/validar/falhar, audiência clara e mídia protegida. |
| 21.3 | Acontece / Publicar | `acontece.publish` | Publicação/Supabase Storage e confirmação não fechadas; R2 está fora do MVP. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Publicar/cancelar/negar/falhar e resultado após reload. |
| 21.4 | Acontece / Remover | `acontece.remove` | Regra negativa e retenção não decididas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Remover/cancelar/negar/falhar, foco e feed atualizado. |
| 22.1 | Agora / Visualizar | `agora.view` | Viewer visual local cobre fullscreen, shell suspenso, quadro responsivo, progresso, autoria, audiência, resposta, ações e retorno; entrada/origem produtiva, autorização, mídia remota e E2E seguem abertos. | `local-green` | B | I | A | C | Completa | 2 h | Evidência local em 375/768/1024/1440, light/dark, 200%, foco, hover, teclado e callbacks honestos; ainda exigir deep link/remoto/E2E para `verified`. |
| 22.2 | Agora / Criar | `agora.create` | Lifecycle e mídia não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar e mídia protegida. |
| 22.3 | Agora / Publicar | `agora.publish` | Publicação real e audiência permanecem abertas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Publicar/cancelar/negar/falhar e reload. |
| 22.4 | Agora / Expirar | `agora.expire` | Regra de expiração e feedback não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Expirar/cancelar/falhar e ausência após reload. |
| 23.1 | Momentos / Visualizar | `momentos.view` | Viewer visual local cobre fullscreen sem shell/dock, retorno contextual e foco, matriz 375–1440, texto 200%, hover e mídia honesta; origem produtiva, autorização, remoto e E2E seguem abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/fechar/deep link, foco, 375–1440 e 200%; ainda exigir composição produtiva e E2E para `verified`. |
| 23.2 | Momentos / Criar | `momentos.create` | Lifecycle/mídia não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar com mídia protegida. |
| 23.3 | Momentos / Publicar | `momentos.publish` | Publicação e audiência não fechadas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Publicar/cancelar/negar/falhar e reload. |
| 23.4 | Momentos / Remover | `momentos.remove` | Regra negativa e retenção não decididas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Remover/cancelar/falhar, foco e retorno correto. |
| 24.1 | Principal / Para Você | `principal.for-you` | Preview visual local cobre repository states, hierarquia, 375–1440, 200%, dock e abertura empilhada de Agora/Momentos com retorno e foco; pacote executável, dados produtivos e E2E seguem abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Conteúdo/empty/error, 375–1440, 200% e materialização futura no pacote Principal. |
| 24.2 | Principal / Perfil-circulares | `principal.profile-view` | Preview visual local cobre capa, avatar, estatísticas, tabs Acontece/Momentos/Circulares/Sobre, feed e contexto desktop; hospedagem executável, repositories produtivos, autorização e E2E seguem abertos. | `local-green` | B | I | A | C | Avançada | 3 h | Tabs/conteúdo/erro, sem `coelo_ui_admin`, teclado e visual no app executável. |
| 24.3 | Principal / Editar perfil | `principal.profile-edit` | Campos, ownership e superfície final não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Editar/validar/falhar e persistir no pacote correto. |
| 25.1 | Segurança infantil / Lista | `child-safety.list` | Lifecycle e autorização ainda sem prova atual. | `local-green` | B | I | A | C | Completa | 2 h | Lista/empty/error/unauthorized, 375–1440 e 200%. |
| 25.2 | Segurança infantil / Criança | `child-safety.child` | Detalhe, acesso direto e estados abertos. | `local-green` | B | I | A | C | Completa | 2 h | Abrir/not-found/unauthorized e sem dado de outra criança. |
| 25.3 | Segurança infantil / Criar autorização | `child-safety.create` | Validação, erro e fluxo sensível precisam rerun. | `local-green` | B | I | A | C | Completa | 2 h | Criar/validar/negar/falhar e baseline de formulário. |
| 25.4 | Segurança infantil / Editar autorização | `child-safety.edit` | Carga, dirty state e erro ainda parciais. | `local-green` | B | I | A | C | Completa | 2 h | Editar/salvar/negar/falhar/abandonar e 200%. |
| 25.5 | Segurança infantil / Suspender | `child-safety.suspend` | Suspensão/revogação e ação negativa não comprovadas. | `audited` | B | I | A | C | Completa | 2 h | Confirmar/cancelar/negar/falhar, foco e reload. |
| 26.1 | Perfis de cuidado / Lista | `health-care.list` | Produção fail-closed; 12 PNGs e visual abertos. | `local-green` | B | I | A | C | Completa | 3 h | Diretório/estados/tabs, 375–1440, 200% e goldens. |
| 26.2 | Criar perfil de cuidado | `health-care.create` | Fluxo sensível e arquivos precisam fechamento. | `local-green` | B | I | A | C | Completa | 3 h | Criar/validar/negar/falhar e mídia privada. |
| 26.3 | Perfil de cuidado / Detalhe | `health-care.detail` | Detail foi removido; decisão de produto bloqueia. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Superfície aprovada ou ausência explícita, acesso e estados. |
| 26.4 | Editar perfil de cuidado | `health-care.edit` | Carga, arquivos, dirty state e erro abertos. | `local-green` | B | I | A | C | Completa | 3 h | Editar/salvar/negar/falhar/abandonar e goldens. |
| 27.1 | Medicação / Lista | `medication.list` | OQ-003/OQ-040 bloqueiam produção. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Lista/estados/negação somente após base legal aprovada. |
| 27.2 | Medicação / Criar | `medication.create` | Dados sensíveis, retenção e mídia não decididos. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Criar/validar/negar/falhar com proteção e consentimento. |
| 27.3 | Medicação / Detalhe | `medication.detail` | Superfície e acesso permanecem bloqueados. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Abrir/not-found/unauthorized sem vazamento sensível. |
| 27.4 | Medicação / Editar | `medication.edit` | Correção, retenção e autoridade não aprovadas. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Editar/validar/negar/falhar e trilha clara. |
| 27.5 | Medicação / Evidência | `medication.evidence` | Upload/download/expiração jurídicos não aprovados. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Enviar/ver/baixar/negar/expirar sem expor caminho. |
| 28.1 | Importações / Hub | `imports.list` | Diretório/tabela/paginação, empty/error e 375–1440 foram fechados visualmente; autorização, provenance e remoto seguem abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Lista/empty/error/filtros, 375–1440 e 200%. |
| 28.2 | Importações / Nova | `imports.create` | Dialog verde não fecha fluxo amplo nem golden. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/fechar/Cancelar/`Esc`/foco e golden aprovado. |
| 28.3 | Importações / Upload | `imports.upload` | Arquivo, validação e falha parcial abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Escolher/validar/enviar/cancelar/falhar. |
| 28.4 | Importações / Preview | `imports.preview` | Proveniência, erros de linha e 200% não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Preview/erros/sem resultados, teclado e responsividade. |
| 28.5 | Importações / Confirmar | `imports.confirm` | Duplo envio, confirmação e erro abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Confirmar/cancelar/falhar/repetir sem duplicação. |
| 28.6 | Importações / Status | `imports.status` | Progresso, falha/retry e reload não comprovados. | `audited` | B | I | A | C | Avançada | 2.5 h | Pending/running/success/failure/retry e reload. |
| 28.7 | Importações / Baixar | `imports.download` | Resultado protegido e expirado não comprovados. | `audited` | B | I | A | C | Avançada | 2.5 h | Baixar permitido/negado/expirado e erro acessível. |
| 29.1 | Arquivos de perfil / Importar | `profile-files.import` | Callback/repository e lifecycle não mapeados. | `audited` | B | I | A | C | Completa | 2 h | Escolher/validar/enviar/falhar sem expor caminho. |
| 29.2 | Arquivos de perfil / Preview | `profile-files.preview` | Conteúdo, erro e privacidade não comprovados. | `audited` | B | I | A | C | Completa | 2 h | Preview permitido/negado/inválido, 200% e teclado. |
| 29.3 | Arquivos de perfil / Confirmar | `profile-files.confirm` | Confirmação, duplo envio e falha parcial abertos. | `audited` | B | I | A | C | Completa | 2 h | Confirmar/cancelar/falhar e reload sem duplicação. |
| 29.4 | Arquivos de perfil / Status | `profile-files.status` | Progresso e recuperação não comprovados. | `audited` | B | I | A | C | Completa | 2 h | Pending/running/success/failure/retry acessíveis. |
| 29.5 | Arquivos de perfil / Exportar | `profile-files.export` | Geração protegida e erro abertos. | `audited` | B | I | A | C | Completa | 2 h | Solicitar/progresso/falhar/retry sem dado sensível na UI. |
| 29.6 | Arquivos de perfil / Baixar | `profile-files.download` | Download/expiração/negação não comprovados. | `audited` | B | I | A | C | Completa | 2 h | Baixar permitido/negado/expirado e foco correto. |
| 30.1 | Auditoria / Lista | `audit.list` | Paginação, sanitização e estados não revisados. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/paginação, 375–1440 e 200%. |
| 30.2 | Auditoria / Filtrar | `audit.filter` | Filtros, datas e sem resultados precisam prova. | `audited` | B | I | A | C | Avançada | 2 h | Busca/filtros/picker canônico/limpar/sem resultados. |
| 30.3 | Auditoria / Detalhe | `audit.detail` | Dados sanitizados e acesso direto não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/not-found/unauthorized sem dados brutos sensíveis. |
| 30.4 | Auditoria / Exportar | `audit.export` | Export protegido, erro e retenção abertos. | `audited` | B | I | A | C | Avançada | 2 h | Solicitar/falhar/retry/baixar sem expor informação proibida. |

### 5.4 Suporte, conta, governança e fechamento

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 31.1 | Suporte / Criar | `support.create` | UI verde; persistência real e goldens abertos. | `local-green` | B | I | A | C | Avançada | 1 h | Criar/validar/falhar sem sucesso falso, 375–1440. |
| 31.2 | Suporte / Tabela | `support.table` | Backend/goldens e estados finais permanecem. | `local-green` | B | I | A | C | Avançada | 1 h | Lista/empty/error/paginação, 100–200% e visual. |
| 31.3 | Suporte / Kanban | `support.kanban` | Status canônico e goldens precisam fechamento. | `local-green` | B | I | A | C | Avançada | 1.5 h | Colunas/scroll/teclado/estados, 375–1440 e visual. |
| 31.4 | Suporte / Detalhe | `support.detail` | Detalhe e link direto não revalidados. | `audited` | B | I | A | C | Avançada | 1.5 h | Abrir/not-found/unauthorized, 200% e foco. |
| 31.5 | Suporte / Responder | `support.reply` | Envio, duplo envio e erro não comprovados. | `audited` | B | I | A | C | Avançada | 1.5 h | Responder/falhar/retry, teclado e sem duplicação. |
| 31.6 | Suporte / Encerrar | `support.close` | Mapeamento de status e ação negativa abertos. | `audited` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Confirmar/cancelar/falhar, foco e status após reload. |
| 32.1 | Conta / Perfil | `account.profile` | Lifecycle, privacidade A→B e matriz non-golden estão verdes; produção, mídia e goldens permanecem. | `local-green` | B | I | A | C | Avançada | 1.5 h | Integrar perfil/autorização/mídia, executar cross-tenant, remoto e goldens. |
| 32.2 | Conta / Configurações | `account.settings` | Estados e visual não revalidados no worktree atual. | `audited` | B | I | A | C | Avançada | 1.5 h | Configurar/salvar/falhar, teclado, 200% e goldens. |
| 32.3 | Conta / Tema | `account.theme` | Duração normativa e regressão ainda abertas. | `local-green` | B | I | A | C | Avançada | 1 h | Light/dark/sistema, reduced motion e persistência local. |
| 32.4 | Conta / MFA | `account.mfa` | Fluxo sensível sem prova atual. | `audited` | B | I | A | C | Avançada | 1.5 h | Habilitar/desabilitar/negar/falhar e sessão revogada. |
| 32.5 | Conta / Sessões | `account.sessions` | Listar/revogar e estado atual não comprovados. | `audited` | B | I | A | C | Avançada | 1.5 h | Lista/empty/error/revogar/reload sem perder sessão errada. |
| 32.6 | Conta / Sair | `account.logout` | Voltar/deep link após revogação precisa rerun. | `local-green` | B | I | A | C | Avançada | 1 h | Logout, voltar/link direto, sem dado anterior e foco. |
| 33.1 | Catálogo / Lista | `catalog.list` | HEAD e fontes preparadas divergem. | `local-green` | B | I | A | C | Intermediária | 1 h | Host/estado/fallback e relatório correspondente ao snapshot. |
| 33.2 | Catálogo / Validar | `catalog.validate` | Validação fresca explica o único diagnóstico restante: `superadmin.forms-response`, bloqueado por contrato funcional. | `local-green` | B | I | A | C | Intermediária | 2 h | 23 testes do sincronizador, índice e fronteiras verdes; diagnóstico restante identificado sem ser ocultado. |
| 33.3 | Catálogo / Sincronizar | `catalog.sync` | Sincronização mecânica concluída; o relatório permanece `catalogStale` somente por `superadmin.forms-response`. | `blocked-decision` | B | I | A | C | Intermediária após decisão | 2 h + decisão | Advanced Color Picker sincronizado; Forms preservado como bloqueio funcional e diff revisado. |
| 33.4 | Catálogo / Publicar | `catalog.publish` | Contrato produtivo de publicação não aprovado. | `blocked-decision` | B | I | A | C | Intermediária após decisão | 1 h + decisão | Acesso/fallback/CSP aprovados; sem deploy implícito. |
| 34.1 | Planos / Diretório | `plans.list` | Fake/protótipo e estados precisam revisão. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/filtros, 375–1440 e 200%. |
| 34.2 | Criar Plano | `plans.create` | Fluxo local não prova contrato comercial. | `local-green` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar sem fingir ativação. |
| 34.3 | Editar Plano | `plans.edit` | Campos, dirty state e erro precisam rerun. | `local-green` | B | I | A | C | Avançada após decisão | 2 h + decisão | Editar/salvar/falhar/abandonar e 200%. |
| 34.4 | Planos / Ativar | `plans.activate` | Autoridade e efeitos comerciais não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Ativar/cancelar/negar/falhar e reload. |
| 34.5 | Planos / Atribuir | `plans.assign` | Regras de cobrança/contexto não aprovadas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Atribuir/negar/conflito/falhar e contexto correto. |
| 35.1 | Cardápios / Diretório | `meal-plans.list` | Lifecycle e estados não revalidados. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/filtros, 375–1440 e 200%. |
| 35.2 | Criar Cardápio | `meal-plans.create` | Wizard, mídia e erro precisam fechamento. | `local-green` | B | I | A | C | Avançada | 2 h | Criar/validar/falhar, mídia e baseline de formulário. |
| 35.3 | Editar Cardápio | `meal-plans.edit` | Carga, dirty state e mídia ainda parciais. | `local-green` | B | I | A | C | Avançada | 2 h | Editar/salvar/falhar/abandonar e goldens. |
| 35.4 | Cardápios / Criar modelo | `meal-plans.model-create` | Modelo e validação não têm prova final. | `local-green` | B | I | A | C | Avançada | 2 h | Criar modelo/validar/falhar e 200%. |
| 35.5 | Cardápios / Editar modelo | `meal-plans.model-edit` | Edição/conflito e regressão permanecem. | `local-green` | B | I | A | C | Avançada | 2 h | Editar/salvar/conflito/falhar e reload. |
| 35.6 | Cardápios / Publicar | `meal-plans.publish` | Contrato de publicação/mídia não aprovado. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Publicar/cancelar/negar/falhar e estado final. |
| 36.1 | Usuários internos / Lista | `internal-users.list` | Domínio/realm e produção não decididos. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Lista/empty/error/negação somente no realm aprovado. |
| 36.2 | Criar usuário interno | `internal-users.create` | Formulário local não prova Auth privilegiado. | `local-green` | B | I | A | C | Completa após decisão | 2 h + decisão | Criar/convidar/negar/falhar com MFA/capability. |
| 36.3 | Editar usuário interno | `internal-users.edit` | Identidade, papel e erro não fechados. | `local-green` | B | I | A | C | Completa após decisão | 2 h + decisão | Editar/validar/negar/conflito/falhar. |
| 36.4 | Usuários internos / Suspender | `internal-users.suspend` | Revogação de sessão e autoridade não aprovadas. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Suspender/cancelar/negar/falhar e sessões revogadas. |
| 36.5 | Usuários internos / MFA | `internal-users.mfa` | Política/realm e recuperação não decididos. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Exigir/recuperar/negar/falhar no realm correto. |
| 37.1 | Erros / 403 | `errors.403` | Baseline e navegação de saída precisam rerun. | `audited` | B | I | A | C | Intermediária | 1 h | Rota direta, sem dado prévio, teclado e visual aprovado. |
| 37.2 | Erros / 404 | `errors.404` | Link direto e retorno não revalidados. | `audited` | B | I | A | C | Intermediária | 1 h | Rota inexistente, voltar/início, foco e 200%. |
| 37.3 | Erros / 409 | `errors.409` | Conflito e recuperação precisam prova. | `audited` | B | I | A | C | Intermediária | 1 h | Conflito sanitizado, ação segura e sem retry indevido. |
| 37.4 | Erros / 500 | `errors.500` | Sanitização e fallback não revalidados. | `audited` | B | I | A | C | Intermediária | 1 h | Erro genérico sem detalhe técnico, navegação e foco. |
| 37.5 | Erros / 503 | `errors.503` | Indisponível e ação alternativa precisam rerun. | `audited` | B | I | A | C | Intermediária | 1 h | Indisponível, retry quando seguro, 375–1440 e 200%. |
| 37.6 | Erros / Tentar novamente | `errors.retry` | Idempotência e retorno de foco não comprovados. | `audited` | B | I | A | C | Intermediária | 1 h | Retry permitido/bloqueado, foco e uma única repetição. |

### 5.5 Totais, pacotes e leitura das estimativas

| Unidade de planejamento | Estimativa preliminar | Observação |
|---|---:|---|
| Temas gerais compartilhados | 290 h brutas | Não somar integralmente às famílias: shell, UI, responsividade, acessibilidade e regressão são absorvidos por vários pacotes de tela. |
| 37 famílias / 207 ações Flutter | 78–96 h líquidas mais prováveis | Estimativa supersedente por família, com setup e regressão compartilhados; exclui Supabase/E2E e import/export real. |
| Pacote Intermediário sugerido para decisão | 2–6 h | Uma ou poucas ações relacionadas de baixo/médio risco; nunca conclui a tela. |
| Pacote Avançado de uma família complexa | 1–2 dias | Inclui ações relacionadas, arquitetura, estados, acessibilidade, responsividade e regressões. |
| Pacote Completo de uma tela | 2–5 dias | Só pode fechar a tela Flutter se todas as ações aplicáveis e evidências estiverem completas. |

As estimativas por linha representam trabalho incremental dentro do pacote da
família. Somá-las entre famílias é válido como ordem de grandeza; somá-las aos
temas gerais duplicaria trabalho compartilhado. Espera por decisão, backend,
ambiente remoto, aprovação visual e inspeção humana de PNGs não está incluída.

## 6. Ordem obrigatória

1. **Fase 0 — inventário:** Git, apps, rotas produtivas e `/dev`, menus, flags,
   repositories fake, testes e imagens de referência alteradas.
2. **Fase 1 — fundação Flutter:** shell, tema, tokens, componentes canônicos,
   router, tratamento de erros e estados compartilhados.
3. **Fase 2 — identidade:** login, sessão, MFA, troca de contexto, perfil e acesso.
4. **Fase 3 — cadastros estruturais:** Instituições primeiro; depois Unidades,
   Grupos, Pessoas, Perfis de Acesso, Modelos e Convites.
5. **Fase 4 — operação:** Atividades, Avaliações, Alunos, Assiduidade, Rotina e Agenda.
6. **Fase 5 — comunicação:** Chat, Avisos, Formulários, Acontece, Agora e Momentos.
7. **Fase 6 — cuidado:** Segurança infantil, Saúde e Medicação.
8. **Fase 7 — plataforma:** Importações, arquivos, Auditoria, Suporte, Catálogo,
   Planos, Cardápios, Usuários internos e páginas de erro.
9. **Fase 8 — fechamento:** regressão global, acessibilidade, responsividade,
   relatório e atualização dos três rastreadores.

Em revisão exclusivamente visual/Flutter, a ordem aprovada de liberação é:
Instituições; Unidades; Turmas; Atividades; Pessoas; Perfis e Permissões;
Usuários internos; Assiduidade; Rotina diária; Segurança da criança; Perfis de
cuidado; Planos de medicação; Planos; Importações; Conversas; Convites;
Auditoria; Catálogo; e, por fim, verificação rápida das demais superfícies.
Auth e shell continuam gates anteriores a essa sequência. A coluna `Ordem` da
matriz abaixo serve para inventário compartilhado entre os três rastreadores,
não substitui esta sequência de liberação Flutter.

Dentro de cada família, seguir: **listar/visualizar → criar → detalhe → editar →
publicar/ativar → arquivar/excluir/revogar → arquivos → erros/permissão → reload**.

### Conselho operacional atual e próximo passo seguro

A prioridade extrema não é tentar “fechar telas” em massa no worktree atual. O
primeiro pacote deve restabelecer uma base de evidência confiável, porque router,
Auth, componentes, catálogo, testes e goldens têm mudanças concorrentes.

| Prioridade | Recorte aconselhado | Nível | Estimativa | Resultado esperado | O que continua pendente |
|---:|---|---|---:|---|---|
| P0 | Fase 0 + `catalog.validate` + `catalog.sync` + gates Flutter/UI do snapshot | Intermediária | 4–6 h | Reproduzir o estado atual, classificar os fingerprints, validar composição prod/DEV e corrigir apenas regressões mecânicas comprovadas do catálogo/gates, com testes. | `superadmin.forms-response` depende de decisão funcional; nenhuma tela concluída; Auth, shell, Instituições, responsividade global, goldens e backend continuam abertos. |
| P0.5 | Recuperação de compilação do snapshot: Forms, Acompanhamento, testes de acesso e fronteira com Unidades | Intermediária de integração | 2–4 h de reconciliação; correções funcionais são reestimadas depois | Localizar os lotes/commits correspondentes, recompor versões coerentes e rerodar analyzer sem criar shims ou esconder fail-closed. | Forms integrado, Acompanhamento, Unidades e backend continuam separados até contratos e ownership próprios. |
| P1 | Auth + shell (`auth.*`, `shell.*`) | Avançada | 1–2 dias | Corrigir navegação/sessão/erros compartilhados com matriz responsiva, teclado, foco e regressão. | Supabase/Auth remoto e demais telas continuam abertos. |
| P2 | Instituições: listar, filtrar, status, erro e reload | Avançada | 1 dia | Revalidar a baseline de diretórios, Cards/tabela, filtros, estados e evidências exatas. | Criar/Editar Instituição e backend continuam abertos. |
| P3 | Criar/Editar Instituição | Avançada | 1 dia | Revalidar a baseline administrativa de wizard/formulários, mídia, rodapé e estados. | Só Completa pode encerrar a tela; integração Supabase continua separada. |

**Conselho final atual:** começar por **P0 Intermediária, com teto de 6 horas**.
É o menor pacote que reduz incerteza sem omitir testes, acessibilidade,
responsividade ou evidência. Se P0 revelar regressão estrutural em Auth/shell,
parar no checkpoint e reestimar P1; se os gates ficarem confiáveis, seguir para
Instituições em pacote Avançado. Não aconselhar uma Básica neste snapshot.

**Critério de parada de P0:** inventário do snapshot reproduzível; fingerprints
classificados; primeira falha real corrigida somente se mecânica e dentro do
recorte; análise/testes/validadores proporcionais executados; rastreador
atualizado; nenhum golden promovido automaticamente; nenhum Supabase alterado.

**Checkpoint de P0:** registrar tempo gasto/restante, comando e resultado em
linguagem comum, arquivos tocados, regressões encontradas, ações corrigidas,
ações ainda abertas, dependências integradas, bloqueio e próxima ação segura.

## 7. Snapshot retomável em 2026-08-26

- Base observada: `447ac02c6c75617a8233f141dd0b2c8dc6c228d1`.
- Este arquivo está não rastreado (`??`) no worktree; preservar até integração
  documental deliberada.
- A revisão desta atualização foi exclusivamente documental. Nenhum analyzer,
  teste Flutter, golden, PNG, E2E, banco ou Supabase foi executado agora.
- A última cadeia registrada chegou a analyzer global sem erros/avisos/infos e
  validadores visuais sem diagnóstico antes dos commits finais. Isso não
  substitui uma execução fresca no worktree integrado atual.
- Há 19 commits integrados entre `9e3c9622` e o HEAD atual.
- O relatório **do HEAD** está `catalogStale` com 8 fingerprints:
  `superadmin.avatar-crop-dialog`, `superadmin.advanced-color-picker`,
  `superadmin.cover-crop-dialog`, `admin.dialog-shell`,
  `admin.interactive-card`, `admin.kanban-board`, `superadmin.forms-editor` e
  `superadmin.forms-response`. O worktree contém fontes/relatório preparados que
  reduziriam a contagem a 2, mas eles não estão commitados e não substituem o
  estado de HEAD. Os 2 restantes desse preparo são Advanced Color Picker e as
  duas superfícies Forms cuja decisão funcional continua aberta.
- Resíduo visual atual: 199 PNGs rastreados alterados fora de `failures/`
  (173 `M`, 26 `D`), 72 PNGs rastreados alterados dentro de `failures/`, 93 PNGs
  não rastreados e 1.564 arquivos existentes sob diretórios `failures/`.
  Nenhum deles foi aprovado, restaurado, apagado ou promovido nesta atualização.

### Inventário documental desta atividade

- Orçamento indicado pelo usuário: preferência teórica por **Intermediária**;
  duração total ainda aberta e dependente do inventário.
- HEAD continua em `447ac02c6c75617a8233f141dd0b2c8dc6c228d1`, mas o worktree possui
  centenas de mudanças concorrentes em código, testes, goldens, fontes, specs e
  decisões. Os dois rastreadores consultados continuam não rastreados (`??`).
- Existem alterações atuais em Auth, shell/router, Instituições, Unidades,
  Atividades, Agenda, Chat, Formulários, Saúde, Pessoas, Suporte, pacotes UI,
  testes e goldens. Elas foram somente inventariadas; esta atividade não assume
  autoria, não restaura, não apaga e não certifica nenhuma delas.
- A busca leve de componentes crus encontrou ocorrências em Login,
  Instituições e Suporte. Elas são **candidatas a auditoria**, não defeitos
  declarados: é obrigatório conferir implementação, componente canônico,
  allowlist e evidência antes de corrigir.
- Nenhum analyzer, teste Flutter, golden, validador de catálogo, execução visual
  ou backend foi executado nesta organização documental. Evidências históricas
  foram preservadas, mas precisam ser reexecutadas no snapshot que vier a ser
  contratado.

### Checkpoint operacional P0 — retomada segura

- Pacote e nível: **P0 Intermediária concluída no recorte contratado**, teto de
  6 horas; aproximadamente 1 h 20 min consumidos e cerca de 4 h 40 min ainda
  disponíveis para diagnóstico e contratação do próximo pacote.
- Posição exata: gates e validação estrutural concluídos; iniciar triagem
  somente leitura dos 100 erros globais para definir o próximo pacote por
  tela/ação, sem misturar correções externas ao catálogo.
- Correção desta atividade: o `example` do seletor avançado de cores foi
  alinhado ao uso já existente de `CoeloAdminDialogShell`, fechamento acessível,
  ações Cancelar/Usar cor e controle por teclado. Nenhum comportamento de tela
  foi alterado por esta atividade.
- Evidências frescas: índice válido com zero diagnóstico; fronteiras válidas
  com zero diagnóstico; contrato visual válido com zero diagnóstico; 23 testes
  do sincronizador executados e aprovados; 6 testes do contrato visual
  executados e aprovados; 2 testes do seletor executados e aprovados; análise
  estática dos arquivos do seletor e Forms sem problemas.
- Resultado do sync: caiu de 2 para 1 diagnóstico. O único restante é
  `superadmin.forms-response`, preservado como `blocked-decision`; não alterar o
  exemplo ou relatório apenas para obter estado verde.
- Gate global inicial: o analyzer completo do Superadmin encontrou 174
  diagnósticos — 100 erros, 29 avisos e 45 infos. Após reconciliar
  Acompanhamento, o gate caiu para 91 diagnósticos — 38 erros, 8 avisos e 45
  infos. Os 38 erros restantes são Forms (34), Perfis de acesso (3) e Unidades
  (1); o app ainda não pode ser declarado verde.
- Causa raiz dos 100 erros: 62 pertencem a Acompanhamento, cujas camadas
  data/tela/testes não rastreadas usam contrato diferente do domínio rastreado;
  34 pertencem a Forms, cujas rotas/camadas não rastreadas e teste rastreado
  esperam a API integrada enquanto a página rastreada permanece fail-closed; 3
  pertencem a testes de Perfis de acesso não rastreados com shims reprovados; 1
  pertence a Unidades e está sob alinhamento com a revisão integrada.
- Contratos incompatíveis mapeados: Forms espera `api`, `occurrenceId`, storage
  do segredo anônimo e request ID; Acompanhamento espera cinco drafts, cinco
  comandos de escrita, `canManage`, definições de instrumento/competência/
  desenvolvimento e storage de arquivos que não pertencem ao domínio atual;
  testes de acesso pedem `accessProfileExtendedRepository`/`contextCount`,
  explicitamente reprovados pelo gate fail-closed canônico.
- Dependência de Unidades: o adapter
  `supabase_unit_backend_commands_gateway.dart` já cobre import/export, porém o
  production auth scope injeta explicitamente gateways indisponíveis. Não
  inventar API nem editar a composição até o handoff Supabase.
- Evidência final do P0: 137 testes do Catálogo, 107 testes de
  `coelo_ui_admin` e 8 testes focados do Superadmin foram executados; todos os
  252 passaram. Essas contagens incluem os testes já executados isoladamente e
  não devem ser somadas novamente. Analyzers de Catálogo, `coelo_ui_admin` e
  arquivos focados do Superadmin passaram. O analyzer global não passou pelos
  174 diagnósticos acima.
- Arquivos alterados por esta atividade até aqui:
  `apps/catalog/assets/coelo-ui.index.jsonl`,
  `apps/catalog/assets/catalog-sync-report.json` e este rastreador. Os dois
  assets já continham mudanças concorrentes; preservar o diff completo e não
  assumir autoria externa.
- Integridade do rastreador: 201 ações, 201 `action_id` únicos, zero duplicação
  e zero linha malformada na tabela por tela/ação. `git diff --check` passou.
- Próximo passo seguro: P0.5, localizar a origem dos lotes incompletos e
  reconciliar versões coerentes antes de alterar superfícies. Não criar shims
  `accessProfileExtendedRepository`, `contextCount` ou equivalentes; não tocar
  Unidades antes do alinhamento integrado; não executar goldens com
  `--update-goldens`.
- Supabase, banco, remoto, stage, commit e deploy: não executados e fora do
  recorte.

### Checkpoint P1 — Auth e shell isolados

- Ações revalidadas: `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`,
  `shell.load`, `shell.navigate` e `shell.unauthorized`.
- Auth: 99 testes de domínio, view models, widgets, telas e matriz responsiva
  foram executados e todos passaram; analyzer da feature e testes sem problema.
- Shell visual: 87 testes foram executados e todos passaram; analyzer de
  `lib/app/shell` e `test/app/shell` sem problema. Há cobertura de item
  selecionado, hierarquia, flyout, hover, claro/escuro, larguras responsivas,
  texto ampliado, teclado, reduced motion, logout e feedback de falha.
- Limite da evidência: router/deep links globais não foram promovidos porque o
  snapshot ainda possui 38 erros externos; `shell.switch-context`,
  `shell.reload` e `auth.mfa` continuam abertos. Nenhuma tela foi declarada
  concluída e nenhuma integração Auth/Supabase foi certificada.
- Próximo passo seguro: recuperar um snapshot coerente no P0.5, rerodar o
  analyzer global e só então executar router/deep links de Auth/shell. Se a
  origem não estiver disponível, preservar este checkpoint sem criar shims.

### Checkpoint P0.5 — grupo Acompanhamento

- Origem canônica: `f525a7f4` (`fix(student-tracking): keep production
  read-only`) é ancestral do HEAD; a árvore rastreada atual da família é
  idêntica a esse commit.
- Origens de gerenciamento `69eb6526`/`1e7a5168`, baselines
  `da2e1538`/`f9399723` e branch `codex/student-tracking-readonly` não são
  ancestrais do HEAD. Não restaurar drafts/comandos de escrita no domínio.
- Resíduo recuperado: 24 arquivos, 451.151 bytes, manifesto determinístico
  SHA-256 `5417fc9b1ce2d84f5f182ade9c4f3a16d640a83e19399558b68bb79ecbd8cd3a`.
  Eles incluem adapter Supabase, página de gerenciamento, testes e goldens;
  foram movidos individualmente para
  `C:\Users\adrie\Documents\Coelo-recovery-20260825-final\student-tracking-legacy-20260826-flutter-recovery`
  sem perda ou alteração de manifesto.
- GREEN canônico: 22 testes rastreados foram executados e todos passaram; a
  análise dos seis arquivos rastreados não encontrou problemas. Há cobertura
  375/768/1024/1440, texto a 200%, teclado, reduced motion, acesso negado,
  offline, unavailable, retry e ausência de ações de gerenciamento.
- Validação posterior: origem com zero arquivo legado, destino com 24 arquivos,
  451.151 bytes e mesmo manifesto; analyzer global caiu de 100 para 38 erros,
  com zero erro de Acompanhamento; 22 testes canônicos passaram novamente.
- Próximo passo seguro: grupo Forms, somente inventário/recuperação de origem
  dos 34 erros antes de alterar código.

### Checkpoint P0.5 — Forms, subgrupo `forms.respond`

- Posição atual: primeiro subgrupo de Forms encerrado; `forms.edit` é o próximo
  grupo permitido. Não avançar para outras ações de Forms antes de novo
  inventário/contrato nominal.
- Causa reproduzida: um lote concorrente substituía o teste fail-closed por um
  contrato integrado ainda não adotado e adicionava uma rota incompatível. Isso
  produzia 32 dos 34 erros de Forms no analyzer global.
- Preservação: os sete arquivos do delta (1 tracked copiado e 6 untracked
  movidos individualmente) estão em
  `C:\Users\adrie\Documents\Coelo-recovery-20260825-final\forms-response-delta-20260826-flutter-recovery`.
  O destino contém 7 arquivos, 40.944 bytes e manifesto determinístico SHA-256
  `bc578089790f4867ce83b3a26e2da05a57c451d6341cdc1eac6ff87ac227af66`.
- Correção executada: somente
  `test/features/forms/presentation/response/form_response_page_test.dart` foi
  restaurado ao blob canônico do HEAD
  `7006d84b0313cd53609edbbdbc8bc8667da92415`; os seis untracked preservados não
  permanecem na árvore ativa. Nenhum outro path de Forms foi alterado.
- GREEN local: 1 teste canônico fail-closed foi executado e passou. O analyzer
  global caiu de 38 para 6 erros e de 34 para 2 erros em Forms; há zero erro em
  `forms.respond`. Os 6 erros restantes são 2 de `forms.edit`, 3 de Perfis de
  acesso e 1 de Unidades. O analyzer global ainda não está verde: reportou 54
  issues ao incluir warnings e infos.
- Catálogo: validação feita com relatório temporário externo retornou exatamente
  1 diagnóstico, `superadmin.forms-response`. O índice e o report rastreados não
  foram atualizados; nenhum golden foi executado ou regenerado.
- Estado correto: `forms.respond` é `local-green` apenas para o fail-closed. A
  ação e a tela não estão concluídas; resposta real e integração Flutter–Supabase
  continuam pendentes.
- Próximo passo seguro: inventariar separadamente os 2 erros de `forms.edit`,
  identificar a origem do editor concorrente e apresentar contrato/ETA antes de
  preservar ou restaurar qualquer arquivo. ETA inicial do subgrupo: 45–75 min.

### Checkpoint P0.5 — Forms, subgrupo `forms.edit`

- Posição atual: erros de compilação de Forms encerrados. O próximo grupo global
  é Perfis de acesso (3 erros); Unidades permanece congelada por dependência
  integrada e não deve ser composta nesta etapa.
- Causa reproduzida: o Editor integrado já estava coerente com o catálogo, mas o
  teste agregado de superfícies dormant ainda o instanciava pelo construtor
  fail-closed antigo. Os 2 erros restantes de Forms vinham exclusivamente dessa
  referência obsoleta.
- Correção mínima: removidos apenas o import do Editor e a entrada `editor` do
  loop fail-closed em
  `test/features/forms/presentation/forms_dormant_surfaces_test.dart`. As
  superfícies `response` e `test` continuam fail-closed. Página, rota, API,
  catálogo, report e goldens não foram alterados neste subgrupo.
- GREEN local: 24 testes non-golden foram executados e todos os 24 passaram: 2
  de autosave/retry, 17 do componente Editor, 1 arquivo de rota e 4 cenários
  dormant. A matriz inclui 375 px e comandos acessíveis; não houve prova nova de
  texto a 150%/200% nem inspeção visual de golden.
- Analyzer global: caiu de 6 para 4 erros e de 2 para zero erro em Forms. Restam
  3 erros de Perfis de acesso e 1 de Unidades. O resultado global ainda não é
  verde: são 52 issues ao contar warnings e infos.
- Catálogo: sync com report temporário externo retornou exatamente 1 diagnóstico,
  `superadmin.forms-response`. Nenhum índice/report do repositório ou golden foi
  atualizado.
- Limite: `forms.edit` é `local-green` somente como componente local/catalogado.
  `forms.create` e `forms.publish` não foram promovidos; rota produtiva,
  capability, persistência/autorizações reais e integração Flutter–Supabase
  continuam bloqueadas. Nenhuma tela foi declarada concluída.
- Manifesto preventivo não movido: 26 arquivos do lote integrado foram
  inventariados (331.564 bytes, SHA-256
  `bd1995b27ce7051020531c793a49c3d23a160522229fa53ad35f979e5d8155ae`),
  mas permaneceram no workspace por decisão nominal de adoção local.
- Próximo passo seguro: inventariar os 3 erros de Perfis de acesso, separar
  testes/wiring do contrato de repository e apresentar causa/ETA antes de
  corrigir. ETA inicial: 45–75 min.

### Checkpoint P0.5 — inventário Perfis/Modelos de acesso

- Posição atual: opção A fail-closed executada após o checkpoint backend; Access
  tem zero erro no analyzer. Unidades é o único erro global restante e continua
  congelada até sinal integrado.
- Erros mapeados: dois testes router untracked tentam injetar
  `accessProfileExtendedRepository` em uma composition root que deliberadamente
  não aceita esse parâmetro e serve 503 nas rotas de modelos. O terceiro erro
  vem do fake untracked que ainda fornece `PrincipalCapability.contextCount`,
  removido do domínio atual; `isDemo` obsoleto também gera warnings em fakes.
- Mapa de ações: wiring de lista → `access-models.list`; deep links →
  `access-models.detail` e `access-models.duplicate`; fake compartilhado →
  `access-profiles.list`, `access-profiles.detail`, `access-profiles.create` e
  `access-profiles.edit`.
- Lacuna corrigida no rastreador: `access-models.filter` foi adicionada como
  ação independente porque a página possui busca, troca de domínio, estado sem
  resultados e reload. `deleteModel` aparece somente no contrato de repository,
  sem ação de UI comprovada; por isso não virou `action_id` de tela e permanece
  apenas como dependência futura bloqueada.
- Preservação executada: os três arquivos foram copiados para
  `C:\Users\adrie\Documents\Coelo-recovery-20260825-final\access-profiles-delta-20260826-flutter-recovery`
  e validados antes de mover somente os dois testes router incompatíveis. O fake
  compartilhado permaneceu ativo. O destino contém 3 arquivos, 12.539 bytes,
  SHA-256 `fe61476c955fe7701abbb9f3583cea1eb8b1c6c7512d56eda5825410e84a95ae`.
- Correção mínima no fake untracked: removidos somente `isDemo` e
  `PrincipalCapability.contextCount`, ambos ausentes do contrato atual. O fake
  tracked com warning não foi alterado por falta de grant nominal.
- Evidência: 9 testes Access independentes passaram, incluindo UI a 200% e
  768 px. Dois arquivos de teste router não chegaram a executar porque a
  composição global ainda falha no erro de Unidades; isso não é falha de
  comportamento Access. O analyzer caiu de 4 para 1 erro e reportou zero erro
  Access, mas 48 issues totais e um warning Access ainda permanecem.
- Catálogo: sync temporário externo retornou somente
  `superadmin.forms-response`; índice, report e goldens não foram atualizados.
- Limite: nenhum `access-profiles.*` ou `access-models.*` foi declarado integrado
  ou concluído. Create/edit/assign/delete/model CRUD permanecem bloqueados;
  composition root segue 503.
- Próximo passo seguro: aguardar o sinal do integrador para Unidades. Depois de
  remover o erro externo, rerodar os dois testes router fail-closed e o analyzer
  global antes de qualquer nova promoção Access.

### Checkpoint P0.5 — `units.list` e estados do diretório

- Posição atual: o último erro de compilação global foi removido com um patch de
  uma linha no caller de `UnitDirectoryStates`. Nenhuma composição import/export
  está autorizada; pausar aqui antes de qualquer fatia vertical integrada.
- Causa/patch: o delta vivo de `unit_directory_states.dart` tornou
  `createAction` obrigatório para failure/empty/noResults, mas o caller canônico
  não o fornecia. Foi adicionado somente
  `createAction: UnitCreateBanner(onPressed: onCreate),` em
  `unit_directory_page.dart`; nenhum outro hunk de código Units mudou.
- Evidência Units: 16 testes non-golden foram executados e todos passaram. Eles
  cobrem states, Cards/tabela, status, 375/768/1024/1440, texto a 200%, toque e
  estados recuperáveis/unauthorized. O teste existente de diálogo import também
  passou incidentalmente, mas isso não certifica import/export ou backend.
- Evidência Access desbloqueada: os 2 arquivos router antes bloqueados por Units
  executaram 5 testes e todos passaram, confirmando 503 fail-closed em
  375/1440 e texto a 200%.
- Analyzer global: zero erros; ainda existem 47 issues (2 warnings e 45 infos),
  portanto o analyzer não é integralmente verde. Catálogo externo manteve
  exatamente `superadmin.forms-response`; nenhum report/índice/golden mudou.
- Ações separadas: `units.filter`, `units.error`, `units.reload` e
  `units.access-denied` foram adicionadas à matriz com estado máximo
  `local-green`, limitado à UI local. `units.create` não foi promovido.
- Dependência integrada: backend local Units reportado 180/180 verde, mas
  produção continua injetando gateways `Unavailable`; `units.import` e
  `units.export` permanecem `blocked-supabase`.
- Próximo passo seguro: enviar checkpoint ao integrador e aguardar contrato
  nominal antes de qualquer composição import/export. Fora desse handoff, o
  próximo pacote Flutter seguro é reduzir warnings/infos por grupo, sem misturar
  backend; ETA inicial 1–2 h para um grupo pequeno.

### Checkpoint seguro — `units.access-denied`

- Posição atual: o pacote independente corrigiu apenas a composição final de
  acesso negado em `unit_directory_page.dart` e adicionou
  `unit_directory_access_denied_test.dart`. O hunk anterior
  `createAction: UnitCreateBanner(onPressed: onCreate),` foi preservado.
- Correção comprovada: quando o ViewModel termina em `unauthorized`, a árvore
  mantém o painel canônico de negação e omite toolbar, busca/filtros, tabs,
  alternância de visualização, `UnitFileActions`, import/export, criar,
  Cards/tabela e paginação. O source atual **não** oculta esses controles em
  `initial/loading`; não registrar essa proteção como executada.
- Evidência TDD: o RED causal encontrou `UnitDirectoryToolbar` no estado final
  negado. Após o patch, o handoff final registrou 23 testes non-golden e todos
  os 23 passaram; uma suíte ampliada desta frente executou 25 testes e todos os
  25 passaram. Isso inclui acesso negado, states, página e rotas prod/DEV
  fail-closed, mas não constitui E2E.
- Evidência de qualidade: analyzer focado dos dois paths sem issues; analyzer
  global com 0 erros, 0 warnings e 45 infos preexistentes; format 2/2 sem
  mudança e diff-check verde. Validador visual admin terminou com exit 0. O
  catálogo em report externo ficou `synchronized` com zero diagnóstico no
  snapshot corrente; essa mudança concorrente não é atribuída ao patch de
  Unidades. Nenhum golden foi executado ou atualizado.
- Manifesto final: `unit_directory_page.dart`, 16.120 bytes, SHA-256
  `8d51cdda14835d4b0eff14f739470e139ffc85af89a83e0ad54913b28777294e`,
  OID `c5cc5a2e1a14fceccd890498d9108adb925995fd`;
  `unit_directory_access_denied_test.dart`, 4.276 bytes, SHA-256
  `02863c77062affbe2bb43bc1301c2a2d6e3507f74353da307cdb59f43a9f1210`,
  OID `19a0d37f85129ecff5dac813f2ab3d372c6bfec0`.
- Estado correto: atividade corretiva local concluída; ação Flutter permanece
  somente `local-green`; tela de Unidades não concluída; Supabase continua
  `audited/fail-closed`; integração permanece `blocked-supabase`; zero E2E.
- Pendências e bloqueios: o ViewModel ainda conserva página/filtros anteriores
  em memória após a negação, embora a UI final não os renderize. Ausência de
  controles antes da primeira resposta, success→revogação, sessão/vínculo
  revogado, tenant A/B, link direto para criar/editar, foco/teclado e prova
  backend/RLS exigem pacote e contrato próprios. Não inferir capacidade pelo
  estado de loading nem ocultar toolbar durante refresh autorizado, pois isso
  faria busca/filtros perderem geometria e foco.
- Dependência integrada adicional: o handoff remoto informou RED 42702/42703 em
  `institutions.import`/`institutions.export`. Este rastreador mantém essas ações
  somente `audited`, sem `local-green` ou E2E; a falha remota não foi revisada ou
  certificada nesta atividade Flutter.
- Próximo passo seguro: congelar os dois paths e este checkpoint para a
  consolidação documental. Um futuro pacote Avançado de 2–4 h deve começar por
  contrato explícito de capability/revogação e testes delayed-load,
  success→revogação, cache/foco e deep link; backend/tenant/E2E permanecem
  separados.

### Checkpoint seguro — `units.export` HARDEN-EXPORT A+B

- Posição atual: o pacote Flutter local de hardening A+B foi executado somente
  em `unit_backend_commands.dart`,
  `supabase_unit_backend_commands_gateway.dart`, `unit_file_actions.dart` e nos
  testes diretos do gateway/widget. A produção continua injetando
  `UnavailableUnitBackendCommandsGateway`; nenhum auth scope, composition root,
  backend, migration, Edge Function, remoto ou golden foi alterado.
- Contrato A: `request_export` envia o snapshot canônico e recebe apenas o job;
  somente um job `SUCESSO` permite chamar `download` com o mesmo `job_id`. O
  parser rejeita DTO privado/malformado, divergência de job/domínio/direção/
  formato, colunas fora da allowlist, URL precoce, TTL inválido e URL que não
  seja HTTPS da origem/porta Supabase e do path privado canônico. Importação usa
  parser separado e permaneceu funcionalmente intacta.
- Contrato B: a ação é single-flight; retry incerto preserva a mesma chave de
  idempotência e o mesmo snapshot, enquanto mudança de payload ou falha não
  repetível inicia nova tentativa. O opener é injetável e chamado no máximo uma
  vez por execução; popup bloqueado reaproveita o artefato validado sem gerar
  outro export. `expiresAt` é revalidado antes da abertura. Busy usa semântica
  live/disabled, bloqueio de foco, teclado e ponteiro, com guarda interna como
  autoridade. O texto não promete revogação física imediata da URL/cache.
- Evidência: os dois arquivos diretos de gateway e widget executaram 41 testes e
  todos os 41 passaram, incluindo regressões de importação, duas chamadas
  ordenadas, correlação do job, URL/TTL, duplo clique, retry/idempotência,
  opener bloqueado, erros tipados, descarte após `dispose` e 375 px com texto a
  200%. O analyzer global encontrou 0 erros, 0 warnings e 45 infos preexistentes;
  portanto não é integralmente verde. Cinco arquivos estavam formatados e o
  diff-check passou. O catálogo foi validado em report externo e manteve somente
  `superadmin.forms-response`; índice/report rastreados não mudaram. Nenhum
  golden foi executado ou atualizado.
- Estado correto: `units.export` está no máximo `audited/local-hardening` no
  Flutter e continua `blocked-supabase`/`blocked-decision`, com zero prova E2E.
  A atividade contratada A+B pode fechar sem declarar a ação ou a tela
  concluída. Signed URL expirada localmente significa apenas “não abrir este
  link”; não comprova indisponibilidade física imediata no CDN.
- Decisões/dependências: OQ-032 e OQ-034 permanecem abertas. A implementação
  atual exige vínculo platform/global para pedir export, mas materializa por
  `units.read` institucional; não promover Operations. Até decisão canônica,
  Owner global + AAL2 é apenas baseline transitório conservador. Filtros do
  cliente nunca definem alcance; um fluxo futuro precisa persistir escopo
  autoritativo derivado do vínculo e reautorizar `units.export` em request,
  materialize, complete, sign e remint. TTL/cache-control/cleanup por objeto são
  responsabilidades backend/remoto fora deste recorte.
- Lacuna separada registrada como `units.people-export`: o botão e o SnackBar
  de falso sucesso foram removidos. A ação produtiva permanece ausente e
  `blocked-decision`, sem confundir com `units.export` nem `people.export`.
  Implementação funcional exige pacote próprio Completa, 18–32 h, começando
  por decisão de capability/AAL2/escopo unitário/colunas minimizadas.
- Próximo passo seguro: preservar estes cinco paths e o rastreador até o handoff
  nominal; não compor produção. Depois, decidir OQ-032/OQ-034 e alinhar o backend
  remoto antes de qualquer fatia de composição/E2E. Se o trabalho continuar só
  no Flutter, executar um pacote separado para as lacunas não bloqueantes de
  teste (sucesso seguido de nova chave e rebuild alterando filtros/view), ETA
  1–2 h, sem tocar em `units.people-export`.

### Checkpoint seguro — `units.export` snapshot após rebuild

- **Action_id:** somente `units.export`; nenhuma migration, Edge Function,
  configuração, dado ou recurso remoto foi alterado.
- **RED reproduzido:** durante `generateExport`, um rebuild com nova
  `UnitDirectoryQuery` fazia a UI abrir a signed URL do snapshot anterior.
- **Causa raiz:** a assinatura era capturada antes do `await`, mas não era
  revalidada antes de abrir o artefato.
- **Correção mínima:** após a resposta, a UI recompõe a assinatura; em caso de
  divergência limpa o download pendente, não abre URL e informa que filtros ou
  visão mudaram, exigindo nova geração.
- **GREEN focado:** `unit_file_actions_test.dart` passou 21/21, incluindo 375 px
  com texto a 200%; o conjunto gateway + widget passa agora 42 testes diretos.
- **Estado:** a correção Flutter desta unidade está `local-green`, mas a ação
  integrada continua `blocked-supabase`, com produção `Unavailable` e zero E2E.
- **Próximo gate:** revisar o request/status/download do gateway sem compor
  produção; preservar os 11 REDs Supabase já catalogados.

### Checkpoint seguro — `units.export` request/status/download

- **Action_id:** somente `units.export`; nenhuma alteração Supabase ou remota.
- **RED reproduzido:** o teste do contrato canônico exigiu três chamadas e
  recebeu somente duas; o gateway pulava `status` e ia de `request_export`
  diretamente para `download`.
- **Causa raiz:** `generateExport` não consumia a ação `status` já prevista e
  testada pelo hub local.
- **Correção mínima:** `status` é chamado com o `job_id` retornado, sua resposta
  não pode conter artefato, precisa manter ID/domínio/direção/formato e chegar a
  `SUCESSO`; somente então o mesmo ID segue para `download`.
- **Provas:** gateway 24/24, incluindo job divergente, artefato prematuro e
  estado não pronto; widget 21/21; analyzer focado em quatro arquivos sem
  issues. Total direto do recorte Flutter: 45/45.
- **Estado:** gate Flutter `local-green`; `units.export` integrado continua
  `blocked-supabase`, produção `Unavailable`, sem remoto mutável e sem E2E.
- **Próximo gate:** provar replay após sucesso sem rematerialização no backend
  local, mantendo a composição produtiva fechada.

### Checkpoint seguro — `units.export` fronteira pós-conclusão

- **Action_id:** somente `units.export`; nenhuma alteração Flutter adicional,
  migration, deploy ou mutação remota.
- **RED:** resposta de conclusão perdida e falha de signed URL provocavam
  deleção do artefato possivelmente canônico e tentativa de marcar erro.
- **Correção:** o worker registra a fronteira antes de chamar a conclusão; após
  esse ponto, falhas retornam de modo seguro sem cleanup otimista nem demotion.
- **Provas:** os dois cenários passaram; arquivo pós-sucesso ficou 3/4, matriz
  Deno 36/44 e regressão Flutter 45/45.
- **Estado:** dois gates locais GREEN; ação Flutter permanece `local-green`,
  integrada `blocked-supabase`, produção `Unavailable`, zero E2E.
- **Próximo gate:** reautorização depois da conclusão e antes da assinatura.

### Checkpoint seguro — `units.export` reautorização pós-conclusão

- **Action_id:** somente `units.export`; nenhuma alteração Flutter, migration,
  deploy ou mutação remota.
- **RED:** ator revogado depois do commit ainda alcançava a mintagem da URL.
- **Correção:** `reauthorizeExportJob` é executada novamente depois da resposta
  de conclusão e imediatamente antes de `createSignedUrl`.
- **Provas:** pós-sucesso 4/4, matriz Deno 37/44, `deno check` GREEN e Flutter
  45/45 preservado.
- **Estado:** gate local GREEN; ação Supabase `audited`, integrada
  `blocked-supabase`, produção `Unavailable`, zero remoto/E2E.
- **Próximo gate:** impedir chamada direta do worker com JWT do navegador.

### Checkpoint seguro — `units.export` delegação exclusiva ao worker

- **Action_id:** somente `units.export`; Flutter não foi recomposto em produção.
- **RED:** JWT do navegador chamava `unit-export` diretamente, alcançava RPC e
  podia receber campos privados fora do sanitizador do hub.
- **Correção:** hub e worker compartilham somente em runtime o segredo dedicado
  `COELO_UNIT_EXPORT_WORKER_SECRET`; o worker exige o header interno antes de
  ler a sessão ou chamar RPC. Não foi usado `service_role` como credencial de
  delegação.
- **Provas:** chamada direta 403/zero RPC; hub verifica o header; pós-sucesso
  4/4; suíte unit-export 41/47 e Flutter 45/45.
- **Estado:** sétimo gate local GREEN e pacote principal 7/7; ação continua
  `blocked-supabase`, pois segredo/deploy remoto, grants, retenção, cleanup,
  composição e E2E seguem abertos.
- **Encerramento medido:** recorte 100,00% (7/7), restante 0,00% (0/7);
  backlog integrado 0,00% (0/207), restante 100,00% (207/207). Foram medidos
  28 min entre o marcador retomável 16:44 e 17:12 BRT; o inventário anterior ao
  marcador não é reconstruível com precisão e não foi inventado.

### Dependências integradas identificadas e fora de escopo

A consulta leve ao rastreador Flutter–Supabase registra a estrutura atual de
**202 ações normativas + 5 ações de shell = 207 IDs totais**. No último
checkpoint integrado recebido, 40 estavam `not-reviewed`, 111
`blocked-supabase` e 51 `blocked-decision`; nenhuma estava `verified-e2e`.
Esses números significam que não há ação com prova atual completa do clique no
Flutter até persistência/autorização no backend. Nesta atividade Flutter:

- Auth, MFA, sessão e usuários internos dependem de Auth/capabilities reais;
- criar, editar, publicar, arquivar, revogar e excluir dependem de comandos
  autorizados e não podem ser simulados pela UI;
- arquivos e mídia do MVP dependem de gateways privados do Supabase Storage;
  R2 está fora do MVP;
- ações com dados infantis, saúde, medicação e auditoria dependem de decisões
  jurídicas, retenção e autorização;
- nenhuma migration, policy, RPC, Edge Function, bucket, deploy ou dado remoto
  será revisado, alterado ou certificado neste recorte Flutter.

### Evidência recente já integrada

As contagens abaixo registram gates executados nas respectivas cessões. Elas não
foram reexecutadas nesta consolidação e não provam ações não cobertas pelo teste.

| Commit | Fechamento Flutter comprovado no lote | Limite ainda aberto |
|---|---|---|
| `447ac02c` | Catálogo Fase 1A integrado; relatório HEAD materializado com 8 fingerprints. | Fontes posteriores preparadas não estão commitadas; Forms editor/response e publicação/API continuam abertas. |
| `bd476af8` | Suporte compacto: 54/54 testes; paginação 15/15; 375/768/1024/1440 e texto 150%/200% no lote. | Detalhe, responder, encerrar e goldens não foram fechados. |
| `c04e49fb` | Assiduidade em 375 px: matriz 9/9, suíte da família 47/47 e DEV 4/4 no handoff; texto 200% coberto no lote. | Dois goldens do dashboard, E2E e exportação permanecem separados. |
| `9119e03b` | Agora/Momentos: rota 6/6 e regressões non-golden 73/73; `Esc` fecha e devolve foco no cenário coberto. | Publicar/remover/expirar reais e E2E continuam abertos. |
| `b2ff69bf` | Central de Ajuda usa flyout canônico; 12/12; viewport, teclado, `Esc` e foco no lote. | Goldens não foram executados. |
| `90982592` | Segurança infantil: correções mecânicas e suíte focada 23/23. | Suspensão/revogação real e matriz visual integral não comprovadas. |
| `ec31171c` | Atividades: 90/90 non-golden; adapters gate-only 21/21; fluxo DEV e fail-closed produtivo. | Produção permanece indisponível e sem E2E. |
| `aa414efa` | Convites: 56/56 non-golden no fechamento consolidado; produção indisponível e DEV isolado. | Email/Supabase, goldens e lifecycle real permanecem abertos. |
| `9e3c9622` | Access Basic estático/fail-closed: 35/35 no runtime e 15/15 no recorte de páginas. | Access Extended, Imports prerequisite, CRUD e goldens continuam bloqueados. |
| `6bdbbdac` | Forms composition fail-closed; rotas indisponíveis sem sucesso aparente. | Editor/respostas reais, arquivos F6 e backend continuam abertos. |
| `672ad118` | Grupos: 30/30 feature, 39/39 feature+roots e 33/33 regressões por fatias; DEV isolado e produção fail-closed. | CRUD produtivo, import/export e goldens continuam abertos. |
| `738ce5a9` | Rotina: 35/35 por fatias, incluindo roots 8/8 e regressões 19/19; DEV isolado e produção fail-closed. | Smoke visual integral, E2E e backend continuam abertos. |
| `e5f0523d`/`258afdb7` | Avaliações: repository 3/3, rotas 4/4, controller 5/5 e timezone server-owned. | Páginas/goldens e fluxo completo não foram revalidados. |
| `440b1ca7`/`e4baa5ff` | Pessoas: identidade fail-closed e fake movido a test-support; gates 18/18 e 45/45 nas cessões. | Oito goldens de diretório, status/card e backend permanecem abertos. |
| `8377197b`/`8e743d2c` | Unidades: closure U0/U1 53/53; produção indisponível e DEV isolado. | Commands reais, import/export, geometria e goldens permanecem abertos. |
| `5a56288e` | Perfil Principal estático: 9/9, 375 e 1440 a 200% no lote non-golden. | É preview estático; edição, backend e goldens ficaram fora. |
| `f525a7f4` | Acompanhamento: 29/29; produção somente leitura; gerenciamento indisponível. | Vincular/transferir/editar/revogar reais continuam bloqueados. |
| `3f4b3bf7` | Saúde B2: 28/28 + 42/42 e rotas 6/6; legado/detail removidos e adapter desconectado. | 12 PNGs Health divergentes e medication plans reais permanecem bloqueados. |
| `31660efe` | Import New Dialog funcional com shell/X/Cancelar no lote source/test. | Proveniência/golden, fluxo de importação e download continuam parciais. |

## 8. Pendências gerais Flutter/Dart

| ID | Estado | Pendência atual | Próxima prova exigida | ETA Flutter |
|---|---|---|---|---:|
| FLU-GEN-001 | `audited` | Reconciliar novamente 79 rotas produtivas, 96 DEV, menus e deep links após os commits finais. | Inventário HEAD + smoke source/runtime sem absorver overlays. | 8 h |
| FLU-GEN-002 | `audited` | Confirmar que fake/fixture/cache DEV não aparece em composição produtiva; várias famílias estão fail-closed. | Source guards e testes de wiring por família. | 12 h |
| FLU-GEN-003 | `audited` | Aplicar e provar shell, diretórios, formulários, flyouts, diálogos, calendário e páginas de erro canônicos. | Checklist `coelo-ui` por família. | 24 h |
| FLU-GEN-004 | `audited` | Revisar componentes Material crus, hover, tokens, tipografia, cores e superfícies. | Validador + inspeção dos estados abertos. | 16 h |
| FLU-GEN-005 | `audited` | Revisar widgets grandes, estado assíncrono, guards de comando, `mounted` e separação UI/estado/dados. | Code review e testes de concorrência/erro. | 24 h |
| FLU-GEN-006 | `regressed` | Não existe prova atual completa de 375/768/1024/1440, light/dark e texto 100%/150%/200% para as 37 famílias. | Matriz responsiva incremental, sem golden update automático. | 48 h |
| FLU-GEN-007 | `audited` | Teclado, foco, `Esc`, semântica, contraste, toque e reduced motion só foram provados em lotes específicos. | Matriz de interação por ação alcançável. | 36 h |
| FLU-GEN-008 | `regressed` | 199 PNGs rastreados fora de `failures/` exigem reconciliação individual; 1.564 artefatos `failures/` não são baseline. | Comparação HEAD/current por família e inspeção consciente. | 40 h |
| FLU-GEN-009 | `audited` | Erros, retry/reload, duplo envio, conflito, confirmação e feedback não estão uniformemente provados. | Testes RED/GREEN por comando e estado. | 32 h |
| FLU-GEN-010 | `audited` | Analyzer global fresco após reconciliar Forms, Access e Units tem zero erros, mas ainda reporta 47 issues (2 warnings e 45 infos). | Tratar warnings/infos por grupo e repetir analyzer, suítes non-golden, validadores e diff-check sem confundir zero erro com gate verde. | 3–6 h |
| FLU-GEN-011 | `regressed` | Catálogo HEAD está `catalogStale` com 8 fingerprints; fontes preparadas e não commitadas reduzem a 2. | Revalidar os 6 mecânicos e decidir Forms editor/response antes de regenerar relatório final. | 6 h |
| FLU-GEN-012 | `blocked-decision` | Tours, Agenda produtiva, Access Extended, Imports parciais, Medication, Plans e usuários internos ainda dependem de contratos/decisões. A evidência visual/local de Agenda não resolve autorização, persistência ou E2E. | Decisão canônica antes de habilitar UI produtiva. | externo |

## 9. Ledger compacto retomável das 37 famílias e ações

Nenhuma família está Flutter 100%. `local-green` significa apenas que o lote
local executado passou; `fail-closed`, `/dev`, preview ou fixture continuam
abertos. O ETA soma trabalho Flutter sequencial e exclui espera por decisões,
backend, ambiente remoto e inspeção humana de cada PNG.

| # | `screen_id` e telas/subtelas | Estado por `action_id` | Bloqueio, próxima ação exata e ETA da família |
|---:|---|---|---|
| 1 | `auth` — Login, recuperar, redefinir, MFA | `auth.login` `local-green`; `auth.recover` `local-green`; `auth.reset` `local-green`; `auth.logout` `local-green`; `auth.mfa` `audited` | O bypass recovery→rota protegida foi corrigido em `f280e291`; 66/66 Auth/guards/router e 21/21 `coelo_auth` passaram. Integração ainda aguarda remoção do delta fora de escopo em `apps/catalog`, ledger/deploy e E2E remoto. |
| 2 | `shell` — Home, menu, contexto, unauthorized, reload | `shell.load` `local-green`; `shell.navigate` `local-green`; `shell.switch-context` `audited`; `shell.unauthorized` `local-green`; `shell.reload` `audited` | Reconciliar deep links e troca de contexto; smoke dos estados e foco; 6 h. |
| 3 | `institutions` — Lista, filtros, detalhe, criar, editar, status, arquivos, importar/exportar, erro, acesso negado e reload | `institutions.list`/`filter`/`create`/`edit`/`status` `local-green`; `institutions.detail`/`files`/`import`/`export`/`error`/`access-denied`/`reload` `audited` | Revalidar baseline e 7 PNGs alterados, com prova isolada das 12 ações e texto 200%; 16 h. |
| 4 | `units` — Lista, filtros, criar, editar, status, erro, acesso negado, reload e arquivos | `units.list`/`filter`/`create`/`edit`/`status`/`error`/`access-denied`/`reload` `local-green`; `units.import`/`export` `blocked-supabase`; `units.people-export` `blocked-decision` | Adapter candidato existe, mas produção permanece `Unavailable`: RPCs people-based não satisfazem OQ-043. Import/export preservam REDs; `people-export` não possui capability/job. Gateway nominal, 17+ PNGs e E2E: 13 h + decisão. |
| 5 | `groups` — Lista, criar, detalhe/editar, membros, arquivos | `groups.list`/`create`/`edit`/`members` `local-green`; `groups.import`/`export` `audited`/`fail-closed` | Adapter candidato passou localmente, mas CRUD/membros produtivos seguem fail-closed até RPC nominal por realm. Provar permitido/negado, tenant A/B, persistência/reload e arquivos reais; 8 h + backend/remoto. |
| 6 | `people` — Lista, criar, editar, vínculos | `people.list` `audited`; `people.create` `local-green`; `people.edit` `local-green`; `people.links` `audited`; `people.reload` `audited` | Identidade produtiva fail-closed; comparar 8 goldens de diretório e revisar status/card, vínculo e reload; 12 h. |
| 7 | `access_profiles` — Lista, criar, detalhe, editar, atribuir/excluir | `access-profiles.list` `audited`; `access-profiles.create` `blocked-decision`; `access-profiles.detail` `audited`; `access-profiles.edit` `blocked-decision`; `access-profiles.assign` `blocked-decision`; `access-profiles.delete` `blocked-decision` | Access Basic 503 é seguro; Access Extended depende de Imports/backend e 16-path closure; não aceitar shims `isDemo/contextCount`; 16 h após decisão. |
| 8 | `access_models` — Lista, filtros, criar, detalhe, editar, duplicar | `access-models.list`/`filter` `audited`; `access-models.detail`/`duplicate`/`create`/`edit` `blocked-decision` | Manter Basic Access; testes concorrentes foram preservados e composition root segue 503. `deleteModel` não possui superfície UI comprovada. Capability/backend ainda bloqueiam composição; 11 h. |
| 9 | `invites` — Lista, criar, detalhe, reenviar, revogar | `invites.list` `local-green`; `invites.create` `local-green`; `invites.detail` `local-green`; `invites.resend` `local-green`; `invites.revoke` `local-green` | UI/DEV verdes, produção unavailable; provar estados, confirmação negativa, email/backend e goldens; 8 h. |
| 10 | `activities` — Lista, wizard, detalhe, editar, publicar, avaliação | `activities.list`/`create`/`detail`/`edit`/`publish`/`assessment` `local-green` | Flutter representa modelos por Unidade; migration/31 asserts seguem somente revisão estática. Faltam replay, remoto, matriz visual final, falha de About e E2E; 12 h. |
| 11 | `assessments` — Lançamento, diário, fechamento/reabertura, detalhe | `assessments.entry` `audited`; `assessments.gradebook` `audited`; `assessments.close` `audited`; `assessments.reopen` `audited`; `assessments.detail` `audited` | Contratos/controller verdes, páginas e 8 comparadores não revalidados; executar non-golden e inspeção visual separada; 10 h. |
| 12 | `students` — Lista, gerenciar, transferir, editar, revogar | `students.list` `local-green`; `students.link` `blocked-decision`; `students.transfer` `blocked-decision`; `students.edit` `blocked-decision`; `students.revoke` `blocked-decision` | Produção somente leitura e sem Gerenciar/Justificar; provar unavailable/offline a 200% e aguardar contrato de commands; 8 h. |
| 13 | `attendance` — Dashboard, nova chamada, presença, correção, conclusão, export | `attendance.dashboard` `local-green`; `attendance.create` `local-green`; `attendance.mark` `local-green`; `attendance.correct` `local-green`; `attendance.finish` `local-green`; `attendance.export` `audited` | Onda operacional revalidou 55 testes funcionais e dois goldens Windows; export, backend, tenant A/B, remoto e E2E continuam separados. |
| 14 | `daily_routine` — Lista, criar, editar, aplicar, publicar | `daily-routine.list` `local-green`; `daily-routine.create` `local-green`; `daily-routine.edit` `local-green`; `daily-routine.apply` `local-green`; `daily-routine.publish` `local-green` | Onda operacional fechou a evidência visual/local com 48 testes verdes, 4 skips justificados e 9 goldens inspecionados; produção/backend/E2E continuam abertos. |
| 15 | `agenda` — Calendário, criar, detalhe, editar, solicitações/permissões | todos os 6 `action_id` `local-green` visual/Flutter | Handoff final registrou Agenda 112/112 e a família Forms/Agenda 238/238, 14/14 rotas/navegação e 113 goldens únicos; produção permanece fail-closed, sem backend, autorização remota ou E2E. |
| 16 | `chat` — Conversas, conversa, mensagens, edição, anexos, recibos/revogação | `chat.list`/`open`/`send` `local-green`; `chat.edit`/`attach`/`receipts`/`revoke` `audited` | Launcher, ordem multi-message/pós-envio e 14 goldens fechados. Paginação total depende do RPC; edição, mídia, recibos, revogação, remoto e E2E continuam abertos; 10–16 h + backend. |
| 17 | `notices` — Lista, criar, editar, agendar, publicar, arquivar | `notices.list` `local-green` com V4.22; `notices.create` `audited`; `notices.edit` `audited`; `notices.schedule` `audited`; `notices.publish` `audited`; `notices.archive` `audited` | V4.22 fecha o diretório Flutter visual local; criação/edição/lifecycle produtivos, autorização, reload remoto e E2E continuam abertos. |
| 18 | `forms_authoring` — Lista, criar, overview, editar, publicar, testar | todos os 6 action_ids `local-green` visual/Flutter | `/dev` funcional e produção com composição equivalente fail-closed; persistência, capability e E2E pendentes. |
| 19 | `forms_responses` — Monitor, responder, respostas, detalhe, exportar | todos os 5 action_ids `local-green` visual/Flutter | Fluxos locais e estados seguros concluídos; fonte autorizada, worker, Storage e E2E pendentes. |
| 20 | `forms_files` — Upload, resolver, baixar, expirar, excluir | todos os 5 action_ids `local-green` visual/Flutter | Lifecycle local persiste em store injetável; Storage, autorização, auditoria remota e E2E pendentes. |
| 21 | `acontece` — Feed, criar/publicar, remover | `acontece.feed` `local-green`; `acontece.create` `blocked-decision`; `acontece.publish` `blocked-decision`; `acontece.remove` `blocked-decision` | Preview enquadrado está verde; produção, mídia em Supabase Storage, publicação/remover e goldens exigem contrato/E2E; R2 está fora do MVP; 10 h. |
| 22 | `agora` — Viewer, criar/publicar, expirar | `agora.view` `local-green`; `agora.create` `blocked-decision`; `agora.publish` `blocked-decision`; `agora.expire` `blocked-decision` | Viewer/foco coberto no lote; provar entrada por card/deep link e lifecycle real sem alterar baseline; 8 h. |
| 23 | `momentos` — Viewer, criar/publicar, remover | `momentos.view` `local-green`; `momentos.create` `blocked-decision`; `momentos.publish` `blocked-decision`; `momentos.remove` `blocked-decision` | `Esc`/foco cobertos; publicação/remover, origem real, Supabase Storage e goldens continuam abertos; R2 está fora do MVP; 8 h. |
| 24 | `principal_profile` — Para Você, perfil/circulares, editar | `principal.for-you` `local-green`; `principal.profile-view` `local-green`; `principal.profile-edit` `blocked-decision` | Preview é estático sem PII/backend; revisar separação de account, responsive/goldens e decidir edição real; 8 h. |
| 25 | `child_safety` — Lista, criança, criar/editar autorização, suspender | `child-safety.list` `local-green`; `child-safety.child` `local-green`; `child-safety.create` `local-green`; `child-safety.edit` `local-green`; `child-safety.suspend` `audited` | Correção mecânica não prova lifecycle; executar suspensão/revogação, erro/permissão, 200% e visual; 10 h. |
| 26 | `health_care` — Perfis, criar, detalhe, editar | `health-care.list` `local-green`; `health-care.create` `local-green`; `health-care.detail` `blocked-decision`; `health-care.edit` `local-green` | Detail legado foi removido conforme spec; 12 PNGs M estão bloqueados e produção está fail-closed; 12 h. |
| 27 | `medication` — Lista, criar, detalhe, editar, evidência | `medication.list` `blocked-decision`; `medication.create` `blocked-decision`; `medication.detail` `blocked-decision`; `medication.edit` `blocked-decision`; `medication.evidence` `blocked-decision` | OQ-003/OQ-040 mantêm planos indisponíveis, zero wiring Supabase; decidir contrato antes da UI; 12 h após decisão. |
| 28 | `imports` — Hub, criar, upload, preview, confirmar, status, download | `imports.list` e `imports.create` `local-green`; `imports.upload`, `imports.preview`, `imports.confirm`, `imports.status` e `imports.download` `audited` | V4.21 fecha diretório e wizard visual local, mas não fecha provenance, arquivo remoto, autorização ou job produtivo; Imports A exige backend amplo e pacotes parciais não são equivalentes. |
| 29 | `profile_files` — Importar, preview, confirmar, status, exportar/baixar | `profile-files.import` `audited`; `profile-files.preview` `audited`; `profile-files.confirm` `audited`; `profile-files.status` `audited`; `profile-files.export` `audited`; `profile-files.download` `audited` | Mapear callbacks/repositories e provar lifecycle, erros, reload e autorização; 12 h. |
| 30 | `audit` — Lista, filtros, detalhe, exportar | `audit.list` `audited`; `audit.filter` `audited`; `audit.detail` `audited`; `audit.export` `audited` | Apenas rota/inventário; revisar dados sanitizados, filtros, detalhe, export e responsividade; 8 h. |
| 31 | `support` — Criar, tabela, kanban, detalhe, responder, encerrar | `support.create` `local-green`; `support.table` `local-green`; `support.kanban` `local-green`; `support.detail` `audited`; `support.reply` `audited`; `support.close` `audited` | Support7 fechou scroll/paginação/200%; revisar detalhe, reply/close negativo, backend e goldens; 8 h. |
| 32 | `account` — Perfil, configurações, tema, MFA, sessões, logout | `account.profile` `audited`; `account.settings` `audited`; `account.theme` `local-green`; `account.mfa` `audited`; `account.sessions` `audited`; `account.logout` `local-green` | Oito PNGs de conta estavam divergentes; revalidar perfil/sessões/MFA, foco e 200%; 8 h. |
| 33 | `catalog` — Lista, validar, sincronizar, publicar | `catalog.list` `local-green`; `catalog.validate` `local-green`; `catalog.sync` `blocked-decision`; `catalog.publish` `blocked-decision` | Validação fresca deixou apenas `superadmin.forms-response` como fingerprint funcional bloqueado; Advanced Color Picker foi sincronizado. Decidir Forms antes de um report totalmente verde; 4–6 h para o P0, além da decisão. |
| 34 | `plans` — Lista, criar, editar, ativar, atribuir | `plans.list` `audited`; `plans.create` `local-green`; `plans.edit` `local-green`; `plans.activate` `blocked-decision`; `plans.assign` `blocked-decision` | Wizard/goldens históricos não provam ativação/atribuição; decidir contrato e rerodar visual; 10 h. |
| 35 | `meal_plans` — Cardápios, criar/editar, modelos, publicar | `meal-plans.list` `audited`; `meal-plans.create` `local-green`; `meal-plans.edit` `local-green`; `meal-plans.model-create` `local-green`; `meal-plans.model-edit` `local-green`; `meal-plans.publish` `blocked-decision` | Interpolações/identificadores têm characterization test; lifecycle, mídia e publicação não foram fechados; 12 h. |
| 36 | `internal_users` — Lista, criar, editar, suspender, MFA | `internal-users.list` `blocked-decision`; `internal-users.create` `local-green`; `internal-users.edit` `local-green`; `internal-users.suspend` `blocked-decision`; `internal-users.mfa` `blocked-decision` | Formulário verde, mas abrir/desativar foi desabilitado sem contrato; decidir domínio e provar MFA/suspensão; 10 h. |
| 37 | `error_pages` — 403, 404, 409, 500, 503, retry | `errors.403` `audited`; `errors.404` `audited`; `errors.409` `audited`; `errors.500` `audited`; `errors.503` `audited`; `errors.retry` `audited` | Baselines protegidas não foram rerenderizadas integralmente; executar rotas, teclado, reload/retry e matriz visual; 6 h. |

**ETA Flutter sequencial supersedente:** 63,5–118,5 h externas, com faixa mais
provável de 78–96 h líquidas. Famílias independentes reduzem o calendário para
30–48 h com três frentes, sem reduzir a prova necessária.

## 10. Resíduos e bloqueios que não podem ser esquecidos

| Resíduo | Estado | Próxima ação segura |
|---|---|---|
| Catálogo D | `regressed` | HEAD contém 8 fingerprints. Preservar o preparo não commitado que chega a 2, revalidar os 6 mecânicos e não promover exports/API para silenciar o gate. |
| Forms | `blocked-decision` | `superadmin.forms-editor` e `superadmin.forms-response` são as duas dívidas funcionais do catálogo; manter authoring/response fail-closed e fechar decisão do editor e F6 files/media. |
| Access Extended | `blocked-decision` | Não integrar helper/shims; retomar Access16 somente após prerequisite Imports canônico. |
| Imports parciais | `audited` | Preservar dialog source/test; provenance/golden e backend A continuam separados. |
| PNG/goldens | `regressed` | Reconciliar 199 rastreados fora de `failures/` individualmente; não atualizar em massa. |
| `failures/` | `audited` | 1.564 arquivos são feedback transitório; nunca baseline, staging ou aprovação. |
| Rotas `/dev` | `local-green` | Manter repositories/cache Development locais e provar tripwire zero em produção. |
| Fail-closed produtivo | `local-green` | É fechamento de segurança, não conclusão da tela; habilitar somente com contrato real. |
| Agenda/Tours | `blocked-decision` | Não inventar conteúdo, permissões ou ações; exigir fonte aprovada. |
| Saúde/Medicação | `blocked-decision` | Health detail removido; medication plans continuam 503/Unavailable e adapter desconectado. |
| Assiduidade | `local-green` | Tratar clock/goldens/export separadamente; preservar U1 e guards de comando. |
| Pessoas | `audited` | Oito goldens de diretório e status/card continuam fora do closure de identidade/rewire. |

## 11. Handoff para o rastreador integrado

O próximo editor de
`docs/reviews/coelo-flutter-integrado-supabase-pendencias.md` deve copiar os
estados abaixo sem convertê-los em `verified-e2e`. Cada grupo contém os
`action_id` oficiais; o lado integrado deve permanecer aberto enquanto backend,
RLS/Edge/Storage, ambiente remoto, cenários negativos e reload não estiverem
comprovados.

Esta organização Flutter passou de 195 para **201 ações** ao separar em
Instituições `detail`, `files`, `import`, `export`, `error` e `access-denied`,
que antes estavam escondidas em linhas agregadas. O controlador integrado
consultado continua com 190 operações normativas. Uma atividade integrada
futura deve mapear essas seis ações às operações existentes ou aprovar o
crosswalk; esta atividade não inventa RPC, tabela, policy ou operação backend.

| `screen_id` | Estado Flutter a alimentar por `action_id` | Estado integrado máximo permitido agora |
|---|---|---|
| `auth` | login/recover/reset/mfa `audited`; logout `local-green` | `blocked-supabase` |
| `shell` | load/navigate/unauthorized `local-green`; switch-context/reload `audited` | `not-reviewed` |
| `institutions` | list/filter/create/edit/status `local-green`; detail/files/import/export/error/access-denied/reload `audited` | `ready-for-e2e` apenas após normalizar o crosswalk e rerun Flutter |
| `units` | list/filter/create/edit/status/error/access-denied/reload `local-green`; import/export `blocked-supabase` | `blocked-supabase` |
| `groups` | list/create/edit/members `local-green`; import/export `audited` | `blocked-supabase` |
| `people` | create/edit `local-green`; list/links/reload `audited` | `blocked-supabase` |
| `access_profiles` | list/detail `audited`; create/edit/assign/delete `blocked-decision` | `blocked-flutter` |
| `access_models` | list/filter `audited`; create/detail/edit/duplicate `blocked-decision`; delete sem superfície UI | `blocked-flutter` |
| `invites` | todos os 5 action_ids `local-green` fail-closed | `blocked-supabase` |
| `activities` | todos os 6 action_ids `local-green` fail-closed | `blocked-supabase` |
| `assessments` | todos os 5 action_ids `audited` | `not-reviewed` |
| `students` | list `local-green`; link/transfer/edit/revoke `blocked-decision` | `blocked-supabase` |
| `attendance` | dashboard/create/mark/correct/finish `local-green`; export `audited` | `ready-for-e2e` somente para ações com backend cedido |
| `daily_routine` | todos os 5 action_ids `local-green` fail-closed | `blocked-supabase` |
| `agenda` | todos os 6 action_ids `local-green` visual/Flutter | `blocked-supabase` |
| `chat` | todos os 7 action_ids `audited` | `not-reviewed` |
| `notices` | list `local-green`; create/edit/schedule/publish/archive `audited` | `blocked-supabase` |
| `forms_authoring` | todos os 6 action_ids `local-green` visual/Flutter | `blocked-supabase` |
| `forms_responses` | todos os 5 action_ids `local-green` visual/Flutter | `blocked-supabase` |
| `forms_files` | todos os 5 action_ids `local-green` visual/Flutter | `blocked-supabase` |
| `acontece` | feed `local-green`; create/publish/remove `blocked-decision` | `blocked-decision` |
| `agora` | view `local-green`; create/publish/expire `blocked-decision` | `blocked-decision` |
| `momentos` | view `local-green`; create/publish/remove `blocked-decision` | `blocked-decision` |
| `principal_profile` | for-you/profile-view `local-green`; profile-edit `blocked-decision` | `blocked-decision` |
| `child_safety` | list/child/create/edit `local-green`; suspend `audited` | `not-reviewed` |
| `health_care` | list/create/edit `local-green`; detail `blocked-decision` | `blocked-supabase` |
| `medication` | todos os 5 action_ids `blocked-decision` | `blocked-decision` |
| `imports` | create `local-green`; demais 6 action_ids `audited` | `blocked-supabase` |
| `profile_files` | todos os 6 action_ids `audited` | `blocked-supabase` |
| `audit` | todos os 4 action_ids `audited` | `not-reviewed` |
| `support` | create/table/kanban `local-green`; detail/reply/close `audited` | `blocked-supabase` |
| `account` | theme/logout `local-green`; profile/settings/mfa/sessions `audited` | `blocked-supabase` |
| `catalog` | list `local-green`; validate/sync `regressed` com 8 fingerprints em HEAD; publish `blocked-decision` | `blocked-flutter` |
| `plans` | create/edit `local-green`; list `audited`; activate/assign `blocked-decision` | `blocked-decision` |
| `meal_plans` | create/edit/model-create/model-edit `local-green`; list `audited`; publish `blocked-decision` | `blocked-decision` |
| `internal_users` | create/edit `local-green`; list/suspend/mfa `blocked-decision` | `blocked-decision` |
| `error_pages` | todos os 6 action_ids `audited` | `not-reviewed` |

## 12. Protocolo de pausa e retomada

Antes de pausar, registrar posição atual, último teste confiável, arquivos
alterados, pendências, bloqueio, próxima ação executável e tempo restante. Ao
retomar, não confiar cegamente no estado registrado: conferir Git, rotas e testes
afetados e iniciar pela primeira ação não `verified` da ordem obrigatória.

O relatório ao usuário deve dizer, sem siglas desnecessárias: **onde estamos,
o que foi concluído, o que foi comprovado, o que falta, qual é o bloqueio, qual
é a próxima ação e quanto tempo efetivo ainda é estimado**.
Na primeira vez que um termo técnico aparecer, escrever também seu significado
cotidiano. Contagens e percentuais devem ser explicados, nunca apresentados
isoladamente.

## 13. Prompt mestre — revisão e correção Flutter

```text
Use obrigatoriamente coelo-flutter-review. Ela deve chamar coelo-ui, rtk,
ponytail, flutter-dart-code-review e flutter-build-responsive-layout, além de
consultar brevemente coelo-flutter-supabase-review para registrar dependências
integradas fora deste recorte Flutter.

Se eu ainda não tiver informado um orçamento, pergunte somente: “Quanto tempo
total você quer investir nesta atividade?”. Aguarde e não corrija nada. Se o
tempo já estiver na minha mensagem, não pergunte novamente.

Depois de saber o orçamento, leia AGENTS.md e
docs/reviews/coelo-flutter-pendencias.md integralmente. Inventarie novamente as
pendências gerais, telas, subtelas e ações.

Antes de alterar código, apresente uma tabela com pendência, nível mínimo
aconselhado, motivo/risco, tempo recalculado, o que cabe no orçamento e o que
continuará pendente. Apresente também objetivo, incluído, fora de escopo, ordem,
critério de parada e evidências. O recorte pode ser todas as pendências, todas as
telas, macrotema, macrotema + X telas, X telas na ordem ou X ações específicas.

Recomende pelo menos Intermediária; eleve para Avançada ou Completa quando o
risco exigir. Básica nunca conclui tela. Somente Completa pode sustentar
conclusão integral do Flutter. Recomende o pacote, peça minha confirmação, pare
e aguarde. Só depois execute as correções autorizadas.

Use Criar/Editar Instituição como baseline administrativa e aplique o Design
System Coelo: shell e contêiner macro, flyout, filtros, Cards/tabelas, diálogos,
wizard, calendário, espaçamento, hover, foco e responsividade. Componentize
quando houver repetição ou responsabilidade separável. Não preserve componente
Material cru ou padrão divergente apenas porque compila.

Corrija o que estiver autorizado, crie ou ajuste testes e atualize o rastreador
após cada ação. Uma rota aberta, um teste isolado, uma imagem golden atualizada,
um mock ou analyzer verde não tornam a tela concluída. Só use `verified` quando
todos os critérios de “Flutter 100%” tiverem evidência atual.

Informe sempre: posição atual, correções feitas, evidências em linguagem simples,
pendências, bloqueios, próxima ação e tempo estimado restante. Antes de pausar,
deixe o Markdown pronto para retomada sem depender da memória da conversa.
```

## 14. Execução Flutter/UI das 17 telas — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações).

**Progresso do recorte — Concluído:** 0,00% (0/89 `action_id` verificados).

**Progresso do recorte — Restante:** 100,00% (89/89 `action_id`).

O trabalho abaixo é evidência `local-green`, regressão ou fail-closed. Não
promove nenhuma ação a `verified`/E2E. O tempo wall-clock confiável deste
checkpoint foi medido de 15:53 a 16:15 (22 min); o trecho paralelo anterior da
mesma execução não tem marco inicial confiável e permanece **não calculável**.
Os oito lotes seguros e seus handoffs foram fechados; a estimativa restante
para verificar os 89 `action_id` permanece não calculável sem decisões de
produto, backend, ambiente integrado e inspeção visual humana pendentes.

| Lote | Telas alteradas ou regredidas | Arquivos modificados | Correções realizadas | Estado atual | Bloqueios e pendências restantes |
|---:|---|---|---|---|---|
| 1–4 | Rotina diária; Segurança da criança; Perfis de cuidado; Planos de medicação; Cardápio/Modelo; Formulários; Conversas; Comunicação | `daily_routine_pages.dart`; `safety_pages.dart`; `health_care_directory_page.dart`; `health_care_file_actions.dart`; `health_care_form_pages.dart`; `health_medication_plan_directory_page.dart`; `meal_plan_directory_page.dart`; `meal_plan_wizard_page.dart`; `forms_directory_page.dart`; `forms_overview_page.dart`; `superadmin_chat_page.dart`; `notice_directory_page.dart`; `notice_popup_preview.dart`; testes focados correspondentes; `superadmin_router.dart`; `health_care_routes_test.dart` | Insets `space4/space6/space10`; ordem toolbar/tabs/conteúdo; cards `space6`; paginação sticky; frames canônicos; datas Coelo; status progressivo; unauthorized sem conteúdo anterior; callbacks ausentes desabilitados; demo de arquivos removida; fixtures de cuidado injetadas somente em `/dev`. | `local-green`/fail-closed; nenhum golden ou backend alterado. | Validação visual global ainda bloqueada por `CheckboxListTile` em Instituições e `InkWell` em Pessoas, fora do recorte. Nomenclatura Avisos/Comunicação depende de produto. |
| 5 | Assiduidade; Rotina diária; Acompanhamento; Agenda | `daily_routine_pages.dart`; `daily_routine_production_page_test.dart`; `agenda_module_shell.dart`; `agenda_calendar_page.dart`; `agenda_calendar_page_test.dart` | Rotina alinhada e fail-closed; Agenda `/dev` sem overflow a 200% e com insets locais. Assiduidade e Acompanhamento passaram regressão sem alteração. | Rotina `local-green`; Agenda continua `/dev`; Assiduidade/Acompanhamento sem desvio estrutural reproduzido. | Agenda, permissões e navegação continuam `blocked-decision`; E2E e goldens permanecem abertos. |
| 6 | Segurança; Perfis de cuidado; Medicação; Cardápio; Modelo de cardápio | `safety_pages.dart`; `safety_pages_test.dart`; quatro libs de `health_care/presentation`; seis testes de `health_care/presentation`; dois arquivos de router/teste; três arquivos de Cardápios e dois testes | Validade aberta preservada; criação exige capability; produção de cuidado indisponível sem contrato; Medicação produtiva 503; wizard Cardápios em `SuperadminFormFrame`; callbacks no-op removidos. | `local-green`, `/dev` ou fail-closed conforme a rota. | Detalhe de Perfis, Medicação OQ-003/OQ-040, publicação/mídia e duas asserções antigas de teste de Medicação permanecem abertas. |
| 7 | Formulários; Conversas; Convites; Comunicação | quatro arquivos de Formulários e testes; `superadmin_chat_page.dart` e teste; `notice_directory_page.dart`, `notice_popup_preview.dart` e dois testes | Diretório/overview de Formulários alinhados; busca Chat canônica com debounce e proteção contra resposta stale; Avisos sem header duplicado, CTA vazio ou vazamento em forbidden. Convites passou regressão sem alteração. | Formulários e UI de Comunicação `local-green`; Convites produtivo continua unavailable. | Editor/respostas/arquivos de Formulários e repository produtivo de Convites permanecem fail-closed; contratos de membership/mídia não mudaram. |
| 8 | Acontece; Para Você; Momentos; Agora | Nenhum arquivo modificado. | 64 testes non-golden passaram; rotas e fixtures confirmadas somente em `/dev`; nenhuma dependência `coelo_ui_admin` foi adicionada ao Principal. | Regressão local verde, sem desvio estrutural reproduzido. | Produção, publicação, lifecycle e mídia dependem de produto/backend; dark específico de algumas superfícies permanece coberto somente por goldens não executados. |

## 15. Consolidação Flutter/UI complementar — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações).

**Progresso do recorte — Concluído:** 0,00% (0/89 `action_id` verificados).

**Progresso do recorte — Restante:** 100,00% (89/89 `action_id`).

Este checkpoint integrou somente evidência local: wizards canônicos de Publicar
Acontece/Momentos/Agora; um único shell para prévias/Perfil e wiring de Conteúdo
somente em `/dev`; Conteúdo demonstrativo com preview responsivo; launcher de
Chat arrastável e fail-safe; tabela canônica de permissões da Agenda; campos de
Medicação legíveis a 200%; e serialização de salvar/publicar no Acontece. Rotas
produtivas, repositories reais, backend, migrations, mídia remota e goldens não
foram habilitados nem executados.

Os gates finais executaram 58 testes não-golden e todos passaram; o analyzer
completo terminou sem issues em 70,6 s. Os handoffs específicos somaram ainda
testes focados previamente aceitos de Momentos, Agora, Conteúdo e Chat. Nenhuma
ação foi promovida a `verified` ou E2E. O tempo total confiável desta rodada não
é calculável porque implementação, revisão paralela e consolidação vieram de
frentes com marcos distintos; a ETA das 89 ações permanece não calculável sem
decisões, backend, ambiente integrado e inspeção visual humana.

Pendências explícitas preservadas: dashboard de Assiduidade; Perfil detalhado;
Lançar atividade; Cardápio/Modelo; Criar Formulário; Perfil de cuidado; e
validação transversal de tabelas/cards, flyouts e shell nas demais telas. O
validador visual continua RED somente nos dois desvios preexistentes fora do
recorte (`CheckboxListTile` em Instituições e `InkWell` em Pessoas).

## 16. Fechamento seguro da worktree Flutter/UI — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

**Progresso do recorte — Concluído:** 0,00% (0/89 `action_id` verificados E2E).

**Progresso do recorte — Restante:** 100,00% (89/89 `action_id` E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas | Shell/navegação; Acontece; Para Você; Momentos; Agora; Perfil; Publicar Acontece/Momentos/Agora; Assiduidade; Atividades; Formulários; Cardápios/Modelos; Perfis de cuidado; Pessoas; Instituições; Unidades; Turmas; Rotina diária; Segurança; Convites; Avisos; Imports; Configurações; Suporte. |
| Arquivos modificados | Manifesto Git da worktree: 97 arquivos rastreados mais 7 arquivos novos de repositories/testes de desenvolvimento; concentrados em `apps/superadmin/lib/app/{navigation,router,shell}`, `apps/superadmin/lib/features/{activities,attendance,forms,groups,health_care,imports,institutions,invites,meal_plans,notices,people,platform_users,principal_*,units}` e testes focados correspondentes. O rastreador é o único arquivo documental deste fechamento. |
| Correções realizadas | Shell único e contêiner direito responsivo nos previews Principal; wizards canônicos; proteção contra respostas A→B obsoletas; retry de cuidado; isolamento `/dev` de Imports, Forms, Agora, Support e Settings; idempotência local de Cardápios alinhada ao receipt produtivo; callbacks vazios removidos; rotas produtivas mutantes sem capability autoritativa redirecionadas antes do builder para 503 fullscreen; comandos embutidos de diretórios ficam ocultos/desabilitados em produção e ativos somente no `/dev` local. |
| Estado atual | `local-green`, `/dev` isolado ou fail-closed conforme a superfície. Analyzer completo: sem issues. `git diff --check`: verde. Suítes focadas de races/wizards/diretórios/rotas passaram nos casos alterados. Nenhum backend, migration, RLS, Auth, Storage remoto ou golden foi alterado. |
| Bloqueios | Capability autoritativa server-side ainda não existe; produção permanece 503 para mutações sem prova. Detalhe de Perfis, Medicação, Agenda, publicação/mídia Principal e partes de Forms dependem de produto/backend. O validador visual ainda aponta o `CheckboxListTile` cru preexistente em `institution_form_sections.dart:471`. Um teste preexistente de semântica de status de Unidades continua RED (`Status: Rascunho` não encontrado). Uma execução acidental do golden de Segurança divergiu 9,97%; imagem não foi atualizada nem ocultada. |
| Pendências restantes | Contrato server-side de capabilities; integrações backend/E2E; decisões de produto listadas; inspeção visual humana final; corrigir o controle cru de Instituições e a semântica do status de Unidades em lote próprio. Access Profiles mantém noop interno apenas em composição produtiva já unavailable; Platform Users é somente `/dev`. |
| Tempo usado | Não calculável com precisão: implementação e revisões ocorreram em frentes paralelas e atravessaram retomadas sem um único marco confiável. |
| Estimativa restante | Não calculável até existirem decisões de produto, contratos backend/capabilities, ambiente integrado e inspeção visual humana. |

## 16.1. Correções visuais focadas — 2026-08-27, lote 10 h

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

Este lote corrige divergências locais reproduzidas sem promover rota `/dev`,
teste de widget ou inspeção de código a evidência ponta a ponta. O recorte
estrito abaixo ficou `local-green` após revisão independente; backend, Auth,
RLS, migrations, mídia remota e goldens permaneceram intocados.

| Campo | Registro factual |
|---|---|
| Telas alteradas | Conversas; Unidades; Criar/Editar Instituição; Agenda > Permissões. |
| Arquivos modificados | `superadmin_chat_launcher.dart`; `chat_routes_test.dart`; `superadmin_chat_launcher_test.dart`; `unit_directory_cards.dart`; `unit_directory_page_test.dart`; `institution_form_sections.dart`; `institution_form_page_test.dart`; `agenda_permissions_page.dart`; `agenda_management_test.dart`. |
| Correções realizadas | Launcher circular apenas no compacto e cápsula `Mens.` em `medium+`, com drag/teclado preservados e navegação shell→Conversas provada; card informativo de Unidade preserva um único anúncio de status sem botão ou ação falsa; representantes sugeridos usam `CoeloAdminMultiSelectField<String>` com nome e e-mail, `Esc`, retorno de foco e `Aplicar`; tabela de Permissões usa linha de 88 px, célula compacta, reflow para cards com texto ampliado e uma única autoridade semântica por toggle. |
| Estado atual | `local-green`. Chat 74/74; Unidades 16/16; Agenda 6/6; Instituições 2/2 focados; analyzer dos 9 paths e validador visual verdes; `git diff --check` verde; revisão independente sem P0/P1. |
| Bloqueios | A suíte completa de Instituições mantém um RED preexistente no teste do seletor avançado de cor (`Dialog` versus cast para `AlertDialog`), fora deste delta. Duas expectativas do `persistent_shell_routes_test.dart` permanecem incompatíveis com o redirecionamento produtivo fail-closed; 62 casos da regressão ampliada passaram e 2 ficaram RED sem tocar router/shell. O contrato documental do launcher diverge entre arraste persistido e launcher fixo; o arraste existente foi preservado conforme pedido explícito do usuário. |
| Pendências restantes | Prova integrada/E2E das 207 ações; inspeção visual humana; decisões e contratos de produto/backend já listados; ampliar a matriz route-level do shell/Principal sem alterar produção salvo RED reproduzido. |
| Tempo usado | 28 min de wall-clock confiável, medidos de 21:12 a 21:40; inventário paralelo anterior sem marco único não foi somado. |
| Estimativa restante | O pacote de 9 paths não possui P0/P1 conhecido após review. O recorte maior continua não calculável até decisões de produto, contratos backend/capabilities, ambiente integrado e inspeção visual humana. |

## 16.2. Matriz shell/Principal e wizard — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Acontece; Para Você; Momentos; Agora; Perfil; Publicar Acontece/Momentos/Agora; Criar/Editar Instituição. |
| Arquivos modificados | `principal_for_you_preview_page.dart`; `persistent_shell_routes_test.dart`; `principal_happens_preview_route_test.dart`; `principal_for_you_preview_route_test.dart`; `principal_now_preview_route_test.dart`; `principal_profile_preview_route_test.dart`; `principal_moments_publication_route_test.dart`; `institution_form_page_test.dart`. |
| Correções realizadas | Matriz route-level prova oito rotas dentro de um único shell persistente e do contêiner direito em 375/768/1024/1440 e texto 100%/200%; Para Você ganhou `Flexible` no título editorial após overflow real de 30 px em 768/200%; Publicar Momentos passou a comprovar `SuperadminFormFrame`, navegação de etapas e footer canônicos; o teste do seletor de cor foi alinhado ao `Dialog` do `CoeloAdminDialogShell` e o fluxo de convite ficou determinístico sem alterar produção. |
| Estado atual | `local-green`. Matriz do shell 1/1; cinco arquivos de rotas Principal 19/19; suíte completa Criar/Editar Instituição 46/46; analyzer dos 8 paths e `git diff --check` verdes. Nenhum golden, router, backend ou fixture produtiva foi alterado. |
| Bloqueios | O arquivo amplo `persistent_shell_routes_test.dart` conserva dois REDs preexistentes fora deste delta, ligados a expectativas anteriores ao fail-closed produtivo; o novo teste foi executado isoladamente e ficou verde. Publicação, mídia e rotas produtivas Principal continuam bloqueadas pelas decisões/contratos já registrados. |
| Pendências restantes | Inspeção visual humana final; integração/E2E; decisões de produto/backend. Não há outro overflow conhecido nas oito rotas cobertas pela matriz atual. |
| Tempo usado | 17 min de wall-clock confiável neste lote, medidos de 21:40 a 21:57. |
| Estimativa restante | Nenhuma correção adicional é conhecida neste recorte de shell/Principal após os gates; o total de 207 ações E2E permanece não calculável pelos bloqueios externos já descritos. |

## 16.3. Rotas reais de wizards e fechamento dos REDs do shell — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Shell persistente; Criar Cardápio; Criar Modelo de cardápio; Criar Formulário; Criar Perfil de cuidado; Criar Plano de medicação. |
| Arquivos modificados | `superadmin_router.dart`; `dev_medication_plan_repository.dart`; `dev_medication_plan_health_care_repository.dart`; `health_medication_plan_form_page.dart`; `persistent_shell_routes_test.dart`; `meal_plan_development_routes_test.dart`; `forms_fail_closed_routes_test.dart`; `health_care_routes_test.dart`; `dev_medication_plan_repository_test.dart`; `dev_medication_plan_health_care_repository_test.dart`; `medication_plan_ui_contract_test.dart`. |
| Correções realizadas | As expectativas antigas do shell e de Cuidado foram alinhadas ao redirecionamento produtivo fail-closed. O detalhe produtivo legado de Perfil agora redireciona diretamente ao 503, antes de montar o formulário. As cinco rotas reais `/dev` comprovam um único shell, wizard dentro do contêiner de conteúdo, `SuperadminFormFrame`, navegação de etapas e footer canônicos em 375/768/1024/1440 com texto a 200%. Cardápio/Modelo comprovam repository local e mídia indisponível; Forms e Cuidado comprovam zero chamada aos adapters produtivos. Medicação usa uma única fonte local no create, diretório, detalhe e edição: salva, reaparece na lista, hidrata o mesmo item e atualiza sua versão. O wizard bloqueia dados obrigatórios e vigência invertida, preserva draft/erro/retry sem falso sucesso, mantém o `requestId` em retry idêntico e cria nova intenção somente após edição real; navegar entre etapas não cria revisão de auditoria falsa. Em resposta ambígua, reconcilia primeiro o receipt da intenção original, recupera `planId/version` e aplica a edição sobre o mesmo item, sem duplicar. O repository `/dev` aplica replay global e CAS síncrono; updates concorrentes produzem um sucesso e um conflito. O adapter preserva o contexto institucional (`atHome=false`) e nunca apresenta falsamente “Casa”. Inputs e selects permanecem dentro do viewport após scroll. |
| Estado atual | `local-green`. Gate conjunto fresco: 49/49; analyzer dos onze arquivos sem issues; formatter aplicado; `git diff --check` verde. Revisão independente final: GREEN, nenhum P0/P1 no delta. Nenhum backend, repository produtivo, fixture produtiva ou golden foi alterado. |
| Bloqueios | As rotas produtivas mutantes continuam 503 sem capability autoritativa; isso é comportamento fail-closed, não conclusão funcional. Persistência real, mídia, decisões de produto e E2E permanecem fora deste pacote. |
| Pendências restantes | Inspeção visual humana; contratos backend/capabilities e verificação E2E das 207 ações. |
| Tempo usado | Cerca de 1 h 30 min de wall-clock desde 21:57; o encerramento exato não foi recuperado pelo shell. Inclui três ciclos de review independente e correção dos P1 encontrados. |
| Estimativa restante | Nenhum desvio estrutural adicional é conhecido nas cinco rotas cobertas; o total E2E continua não calculável pelos bloqueios externos já registrados. |

## 16.4. Assiduidade Dashboard e contraprova de Principal — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Dashboard de Assiduidade; contraprova sem alteração de Acontece, Para Você, Momentos, Agora, Perfil e três publicações. |
| Arquivos modificados | `superadmin_router.dart`; `attendance_dashboard_controller.dart`; `attendance_dashboard_page.dart`; `attendance_routes_test.dart`; `attendance_dashboard_controller_test.dart`; `attendance_pages_test.dart`. |
| Correções realizadas | Produção deixa de exibir botão, coluna ou cabeçalho de abrir chamada quando a rota mutante está indisponível; `/dev` preserva a ação e a navegação local. Reloads fora de ordem validam a geração antes de alterar access/query. Trocar repository/contexto dispõe o controller anterior, cancela seu debounce, limpa a busca e carrega somente o contexto novo; resposta tardia de A não aparece em B. |
| Estado atual | `local-green`. REDs reproduzidos; regressão conjunta fresca 44/44; analyzer dos seis arquivos sem issues; formatter e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Principal passou contraprova non-golden separada de 62/62, confirmando shell único, `embedded` e wizard canônico; nenhum arquivo Principal mudou. |
| Bloqueios | Abrir/criar chamada em produção permanece 503 sem capability autoritativa. Backend, autorização integrada, dois goldens do dashboard e E2E continuam fora do pacote. |
| Pendências restantes | Clock do dashboard ainda não é injetável; banner de refresh-error não possui matriz própria 375/1440 a 200%; inspeção visual humana e contratos integrados permanecem necessários. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu inventário paralelo, três REDs, duas rodadas de review e gates focados. |
| Estimativa restante | O próximo lote seguro é Rotina diária ou Comunicação/Avisos para fechar troca de repository/contexto; a ETA E2E continua não calculável sem backend e decisões de capability. |

## 16.5. Rotina diária — troca segura de contexto — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Rotina diária. |
| Arquivos modificados | `daily_routine_pages.dart`; `daily_routine_production_page_test.dart`. |
| Correções realizadas | Ao receber outra instância de repository/contexto, a página remove o listener e descarta o controller anterior, limpa busca e permissão de gestão, restaura o tipo inicial e carrega um controller novo. O descarte invalida a carga anterior; uma resposta tardia do tenant A não pode notificar nem repovoar a superfície do tenant B. Estado `unauthorized` do novo contexto retorna antes de toolbar, tabs, criação e conteúdo anterior. |
| Estado atual | `local-green`. RED reproduzido antes da correção; regressão não-golden fresca 37/37; analyzer dos dois arquivos sem issues; formatter aplicado; `git diff --check` verde. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Persistência real, autorização integrada, cross-tenant remoto, inspeção visual humana e E2E permanecem fora deste pacote. |
| Pendências restantes | Contraprova futura pode cobrir troca para tenant B autorizado preservando uma preferência de layout explícita; isso não altera a correção de privacidade já exercitada. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu RED, correção, 37 testes e duas revisões independentes. |
| Estimativa restante | O próximo lote seguro é Comunicação/Avisos, com foco em troca de repository/ID e comandos assíncronos; a ETA E2E continua dependente dos bloqueios externos registrados. |

## 16.6. Comunicação/Avisos — isolamento do diretório — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Comunicação/Avisos; composição produtiva e `/dev` da rota. |
| Arquivos modificados | `notice_directory_page.dart`; `notice_directory_page_test.dart`; `notice_logout_wiring_test.dart`. |
| Correções realizadas | Troca de repository/tenant invalida loads e comandos anteriores, cancela debounce, limpa busca, filtros, cursores, preview, ledger e busy antes de carregar B. Resposta ou comando atrasado de A não mostra feedback, não recarrega nem altera B. Preview e diálogo de inativação pertencentes à página são removidos no swap/dispose; o fechamento termina antes do descarte de controllers. Request IDs são estáveis apenas para intenção idêntica e mudam quando ação, versão ou motivo normalizado mudam. Criar comunicação é omitido sem callback real: produção não promete uma rota 503, enquanto `/dev` preserva a ação local. |
| Estado atual | `local-green`. REDs reproduzidos antes das correções; regressão não-golden fresca 75/75; analyzer dos três arquivos sem issues; formatter aplicado; validador visual canônico e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Capabilities produtivas de criação/lifecycle continuam indisponíveis e fail-closed; backend, autorização integrada, mídia e E2E permanecem fora deste pacote. |
| Pendências restantes | Formulário de Avisos ainda requer sublote próprio para estado de load sem footer mutante, retry transitório e reconciliação de resposta ambígua antes de edição subsequente. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu cinco REDs, correções incrementais, suíte 75/75 e duas rodadas de review. |
| Estimativa restante | Próximo sublote seguro: formulário de Avisos; a ETA E2E permanece dependente dos contratos externos registrados. |

## 16.7. Comunicação/Avisos — estados de load do formulário — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Criar/Editar Comunicação/Aviso. |
| Arquivos modificados | `notice_form_controller.dart`; `notice_form_page.dart`; `notice_form_page_test.dart`. |
| Correções realizadas | Loading e falha de carregamento retornam uma superfície de estado antes de montar `SuperadminFormFrame`, navegação de etapas ou footer mutante. Edição com falha transitória oferece retry generation-safe no mesmo local; 403 e not-found continuam sem retry e sem affordance de salvar/publicar. Sucesso reidrata o wizard canônico. |
| Estado atual | `local-green`. Regressão focada fresca 25/25; analyzer dos três arquivos sem issues; formatter, validador visual canônico e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0 no delta. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Criação/edição produtiva continua 503 sem capability autoritativa; persistência real, autorização integrada, mídia e E2E permanecem fora deste pacote. |
| Pendências restantes | Reconciliação de save ambíguo após edição permanece P1 separado e não foi promovida por este GREEN. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu testes de retry/403, regressão focada e duas revisões independentes. |
| Estimativa restante | Próximo sublote seguro: receipt/idempotência do save de Avisos; ETA E2E depende dos contratos externos registrados. |

## 16.8. Comunicação/Avisos — receipts ambíguos do formulário — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Criar/Editar Comunicação/Aviso; comandos Salvar rascunho e Publicar. |
| Arquivos modificados | `notice_form_controller.dart`; `notice_form_controller_test.dart`. |
| Correções realizadas | Save ambíguo preserva request ID e payload exatos, reconcilia o receipt persistido e atualiza o mesmo aviso com nova intenção quando o draft mudou. Publicação ambígua preserva uma intenção tipada através de edições, replaya primeiro o comando original, valida ID/versão/status e só então salva/publica a edição sobre a versão reconciliada. Edição durante qualquer replay invalida o follow-up automático. Receipts impossíveis falham fechado; falhas determinísticas descartam a intenção e falhas transitórias a preservam. |
| Estado atual | `local-green`. Regressão focada fresca 16/16 e suíte não-golden de Avisos 79/79; analyzer dos dois arquivos sem issues; formatter, `git diff --check` e secret scan verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Criação/edição/publicação produtiva continua condicionada à capability autoritativa e aos contratos backend/RLS. Este pacote prova somente comportamento Flutter local e fail-closed; não constitui E2E. |
| Pendências restantes | Persistência produtiva, autorização integrada, mídia, resposta remota perdida real e validação cross-tenant continuam nos rastreadores backend/integrado. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de save/publish ambíguos, gates não-golden e duas rodadas de revisão independente. |
| Estimativa restante | Próximo lote Flutter deve ser independente deste formulário; ETA E2E continua dependente dos contratos externos registrados. |

## 16.9. Conversas — lifecycle, isolamento e envio idempotente — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Conversas; seleção/reseleção de conversa e envio de mensagem. |
| Arquivos modificados | `superadmin_chat_page.dart`; `superadmin_chat_page_test.dart`. |
| Correções realizadas | Troca de repository/contexto limpa estado e PII antes de carregar o novo contexto e descarta inbox, thread, `markRead` e envio tardios do contexto anterior. O envio é single-flight e mantém intenção tipada com `idempotencyKey` estável em falha transitória ou ambígua; mudança real de conversa, repository ou corpo cria nova intenção. Reselecionar a mesma conversa válida preserva busy/intenção e não inicia refetch capaz de sobrescrever uma mensagem recém-confirmada; thread ausente ou com erro continua permitindo retry. |
| Estado atual | `local-green`. Suíte Chat não-golden fresca 32/32; analyzer dos dois arquivos sem issues; formatter e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, router produtivo ou golden foi alterado. |
| Bloqueios | Persistência produtiva, autorização/RLS, resposta remota perdida real, realtime e validação cross-tenant permanecem fora deste pacote. O resultado local não constitui E2E. |
| Pendências restantes | Refresh manual de uma thread válida não é acionado por reseleção; refresh/realtime permanecem caminhos próprios. Evidência E2E das 207 ações e inspeção visual humana continuam pendentes. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de swap A→B, reseleção A→A, retry ambíguo, suíte focada e duas revisões independentes. |
| Estimativa restante | Próximo lote seguro: lifecycle de save/publicação de Momentos; ETA E2E continua dependente dos contratos externos registrados. |

## 16.10. Momentos — lifecycle de carregar, salvar e publicar — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Publicar em Momentos; carregar rascunho, salvar e publicar. |
| Arquivos modificados | `moments_publication_controller.dart`; `principal_moments_publication_page.dart`; `principal_moments_publication_components.dart`; testes do controller e da página. |
| Correções realizadas | Load, save e publish compartilham lifecycle single-flight e ignoram continuações após descarte. Save concluído após edição preserva os campos atuais e reconcilia somente ID/versão; erros sempre saem do estado busy com feedback retryable. Loading mostra estado sem inputs/ações. Publishing bloqueia ponteiro, foco e teclado, mantém snapshot estável e comunica o receipt confirmado exatamente uma vez. |
| Estado atual | `local-green`. Suíte Momentos não-golden fresca 38/38; analyzer dos cinco paths sem issues; formatter e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, router produtivo ou golden foi alterado. |
| Bloqueios | Persistência produtiva, autorização/RLS, mídia R2 real, resposta remota perdida e validação cross-tenant permanecem fora deste pacote. O resultado local não constitui E2E. |
| Pendências restantes | Evidência E2E das 207 ações, inspeção visual humana e contratos integrados de mídia/publicação continuam pendentes nos rastreadores correspondentes. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de concorrência, receipt stale, loading, erros, dispose, teclado/foco e revisões independentes. |
| Estimativa restante | Próximo lote Flutter deve ser independente deste fluxo; ETA E2E continua dependente dos contratos externos registrados. |

## 16.11. Agora — lifecycle local de carregar, salvar e publicar — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Publicar Agora; carregar rascunho, editar mídia/áudio, salvar e publicar na composição local `/dev`. |
| Arquivos modificados | `now_publication_controller.dart`; `principal_now_publication_page.dart`; testes do controller e da página. |
| Correções realizadas | Load, save e publish compartilham lifecycle single-flight e descartam continuações após dispose. Checkpoints confirmados reconciliam ID, versão e metadados remotos sem apagar crop, capa, direitos ou legenda editados durante o comando. Troca de repository ou contexto completo — tenant, escopos, labels, audiências e capability — recria o controller, limpa A e carrega B. Dialogs e bottom sheets são registrados antes do `push`, encerrados pelo navigator proprietário em swap/dispose e têm callbacks vinculados à geração/controller de origem. Loading não monta formulário; comandos bloqueiam ponteiro, foco e teclado conforme o estado. |
| Estado atual | `local-green`. Suíte Agora não-golden fresca 43/43; analyzer dos quatro paths sem issues; formatter e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, router produtivo ou golden foi alterado. |
| Bloqueios | O contrato `NowPublicationRepository` não recebe requestId e o adapter produtivo gera novas chaves por chamada; retry após resposta remota ambígua ainda não possui reconciliação/idempotência comprovada. Persistência produtiva, autorização/RLS, mídia R2 real e validação cross-tenant continuam fora deste pacote. O resultado local não constitui E2E. |
| Pendências restantes | Definir e implementar o contrato server-side/adapter de idempotência para save/upload/publish, com receipt/replay e testes de resposta perdida; executar evidência E2E das 207 ações, inspeção visual humana e goldens quando autorizados. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de load/swap, single-flight, checkpoints, edição concorrente, dispose, foco/teclado e ownership de overlays antes do primeiro frame, além de duas revisões independentes. |
| Estimativa restante | Próximo lote Flutter deve ser independente deste fluxo; o fechamento E2E de Agora depende do contrato integrado de idempotência, mídia e autorização. |

## 16.12. Perfil/Conta — lifecycle, privacidade e responsividade local — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Conta / Perfil em `/dev/profile`; `/profile` produtivo permanece fail-closed em 503. |
| Arquivos modificados | `account_controller.dart`; `profile_page.dart`; `superadmin_advanced_color_picker_dialog.dart`; testes do controller, página e rotas; spec canônica e projeção de conhecimento de Perfil/Configurações. |
| Correções realizadas | Load possui estado tipado, erro/retry, generations supersedíveis e descarte após dispose. Save, cancelamento e decisão de e-mail compartilham single-flight e guardam efeitos pós-await. A página limpa rascunho/avatar/erros/overlays em troca de controller ou reload e reidrata por revisão/origem confirmada: load/cancel/resolve aplicam o snapshot atual, save preserva edição concorrente e falha preserva o draft. Dirty/cancel abrangem todos os campos e avatar. Senha indisponível não monta nem solicita credenciais. Comandos bloqueiam ponteiro, foco e teclado. Layout troca linhas/colunas também pelo text scale e não apresenta overflow em 375/768/1024/1440 a 100/200%. Dialogs Flutter são registrados antes do push e encerrados em swap/dispose. |
| Estado atual | `local-green`. Gate não-golden do owner: controller+página 34/34 e rotas 5/5; analyzer dos seis paths sem issues; validador visual, formatter, memória e `git diff --check` verdes. Revisão independente inicial encontrou dois P1 de reload/reidratação, corrigidos com REDs específicos; revalidação final registrada no handoff. Nenhum backend, nova rota produtiva ou golden foi alterado. |
| Bloqueios | Produção continua 503 por ausência de repository/capability autoritativos; persistência real, autorização/RLS, mídia privada, e-mail transacional, MFA/sessões e validação cross-tenant permanecem fora. O seletor nativo do sistema aberto pelo `FilePicker` não pode ser fechado pela página em swap, mas seu resultado é descartado por generation e não altera o novo contexto. O resultado local não constitui E2E. |
| Conhecimento capturado | A spec fonte e `docs/knowledge/team/superadmin-profile-settings.md` agora registram `/profile` fail-closed, `/dev/profile` local isolado, cancelamento integral e ausência de coleta de senha sem capability/comando reais. Os dois validadores da memória passaram. |
| Pendências restantes | Integrar contratos produtivos, executar testes cross-tenant/remotos e goldens autorizados; manter as 207 ações E2E como não concluídas até evidência integrada. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de load concorrente, A→B, dispose, command lock, erro/retry, dirty/cancel, overlays, foco/teclado, matriz responsiva e revisão independente. |
| Estimativa restante | O próximo lote Flutter deve ser independente; o fechamento E2E de Conta depende dos contratos produtivos registrados. |

## 16.13. Acontece — troca de contexto e lifecycle local — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Feed Acontece e Publicar no Acontece na composição local. |
| Arquivos modificados | `principal_happens_preview_page.dart`; `happens_publication_controller.dart`; `principal_happens_publication_page.dart`; testes de feed, controller e página; spec canônica e projeção de conhecimento. |
| Correções realizadas | Troca de repository, escopo ou variante limpa posts mixed/produtivos, erro, curtidas e salvos antes do novo load e descarta respostas tardias. O publicador recria controller em troca integral de contexto, invalida picker/callbacks A e guarda todas as continuações após dispose. Loading e falha de load são state-only. Picker, remoção, autosave, save e publish compartilham exclusão mútua; corpo e navegação bloqueiam ponteiro/foco. Remoção rearma autosave; falhas operacionais preservam o draft e permitem retry. O receipt de save reconcilia ID/versão antes de upload/publish para impedir nova criação no retry local. |
| Estado atual | `local-green`. Suíte Acontece non-golden fresca 48/48 antes dos dois REDs finais; gate focado final do publicador 29/29 e feed 2/2; analyzer focado sem issues; formatter e `git diff --check` verdes. Revisões independentes finais dos dois sublotes: GREEN, P0=0/P1=0. Nenhum backend, router produtivo ou golden foi alterado. |
| Bloqueios | O contrato de save/publish não possui requestId/receipt de comando capaz de reconciliar publicação remota que persistiu e perdeu a resposta. Persistência produtiva, autorização/RLS, mídia privada/R2 e validação cross-tenant continuam fora deste pacote. O resultado local não constitui E2E. |
| Conhecimento capturado | A spec fonte e `docs/knowledge/team/happens-publication-mvp.md` registram loading state-only, single-flight do composer, limpeza cross-context e retry operacional preservando o draft. |
| Pendências restantes | Implementar e provar idempotência/receipt no contrato integrado; executar testes remotos/cross-tenant, inspeção visual humana e goldens autorizados; manter 0/207 E2E. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs A→B, dispose, picker tardio, autosave/removal, failure origin, checkpoint de save e duas revisões independentes. |
| Estimativa restante | Próximo lote Flutter deve ser independente; o fechamento E2E de Acontece depende dos contratos produtivos registrados. |

## 16.14. Para Você — lifecycle e privacidade local — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Para Você; carregamento de Comunicações e seletor local de contexto. |
| Arquivos modificados | `principal_for_you_route_page.dart`; `principal_for_you_preview_page.dart`; testes homônimos; spec canônica, projeção de conhecimento e tracker. |
| Correções realizadas | Troca de repository, dados de apoio ou relógio inicia generation B, limpa A e captura todas as dependências antes do await; respostas e erros tardios são descartados. `NoticeUnauthorizedException` monta estado 403 sem preview nem retry. O preview preserva contexto somente por ID ainda presente em B, usando o objeto novo; sheets são registradas antes do push, removidas em swap/dispose e seus retornos validam generation e membership atual. |
| Estado atual | `local-green`. Suíte non-golden completa de Para Você 24/24; analyzer do feature e testes sem issues; formatter, validador visual, memória e `git diff --check` verdes. Review independente final: GREEN, P0=0/P1=0. Nenhum backend, router produtivo ou golden foi alterado. |
| Bloqueios | O seletor continua demonstrativo/local e não autoriza nem persiste a troca produtiva da ADR 0012. Contrato remoto, RLS, cross-tenant e E2E permanecem fora. |
| Conhecimento capturado | A spec fonte e `docs/knowledge/team/principal-for-you-preview.md` registram limpeza A→B, preservação somente por ID válido, ownership de sheet e 403 sem retry. |
| Pendências restantes | Provar integração produtiva, autorização e contexto remoto; executar goldens autorizados, inspeção visual humana e evidência E2E; manter 0/207. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de repository A→B, dependências capturadas, resposta tardia, contexto local, ownership pre-push e unauthorized. |
| Estimativa restante | Próximo lote Flutter deve ser independente; fechamento E2E depende da troca contextual produtiva e autorização. |

## 16.15. Convites — Card–Table e isolamento de contexto — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Convites; busca/filtros, cards, tabela, flyout, revogação e link de reenvio. |
| Arquivos modificados | platform_invite.dart; invite_directory_page.dart; invite_directory_widgets.dart; testes de domínio, diretório e responsividade; checkpoint fonte e projeção de conhecimento. |
| Correções realizadas | A visão inicial agora usa cards e oferece a tabela canônica pelo toggle de diretório. Cards usam paginação 11, grid de largura canônica, padding 6/4, status expansível e card Criar persistente nos estados recuperáveis; tabela usa paginação 8, chip e banner. Troca de repository cancela debounce, invalida load/comando, fecha overlays próprios e limpa busca, filtros, paginação, busy, ledger e dados A antes de carregar B. Comandos capturam repository/generation antes do primeiro await; confirmações, links, feedback e refresh tardios de A não atingem B. |
| Estado atual | local-green. Gate focado ampliado 30/30 e suíte Invites non-golden 43/43; analyzer dos seis paths sem issues; formatter, validador visual, git diff --check e secret scan verdes. Revisão independente final: GREEN, P0=0/P1=0. Nenhum backend, router produtivo ou golden foi alterado. |
| Bloqueios | Capability autoritativa, RLS, persistência/entrega real, auditoria, resposta remota ambígua e validação cross-tenant permanecem fora. O resultado local não constitui E2E. |
| Conhecimento capturado | O checkpoint anterior foi atualizado para registrar que a decisão de tabela única foi substituída pelo pedido posterior Card–Table; docs/knowledge/team/superadmin-invites-directory.md projeta a baseline e a fronteira A→B. |
| Pendências restantes | Inspeção visual humana, goldens autorizados e evidência integrada das 207 ações. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de swap/debounce, overlays/comandos cross-context e matriz 375/768/1024/1440 a 100/200%. |
| Estimativa restante | Próximo lote Flutter deve ser independente; o fechamento E2E de Convites depende dos contratos produtivos registrados. |

## 16.16. Agenda / Eventos — Card–Table e lifecycle local — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Agenda > Eventos em /dev/agenda/events; nenhuma rota produtiva foi habilitada. |
| Arquivos modificados | agenda_events_page.dart; agenda_management_test.dart; este tracker. |
| Correções realizadas | Cards tornou-se a visão inicial com paginação 11, grid definido pelas constraints, card Criar e status expansível; a tabela canônica usa paginação 8, banner Criar, chip e o mesmo flyout de ações. A troca de AgendaPrototypeStore limpa busca, tipo, status e página antes de projetar o novo contexto. A matriz non-golden cobre 375/768/1024/1440 a 100/200%. |
| Estado atual | local-green do protótipo. Gate focado 10/10 e quatro arquivos Agenda non-golden explícitos 24/24; analyzer dos dois paths sem issues; formatter, validador visual, git diff --check e credential scan verdes. Review independente final: GREEN, P0=0/P1=0. |
| Bloqueios | Agenda continua blocked-decision: spec, capability autoritativa, persistência, RLS, recorrência/conflitos, autorização cross-tenant e integração produtiva permanecem fora. Uma execução por diretório alcançou seis goldens legados sem tag e encontrou divergências; nenhuma imagem foi atualizada e os artefatos temporários foram removidos. O resultado local não constitui E2E. |
| Conhecimento capturado | Nenhum conhecimento durável novo: o lote converge a UI local à baseline Card–Table já aprovada e não decide o contrato de Agenda. |
| Pendências restantes | Decidir o contrato canônico de Agenda; implementar backend e autorização; executar inspeção visual humana e goldens quando autorizados; manter 0/207 E2E até evidência integrada. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de Card–Table, equivalência de ações/status, troca de store e matriz responsiva, além de gates e review independente. |
| Estimativa restante | O próximo lote Flutter deve ser independente; o fechamento de Agenda depende das decisões e contratos registrados. |

## 16.17. Formulários / Diretório — Card–Table e isolamento de API — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Formulários; busca, filtros, paginação, cards e tabela. |
| Arquivos modificados | forms_directory_page.dart; forms_directory_page_test.dart; este tracker. |
| Correções realizadas | Cards tornou-se a visão inicial; cada card usa altura mínima 216, padding horizontal 6/vertical 4 e status expansível localizado sem excluir a semântica filha. A tabela canônica preserva chip de status. Troca de FormsApi cancela debounce e generation A, limpa busca, situação, período, página, cursores, mensagem e projeção antes de uma única consulta B vazia. A matriz non-golden alterna Cards e Table em 375/768/1024/1440 a 100/200%. |
| Estado atual | local-green. Gate focado 7/7 e conjunto directory+dormant+lifecycle 14/14; analyzer dos dois paths sem issues; formatter, validador visual, diff-check e credential scan verdes. Review independente final: GREEN, P0=0/P1=0. |
| Bloqueios | Produção criar/editar continua fail-closed em 503; nenhum card Criar foi exposto. Capability autoritativa, persistência, RLS, cross-tenant e E2E permanecem fora. |
| Conhecimento capturado | Nenhum conhecimento durável novo; o lote aplica ao diretório a baseline Card–Table já aprovada e reforça a fronteira de privacidade A→B. |
| Pendências restantes | Integrar contratos produtivos e autorização; executar inspeção visual humana, goldens autorizados e evidência integrada; manter 0/207 E2E. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de query/debounce/cursor A→B, anatomia/status e matriz Cards/Table, gates e review independente. |
| Estimativa restante | O próximo lote Flutter deve ser independente; o fechamento E2E de Formulários depende dos contratos produtivos registrados. |

## 16.18. Perfis de acesso / Diretório — lifecycle e fail-closed local — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Perfis de acesso; troca de repository, estados de autorização, callbacks de criar/abrir e retenção local de dados. |
| Arquivos modificados | `access_profile_directory_page.dart`; `access_profile_view_model.dart`; testes da página e do view model; este tracker. |
| Correções realizadas | Troca de repository descarta o view model A, limpa busca/footer e carrega B com generation própria; resposta A tardia não repinta. Callbacks ausentes permanecem nulos, portanto criação e abertura ficam ausentes ou informativas, sem falso sucesso. O view model limpa a coleção inativa, snapshots e consulta sensível em unauthorized/dispose. Unauthorized retorna antes da toolbar, tabs, filtros, toggle, cards, tabela e paginação, mantendo somente o painel 403. A matriz non-golden alterna Cards e Table em 375/768/1024/1440 a 100/200%. |
| Estado atual | `local-green`. Suíte Access Profiles non-golden 23/23; analyzer dos quatro paths sem issues; formatter 0 mudanças; validador visual, `git diff --check` e secret scan verdes. Review independente final: GREEN, P0=0/P1=0. |
| Bloqueios | Capability autoritativa, repository produtivo, criação/edição/atribuição/exclusão, RLS, validação cross-tenant, goldens e E2E permanecem fora. O resultado local não constitui E2E. |
| Conhecimento capturado | `no-op`: o lote aplica a baseline Instituições e a regra fail-closed já aprovadas; nenhuma regra durável nova foi decidida. |
| Pendências restantes | Integrar contratos produtivos e autorização; executar inspeção visual humana, goldens autorizados e evidência integrada; manter 0/207 E2E. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs A→B, resposta tardia, callbacks ausentes/reais, limpeza de PII, unauthorized state-only, matriz responsiva, gates e review independente. |
| Estimativa restante | O fechamento E2E de Perfis de acesso depende dos contratos produtivos e decisões registradas. |

## 16.19. Programa de conclusão visual aprovado — 2026-08-28

**Spec canônica:**
`docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md`.

**Entrega documental — Concluída:** 100,00% (1/1 spec registrada).

**Programa visual — Aceito visualmente:** 0,00% (0/31 entregáveis).

**Flutter local — `local-green`:** 50,72% (105/207 ações). Esse número registra
evidência local e não significa que 105 ações estejam concluídas ponta a ponta.

**Flutter local — restante fora de `local-green`:** 49,28% (102/207 ações).

**Flutter `verified`:** 0,00% (0/207 ações). O estado exige todos os gates
Flutter da seção 2, inclusive inspeção visual e regressões aplicáveis.

**Integração E2E:** 0,00% (0/202 ações), conforme o rastreador integrado. Esta
métrica não deve mais ser apresentada como “progresso Flutter”.

**Supabase `done`:** 0,00% (0/37 famílias). Há 8,11% (3/37 famílias) em
`local-green`, evidência local que ainda não constitui backend remoto concluído.

**Projeto estrito ponta a ponta:** 0,00% (0/229 unidades estritas), conforme o
rastreador integrado. Esse percentual mede somente conclusão integral; ele não
apaga os 86 itens Flutter e três famílias Supabase já verdes localmente.

| Campo | Registro factual |
|---|---|
| Modalidade | Macrotema + telas específicas: conclusão visual e navegação local antes de revisão profunda ou backend. |
| Objetivo | Fechar 31 entregáveis visuais em cinco ondas, usando os 69 anexos como referências de anatomia/comportamento e preservando a identidade Coelo. |
| Incluído | Login; Conversas; menu/shell; arquivos; Turmas; rodapés; Atividades/modelos; Assiduidade; Rotina diária; Acompanhamento; Segurança infantil; Usuários internos; Perfis/modelos de acesso; Cuidado; Medicação; Cardápios; Formulários; Importações; Comunicações; Circulares; Acontece; Agora; Para você; Momentos; Perfil e publicadores. |
| Fora de escopo | Componentização profunda, Supabase, migrations, RLS, RPCs, Storage/R2, autorização produtiva, publicação real e E2E remoto. Saúde/Cuidado permanece liberado para UI local. |
| Ordem | V1 Fundação → V2 Estrutura/Operação → V3 Acessos/Cuidado → V4 Formulários/Comunicação → V5 Principal/Mídia → regressão transversal → componentização profunda → integração. |
| Critério de parada | Onda aceita com evidência; limite de tempo; conflito canônico; regressão sem correção segura; ou pedido do Owner. Toda pausa atualiza spec e tracker no mesmo turno. |
| Evidências | RED→GREEN, 375/768/1024/1440, light/dark, texto 200%, teclado/foco/semântica, comparação visual, analyzer, testes focados, validador visual e diff-check. |
| Estado atual | `approved-design`; nenhuma correção de código desta nova etapa foi iniciada. O delta concorrente de Avaliações permanece intocado. |
| Padrões UI existentes | Baselines aprovadas, interação sem cinza, Cards/Tabela, arquivos, calendário, wizard e `SuperadminFormActionFooter`. |
| Gaps `coelo-ui` | Promover antes do uso: construtor de perguntas, seletor Coelo de hora, viewer social fullscreen e perfil rico do Principal. |
| ETA inicial | 104–160 h para as cinco ondas e regressão transversal; V1 = 10–14 h. Recalcular depois de V1 com custo observado. |

### Ordem de retomada obrigatória

Quando o Owner perguntar o próximo trabalho, responder primeiro com esta etapa e
começar por V1. A primeira entrega de implementação deve abranger Login,
Conversas, menu/shell e ações de arquivo dentro da janela aprovada. Revisão
profunda e componentização vêm após o aceite visual, sem ampliar silenciosamente
o recorte.

## 16.20. V1 — Fundação e navegação local — abertura — 2026-08-28

**Entrega atual:** 0,00% (0/5 entregáveis `local-green` ou `accepted`).

**Programa visual:** 0,00% (0/31 entregáveis `accepted`).

**Flutter local:** 40,58% (84/207 ações `local-green`). **Flutter verified:**
0,00% (0/207). **Supabase local:** 8,11% (3/37 famílias `local-green`).
**Supabase concluído:** 0,00% (0/37). **Integração E2E:** 0,00% (0/202).
**Projeto estrito:** 0,00% (0/229). E2E e estrito medem conclusão integral e
não anulam trabalho local.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Login; Conversas em `/communication/conversations`; menu e shell persistentes; ações de arquivo nos diretórios pertinentes. |
| Arquivos alterados | Esta spec e este rastreador antes do código. Os arquivos dirty de Avaliações estão fora do recorte. |
| Correções realizadas | Contrato operacional V1 registrado; nenhuma correção de produção ainda. |
| Testes e resultados | Baseline focado Login + Chat routes + Navegação + Shell: 96/96 verdes. |
| Inspeções responsivas | Pendentes: 375/768/1024/1440, texto 200%, light/dark, teclado/foco/Escape/semântica/alvos e reduced motion. |
| Bloqueios | Nenhum. Backend e E2E permanecem deliberadamente fora do recorte. |
| Tempo usado | 0 h de execução no início, às 11:21 BRT. |
| Estimativa restante | 10–14 h para V1; janela autorizada de 10 h. |
| Próximo item exato | Login: escrever REDs para hover sem cinza, clique em controle/rótulo/linha, foco visível e teclado. |
| Conhecimento capturado | `no-op`: a execução aplica a spec canônica já aprovada. |

## 16.21. V1.1 Login — interação de sessão — 2026-08-28

**Entrega atual:** 20,00% (1/5 entregáveis `local-green` ou `accepted`).
**Programa visual:** 0,00% (0/31 `accepted`). **Flutter local:** 40,58%
(84/207). **Flutter verified:** 0/207. **Supabase local:** 3/37 (8,11%).
**Supabase done:** 0/37. **Integração:** 0/202. **Projeto estrito:** 0/229.
As duas últimas métricas medem conclusão integral e não anulam o GREEN local.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Login do Superadmin. |
| Arquivos alterados | `superadmin_login_form.dart`; `superadmin_login_screen_test.dart`; spec e tracker. |
| Correções realizadas | Controle local único para “Manter sessão aberta”, sem hover cinza, acionável por checkbox, rótulo, linha, Space e Enter, com foco Coelo visível, semântica e alvo de 48 px. |
| Testes e resultados | Três REDs iniciais; suíte final 18/18; analyzer focado sem issues; formatter e diff-check verdes. |
| Inspeções responsivas | 375/768/1024/1440 em light/dark, texto 200%, além do cenário compacto 320×568; sem overflow. |
| Bloqueios | Somente inspeção/aceite visual humano; backend e E2E seguem fora do recorte. |
| Tempo realmente usado | 0 h 07 min. |
| Estimativa restante | 9 h 53 min da janela; 9 h 53 min–13 h 53 min pela faixa V1. |
| Próximo item exato | Conversas: REDs de launcher/item lateral, navegação de saída e callback ausente. |
| Conhecimento capturado | `no-op`: aplicação de `pattern.interaction-states` e `pattern.selection-controls` já aprovados. |

## 16.22. V1.2 Conversas — navegação total do shell — 2026-08-28

**Entrega atual:** 40,00% (2/5 `local-green` ou `accepted`). **Programa
visual:** 0/31 `accepted`. **Flutter local:** 84/207 (40,58%). **Flutter
verified:** 0/207. **Supabase local:** 3/37 (8,11%). **Supabase done:** 0/37.
**Integração:** 0/202. **Projeto estrito:** 0/229. E2E e estrito medem
conclusão integral e não anulam evidência local.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Launcher/item lateral para Conversas em produção e `/dev`; navegação de Conversas para Atividades. |
| Arquivos alterados | `superadmin_router.dart`; `superadmin_shell.dart`; testes de chat routes e shell; spec e tracker. |
| Correções realizadas | Mapeadores centrais substituem callbacks parciais; shell persiste; controle visível nunca recebe callback vazio e some quando nenhuma capability de navegação foi injetada. |
| Testes e resultados | RED do launcher morto; GREEN conjunto 70/70; analyzer focado sem issues; formatter verde. |
| Inspeções responsivas | Matriz do shell em 375/768/1024/1440, light/dark, texto ampliado e reduced motion. |
| Bloqueios | Inspeção/aceite humano; chat remoto permanece fora do recorte. |
| Tempo realmente usado | 0 h 07 min; 0 h 14 min acumulados. |
| Estimativa restante | 9 h 46 min da janela; 9 h 46 min–13 h 46 min pela faixa V1. |
| Próximo item exato | Menu: RED para remover `Criar ...` e preservar `Nova chamada`/três `Publicar ...`. |
| Conhecimento capturado | `no-op`: aplicação de `pattern.stable-route-content-transition` já aprovado. |

## 16.23. V1.3 Menu lateral — hierarquia operacional — 2026-08-28

**Entrega atual:** 60,00% (3/5 `local-green` ou `accepted`). **Programa
visual:** 0/31 `accepted`. **Flutter local:** 84/207 (40,58%). **Flutter
verified:** 0/207. **Supabase local:** 3/37 (8,11%). **Supabase done:** 0/37.
**Integração:** 0/202. **Projeto estrito:** 0/229. E2E e estrito medem
conclusão integral e não anulam evidência local.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Menu lateral expandido/recolhido e busca; rotas de criação continuam acessíveis somente pelos CTAs das telas. |
| Arquivos alterados | `superadmin_navigation.dart`; teste de navegação; spec e tracker. |
| Correções realizadas | Dezoito rótulos genéricos `Criar ...` removidos; `Nova chamada` e três publicações preservadas com capabilities fail-closed. |
| Testes e resultados | RED de árvore/busca; navegação 15/15 e regressão Navegação+Chat 20/20; analyzer sem issues; formatter verde. |
| Inspeções de interação | Busca inline/recolhida, breadcrumbs, teclado, foco e Escape. A matriz responsiva do shell segue verde no checkpoint anterior. |
| Bloqueios | Inspeção/aceite humano; nenhum bloqueio local. |
| Tempo realmente usado | 0 h 04 min; 0 h 18 min acumulados. |
| Estimativa restante | 9 h 42 min da janela; 9 h 42 min–13 h 42 min pela faixa V1. |
| Próximo item exato | Shell: provar instância/geometria estáveis e contêiner direito amplo na matriz obrigatória. |
| Conhecimento capturado | `no-op`: aplica a regra de navegação já aprovada na spec. |

## 16.24. V1.4 Shell e contêiner — geometria persistente — 2026-08-28

**Entrega atual:** 80,00% (4/5 `local-green` ou `accepted`). **Programa
visual:** 0/31 `accepted`. **Flutter local:** 84/207 (40,58%). **Flutter
verified:** 0/207. **Supabase local:** 3/37 (8,11%). **Supabase done:** 0/37.
**Integração:** 0/202. **Projeto estrito:** 0/229. E2E e estrito medem
conclusão integral e não anulam evidência local.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Instituições → Conversas → Pessoas em `/dev`, dentro do host persistente. |
| Arquivos alterados | Teste de rotas persistentes; spec e tracker. Nenhum arquivo de produção. |
| Correções realizadas | Nenhuma necessária: o novo gate comprovou instância e geometria estáveis, superfície direita ampla e gutters canônicos. |
| Testes e resultados | Cenário novo 1/1; suíte persistent shell 15/15; analyzer sem issues; formatter verde. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%; light/dark e reduced motion cobertos pela suíte Shell 70/70 anterior. |
| Bloqueios | Inspeção/aceite humano; nenhum bloqueio local. |
| Tempo realmente usado | 0 h 03 min; 0 h 21 min acumulados. |
| Estimativa restante | 9 h 39 min da janela; 9 h 39 min–13 h 39 min pela faixa V1. |
| Próximo item exato | Arquivos: REDs de visibilidade e indisponibilidade honesta, começando por Instituições. |
| Conhecimento capturado | `no-op`: prova adicional de `pattern.stable-route-content-transition` já aprovado. |

## 16.25. Programa V1–V5 confirmado; V1.5 Arquivos em RED — 2026-08-28

**Entrega atual:** 80,00% (4/5 `local-green` ou `accepted`); Arquivos está
`in-progress`. **Programa visual:** 0/31 `accepted`. **Flutter local:** 84/207
(40,58%). **Flutter verified:** 0/207. **Supabase local:** 3/37 (8,11%).
**Supabase done:** 0/37. **Integração:** 0/202. **Projeto estrito:** 0/229.
E2E e estrito medem conclusão integral e não anulam evidência local.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`; fase RED de Arquivos concluída, GREEN pendente. O Owner confirmou que o escopo total autorizado vai da V1 à V5; 10 h é checkpoint inicial, não encerramento do programa. |
| Tela e rota | Instituições; Turmas/Grupos; Pessoas; Cuidado/Medicação; Segurança; Atividades; Rotina diária; Suporte; Pessoas da Unidade. |
| Arquivos alterados | Testes focados das nove superfícies; spec e este tracker. Nenhum arquivo de produção neste checkpoint. |
| Correções realizadas | Ainda nenhuma de produção. O contrato de teste passou a exigir `CoeloAdminFileActions` visível e indisponibilidade honesta quando não existe capability real. |
| Testes e resultados | O conjunto RED falhou como esperado por ações ocultas em sete superfícies, mensagem de sucesso simulada em Suporte e exportação ausente em Pessoas da Unidade. A execução também encontrou expectativas antigas de launcher sem callback em Cuidado e Atividades; os fixtures serão corrigidos para injetar a capability. |
| Inspeções responsivas | Pendentes do GREEN: 375/768/1024/1440, texto 200%, light/dark, teclado, Escape, retorno de foco e alvos. |
| Regressões e bloqueios | Golden de Segurança divergiu 9,84% antes das mudanças de produção. É proibido atualizá-lo automaticamente; requer inspeção e aceite visual humano. Os testes não-golden continuam seguros. Avaliações permanecem fora do diff autorizado. |
| Tempo realmente usado | 0 h 27 min acumulados, às 11:48 BRT. |
| Estimativa restante | 9 h 33 min da janela inicial. Programa V1–V5: 104–160 h, executado por checkpoints seguros. |
| Próximo item exato | GREEN de Instituições; depois as demais superfícies de Arquivos. Após V1, iniciar V2.6 Turmas/Grupos, sem saltar ondas. |
| Conhecimento capturado | `no-op`: a indisponibilidade honesta, `admin.file-actions` e a ordem V1–V5 já estão aprovadas na fonte canônica. |

## 16.26. V1.5 Arquivos — fechamento local-green — 2026-08-28

**Entrega atual:** 100,00% (5/5 `local-green` ou `accepted`). **Programa
visual:** 0/31 `accepted`. **Flutter local:** 84/207 (40,58%). **Flutter
verified:** 0/207. **Supabase local:** 3/37 (8,11%). **Supabase done:** 0/37.
**Integração:** 0/202. **Projeto estrito:** 0/229. E2E e estrito medem
conclusão integral e não anulam o trabalho Flutter local.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Instituições; Turmas/Grupos; Pessoas; Cuidado/Medicação; Segurança; Atividades; Rotina diária; Suporte; Pessoas da Unidade; Atividades em produção e `/dev`. |
| Arquivos alterados | `institution_file_actions.dart`; `group_directory_page.dart`; `person_file_actions.dart`; `health_care_file_actions.dart`; `safety_pages.dart`; `activity_directory_page.dart`; `daily_routine_pages.dart`; `support_page.dart`; `unit_local_management_section.dart`; router e repository `/dev` de Atividades; testes correspondentes; spec e tracker. |
| Correções realizadas | Ações pertinentes ficaram visíveis via `CoeloAdminFileActions`; capability real continua sendo executada; fallback mostra exatamente `Indisponível nesta etapa`. Removidos sucesso falso de Suporte, prévia fictícia de Pessoas da Unidade e export/download `dev.invalid` de Atividades. |
| Testes e resultados | REDs confirmaram ações ocultas e sucessos falsos. GREEN: 17/17 + 86/86 + 5/5 + 3/3 não-golden de Segurança + 2/2 do flyout = 113 testes relevantes. Escape fecha o flyout e devolve foco. Analyzer focado e diff-check verdes. |
| Inspeções responsivas | Matrizes existentes/focadas cobrem 375/768/1024/1440, light/dark e texto 200%; Segurança 200% foi reexecutada. Alvos de toque, teclado, Escape e foco usam o componente canônico. |
| Bloqueios | Golden legado de Segurança divergiu 9,84% antes do GREEN. Não foi atualizado; exige inspeção e aprovação visual humana. `accepted` segue 0/31. Arquivos dirty de Avaliações permanecem fora do recorte. |
| Tempo realmente usado | 0 h 39 min acumulados, às 12:00 BRT. |
| Estimativa restante | 9 h 21 min da janela inicial; V2–V5 seguem autorizadas e em ordem. |
| Próximo item exato | Gates finais/commit da V1; depois V2.6 Turmas/Grupos — cards com tipo, alunos, atividades e professores/responsáveis. |
| Conhecimento capturado | `no-op`: apenas regras já aprovadas foram aplicadas. |

Gate adicional às 12:06 BRT: o validador administrativo encontrou no Login o
`InkWell` cru introduzido no primeiro GREEN e a allowlist de `CheckboxListTile`
já obsoleta. Ambos foram corrigidos sem ampliar o comportamento: Login 18/18,
anatomia responsiva preservada e validador GREEN. A suíte final de Shell,
Navegação, Conversas, rotas persistentes e Atividades ficou 106/106. Tempo
acumulado: 0 h 45 min; próximo item continua sendo o commit de Arquivos e depois
V2.6.

## 16.27. V2.6 Turmas/Grupos — cards ricos — abertura — 2026-08-28

**Entrega atual V2:** 0,00% (0/6 `local-green` ou `accepted`). **Programa
visual:** 0/31 `accepted`. **Flutter local:** 84/207 (40,58%). **Flutter
verified:** 0/207. **Supabase local:** 3/37 (8,11%). **Supabase done:** 0/37.
**Integração:** 0/202. **Projeto estrito:** 0/229. E2E e estrito medem
conclusão integral e não anulam a V1 localmente concluída.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`; V1 ficou 5/5 `local-green`, sem `accepted` humano. |
| Tela e rota | Diretório de Turmas/Grupos, Cards, produção e `/dev`. |
| Arquivos alterados | Spec e tracker antes do RED; código/teste de Grupos será registrado no GREEN. |
| Correções realizadas | Nenhuma nesta abertura. Índice `coelo-ui` consultado para diretório, card interativo, status, cards compactos, filtros responsivos e transição estável. |
| Testes e resultados | O teste existente ainda afirma a ausência de Atividades, Responsáveis e Crianças/Alunos; será convertido em RED explícito. |
| Inspeções responsivas | Pendentes: 375/768/1024/1440, texto 200%, light/dark, foco, teclado, alvo e reduced motion. |
| Bloqueios | Nenhum local; aceite visual humano pendente. Assessments fora do recorte. |
| Tempo realmente usado | 0 h 45 min acumulados, às 12:06 BRT. |
| Estimativa restante | 1–2 h para V2.6; 9 h 15 min da janela inicial. |
| Próximo item exato | RED do primeiro card exigindo tipo, alunos, atividades e professores/responsáveis com fixtures locais seguras. |
| Conhecimento capturado | `no-op`: o comportamento já está aprovado na spec canônica. |

## 16.28. V2.6 Turmas/Grupos — cards ricos — local-green — 2026-08-28

**Entrega atual V2:** 16,67% (1/6 `local-green` ou `accepted`). **Programa
visual:** 0/31 `accepted`. **Flutter local:** 84/207 (40,58%). **Flutter
verified:** 0/207. **Supabase local:** 3/37 (8,11%). **Supabase done:** 0/37.
**Integração:** 0/202. **Projeto estrito:** 0/229. E2E e estrito medem
conclusão integral e não anulam V1/V2.6 locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Diretório de Turmas/Grupos, Cards, produção e `/dev`. |
| Arquivos alterados | `group_directory.dart`; `fake_group_directory_repository.dart`; `group_directory_page.dart`; `group_directory_page_test.dart`; spec e tracker. |
| Correções realizadas | Card de Instituições preservado como baseline; Turmas ganhou tipo, alunos, atividades e professores/responsáveis com fixtures locais seguras, plurais honestos e alinhamento com o tile de criação. |
| Testes e resultados | RED reproduzido. GREEN 19/19 Grupos + 8/8 card/status canônicos; analyzer, validador administrativo e diff-check verdes. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%, light/dark por comparação de golden; saídas light 375/768/1440 inspecionadas. Foco, teclado, alvo e reduced motion verdes nos componentes compartilhados. |
| Bloqueios | 16 goldens antigos divergem 22,53%–40,14% devido às mudanças esperadas de Cards e Arquivos. Nenhum foi atualizado; aprovação visual humana é necessária para novos baselines e `accepted`. Assessments intocado. |
| Tempo realmente usado | 0 h 07 min; 0 h 52 min acumulados, às 12:13 BRT. |
| Estimativa restante | 9 h 08 min da janela; V2.7 inicialmente 1–2 h. |
| Próximo item exato | V2.7: inventário e RED do rodapé universal de criação/edição com `SuperadminFormActionFooter`. |
| Conhecimento capturado | `no-op`: comportamento já aprovado na spec. |

## 16.29. V2.7 Rodapé universal — abertura — 2026-08-28

**Entrega atual V2:** 16,67% (1/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
o trabalho local.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Formulários/wizards reais de criação e edição do Superadmin. |
| Arquivos alterados | Spec e tracker antes do gate; nenhum código de produção. |
| Inventário | Todos os `form_page`, `form_pages` e `wizard_page` reais já consomem `SuperadminFormActionFooter`. Páginas de resposta, teste, overview, diretório e wrappers que delegam ao formulário não são infratoras. |
| Testes e resultados | Pendentes: gate de adoção, suíte do componente e amostra responsiva de consumidores. |
| Inspeções responsivas | Planejadas em 375/768/1024/1440 e texto 200%; light/dark conforme testes/goldens existentes. |
| Bloqueios | Nenhum; sem produção a corrigir até aqui. |
| Tempo realmente usado | 0 h 52 min acumulados, às 12:13 BRT. |
| Estimativa restante | 0 h 30–1 h para V2.7; 9 h 08 min da janela. |
| Próximo item exato | Gate explícito de adoção universal do footer canônico. |
| Conhecimento capturado | `no-op`: baseline já documentada no índice `coelo-ui`. |

## 16.30. V2.7 Rodapé universal — local-green — 2026-08-28

**Entrega atual V2:** 33,33% (2/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual pendente. |
| Tela e rota | 23 superfícies atuais de criação/edição/editor/wizard do Superadmin. |
| Arquivos alterados | `superadmin_form_action_footer_adoption_test.dart`; spec e tracker. Nenhuma produção. |
| Correções realizadas | Nenhuma necessária: todos os formulários reais já usam `SuperadminFormActionFooter`; seis candidatos sem footer são semanticamente diretório/resposta/teste/wrapper. |
| Testes e resultados | Adoção 2/2 + footer 5/5 + matrizes Turmas/Unidades 2/2 = 9/9; analyzer e diff-check verdes. |
| Inspeções responsivas | Compacto/intermediário/1024 e texto 200% no componente; consumidores em 375/768/1024/1440, light/dark e 200%. |
| Bloqueios | Nenhum local; Assessment foi apenas lido pelo gate e continua intocado. |
| Tempo realmente usado | 0 h 04 min; 0 h 56 min acumulados, às 12:17 BRT. |
| Estimativa restante | 9 h 04 min da janela; V2.8 = 1–2 h inicial. |
| Próximo item exato | V2.8 Atividades/Modelos: edição, duplicação com novo nome e modelo sem vínculos. |
| Conhecimento capturado | `no-op`: contrato aprovado ganhou gate executável. |

## 16.31. V2.8 Atividades e modelos — abertura — 2026-08-28

**Entrega atual V2:** 33,33% (2/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Diretório de Atividades, coleção Modelos e wizard canônico, produção e `/dev`. |
| Arquivos alterados | Spec e tracker antes dos REDs; produção/testes serão registrados no GREEN. |
| Regressões | Card ainda abre detalhe apesar de receber callback de edição; dialog de duplicação não solicita novo nome; criação de modelo usa dialog local e ainda não prova wizard sem vínculos. |
| Testes planejados | Três contratos RED→GREEN independentes: abrir edição, duplicar com nome obrigatório e criar modelo pelo wizard omitindo vínculos. |
| Inspeções responsivas | Pendentes em 375/768/1024/1440, texto 200%, light/dark, teclado, foco, Escape, alvos e reduced motion. |
| Bloqueios | Nenhum local; Supabase/backend e Assessments permanecem fora do recorte. |
| Tempo realmente usado | 0 h 56 min acumulados, às 12:17 BRT. |
| Estimativa restante | 1–2 h para V2.8; 9 h 04 min da janela inicial. |
| Próximo item exato | RED do card abrindo edição; depois novo nome na duplicação e modo modelo sem vínculos no wizard. |
| Conhecimento capturado | `no-op`: comportamento já aprovado na spec do programa. |

## 16.32. V2.8 Atividades e modelos — local-green — 2026-08-28

**Entrega atual V2:** 50,00% (3/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Atividades/Modelos e criação/edição `/dev`; produção permanece sem mutação quando não há capability. |
| Arquivos alterados | `activity_directory_page.dart`; `superadmin_router.dart`; testes de diretório, formulário e golden; dialog shell compartilhado e teste; spec e tracker. |
| Correções realizadas | Card/tabela abrem edição quando disponível e mantêm detalhe como fallback; duplicação exige novo nome e o encaminha à cópia local; criação de modelo usa wizard Contexto → Identidade → Revisão e declara ausência de vínculos. Dialog compartilhado ganhou rolagem integral em texto ampliado e ações empilhadas em largura estreita. |
| Testes e resultados | REDs: edição ignorada, callback sem nome, criação sem wizard e overflow 375/200%. GREEN 42/42 Atividades/rotas + 4/4 dialog; analyzers focados, validador administrativo e diff-check verdes. |
| Inspeções responsivas | Wizard 375/768/1024/1440 a 200%; diretório/formulário já cobrem light/dark e reduced motion; dialog cobre teclado, Escape, retorno de foco e alvos. |
| Bloqueios | Nove grupos de goldens antigos divergem 4,72%–46,27% e um cenário interativo legado não alcança a chave esperada. Não atualizados. Mudanças V1 de launcher/Arquivos explicam o deslocamento constante de várias referências; inspeção/aceite humano pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 17 min; 1 h 13 min acumulados, às 12:34 BRT. |
| Estimativa restante | 8 h 47 min da janela; V2.9 = 2–3 h inicial. |
| Próximo item exato | V2.9 Assiduidade: inventário e RED de dashboard/chamada, começando por Salvar por aluno. |
| Conhecimento capturado | `no-op`: contratos de UX já aprovados foram aplicados. |

## 16.33. V2.9 Assiduidade — abertura — 2026-08-28

**Entrega atual V2:** 50,00% (3/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Dashboard, nova chamada e lançamento/detalhe de Assiduidade, produção e `/dev`. |
| Inventário | Dashboard, chamada, cinco estados individuais, responsividade e seam de Rotina diária já estão implementados. Falta sentimento e `Salvar` explícito por aluno; hoje tocar no estado dispara mutation imediatamente. |
| Testes planejados | RED de edição local por participante: escolher estado/sentimento não chama repository; `Salvar` chama uma vez; erro preserva a seleção; Rotina demonstrativa continua visível. |
| Bloqueios | Persistência real de sentimentos está fora do recorte/backend; a demonstração local não pode anunciar sucesso remoto. Assessments permanece intocado. |
| Tempo realmente usado | 1 h 13 min acumulados, às 12:34 BRT. |
| Estimativa restante | 2–3 h para V2.9; 8 h 47 min da janela. |
| Próximo item exato | RED do primeiro card exigindo sentimento Coelo e botão individual `Salvar`. |
| Conhecimento capturado | `no-op`: comportamento já aprovado no programa visual. |

## 16.34. V2.9 Assiduidade — local-green — 2026-08-28

**Entrega atual V2:** 66,67% (4/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Dashboard, nova chamada e chamada; `/dev/attendance/calls/call-progress` ligado à Rotina diária local. |
| Arquivos alterados | `attendance_pages.dart`; `superadmin_router.dart`; testes de página e rotas; spec e tracker. |
| Correções realizadas | Selecionar estado não persiste até `Salvar` por aluno; falha mantém seleção. Sentimentos reutilizam o picker Coelo e são rotulados como demonstração local não persistida. A fixture `/dev` mostra rotina pendente e navega a `/dev/daily-routine`. |
| Testes e resultados | Dois REDs reproduzidos; GREEN 50/50 suíte focada de Assiduidade + 6/6 rotas. Analyzer, validador administrativo e diff-check verdes. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%, light/dark e reduced motion pelos testes existentes; foco/Escape/alvos preservados. Saída dark 1440 inspecionada. |
| Bloqueios | Goldens antigos divergem 59,47% e 12,86%; não atualizados. Emoji aparece como tofu no renderer de teste e precisa inspeção em runtime. Persistência de sentimentos continua corretamente fora do recorte. Assessments intocado. |
| Tempo realmente usado | 0 h 11 min; 1 h 24 min acumulados, às 12:45 BRT. |
| Estimativa restante | 8 h 36 min da janela; V2.10 = 1–2 h. |
| Próximo item exato | V2.10 Rotina diária: RED de cards ricos, duplicação ou criação por modelo conforme o primeiro gap confirmado. |
| Conhecimento capturado | `no-op`: contratos já aprovados foram aplicados sem nova regra durável. |

## 16.35. V2.10 Rotina diária — abertura — 2026-08-28

**Entrega atual V2:** 66,67% (4/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Diretório e editor de Rotina diária, produção e `/dev`. |
| Inventário | Cards/Tabela e deep links tipados existem; card atual mostra status, versão, origem e efetivo. Não há duplicação, criação por modelo ou CTA tipado. |
| Testes planejados | RED do card de modelo com duplicação e criação por modelo, sem perder abertura do card; matriz responsiva e rotas `/dev` depois do GREEN. |
| Bloqueios | Nenhum local; backend e Assessments fora do recorte. |
| Tempo realmente usado | 1 h 24 min acumulados, às 12:45 BRT. |
| Estimativa restante | 1–2 h para V2.10; 8 h 36 min da janela. |
| Próximo item exato | RED das duas ações no primeiro modelo. |
| Conhecimento capturado | `no-op`: contrato aprovado no programa. |

## 16.36. V2.10 Rotina diária — local-green — 2026-08-28

**Entrega atual V2:** 83,33% (5/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Diretório e editores locais de Rotina diária em `/dev/daily-routine`. |
| Arquivos alterados | `daily_routine_pages.dart`; `daily_routine_form_sections.dart`; `superadmin_router.dart`; testes de diretório/rotas; spec e tracker. |
| Correções realizadas | CTA agora é `Criar modelo`; cards mantêm status, versão, origem e efetividade e mostram ações gerenciáveis de duplicação e criação de rotina por modelo. Rotas `/dev` criam rascunho duplicado e aplicação herdada do modelo com fixture local compartilhada. Produção continua sem ação quando a capability não foi fornecida. |
| Testes e resultados | REDs reproduzidos; GREEN 16/16 diretório+rotas; analyzer focado, validador visual e diff-check verdes. |
| Inspeções responsivas | Card rico em 375/768/1024/1440 com texto 200%; ações quebram linha sem overflow e preservam rótulo/ícone/alvo. |
| Bloqueios | Persistência/backend fora do recorte; nenhum sucesso remoto simulado. Aceite visual humano pendente. Assessments intocado. |
| Tempo realmente usado | 0 h 11 min; 1 h 35 min acumulados, às 12:56 BRT. |
| Estimativa restante | 8 h 25 min da janela; V2.11 = 1–2 h. |
| Próximo item exato | V2.11 Acompanhamento do aluno: inventário da rota visível e RED de navegação com exemplos locais. |
| Conhecimento capturado | `no-op`: contrato já aprovado foi aplicado sem nova regra durável. |

## 16.37. V2.11 Acompanhamento do aluno — abertura — 2026-08-28

**Entrega atual V2:** 83,33% (5/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | `Acompanhamento de alunos`, produção e `/dev/students`. |
| Inventário | Página read-only e testes canônicos existem, mas `/dev/students` usa repository indisponível e não demonstra os exemplos locais pedidos. Produção está corretamente fail-closed. |
| Testes planejados | RED de rota `/dev` com aluno, contexto e indicadores locais, sem tocar repository produtivo; regressão da suíte read-only e matriz responsiva. |
| Bloqueios | Commands de gestão e backend permanecem fora do recorte; Assessments intocado. |
| Tempo realmente usado | 1 h 37 min acumulados, às 12:58 BRT. |
| Estimativa restante | 1–2 h para V2.11; 8 h 23 min da janela. |
| Próximo item exato | RED da fixture navegável em `/dev/students`. |
| Conhecimento capturado | `no-op`: o contrato read-only já é canônico. |

## 16.38. V2.11 Acompanhamento do aluno — local-green — 2026-08-28

**Entrega atual V2:** 100,00% (6/6). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; V2 completa localmente; aceite visual humano pendente. |
| Tela e rota | Acompanhamento do aluno em `/students` e `/dev/students`; gestão segue indisponível. |
| Arquivos alterados | `development_student_tracking_repository.dart`; `superadmin_router.dart`; `student_tracking_fail_closed_routes_test.dart`; spec e tracker. |
| Correções realizadas | Rota `/dev` deixou o estado indisponível e passou a carregar fixture read-only com duas crianças, contextos, períodos e exemplos completos de acompanhamento. Repository produtivo não é chamado e rotas de gestão continuam fail-closed. |
| Testes e resultados | RED reproduzido; GREEN 45/45 Acompanhamento+rotas+navegação; analyzer focado, validador visual e diff-check verdes. Invocação inicial do validador no cwd errado falhou por caminho; repetição correta em `apps/catalog` saiu 0. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%, light/dark, teclado e reduced motion pela suíte canônica; seletores e tabs cobertos. |
| Bloqueios | Gerenciamento, backend e E2E fora do recorte; aceite humano pendente. Assessments intocado. |
| Tempo realmente usado | 0 h 04 min; 1 h 41 min acumulados, às 13:02 BRT. |
| Estimativa restante | 8 h 19 min da janela; V3.12 = 1–2 h. |
| Próximo item exato | V3.12 Segurança infantil: inventário de diretório/wizard e primeiro RED de navegação. |
| Conhecimento capturado | `no-op`: comportamento read-only já aprovado; apenas fixture local segura. |

## 16.39. V3.12 Segurança infantil — abertura — 2026-08-28

**Entrega atual V3:** 0,00% (0/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Diretório e wizard de Segurança infantil, produção e `/dev`. |
| Baseline consultado | Instituições, Cards/Tabela, filtros/flyouts, wizard canônico e rodapé universal. |
| Testes planejados | RED do primeiro ponto morto entre diretório, criação, revisão e edição; matriz responsiva e regressão depois do GREEN. |
| Bloqueios | Backend/Supabase e Assessments fora do recorte. |
| Tempo realmente usado | 1 h 42 min acumulados, às 13:03 BRT. |
| Estimativa restante | 1–2 h para V3.12; 8 h 18 min da janela. |
| Próximo item exato | Inventário de rotas, callbacks e passos do wizard. |
| Conhecimento capturado | Pendente do inventário; não criar memória sem regra durável aprovada. |

## 16.40. V3.12 Segurança infantil — local-green — 2026-08-28

**Entrega atual V3:** 14,29% (1/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Diretório, criação, detalhe e edição de Segurança infantil em `/dev`. |
| Arquivos alterados | `dev_child_safety_repository.dart`; `superadmin_routes.dart`; `superadmin_router.dart`; `safety_routes_test.dart`; spec e tracker. |
| Correções realizadas | Repositório local ganhou três exemplos e busca de crianças; rota de edição `/dev` foi declarada; detalhe liga cadastro e edição; wizard de quatro passos permanece canônico e localmente salvável. Produção permanece sem mutation callbacks quando indisponíveis. |
| Testes e resultados | RED reproduzido; GREEN 20 testes funcionais Segurança/rotas; analyzer focado, validador visual e diff-check verdes. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%, light/dark; cards/tabela, detalhe e wizard cobertos. Rota integral exercitada em 375. |
| Bloqueios | Golden antigo diverge 9,84%, concentrado no shell alterado na V1; resultado atual inspecionado e não promovido. Backend/E2E e aceite humano pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 05 min; 1 h 46 min acumulados, às 13:07 BRT. |
| Estimativa restante | 8 h 14 min da janela; V3.13 = 1–2 h. |
| Próximo item exato | V3.13 Usuários internos: inventário de edição, máscara de CPF e calendário Coelo. |
| Conhecimento capturado | `no-op`: sem regra durável nova. |

## 16.41. V3.13 Usuários internos — abertura — 2026-08-28

**Entrega atual V3:** 14,29% (1/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Usuários internos/plataforma, diretório e formulário `/dev`. |
| Testes planejados | RED de deep link de edição, máscara de CPF e calendário Coelo conforme gaps reais. |
| Bloqueios | Backend/Supabase e Assessments fora do recorte. |
| Tempo realmente usado | 1 h 47 min acumulados, às 13:08 BRT. |
| Estimativa restante | 1–2 h para V3.13; 8 h 13 min da janela. |
| Próximo item exato | Inventário de arquivos, rotas e controles de CPF/data. |
| Conhecimento capturado | Pendente; não criar memória sem regra durável aprovada. |

## 16.42. V3.13 Usuários internos — local-green — 2026-08-28

**Entrega atual V3:** 28,57% (2/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Criação/edição de Usuários internos em `/dev/internal-users`. |
| Arquivos alterados | `platform_user_form_page.dart`; `coelo_date_range_picker.dart`; testes correspondentes; spec e tracker. |
| Correções realizadas | CPF ganhou máscara progressiva e edição inicial formatada; nascimento passou a calendário Coelo com seleção única, sem datas futuras; edição local e rodapé canônico preservados. |
| Testes e resultados | REDs reproduzidos; GREEN 28/28 não-golden+rotas e 11/11 calendário; analyzers focados, validador visual e diff-check verdes. Duas invocações no cwd errado falharam por caminho e foram repetidas corretamente. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%; create light 375 e edit dark 1440 inspecionados; foco/Escape/retorno do calendário cobertos. |
| Bloqueios | Goldens antigos divergiram 0,41%–47,07% e não foram atualizados; deltas pequenos são o campo novo, grandes permanecem no shell V1. Backend/E2E e aceite humano pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 08 min; 1 h 54 min acumulados, às 13:15 BRT. |
| Estimativa restante | 8 h 06 min da janela; V3.14 = 1–2 h. |
| Próximo item exato | V3.14 Perfis e modelos de acesso: inventário de lista/criação/detalhe/edição. |
| Conhecimento capturado | `no-op`: requisito já aprovado, sem regra durável nova. |

## 16.43. V3.14 Perfis e modelos de acesso — abertura — 2026-08-28

**Entrega atual V3:** 28,57% (2/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Perfis e permissões/Modelos de perfil em `/dev`. |
| Baseline consultado | `access-profiles-superadmin`, Instituições, diretório e wizard/rodapé canônicos. |
| Testes planejados | RED do primeiro elo ausente em lista → criação → detalhe → edição local. |
| Bloqueios | Backend/Supabase e Assessments fora do recorte. |
| Tempo realmente usado | 1 h 55 min acumulados, às 13:16 BRT. |
| Estimativa restante | 1–2 h para V3.14; 8 h 05 min da janela. |
| Próximo item exato | Inventário de rotas, callbacks e repository local. |
| Conhecimento capturado | Pendente; não criar memória sem regra durável aprovada. |

## 16.44. V3.14 Perfis e modelos de acesso — local-green — 2026-08-28

**Entrega atual V3:** 42,86% (3/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Perfis `/dev/profiles` e Modelos `/dev/profile-models`, com lista/criação/detalhe/edição. |
| Arquivos alterados | Router/rotas; três páginas Access Profiles; novo teste de rotas; spec e tracker. |
| Correções realizadas | O menu `/dev` deixou de cair nas rotas produtivas 503. Oito rotas locais usam dois repositórios fake separados e ligam CTA, card, detalhe e edição. Modelos reutilizam o diretório/wizard canônico com título, CTA e destination próprios. Produção/backend não foram promovidos. |
| Testes e resultados | RED das oito rotas ausentes; GREEN 25/25 não-golden; analyzer focado, validador visual e diff-check verdes. Primeira chamada do validador sem argumentos falhou por uso e foi repetida com repo/allowlist corretos. |
| Inspeções responsivas | Matriz 375/768/1024/1440 × texto 100%/200% verde em Cards/Tabela, sem overflow; cliques CTA/card/edição exercitados. |
| Bloqueios | Goldens antigos comparados e não atualizados: divergências 4,36%–79,97%, concentradas no shell V1; aceite humano, backend e E2E pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 08 min; 2 h 03 min acumulados, às 13:24 BRT. |
| Estimativa restante | 7 h 57 min da janela; V3.15 = 1–2 h. |
| Próximo item exato | V3.15 Perfis de cuidado: inventário de criação/edição pelo wizard canônico e primeiro RED. |
| Conhecimento capturado | `no-op`: nenhuma regra durável nova. |

## 16.45. V3.15 Perfis de cuidado — abertura — 2026-08-28

**Entrega atual V3:** 42,86% (3/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Perfis de cuidado em `/dev/health-care/profiles`, da lista à edição. |
| Baseline consultado | Wizard/formulário de Instituições, rodapé universal e diretório canônico. |
| Testes planejados | RED do primeiro elo ausente na navegação integral e regressão do wizard responsivo. |
| Bloqueios | Backend/Supabase, Medicação e Assessments fora do recorte. |
| Tempo realmente usado | 2 h 05 min acumulados, às 13:26 BRT. |
| Estimativa restante | 1–2 h para V3.15; 7 h 55 min da janela. |
| Próximo item exato | Inventário das páginas, callbacks, etapas e testes de Perfis de cuidado. |
| Conhecimento capturado | Pendente; não criar memória sem regra durável aprovada. |

## 16.46. V3.15 Perfis de cuidado — local-green — 2026-08-28

**Entrega atual V3:** 57,14% (4/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Perfis de cuidado: diretório, criação e edição em `/dev/health-care/profiles`. |
| Arquivos alterados | Router; novo teste integral de rota; ajuste de regressão dos formulários; spec e tracker. |
| Correções realizadas | Card abre diretamente a edição local; cancelamento e save retornam ao diretório sem depender de redirect/stack. Wizard de quatro passos e rodapé universal preservados; launcher sem destino permanece oculto. Produção não foi alterada. |
| Testes e resultados | RED do card/rota; GREEN 37/37 focados; analyzer e validador visual verdes. Três testes legados de launcher foram corrigidos para o contrato fail-closed V1. Analyzer lançado uma vez no cwd do Catálogo falhou por path e foi repetido no Superadmin. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%, light/dark, wizard, rodapé e ausência de overflow. CTA/card/edição/cancelamento exercitados. |
| Bloqueios | Quatro cenários de golden antigo falharam sem atualização; exemplos do diretório 9,52%–18,37% por mudanças já existentes do shell. Aceite humano, backend e E2E pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 10 min; 2 h 15 min acumulados, às 13:36 BRT. |
| Estimativa restante | 7 h 45 min da janela; V3.16 = 1–2 h. |
| Próximo item exato | V3.16 Medicação: inventário da família `/dev/health-care/medication-plans` e primeiro RED. |
| Conhecimento capturado | `no-op`: nenhuma regra durável nova. |

## 16.47. V3.16 Medicação — diretório, criação, detalhe e edição — abertura — 2026-08-28

**Entrega atual V3:** 57,14% (4/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Medicação em `/dev/health-care/medication-plans`, lista/criação/detalhe/edição. |
| Baseline consultado | Diretório Instituições, Cards/Tabela e wizard/rodapé canônicos. |
| Testes planejados | RED do primeiro elo morto ou retorno instável na cadeia local. |
| Bloqueios | Backend/Supabase, datas/espaçamento V3.17 e Assessments fora do recorte. |
| Tempo realmente usado | 2 h 17 min acumulados, às 13:38 BRT. |
| Estimativa restante | 1–2 h para V3.16; 7 h 43 min da janela. |
| Próximo item exato | Inventário das rotas, repository dev, cards/linhas e callbacks. |
| Conhecimento capturado | Pendente; não criar memória sem regra durável aprovada. |

## 16.48. V3.16 Medicação — diretório, criação, detalhe e edição — local-green — 2026-08-28

**Entrega atual V3:** 71,43% (5/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Medicação `/dev/health-care/medication-plans`: lista/criação/edição e deep link de detalhe compatível. |
| Arquivos alterados | Router; teste integral de Health Care; spec e tracker. |
| Correções realizadas | Card abre edição diretamente e não retorna à lista pelo redirect intermediário. Fixture local prova criação, reabertura, edição e versionamento; repository produtivo segue sem chamadas. |
| Testes e resultados | RED do clique real; GREEN 37/37; analyzer focado e validador visual verdes. |
| Inspeções responsivas | 375/768/1024/1440, texto 200% pela matriz canônica; card/linha, wizard e rodapé preservados. |
| Bloqueios | Goldens de Health Care já comparados no item anterior e não atualizados; backend/upload/E2E pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 01 min; 2 h 18 min acumulados, às 13:39 BRT. |
| Estimativa restante | 7 h 42 min da janela; V3.17 = 1–2 h. |
| Próximo item exato | V3.17 Medicação: RED de datas e espaçamento do wizard. |
| Conhecimento capturado | `no-op`: nenhuma regra durável nova. |

## 16.49. V3.17 Medicação — datas e espaçamento do wizard — abertura — 2026-08-28

**Entrega atual V3:** 71,43% (5/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`. |
| Tela e rota | Wizard criar/editar Medicação `/dev/health-care/medication-plans/...`. |
| Baseline consultado | Calendário Coelo, estados de interação, wizard de Instituições e rodapé universal. |
| Testes planejados | RED do primeiro campo de vigência cru ou gutter/overflow divergente. |
| Bloqueios | Horários V3.18, backend/Supabase e Assessments fora do recorte. |
| Tempo realmente usado | 2 h 20 min acumulados, às 13:41 BRT. |
| Estimativa restante | 1–2 h para V3.17; 7 h 40 min da janela. |
| Próximo item exato | Inventário de `health_medication_form_sections.dart` e testes de datas/responsividade. |
| Conhecimento capturado | Pendente; não criar memória sem regra durável aprovada. |

## 16.50. V3.17 Medicação — datas e espaçamento do wizard — local-green — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `local-green`; aceite visual humano pendente. |
| Tela e rota | Vigência do wizard Medicação em criação/edição `/dev`. |
| Arquivos alterados | Spec e tracker; produção `no-op`. |
| Correções realizadas | Nenhuma necessária: datas já usam calendário Coelo single-date; intervalo inválido é bloqueado semanticamente; grid e rodapé já seguem gutters canônicos. |
| Testes e resultados | Evidência do gate V3.16: 37/37, analyzer e validador verdes; cobertura explícita de calendário Coelo, datas inválidas e matriz responsiva. |
| Inspeções responsivas | 375/768/1024/1440, texto 200%, empilhamento sem clipping/overflow e rodapé universal. |
| Bloqueios | Goldens antigos já comparados sem promoção; aceite humano, backend e E2E pendentes. Assessments intocado. |
| Tempo realmente usado | 0 h 01 min; 2 h 21 min acumulados, às 13:42 BRT. |
| Estimativa restante | 7 h 39 min da janela; V3.18 = 1–2 h. |
| Próximo item exato | V3.18 Cardápio/modelo: promover `pattern.coelo-time-picker` antes do código, então implementar hora Coelo e detalhes. |
| Conhecimento capturado | `no-op`: nenhuma regra durável nova. |

## 16.51. V3.18 Cardápio/modelo — abertura e gate de padrão — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`, bloqueado antes de produção pela aprovação explícita de `pattern.coelo-time-picker`. |
| Tela e rota | Cardápio/Modelo `/dev/meal-plans/...`; extração também convergirá o diálogo privado de data/hora e o picker Material de Medicação. |
| Arquivos alterados | Referência `coelo-time-picker.md`, `coelo-ui/SKILL.md`, índice do catálogo, spec e tracker. |
| Inventário | Cardápio tem campos textuais HH:mm posicionados antes do nome; detalhes são campo simples. `CoeloDateTimeField` possui diálogo privado reaproveitável; Medicação usa `showTimePicker`. |
| Proposta | `CoeloTimeField` + `showCoeloTimePicker` no `coelo_ui_core`; surface neutra, HH:mm 24 h, Cancelar/Aplicar, teclado, Escape e retorno de foco; sem novos tokens ou variantes futuras. |
| Testes planejados | REDs públicos de abertura/retorno de foco/erro/disabled/semântica/200%; catálogo; goldens open light/375 e dark/1440; matriz V3.18 completa. |
| Bloqueios | Aprovação visual/API humana obrigatória pela skill. Backend/Supabase e Assessments seguem fora do recorte. |
| Tempo realmente usado | 0 h 03 min; 2 h 24 min acumulados, às 13:44 BRT. |
| Estimativa restante | 7 h 36 min da janela; V3.18 requer 1–2 h após aprovação. |
| Próximo item exato | Obter aprovação da extração/API/goldens; escrever primeiro RED em `coelo_ui_core`. |
| Conhecimento capturado | `no-op`: proposta ainda não aprovada, portanto não entra em `docs/knowledge`. |

## 16.52. V3.18 Cardápio/modelo — aprovação do padrão — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`; bloqueio de aprovação removido. |
| Aprovação | Owner aprovou a imagem mobile light/375 + desktop dark/1440 e autorizou a API mínima `CoeloTimeField`/`showCoeloTimePicker`. |
| Arquivos alterados | Referência pública, skill, índice, spec e tracker. |
| Escopo desbloqueado | RED→GREEN no core; catálogo e goldens; Cardápio/Modelo; convergência de `CoeloDateTimeField` e Medicação. |
| Bloqueios restantes | `local-green` exige testes/goldens/inspeções reais; `accepted` do entregável exige nova aprovação visual da implementação. Backend/Supabase e Assessments permanecem fora. |
| Tempo realmente usado | 2 h 24 min acumulados, às 14:40 BRT. |
| Estimativa restante | 7 h 36 min da janela; V3.18 = 1–2 h. |
| Próximo item exato | RED público do seletor em `packages/coelo_ui_core/test`. |
| Conhecimento capturado | `no-op`: decisão visual pertence à fonte canônica da skill/spec. |

## 16.53. V3.18 Cardápio/modelo — implementação GREEN, aceite visual pendente — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`; implementação GREEN, goldens reais aguardam aceite humano. |
| Arquivos alterados | Core time picker/date-time; Cardápio; Medicação; catálogo; testes comportamentais e dois PNGs golden; spec/tracker. |
| Correções realizadas | API pública isolada de hora; diálogo surface `HH:mm`; teclado/Escape/foco/erro/disabled; Cardápio usa início/fim após nome e detalhes multilinha; Medicação remove picker Material. |
| Testes e resultados | Core 8/8; Cardápio/Medicação 17/17; catálogo 1/1; analyzers focados e validador visual verdes; goldens comparados sem diferença após geração autorizada. |
| Regressões encontradas | Primeira imagem usou fonte Ahem e foi rejeitada; loader de Nunito Sans/Material Icons corrigiu a evidência. Analyzer encontrou import redundante e helper `_timeLabel` órfão; ambos removidos e gates repetidos verdes. |
| Inspeções | Golden light/375 e dark/1440 reais; teste 200% reempilha ações. 768/1024 e matriz final ainda pendentes. |
| Bloqueios | Aprovação humana dos PNGs reais; depois concluir matriz e promover padrão a `implemented`. Assessments segue intocado. |
| Tempo realmente usado | 0 h 12 min desde aprovação; 2 h 36 min acumulados, às 14:52 BRT. |
| Estimativa restante | 7 h 24 min da janela; 30–60 min para fechar V3.18. |
| Próximo item exato | Owner aprovar/reprovar os dois goldens reais exibidos. |
| Conhecimento capturado | `no-op`: implementação do padrão já documentado na fonte canônica. |

## 16.54. V3.18 Cardápio/modelo — aceite dos goldens reais — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`; aceite visual dos goldens reais confirmado pelo Owner. |
| Decisão | Promover `pattern.coelo-time-picker` a `implemented`; este aceite não será solicitado novamente. |
| Bloqueios | Apenas gates técnicos finais de V3.18; backend/Supabase e Assessments seguem fora. |
| Próximo item exato | Matriz 768/1024 + catálogo completo + gates finais; depois V4.19. |

## 16.55. Programa visual — gate humano por entregável — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Mudança solicitada | Antes de qualquer entregável visual restante: parar, mostrar imagem e caminho absoluto, explicar escopo e aguardar aprovação explícita antes do código. |
| Estado atual | V3.18 já aprovado em contrato e goldens; somente gates técnicos podem continuar sem novo aceite. |
| Regressão | Catálogo completo expôs `publicFile` incompatível com o inventário de componentes implementados; índice corrigido para o barrel do package, preservando a referência pública da skill. |
| Próximo aceite | Imagens completas de V4.19 Diretório de Formulários, antes de qualquer RED/produção desse item. |
| Conhecimento capturado | Regra processual registrada na spec e tracker; `docs/knowledge` permanece `no-op`. |

## 16.56. V4/V5 — pacote visual de alta fidelidade aguardando aprovação — 2026-08-28 15:58 BRT

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Campo | Registro factual |
|---|---|
| Status | `in-progress`; pausa obrigatória para aceite visual antecipado de V4/V5. |
| Evidência rejeitada | Grades/HTML anteriores eram wireframes coloridos; Owner rejeitou. Foram invalidados e não concedem aceite a nenhum item. |
| Evidência substituta | Capturas individuais Flutter reais, com fonte legível, nos viewports administrativos 1440×1000 e Principal 430/520×900/1000. Propostas não implementadas usam captura Flutter como base e são identificadas como composição de alta fidelidade. |
| Formulários | Proposta 19 reproduz o card de criação de Instituições e não adiciona botão superior. Proposta 20 preserva wizard/rodapé canônicos e detalha o builder de seções, perguntas, opções, mídia, obrigatoriedade e ramificação. Patch temporário de captura revertido; zero diff real em Forms/router. |
| Telas e rotas | `/dev/forms`, `/dev/forms/new`, `/dev/imports`, `/dev/imports/new`, `/dev/notices`, `/dev/principal-happens`, `/dev/principal-for-you`, `/dev/principal-now`, `/dev/principal-moments`, `/dev/principal-profile` e três composers Principal. Circulares usa goldens Flutter reais do componente ainda sem rota pública própria. |
| Arquivos alterados | Somente spec/tracker para registrar o gate; imagens e scripts ficam fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. Nenhum arquivo Assessments tocado. |
| Testes e resultados | `flutter build web --debug --no-web-resources-cdn` GREEN; rotas capturadas do build local; patches temporários de Forms revertidos com blobs iguais ao índice Git; `git diff --check` sem erro novo. |
| Inspeções | Todas as imagens revisadas em resolução original; texto legível, shell/tokens/fontes reais e ausência de cortes nas evidências escolhidas. `actual-31b-now-composer-520.png` substitui a captura 430 com corte. |
| Bloqueios | Aceite ou ajustes do Owner por número; nenhum código V4/V5 começa antes do `okay` final. |
| Tempo realmente usado | 3 h 41 min acumulados às 15:58 BRT. |
| Estimativa restante | 6 h 19 min da janela inicial; o programa V1–V5 continuará por checkpoint seguro quando a janela acabar. |
| Próximo item exato | Exibir imagens individuais; registrar aprovações/ajustes; aguardar `okay`; então fechar V3.18 e iniciar V4.19 RED→GREEN. |
| Conhecimento capturado | `no-op` até aprovação humana. |

## 16.57. V4/V5 — revisão humana das propostas e contratos corrigidos — 2026-08-28

**Entrega atual V3:** 85,71% (6/7). **Programa visual:** 0/31 `accepted`.
**Flutter local:** 84/207 (40,58%). **Flutter verified:** 0/207. **Supabase
local:** 3/37 (8,11%). **Supabase done:** 0/37. **Integração:** 0/202.
**Projeto estrito:** 0/229. E2E e estrito medem conclusão integral e não anulam
os GREENs locais.

| Item | Decisão do Owner e próximo ajuste |
|---|---|
| 19 Formulários | Direção aprovada parcialmente. Refazer em tabela canônica de Instituições, com criar no topo da tabela, status, contexto, visitas/respostas, agendamentos e menu por linha para editar, ativar/inativar, duplicar, copiar contexto e administrar agendamentos. Preservar shell + contêiner direito. |
| 20A/20B Editor | Refazer seguindo anexos 8–26 e a anatomia modular de Rotina diária: seções, catálogo pesquisável de tipos, duplicação/cópia, ordenação, mídia, obrigatoriedade, escolhas, ramificação e preview. Pergunta Data aceita `livre`, `a partir de`, `até` e `intervalo permitido`. Preservar shell + contêiner direito. |
| 21 Importações | Diretório simples em tabela, como Instituições, com criar/importar no topo. Wizard dentro do shell + contêiner direito e catálogo visível de instituições, unidades, pessoas, turmas/grupos, atividades e demais entidades pertinentes, ainda que a execução permaneça `Indisponível nesta etapa`. |
| 22 Comunicações | Proposta rejeitada. Refazer pela anatomia responsiva do anexo 27: busca, filtros aplicados, categorias com contagem, tabela/lista, paginação e prévia rica lateral. |
| 23 Circulares | Card de Perfil aprovado com pedido de refinamento visual. Composer atual é boa base, mas deve depender primeiro do builder de Formulários e reutilizar seções/perguntas modulares. |
| 24 Acontece | `visual-contract-approved`. Agora no topo como carrossel horizontal sem `Ver tudo`; primeiro card retangular publica Agora. Abaixo, título discreto Acontece e feed conjunto de publicações Acontece + Circulares. Cabeçalho Principal usa marca Coelo + chevron para menu e avatar; sem hambúrguer. Shell, contêiner direito e espaçamentos canônicos são correções obrigatórias de execução. Menu inferior em mobile/tablet/web: Home, Para você, ação central `+` de publicar Agora, Momentos e Pesquisar; o `+` atravessa o topo da barra em 50/50 e o web usa dock compacto, não largura total. Mensagens permanece flutuante; Perfil não entra no rodapé. |
| 25/29 Agora e Momentos | Item 25 Agora `visual-contract-approved`: viewer imersivo fullscreen, mídia vertical, progressão, autoria, contexto, audiência, resposta e ações Coelo; mobile edge-to-edge, tablet centralizado e web com prévias laterais discretas. O shell fica temporariamente suspenso. Item 29 Momentos ainda precisa de aprovação visual própria. |
| 26 Galeria | Contrato visual aprovado pelo Owner. Não solicitar novamente o mesmo aceite; implementação/golden real ainda serão necessários antes do status final `accepted`. |
| 27/31 Composers | Refazer pela anatomia dos anexos 34/36, mantendo no web shell, contêiner direito e espaçamento Coelo. O mesmo contrato adapta Acontece, Momentos e Agora aos respectivos contextos. |
| 28 Para você | Refazer conforme anatomia responsiva do anexo 35, sem copiar identidade externa. |
| 30 Perfil | Refazer cabeçalho conforme contrato Principal; avatar não pode ser cortado e a capa deve ocupar toda a largura disponível. |

Arquivos de referência do Owner: `codex-clipboard-8c61aca7...png` a
`codex-clipboard-6a2b8db4...png` (anexos 1–36). Servem somente para anatomia,
proporção e comportamento; identidade permanece Nunito Sans, `#D63C00`,
`#3F4549`, tokens semânticos, light/dark e componentes Coelo.

Status: `in-progress`, sem código V4/V5 autorizado ainda. Próximo item exato:
refazer as imagens de aprovação 19, 20, 21, 22, 23A, 24, 25, 27, 28, 29,
30 e 31; não refazer 26. `docs/knowledge` permanece `no-op` até o aceite das
novas propostas.

## 16.58. V4/V5 — pacote visual revisado após feedback — 2026-08-28

| Campo | Estado |
|---|---|
| Objetivo | Materializar o feedback do Owner em pranchas Coelo legíveis, separadas e de alta fidelidade antes de qualquer implementação V4/V5. |
| Incluído | 19 diretório e agendamento; 20 overview do builder e catálogo; 21A diretório e 21B wizard; 22 diretório responsivo/preview; 24 Acontece; 25 Agora fullscreen; 27 composer; 28 Para você; 29 Momentos fullscreen; 30 Perfil; 31A/31B composers. |
| Circulares | 23A e 23B preservam os goldens já considerados praticamente aprovados; 23A recebe polimento no ciclo produtivo e 23B fica explicitamente dependente do builder modular de Formulários. |
| Item 26 | Mantido `visual-contract-approved`; não foi redesenhado nem reapresentado como pendência. Ainda não conta como `accepted` do programa. |
| Evidências | `revised-forms-list.png`, `revised-forms-directory.png`, `revised-forms-editor-overview.png`, `revised-forms-editor.png`, `revised-imports-directory.png`, `revised-import-wizard.png`, `revised-communications.png`, `revised-happens.png`, `revised-now.png`, `revised-composer.png`, `revised-for-you.png`, `revised-moments.png`, `revised-profile.png`, `revised-moment-composer.png` e `revised-now-composer.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Inspeção | Pranchas renderizadas em 1440×900 ou 430×900 com Nunito Sans, shell/tokens Coelo, texto legível, contêiner canônico e fotografias das fixtures locais. |
| Código de produção | Nenhum arquivo Flutter/Supabase de V4/V5 alterado; protótipo visual permanece fora do repositório. Arquivos Assessment protegidos não foram tocados. |
| Gate | Aguardar aprovações/ajustes por item e o `okay` final do Owner antes de fechar V3.18 e iniciar V4.19 RED→GREEN. |
| Conhecimento capturado | `no-op`: decisões estão sincronizadas na spec canônica, mas nenhuma projeção em `docs/knowledge` será criada antes do aceite final. |

## 16.59. V4/V5 — segunda rodada rejeitada por baixa fidelidade — 2026-08-28

| Campo | Estado |
|---|---|
| Avaliação do Owner | A ideia e a anatomia ficaram boas, porém as imagens continuam com aparência de `wireframe colorido` e não dão confiança de fidelidade ao resultado Flutter. |
| Consequência | Nenhuma prancha de 19–25 ou 27–31 recebe aceite visual. O contador do programa permanece 0/31 `accepted`; somente o contrato já aprovado do item 26 continua registrado separadamente. |
| Causa | As pranchas foram compostas em HTML com aproximações de componentes, ícones, densidade, estados e mídia, em vez de serem renderizadas pelos componentes Flutter canônicos do Coelo. |
| Evidência descartada | Todos os arquivos `revised-*.png` da seção 16.58 ficam classificados como rascunhos estruturais rejeitados e não podem orientar golden ou implementação. |
| Método corrigido | Gerar a próxima evidência a partir de Flutter real: shell atual, tokens, Nunito Sans, `CoeloAdminListingToolbar`, `CoeloAdminResizableTable`, `CoeloAdminPagination`, `CoeloAdminFlyout`, campos e fixtures reais. Superfície ainda ausente usa harness visual isolado, sem backend, rota produtiva ou promoção funcional. |
| Redução de risco | Produzir primeiro um piloto fiel do item 19. Somente após calibrar essa qualidade com o Owner, repetir o método nos demais itens. |
| Código de produção | Continua sem autorização para V4/V5. Nenhum aceite visual ou estrutural autoriza integração, backend ou declaração de conclusão. |
| Conhecimento capturado | `no-op`: rejeição e método ficam na spec/tracker de trabalho; não há conhecimento aprovado para `docs/knowledge`. |

## 16.60. V4.19 — piloto de fidelidade renderizado pelo Flutter real — 2026-08-28

| Campo | Estado |
|---|---|
| Objetivo | Calibrar o nível de fidelidade visual antes de reconstruir todo o pacote V4/V5. |
| Baseline | Golden `institution_directory_table_light_1440.png` e implementação real de Instituições. |
| Componentes reais | `SuperadminShell`, `CoeloAdminListingToolbar`, `CoeloSearchField`, `CoeloAdminMultiSelectField`, `CoeloAdminSingleSelectField`, `CoeloAdminCreateAction.banner`, `CoeloAdminResizableTable`, `CoeloAdminPagination`, `CoeloAdminFlyout`, `CoeloAdminDialogShell`, `CoeloAdminToggleField` e `CoeloFormTextField`. |
| Estados capturados | Diretório padrão, flyout de ações aberto e edição de agendamento. |
| Evidências | `pilot-19-flutter-directory.png`, `pilot-19-flutter-actions.png` e `pilot-19-flutter-schedule.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Teste | Harness isolado executado com `flutter test test/visual_pilot_19_test.dart`: 1/1 GREEN; harness removido imediatamente após as capturas. |
| Produção | Nenhum arquivo produtivo V4/V5 alterado; nenhuma rota, backend, fixture produtiva ou contrato público criado. |
| Gate | Aguardar avaliação do Owner sobre a fidelidade deste piloto. Não replicar aos demais itens antes dessa calibração. |
| Conhecimento capturado | `no-op`: o piloto ainda não foi aprovado. |

## 16.61. V4.19 — contrato visual aprovado com correções obrigatórias — 2026-08-28

| Campo | Estado |
|---|---|
| Decisão do Owner | Piloto considerado aprovado para orientar a implementação. |
| Status correto | `visual-contract-approved`; não é `accepted`, `local-green`, integração ou conclusão do entregável. Programa visual permanece 0/31 `accepted`. |
| Tabela | Reproduzir 100% o alinhamento das fontes, baseline tipográfica, altura e padding de células da tabela de Instituições; a aproximação do piloto não é aceita como delta permanente. |
| Paginação | Usar literalmente o posicionamento, alinhamento e espaçamento da paginação da tela de Instituições; a paginação deslocada para a direita no piloto não é aceita como delta permanente. |
| Toolbar | Corrigir alinhamento, largura e espaçamento de busca, filtros e ações pela implementação responsiva literal de Instituições. |
| Flyout | Preservar largura útil/painel canônicos, mas afastar a superfície da borda direita pela safe area/gap tokenizado; contorno usa `outlineVariant` suave e não pode aparentar preto ou pesado. |
| Agendamento | Eliminar o espaço branco excedente; altura da superfície acompanha o conteúdo, preservando `CoeloAdminDialogShell`, ações 50/50 e comportamento responsivo. |
| Evidência de aceite futuro | Golden Flutter real do diretório, flyout e agendamento, comparado à baseline de Instituições e aprovado visualmente pelo Owner. |
| Próximo item visual | V4.20 Editor de Formulários, pelo mesmo método Flutter real; nenhum RED/produção V4 começa antes do `okay` final do pacote. |
| Conhecimento capturado | `no-op`: contrato já está na spec canônica; projeção em `docs/knowledge` aguarda o aceite final do conjunto. |

## 16.62. V4.20 — proposta visual Flutter real aguardando avaliação — 2026-08-28

| Campo | Estado |
|---|---|
| Escopo visual | Editor modular de Formulários dentro do `SuperadminShell`, com rail de seções, canvas de perguntas, preview contínuo, catálogo pesquisável, validação de Data e ramificação por resposta. |
| Estados capturados | Visão geral; catálogo com os onze tipos mínimos; Data em modo `Intervalo permitido` junto de Sim/Não com pergunta Foto aninhada no caminho `Sim`. |
| Componentes reais | `SuperadminShell`, `CoeloFormTextField`, `CoeloAdminSingleSelectField`, `CoeloAdminToggleField`, `CoeloAdminInteractiveCard`, `CoeloAdminCreateAction` e `CoeloSearchField`, além de tokens oficiais. |
| Evidências | `pilot-20-flutter-overview.png`, `pilot-20-flutter-types.png` e `pilot-20-flutter-date-branch.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Teste | Harness isolado executado com `flutter test test/visual_pilot_20_test.dart`: 1/1 GREEN; harness removido imediatamente após as capturas. |
| Produção | Nenhum arquivo produtivo V4/V5 alterado; nenhuma rota, backend, fixture produtiva ou contrato público criado. |
| Status correto | Proposta visual aguardando avaliação; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Gate | Aguardar avaliação do Owner. Não iniciar RED/produção V4 antes do `okay` final do pacote visual. |
| Conhecimento capturado | `no-op`: nenhuma decisão durável nova foi aprovada nesta etapa. |

## 16.63. V4.20 — contrato visual aprovado com correções obrigatórias — 2026-08-28

| Campo | Estado |
|---|---|
| Decisão do Owner | Proposta considerada aprovada para orientar a implementação, condicionada aos ajustes abaixo. |
| Status correto | `visual-contract-approved`; não é `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Preview | Nasce oculto e só ocupa espaço quando o usuário solicitar a prévia. |
| Catálogo | Tipos aparecem em categorias verticais explícitas — `Texto e números`, `Escolhas`, `Mídias` e demais grupos pertinentes — uma abaixo da outra, com rolagem própria. |
| Superfície | Conteiner principal usa `colorScheme.surface`; cinza estrutural/global é proibido. |
| Ações | Remover Salvar e Preview do cabeçalho; reutilizar o rodapé canônico de Criar/Editar Instituição, com a hierarquia oficial. |
| Seções | Preservar rail e organização aprovados, refinando o marcador ativo; não usar círculo laranja com número preto. |
| Evidência de aceite futuro | Goldens Flutter reais com preview fechado por padrão, catálogo rolável categorizado, superfície neutra, seção refinada e `SuperadminFormActionFooter`, aprovados visualmente pelo Owner. |
| Próximo item visual | V4.21 Importações, pelo mesmo método Flutter real; nenhum RED/produção V4 começa antes do `okay` final do pacote. |
| Conhecimento capturado | `no-op`: o contrato foi consolidado na spec canônica; projeção em `docs/knowledge` aguarda o aceite final do conjunto. |

## 16.64. V4.21 — proposta visual Flutter real aguardando avaliação — 2026-08-28

| Campo | Estado |
|---|---|
| Escopo visual | Diretório de Importações e wizard administrativo dentro do `SuperadminShell`, seguindo Instituições e Criar/Editar Instituição. |
| Estados capturados | Histórico tabular com criação e paginação; seleção de entidade e contexto; mapeamento de colunas com indisponibilidade remota explícita. |
| Entidades visíveis | Instituições, Unidades, Pessoas, Grupos e turmas, Atividades, Planos de medicação, Cardápios e Formulários, em grid responsivo. |
| Componentes reais | `SuperadminShell`, `CoeloAdminListingToolbar`, `CoeloSearchField`, `CoeloAdminSingleSelectField`, `CoeloAdminCreateAction`, `CoeloAdminResizableTable`, `CoeloAdminPagination`, `SuperadminListingPaginationFooter`, `SuperadminFormFrame`, `SuperadminFormStepNavigation`, `SuperadminFormActionFooter` e `CoeloAdminInteractiveCard`. |
| Evidências | `pilot-21-flutter-directory.png`, `pilot-21-flutter-entity.png` e `pilot-21-flutter-mapping.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Teste | Harness isolado executado com `flutter test test/visual_pilot_21_test.dart`: 1/1 GREEN após ajuste responsivo; harness removido imediatamente após as capturas. |
| Produção | Nenhum arquivo produtivo V4/V5 alterado; nenhuma rota, backend, fixture produtiva ou contrato público criado. |
| Status correto | Proposta visual aguardando avaliação; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Gate | Aguardar avaliação do Owner. Não iniciar RED/produção V4 antes do `okay` final do pacote visual. |
| Conhecimento capturado | `no-op`: a proposta preserva conhecimento já registrado em `superadmin-operational-prototypes` e `superadmin-institution-form`; nenhuma regra nova foi aprovada. |

## 16.65. V4.21 — contrato visual aprovado com correção obrigatória — 2026-08-28

| Campo | Estado |
|---|---|
| Decisão do Owner | Proposta considerada aprovada para orientar a implementação. |
| Status correto | `visual-contract-approved`; não é `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Tabela | Reutilizar literalmente a tabela de Instituições: alinhamento horizontal e vertical do cabeçalho e das células, baseline tipográfica, alturas e paddings internos. A aproximação apresentada no piloto não é aceita como delta permanente. |
| Evidência de aceite futuro | Golden Flutter real do diretório comparado diretamente ao golden canônico de Instituições, além dos estados do wizard, e aprovado visualmente pelo Owner. |
| Próximo item visual | V4.22 Comunicações, pelo mesmo método Flutter real; nenhum RED/produção V4 começa antes do `okay` final do pacote. |
| Conhecimento capturado | `no-op`: a baseline literal de Instituições já é conhecimento canônico em `superadmin-operational-prototypes`; nenhuma projeção adicional é necessária. |

## 16.66. V4.22 — proposta visual Flutter real aguardando avaliação — 2026-08-28

| Campo | Estado |
|---|---|
| Escopo visual | Diretório responsivo de Comunicações do app dentro do `SuperadminShell`, com filtros aplicados, categorias, listagem e prévia rica do item selecionado. |
| Estados capturados | Mobile em cards; tablet em tabela; desktop em tabela com painel lateral de prévia e resumo. |
| Toolbar e categorias | Busca, Status, Período, Mais filtros, chips removíveis e ação Limpar filtros; abas lineares com contagem para Todos, Avisos, Conteúdos, Destaques e Para você. |
| Componentes reais | `SuperadminShell`, `CoeloAdminListingToolbar`, `CoeloSearchField`, `CoeloAdminSingleSelectField`, `SuperadminUnderlineTabs`, `CoeloAdminInteractiveCard`, `CoeloAdminResizableTable`, `CoeloAdminPagination`, `SuperadminListingPaginationFooter`, `CommunicationTypeBadge` e `NoticePopupPreview`. |
| Evidências | `pilot-22-flutter-mobile.png`, `pilot-22-flutter-tablet.png` e `pilot-22-flutter-desktop.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Teste | Harness isolado executado com `flutter test test/visual_pilot_22_test.dart`: 1/1 GREEN após correções responsivas e de contraste da prévia; harness removido imediatamente após as capturas. |
| Produção | Nenhum arquivo produtivo V4/V5 alterado; nenhuma rota, backend, fixture produtiva ou contrato público criado. |
| Status correto | Proposta visual aguardando avaliação; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Gate | Aguardar avaliação do Owner. Não iniciar RED/produção V4 antes do `okay` final do pacote visual. |
| Conhecimento capturado | `no-op`: a proposta aplica o conhecimento já registrado em `superadmin-notices-mvp`; nenhuma regra durável nova foi aprovada. |

## 16.67. V4.22 — proposta rejeitada e checkpoint seguro — 2026-08-28

| Campo | Estado |
|---|---|
| Decisão do Owner | As três evidências `pilot-22-flutter-*` foram rejeitadas: a tabela ficou fora do padrão e a composição não reproduziu a anatomia da referência enviada, ainda que a identidade final deva permanecer Coelo. |
| Status correto | `rejected` e `paused`; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Baseline obrigatória | Instituições deve ser reutilizada literalmente para toolbar, filtros, toggle, cards, tabela, alinhamentos, tipografia, alturas, paddings, estados, gaps e paginação. Aproximação local não é aceita. |
| Modos de visualização | Comunicações deve oferecer explicitamente `Cards` e `Tabela` pelo toggle segmentado canônico de Instituições. O breakpoint pode escolher o modo inicial mais adequado, mas não pode remover a escolha do usuário. |
| Referência anexada | `codex-clipboard-ed247b47-ba55-4574-aba2-0336ac85ed3a.png` orienta anatomia informacional/responsiva — categorias, filtros aplicados, densidade da tabela e preview lateral no desktop — traduzida aos componentes e tokens Coelo. |
| Evidência descartada | `pilot-22-flutter-mobile.png`, `pilot-22-flutter-tablet.png` e `pilot-22-flutter-desktop.png` não podem orientar implementação, golden ou aceite futuro. |
| Regra de retomada | Não ajustar, implementar nem enviar nova imagem espontaneamente. Aguardar o Owner pedir os ajustes; somente depois de a tela estar ajustada, enviar a nova evidência para aprovação. Não avançar ao próximo item visual enquanto este checkpoint estiver pausado. |
| Produção | Nenhum arquivo produtivo V4/V5 foi alterado; o harness já estava removido. Assessments permaneceu intocado. |
| Próximo item exato | Aguardar solicitação explícita do Owner para retomar os ajustes do item 22. |
| Conhecimento capturado | Contrato durável consolidado primeiro na spec canônica de Comunicações e projetado em `docs/knowledge/team/superadmin-notices-mvp.md`. |

## 16.68. V4.22 — proposta visual corrigida aguardando avaliação — 2026-08-31

| Campo | Estado |
|---|---|
| Retomada autorizada | O Owner solicitou continuar do checkpoint, mantendo o rito de aprovação tela a tela antes de qualquer implementação. |
| Baseline literal | Estrutura visual de Instituições: toolbar responsiva, toggle segmentado Cards/Tabela, criação na primeira posição, tabela com cabeçalho de 56 px, linhas de 64 px e paginação inferior canônica. |
| Estados capturados | Mobile em Cards; tablet em Tabela; desktop em Tabela com item selecionado, prévia compacta e resumo. A alternância Cards/Tabela foi exercitada no harness. |
| Anatomia aplicada | Categorias lineares, filtros aplicados fora do mobile, densidade administrativa e preview lateral somente quando há largura útil, conforme a referência funcional enviada e a identidade Coelo. |
| Evidências | `pilot-22-v2-mobile-cards.png`, `pilot-22-v2-tablet-table.png` e `pilot-22-v2-desktop-table-preview.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. As evidências anteriores continuam rejeitadas. |
| Teste | Harness isolado executado com `flutter test test/visual_pilot_22_v2_test.dart --reporter compact`: 1/1 GREEN, sem overflow; harness removido após captura e inspeção. |
| Produção | Nenhum arquivo produtivo V4/V5 alterado; nenhuma rota, backend, fixture produtiva ou contrato público criado. Assessments permaneceu intocado. |
| Status correto | Proposta visual aguardando avaliação; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Gate | Aguardar avaliação do Owner sobre o Item 22. Não avançar ao Item 23 nem iniciar implementação antes do aceite explícito aplicável. |
| Conhecimento capturado | `no-op`: a proposta aplica o contrato durável já registrado; nenhuma nova regra de produto foi aprovada nesta etapa. |

## 16.69. V4.22 — terceira proposta visual aguardando avaliação — 2026-08-31

| Campo | Estado |
|---|---|
| Ajuste solicitado | O Owner removeu a alternativa Cards/Tabela e pediu maior fidelidade à anatomia da referência, preservando a identidade Coelo e o rito de aprovação tela a tela. |
| Baseline literal | Tabela e status seguem o ritmo visual canônico de Instituições. A referência enviada orienta somente a composição responsiva: lista compacta automática no mobile, tabela no tablet e tabela dominante com preview auxiliar no desktop. |
| Anatomia aplicada | Busca e filtros mantêm alinhamento comum; categorias permanecem em abas lineares; o preview desktop deixou de ser um grande contêiner único e passou a combinar cabeçalho, simulação compacta e resumo independentes. Não existe controle de modo Cards/Tabela. |
| Status na tabela | Estados usam `CoeloStatusChip`, alinhados como célula tabular e sem o indicador expansível de cards/diretórios. |
| Evidências | `pilot-22-v3-mobile-list.png`, `pilot-22-v3-tablet-table.png` e `pilot-22-v3-desktop-preview.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. As propostas anteriores continuam rejeitadas. |
| Teste | Harness visual isolado executado com `flutter test test/visual_pilot_22_v3_test.dart --reporter compact`: 3/3 GREEN, cobrindo 375, 768 e 1440 px. |
| Produção | Nenhum arquivo produtivo V4/V5 alterado por esta proposta; nenhuma rota, backend, fixture produtiva ou contrato público criado. Assessments permaneceu intocado. |
| Status correto | Proposta visual aguardando avaliação; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. Programa visual permanece 0/31 `accepted`. |
| Gate | Aguardar avaliação do Owner sobre o Item 22. Não avançar ao Item 23 nem iniciar implementação antes do aceite explícito aplicável. |
| Conhecimento capturado | A decisão durável de remover o seletor Cards/Tabela foi consolidada primeiro na spec canônica de Comunicações e projetada em `docs/knowledge/team/superadmin-notices-mvp.md`; validações de conhecimento passaram. |

## 16.70. V4.22 — contrato visual aprovado com ajustes obrigatórios — 2026-08-31

| Campo | Estado |
|---|---|
| Decisão do Owner | A terceira proposta ficou suficientemente próxima para avançar ao próximo item sem quarta imagem. O aceite visual inclui os ajustes descritos pelo Owner como bloqueantes da implementação. |
| Criação | Não existe botão laranja isolado no topo. Mobile usa o tile de criação de Instituições; tablet/desktop usam a faixa de criação canônica acima da tabela, seguida do respiro tokenizado. |
| Tabela e filtros | Busca, filtros, distribuição, gaps, tipografia, células, linhas, status e paginação reproduzem Instituições. A coluna Tipo usa badges uniformes, com caixas e alinhamento consistentes. |
| Preview desktop | Fica dentro de um contêiner auxiliar único e funcional, respeitando hierarquia, paddings, raios e espaçamentos Coelo. |
| Responsividade | Sem toggle Cards/Tabela: cards compactos automáticos no mobile; tabela no tablet e desktop. |
| Produção | Nenhuma implementação produtiva autorizada nesta etapa. O contrato foi consolidado na spec canônica e na projeção de conhecimento para execução futura. |
| Status correto | `visual-contract-approved` com ajustes obrigatórios; ainda não é `accepted`, `local-green`, integração ou conclusão. |
| Próximo gate | Prosseguir somente com a proposta visual do Item 23 — Circulares. Não iniciar implementação do programa antes do `okay` final aplicável. |

## 16.71. V4.23 — diretório de Circulares aguardando avaliação — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Primeira tela do Item 23: diretório operacional de Circulares. Composer e projeções no Perfil/Acontece permanecem para validações visuais seguintes do mesmo item. |
| Baseline | Instituições para toolbar, filtros, tabs, criação, cards, tabela, status e paginação. A spec 037 fornece estados e conteúdo de domínio. |
| Responsividade | Mobile usa tile de criação seguido por cards compactos; tablet e desktop usam faixa de criação seguida pela tabela canônica. Não há botão laranja isolado nem alternância manual de visualização. |
| Estados apresentados | Todas, Rascunhos, Agendadas, Publicadas e Encerradas; células incluem público/contexto, autoria, publicação, conteúdo e respostas conforme a largura útil. |
| Evidências | `pilot-23-circulars-mobile.png`, `pilot-23-circulars-tablet.png` e `pilot-23-circulars-desktop.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Teste | Harness visual isolado executado em 375, 768 e 1440 px: 3/3 GREEN e sem exceção de layout. |
| Produção | Nenhum arquivo produtivo de Circulares foi alterado por esta proposta; o harness temporário foi removido após captura. |
| Status correto | Proposta visual aguardando avaliação; não é `visual-contract-approved`, `accepted`, `local-green`, integração ou conclusão. |
| Gate | Aguardar avaliação do Owner sobre o diretório do Item 23 antes de desenhar o composer ou alterar produção. |
| Conhecimento capturado | `no-op`: a proposta aplica a spec 037 e os contratos visuais existentes; nenhuma nova regra durável foi aprovada nesta etapa. |

## 16.72. V4.23 — diretório de Circulares aprovado visualmente — 2026-08-31

| Campo | Estado |
|---|---|
| Decisão do Owner | Diretório aprovado sem ajustes adicionais. |
| Contrato congelado | Mobile com tile e cards compactos; tablet/desktop com faixa de criação e tabela; sem botão laranja isolado e sem alternância manual. Toolbar, tabs, status e paginação seguem Instituições. |
| Fonte canônica | Decisão registrada em `specs/037-principal-circulars.md` e projetada em `docs/knowledge/team/principal-circulars.md`. |
| Produção | Nenhuma implementação produtiva autorizada ou realizada por este aceite. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, `local-green`, integração ou conclusão. |
| Próximo gate | Avaliar o composer Criar/Editar Circular como próxima tela do Item 23. |

## 16.73. V4.23 — proposta administrativa de composer superada antes da avaliação — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Direção de Criar/Editar Circular baseada no frame de Criar/Editar Instituição. |
| Correção do Owner | Antes da entrega, o Owner definiu Publicar Circular como parte dos composers do Principal, ao lado de Acontece, Agora e Momentos. |
| Resultado | Proposta superada e não apresentada para aprovação; suas imagens não constituem evidência válida nem baseline. |
| Produção | Nenhum arquivo produtivo foi alterado. |
| Status correto | `superseded-before-review`; não é contrato visual, aceite, integração ou conclusão. |

## 16.74. V4.23 — Publicar Circular com contrato visual aprovado — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Publicar Circular com título, texto, mídia, perguntas, público/contexto, agendamento, rascunho e preview. |
| Baseline | Composers do Principal — Publicar no Acontece, Agora e Momentos — com tokens, fonte, raios e espaçamentos do Design System Coelo. |
| Responsividade | Mobile em fluxo vertical; tablet com editor linear; desktop com shell e rail separados, contêiner direito arredondado, editor central e preview lateral. Rodapé reproduz Criar/Editar Instituição: Cancelar à esquerda; Salvar rascunho/Publicar à direita; compacto com primária primeiro. |
| Evidências | `pilot-23-circulars-publish-mobile-approved.png`, `pilot-23-circulars-publish-tablet-approved.png` e `pilot-23-circulars-publish-desktop-approved.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Teste | Harness visual isolado, usando o `SuperadminFormActionFooter` real, executado em 375, 768 e 1440 px: 3/3 GREEN. |
| Produção | Nenhum arquivo produtivo alterado; harness temporário removido após as capturas. |
| Status correto | `visual-contract-approved`; não é `accepted`, implementação, integração ou conclusão. |
| Gate | Pode avançar para a próxima superfície visual. Implementação continua bloqueada até o `okay` final do conjunto de telas. |
| Conhecimento capturado | Fonte canônica e projeção registram o composer Principal, a geometria externa canônica e o rodapé responsivo de Criar/Editar Instituição. |

## 16.75. Principal — padrão visual comum para todos os fluxos Publicar — 2026-08-31

| Campo | Estado |
|---|---|
| Decisão do Owner | O padrão aprovado de Publicar Circular faz sentido e passa a orientar Publicar no Acontece, Publicar no Agora e Publicar em Momentos. |
| Contrato comum | Shell, contêiner direito, insets, preview lateral quando as constraints comportarem e rodapé responsivo de Criar/Editar Instituição. |
| Variação permitida | Mídia, campos, ferramentas, texto, audiência, agendamento, validações e CTA adaptam-se ao domínio de cada publicação. |
| Fronteira | A aprovação visual comum não compartilha domínio, repository, ownership, storage ou autorização entre os módulos. |
| Status correto | `visual-contract-approved`; nenhuma implementação produtiva foi iniciada e nenhum item foi promovido a `accepted`. |
| Gate | Aplicar o padrão nas próximas propostas visuais; implementação continua bloqueada até o `okay` final do conjunto. |
| Conhecimento capturado | Fontes canônicas e projeções de Acontece, Agora, Momentos e Circulares foram sincronizadas. |

## 16.76. V4.23 — Circular no Perfil e projeção no Acontece aprovadas — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Descoberta de Circulares na aba do Perfil e projeção da mesma Circular no feed Acontece, sem duplicar o agregado canônico. |
| Decisão do Owner | Proposta aprovada sem necessidade de nova imagem, com uma correção obrigatória para web. |
| Mobile e tablet | Mobile preserva Perfil com lista compacta de Circulares; tablet apresenta a Circular como publicação editorial completa no Acontece. |
| Correção web | A prévia no Acontece não permanece em coluna lateral nem comprime a tela. Ela nasce oculta e abre em popup contextual somente por ação explícita. |
| Contrato do popup | Superfície neutra, barreira, corpo rolável, fechamento acessível e retorno de foco conforme `pattern.overlay-surfaces`. |
| Fronteira | O ajuste é da consulta da Circular no Perfil web; não remove o preview lateral já aprovado dos composers de publicação. |
| Evidência | `pilot-23c-circular-delivery.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`, acrescida da correção textual aprovada pelo Owner. |
| Produção | Nenhum código produtivo alterado; nenhuma nova imagem solicitada ou gerada para a correção. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para a próxima superfície visual; implementação continua bloqueada até o `okay` final do conjunto. |
| Conhecimento capturado | `specs/037-principal-circulars.md` e `docs/knowledge/team/principal-circulars.md` registram a prévia web sob demanda em popup. |

## 16.77. Checkpoint técnico para consolidação das worktrees — 2026-08-31

**Progresso geral conhecido — Concluído localmente:** 40,58% (84/207 ações).
**Progresso geral conhecido — Restante local:** 59,42% (123/207 ações).
**Flutter `verified`:** 0,00% (0/207). **Programa visual `accepted`:**
0,00% (0/31). **Integração E2E:** 0,00% (0/202). **Projeto estrito:**
0,00% (0/229). A base continua sendo os `action_id` e gates deste rastreador;
o fechamento de uma fundação visual compartilhada não promove ações de produto,
E2E ou conclusão estrita sem suas próprias evidências.

| Campo | Estado factual |
|---|---|
| Objetivo | Converter o lote dirty da worktree visual em commits pequenos, testados e alcançáveis antes da consolidação final local. |
| V3.18 | `pattern.coelo-time-picker` implementado no `coelo_ui_core`, consumido por Cardápio, Medicação e `CoeloDateTimeField`, com catálogo e goldens aprovados. O gate técnico da entrega ficou GREEN; isso não altera o programa visual `accepted` nem qualquer ação E2E. |
| Assessments concorrente | O delta já existente e protegido foi preservado em commit próprio `bc6f8d00`, com isolamento de loads/comandos assíncronos, limpeza de estado sensível e troca segura de repository/gradebook. O analyzer exigiu duas guardas `mounted` explícitas; elas foram acrescentadas antes do commit. As cinco ações de Assessments permanecem `audited`, sem promoção de tela ou integração. |
| Commits | `bc6f8d00` Assessments; `083bacc1` seletor de hora e consumidores; `7b2afa92` fontes canônicas visuais; `3b310668` projeção de conhecimento. Este checkpoint será o commit documental final da branch visual. |
| Testes | Core data/hora 10/10; catálogo 9/9; Superadmin focado 28/28; analyzers de `coelo_ui_core`, Catálogo e Superadmin sem issues; validador administrativo exit 0; conhecimento validado pelos dois scripts; `git diff --check` sem erro. |
| Responsividade e acessibilidade | Seletor coberto em 375/768/1024/1440, light/dark, texto a 200%, reduced motion, teclado, Escape, erro, disabled e retorno de foco. Assessments coberto em 375/768/1024/1440 e texto a 100%/200% no teste focado, sem promover aceite visual. |
| Conhecimento | Fontes canônicas foram commitadas antes da projeção; os dois gates da memória Coelo passaram. Nenhuma PII, fixture real ou segredo foi introduzido. |
| Tempo usado | O tempo adicional desta retomada não é calculável com confiabilidade a partir do ledger disponível; o checkpoint anterior preserva 3 h 41 min acumulados. Nenhuma duração foi inferida por percentual. |
| Primeiro gate incompleto | Integração dos commits exclusivos da branch visual com a fundação backend na worktree `codex/final-consolidation`, seguida das regressões combinadas. |

## 16.78. Regressão da consolidação visual — 2026-08-31

| Campo | Evidência |
| --- | --- |
| Objetivo | Validar o lote visual já commitado dentro da consolidação, sem promover ações Flutter ou E2E. |
| GREEN não-golden | 71 arquivos alterados, 773 testes aprovados; o seletor de data em 200% foi estabilizado tornando o alvo visível antes do gesto. |
| Menu `/dev` | Os dois testes funcionais passaram: ordem completa dos destinos e uso em 375/768/1024/1440. O flyout agora limita a altura ao viewport seguro e capacidades sintéticas ficam restritas ao catálogo `/dev`. |
| Análise | `flutter analyze` verde em Superadmin, `coelo_ui_admin`, `coelo_ui_core` e catálogo. |
| Limites honestos | Goldens divergentes não foram regravados sem aprovação visual. A suíte integral do catálogo mantém uma falha histórica reproduzida no baseline backend. Falhas históricas da suíte Superadmin também foram reproduzidas no baseline e não foram chamadas de regressões fechadas. |
| Estado | Flutter `verified` permanece 0,00% (0/207); ações local-green e denominadores anteriores não são promovidos por esta consolidação. |
| Conhecimento | `no-op`: o ajuste implementa contratos visuais já aprovados, sem regra durável nova. |
| Próximo comando exato | Recalcular `rtk git cherry dev codex/flutter-ui-10h`; na worktree final, aplicar em ordem somente as linhas `+`, resolver documentos de forma append-only e repetir os gates backend/Flutter. |

## 16.79. V5.24 — estrutura do Acontece aprovada visualmente — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Estrutura responsiva do feed Acontece em 375, 768 e 1440 px, incluindo Agora, publicação, ações sociais, navegação e contexto lateral. |
| Decisão do Owner | Proposta aprovada com correções obrigatórias de fidelidade na execução. |
| Hierarquia congelada | Cabeçalho Principal → Agora com primeiro card de publicação → título discreto Acontece → autor → mídia dominante → ações → prova social/legenda → próxima publicação. Não existe texto editorial antes da mídia nem barra interna redundante. |
| Shell e contêiner | Shell, contêiner direito, largura útil, insets, raios e gaps devem reproduzir os contratos canônicos aprovados em todos os breakpoints. Fundo-base claro permanece `surface`, sem cinza estrutural. |
| Navegação inferior | Presente em mobile, tablet e web com Home, Para você, ação central `+` de publicar Agora, Momentos e Pesquisar. A ação central atravessa o topo do menu, aproximadamente metade dentro e metade fora. Tablet respeita safe areas/constraints; web usa dock compacto e contido, sem ocupar toda a largura. |
| Complementos | Mensagens permanece flutuante; Perfil permanece no cabeçalho; o desktop preserva contexto auxiliar à direita dentro da mesma composição. |
| Evidências | `pilot-24-happens-v4-mobile.png`, `pilot-24-happens-v4-tablet.png` e `pilot-24-happens-v4-desktop.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`, acrescidas das correções textuais aprovadas pelo Owner. |
| Produção | Nenhum código produtivo foi alterado por esta aprovação. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para o Item 25, viewer fullscreen do Agora. Implementação continua bloqueada até o `okay` final do conjunto. |
| Conhecimento capturado | Fonte canônica atualizada e projeção interna criada em `docs/knowledge/team/principal-happens-feed.md`. |

## 16.80. V5.25 — visualizador do Agora aprovado — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Viewer imersivo do Agora em 375, 768 e 1440 px. |
| Decisão do Owner | Proposta aprovada sem ajuste visual adicional. |
| Responsividade | Mobile usa mídia vertical de ponta a ponta; tablet mantém quadro vertical seguro e centralizado; web centraliza o story e oferece prévias laterais discretas com setas. |
| Conteúdo e ações | Barras de progresso, marca Coelo branca, autoria, tempo/contexto, som, mais opções, fechar, audiência, resposta, curtir e compartilhar permanecem acessíveis e subordinados à mídia. |
| Shell | O viewer ocupa a tela inteira e suspende temporariamente shell, rail e dock global; fechar devolve o usuário ao ponto de origem no Acontece. |
| Evidências | `pilot-25-now-v2-mobile.png`, `pilot-25-now-v2-tablet.png` e `pilot-25-now-v2-desktop.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Produção | Nenhum código produtivo foi alterado por esta aprovação. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para o Item 27, conteúdo específico de Publicar no Acontece. |
| Conhecimento capturado | Fonte canônica atualizada e projeção interna criada em `docs/knowledge/team/principal-now-viewer.md`. |

## 16.81. V5.27 — Publicar no Acontece aprovado visualmente — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Composer específico do Acontece em 375, 768 e 1440 px. |
| Decisão do Owner | Proposta aprovada com ressalva obrigatória sobre a fidelidade do shell, contêiner direito e seus espaçamentos. |
| Responsividade | Mobile e tablet usam fluxo linear com mídia dominante, legenda, público/contexto e rodapé; desktop usa rail, editor central e prévia lateral. |
| Rodapé | Reproduz Criar/Editar Instituição: compacto com ação primária primeiro; amplo com Cancelar à esquerda e Salvar rascunho/Publicar à direita. |
| Evidências | `pilot-27-publish-happens-mobile.png`, `pilot-27-publish-happens-tablet.png` e `pilot-27-publish-happens-desktop.png`, fora do repositório em `.codex/visualizations/.../01a048b4-b90b-70c0-94f7-f7e43bcf5a6e`. |
| Produção | Nenhum código produtivo foi alterado por esta aprovação. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para o Item 28, Para você. |
| Conhecimento capturado | Fonte canônica e `docs/knowledge/team/happens-publication-mvp.md` atualizados. |

## 16.82. V5.28 — Para você aprovado visualmente — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Para você em 375, 768 e 1440 px. |
| Decisão do Owner | Proposta aprovada com correção obrigatória do shell, contêiner direito e espaçamentos no web. |
| Hierarquia congelada | Saudação/contexto → destaque protagonista → atalhos → conteúdo editorial → resumo do dia → contexto atual. |
| Navegação global | O dock flutuante web passa a ser padrão em mobile, tablet e web. A ação central laranja fica entre 10% e 25% maior e atravessa exatamente em 50/50 o limite superior do dock. |
| Evidência | `exec-32a1d29d-e68b-47e9-bd44-774745216334.png`, fora do repositório em `.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c`. |
| Produção | Nenhum código produtivo foi alterado por esta aprovação. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para o Item 29, Visualizador de Momentos. |
| Conhecimento capturado | Fonte canônica e projeções `principal-for-you-preview`, `principal-happens-feed` e `principal-global-navigation` atualizadas. |

## 16.83. V5.29 — Visualizador de Momentos aprovado — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Visualizador de Momentos em 375, 768 e 1440 px. |
| Decisão do Owner | Proposta aprovada com correções obrigatórias do shell, contêiner direito e espaçamentos no web. |
| Hierarquia congelada | Mídia dominante → autoria/contexto → legenda → prova social → ações; desktop acrescenta contexto auxiliar compacto. |
| Dock global | Deve flutuar em mobile, tablet e web, com respiro tokenizado da borda inferior. A ação central preserva tamanho ampliado e interseção exata 50/50. |
| Evidência | `exec-ea57ded2-3e82-4ba5-ad21-bed472e766a5.png`, fora do repositório em `.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c`. |
| Produção | Nenhum código produtivo foi alterado por esta aprovação. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para o Item 30, Perfil completo do Principal. |
| Conhecimento capturado | Fonte canônica e projeções `principal-global-navigation` e `principal-moments-viewer` atualizadas. |

## 16.84. V5.30 — Perfil completo do Principal aprovado — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte visual | Perfil completo do Principal em 375, 768 e 1440 px. |
| Decisão do Owner | Proposta aprovada com correção obrigatória do shell, contêiner direito e espaçamentos no web. |
| Hierarquia congelada | Capa panorâmica → avatar integral → identidade/contexto/estatísticas → tabs Acontece, Momentos, Circulares e Sobre → conteúdo editorial. |
| Desktop | Feed principal e contexto auxiliar compacto dentro do contêiner direito canônico; sem aproximações de largura, inset, raio ou gap. |
| Evidência | `exec-34a4cec5-734a-42a9-b231-f23e368df64e.png`, fora do repositório em `.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c`. |
| Produção | Nenhum código produtivo foi alterado por esta aprovação. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para Publicar em Momentos. |
| Conhecimento capturado | Fonte canônica e projeção `principal-profile` atualizadas. |

## 16.85. V5.31A — Publicar em Momentos em revisão visual — 2026-08-31

| Campo | Estado |
|---|---|
| Primeira proposta | A prancha `exec-3d04c826-02e9-421b-81c3-e2f5adc1118e.png` foi considerada funcional, mas divergente da anatomia comum já aprovada para todos os fluxos `Publicar`. |
| Correção solicitada | Reproduzir literalmente Publicar no Acontece em cabeçalho, título `Sua publicação`, ordem das seções, largura útil, shell, contêiner, preview e rodapé; variar somente as ferramentas próprias de Momentos. |
| Referências do Owner | `codex-clipboard-3844bf32-6274-45a9-878c-93bb5823f43e.png`, `codex-clipboard-927a08eb-055d-4d49-a1e2-da548d9fd812.png` e `codex-clipboard-17064514-e319-42e3-bebc-56ab5b3e5299.png`. |
| Produção | Nenhum código produtivo foi alterado. |
| Status correto | `revision-requested`; ainda não é `visual-contract-approved`, `accepted`, implementação ou conclusão. |
| Próximo gate | Apresentar a revisão do Publicar em Momentos antes de seguir para Publicar no Agora. |
| Conhecimento capturado | `no-op`: o padrão comum já estava aprovado; esta rodada corrige a fidelidade da proposta. |

## 16.86. V5.31A — Publicar em Momentos aprovado — 2026-08-31

| Campo | Estado |
|---|---|
| Decisão do Owner | A revisão de Publicar em Momentos foi aprovada com correção obrigatória da geometria do shell, contêiner e espaçamentos web. |
| Anatomia congelada | Reproduz literalmente Publicar no Acontece em cabeçalho, `Sua publicação`, ordem das seções, largura útil, preview e rodapé; somente mídia vertical, ferramentas, capa e CTA variam. |
| Evidência | `exec-c0319a7b-45bd-4665-ba18-f5b436e41b6b.png`, fora do repositório em `.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c`. |
| Produção | Nenhum código produtivo foi alterado. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Prosseguir para Publicar no Agora. |
| Conhecimento capturado | Fonte canônica e projeção `moments-publication-preview` atualizadas. |

## 16.87. V5.31B — Publicar no Agora aprovado — 2026-08-31

| Campo | Estado |
|---|---|
| Decisão do Owner | A proposta de Publicar no Agora foi aprovada com correção obrigatória do shell, contêiner direito e espaçamentos web. |
| Anatomia congelada | Reproduz literalmente o contrato comum de Publicar no Acontece/Momentos: cabeçalho, `Sua publicação`, ordem das seções, largura útil, preview e rodapé; varia somente para mídia temporária vertical, texto curto, ferramentas, aviso de 24 horas e CTA do Agora. |
| Responsividade | Mobile usa fluxo linear e ações empilhadas; tablet preserva editor linear; desktop mantém shell, editor central, preview lateral e rodapé dentro do contêiner direito canônico. |
| Evidência | `exec-59c8c015-634c-4451-8390-f8652f75190e.png`, fora do repositório em `.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c`. |
| Produção | Nenhum código produtivo foi alterado. |
| Status correto | `visual-contract-approved`; ainda não é `accepted`, implementação, integração ou conclusão. |
| Próximo gate | Encerrar a aprovação visual do conjunto e iniciar a implementação tela a tela somente no novo ciclo autorizado pelo Owner. |
| Conhecimento capturado | Fonte canônica e projeção `now-publication-mvp` atualizadas. |

## 16.88. V4.19 — Diretório de Formulários e agendamento implementados localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V4.19 — Diretório de Formulários e agendamentos. |
| `action_id` afetado | `forms.list` permanece `local-green`. O popup subordinado agora é alcançável pelo caller da rota produtiva sem conceder as mutações de lifecycle; como faltam capability, vínculo de aplicação e persistência aprovados, `Salvar` permanece fail-closed e nenhum novo `action_id` produtivo foi criado. |
| Implementação | Diretório passou a abrir em tabela, reutiliza criação, toolbar, tabela, paginação, badges e shell canônicos de Instituições; projeções opcionais mostram Contexto, Público, Respostas, Agendamentos e Criado em sem inventar dados ausentes. |
| Flyout | Ações de editar, duplicar, copiar, mover, agendamentos, arquivar e excluir usam `CoeloAdminFlyout`; o componente compartilhado agora preserva gap externo/safe area, alinhamento final, `outlineVariant` translúcido e zero halo de elevação. |
| Agendamento | `FormsScheduleDialog` responsivo com ativo, nome, início/fim, frequência, dias e audiência somente leitura; superfície acompanha o conteúdo e preserva ações 50/50. A rota real abre o popup, informa a indisponibilidade da integração e mantém `Salvar` desabilitado. Término anterior ao início e recorrência semanal sem dia são rejeitados antes do callback. Persistência remota não foi simulada. |
| Estados e criação | Vazio, sem resultados e erro preservam a criação canônica quando autorizada; unauthorized omite toolbar e criação. A ação permanece visual/fail-closed e não concede capability. |
| TDD e testes | RED→GREEN para tabela padrão/criação/responsividade, ações de lifecycle, alcançabilidade pela rota real, estados, fail-closed, término >= início, recorrência semanal com dia, altura do diálogo e margem do flyout. O commit focado V4.19/V4.20 foi verificado isoladamente com 72/72 testes Forms/rotas e 13/13 testes de overlays. |
| Goldens Flutter reais | Quinze arquivos em `apps/superadmin/test/features/forms/presentation/directory/goldens/`: matriz light/dark em 375, 768, 1024 e 1440 px, flyout, agendamento integrado/indisponível e estados vazio, sem resultados, erro e unauthorized a 200%. |
| Inspeção visual | Os quinze goldens foram abertos ao longo da unidade; verificados shell, Nunito Sans, superfície, tabela, scroll horizontal, paginação, estados, margem/contorno suave do flyout, motivo de indisponibilidade, altura e rodapé 50/50 do diálogo; nenhuma imagem quebrada ou overflow visível. |
| Analyzer e formatter | `flutter analyze` integral do Superadmin, `dart analyze` de `coelo_api` e `coelo_ui_admin`: zero erros. `dart format` aplicado somente aos 15 arquivos Dart da unidade. |
| Validador | `apps/catalog/tool/validate_admin_visual_contracts.dart` passou sem ampliar allowlist; `git diff --check` passou. |
| Limite honesto | Flutter visual local concluído para V4.19. Criar/editar/agendar em rota produtiva, autorização, estados remotos, backend/Supabase e E2E não foram promovidos nem declarados concluídos. |
| Conhecimento capturado | `no-op`: a implementação materializa o contrato já aprovado em 16.61 e não cria regra durável nova de produto, permissão ou domínio. |
| Próximo item | V4.20 — Editor modular de Formulários, começando por consulta ao índice Coelo UI e baseline real de Criar/Editar Instituição. |

## 16.89. V4.20 — Editor modular de Formulários implementado localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V4.20 — Editor modular de Formulários. |
| `action_id` afetado | `forms.edit` permanece `local-green` com evidência visual ampliada. `forms.create` permanece `audited`, pois a rota produtiva de criação continua indisponível e não foi promovida por um fixture local. |
| Implementação | O preview raso de três campos foi substituído por editor modular em `colorScheme.surface`, com rail de seções sem marcador numerado preto/laranja, cards de perguntas, título/contexto/recorrência e rodapé literal de Criar/Editar Instituição. |
| Catálogo | Catálogo fechado com rolagem própria e grupos verticais `Texto e números`, `Escolhas`, `Mídias` e `Estrutura`; contém os onze tipos aprovados e busca local. |
| Operações | Criar, selecionar, reordenar, duplicar e excluir seção com confirmação; reordenar, duplicar, excluir e mover pergunta entre seções; obrigatoriedade, opções, mídia e ramo por resposta com pergunta subordinada. |
| Data | Quatro modos visuais e comportamentais: Livre, A partir de, Até e Intervalo permitido, usando os campos de data Coelo. |
| Preview e footer | Preview nasce ausente. Em amplo, aparece lateralmente só após ação explícita; em compacto, abre em diálogo acessível. Salvar/Preview não existem no cabeçalho; Cancelar, Salvar rascunho e Salvar formulário ficam no `SuperadminFormActionFooter`. |
| Proteção de dados | Cancelar, excluir seção e excluir pergunta exigem confirmação. A prévia local informa explicitamente que não envia dados; backend, autosave remoto e publicação não são simulados. |
| TDD e testes | RED→GREEN para preview oculto, catálogo vertical/rolável, 11 tipos, quatro modos de Data, operações de seção/pergunta, ramo, 375–1440 e texto 100/200%. O header compacto foi refeito sem ellipsis e a navegação de seções ganhou scroll próprio após RED reproduzir perda do título/subtítulo e overflow; o commit focado V4.19/V4.20 passou isolado com 72/72. |
| Goldens Flutter reais | Quatorze arquivos em `apps/superadmin/test/features/forms/presentation/editor/goldens/`: oito combinações 375/768/1024/1440 light/dark; catálogo no topo e grupos inferiores; Data em intervalo; preview explícito; 375 light e 1440 dark a 200%. |
| Inspeção visual | Os quatorze goldens foram abertos individualmente. Foram verificados shell, rail, superfície, perguntas, rodapé responsivo, catálogo, grupos, Data, preview lateral, dark mode, texto ampliado e ausência de overflow visível. |
| Analyzer e validador | `flutter analyze` integral do Superadmin: zero erros/warnings. Validador administrativo passou sem ampliar allowlist; `git diff --check` passou. |
| Componente compartilhado | `SuperadminFormFrame` ganhou `bodyMaxWidth` opcional com default preservado em 880; o editor usa 1180 somente quando o contêiner real permite editor + preview. |
| Limite honesto | Atividade e componente Flutter visual concluídos localmente. Rota produtiva continua fail-closed; capability, autorização, autosave, conflito/versionamento, persistência, backend/Supabase e E2E seguem pendentes. |
| Conhecimento capturado | `no-op`: nenhuma regra durável nova foi criada; a implementação materializa o contrato aprovado em 16.63 e a spec canônica de Formulários. |
| Próximo item | V4.21 — Diretório de Importações e wizard. |

## 16.90. V4.21 — Importações e wizard implementados localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V4.21 — Diretório de Importações e wizard. |
| `action_id` afetado | `imports.list` passa de `audited` para `local-green`; `imports.create` permanece `local-green`. `imports.upload`, `imports.preview`, `imports.confirm`, `imports.status` e `imports.download` permanecem `audited`, porque a evidência visual local não comprova arquivo remoto, autorização, idempotência, job, download ou reload produtivo. |
| Diretório | Reutiliza `CoeloAdminListingToolbar`, `CoeloAdminResizableTable`, `CoeloAdminPagination` e `SuperadminListingPaginationFooter` com as alturas 56/64 e os alinhamentos de Instituições. A tabela mostra Arquivo, Entidade, Destino, Registros, Status, Criado em e Responsável, com scroll horizontal responsivo. |
| Wizard | Reutiliza `SuperadminFormFrame`, `SuperadminFormStepNavigation` e `SuperadminFormActionFooter`; o corpo ocupa largura útil estável e reseta o scroll por etapa, sem mover ou encolher confirmação/status. |
| Entidades | Catálogo responsivo expõe literalmente Instituições, Unidades, Pessoas, Grupos e turmas, Atividades, Planos de medicação, Cardápios e Formulários. Somente Unidades mantém execução disponível; as demais ficam selecionáveis para leitura do contrato, mas Continuar permanece desabilitado com indisponibilidade explícita e zero chamada ao repository. |
| Mapeamento e segurança | Resumo de arquivo, chave, pares coluna→campo e aviso honesto deixam claro que a prévia não aplicou alterações e depende do serviço autorizado. Upload/persistência remotos não foram simulados. |
| Estados | Evidência cobre histórico populado, vazio, sem resultados, unauthorized, indisponível/retry, criação/fechamento/foco, seleção disponível e indisponível, arquivo/mapeamento, prévia com conflito, confirmação e status concluído. `42501`, `PGRST301` e `PGRST302` são mapeados para unauthorized; outros erros continuam indisponíveis sem inventar autorização. |
| Busca e criação | Busca usa debounce de 350 ms e submissão por teclado, sem botão divergente. Vazio, sem resultados e erro preservam criação; unauthorized não expõe criação. |
| TDD e testes | RED→GREEN para oito entidades, unauthorized distinto, busca, criação persistente, bloqueio fail-closed sem repository, paginador canônico e geometria estável. O gate final conjunto Forms/Imports/Notices terminou 183/183. |
| Goldens Flutter reais | Vinte e sete goldens referenciados: diretório e wizard light/dark em 375, 768, 1024 e 1440; texto 200% em 375 e 1440; vazio, sem resultados, unauthorized, indisponível, diálogo, mapeamento, prévia, confirmação e concluído. |
| Inspeção visual | Os 27 goldens referenciados foram abertos e inspecionados após a última geração. Verificados Nunito Sans, surface, tabela/paginação, estados honestos, rail, footer, scroll, dark mode, texto 200%, avisos e ausência de overflow ou imagem quebrada. Nove variantes iterativas não referenciadas permanecem fora dos commits/evidências. |
| Analyzer e validador | `flutter analyze` integral do Superadmin sem issues; validador administrativo verde sem ampliar allowlist; formatter e `git diff --check` verdes. |
| Limite honesto | Atividade e tela Flutter visual local concluídas para V4.21. Supabase, capability, tenant, provenance, upload/Storage, job remoto, idempotência, falha parcial, download, reload e E2E continuam fora deste recorte e não foram promovidos. |
| Conhecimento capturado | `no-op`: a implementação materializa 16.64/16.65 e as baselines já projetadas; nenhuma regra durável nova de produto, domínio ou permissão foi criada. |
| Próximo item | V4.22 — Comunicações do app, começando pelo índice Coelo UI e pelas baselines reais de Instituições/preview. |

## 16.91. V4.22 — Comunicações do app implementadas localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V4.22 — Diretório de Comunicações do app. |
| `action_id` afetado | `notices.list` passa de `audited` para `local-green`. `notices.create`, `notices.edit`, `notices.schedule`, `notices.publish` e `notices.archive` permanecem `audited`, porque o diretório visual não comprova commands, autorização, persistência ou reload produtivos. |
| Responsividade | Mobile usa tile de criação e cards compactos automaticamente; tablet e desktop usam faixa de criação e tabela, sem seletor Cards/Tabela. O preview auxiliar aparece somente no breakpoint desktop de 1200 px ou mais, sem comprimir a tabela em 1024 px. |
| Baseline literal | Reutiliza toolbar, tabs, `CoeloAdminCreateAction`, `CoeloAdminResizableTable`, `CoeloAdminPagination` e footer de Instituições. Cabeçalho/linhas usam 56/64 px, com criação seguida por `space4`. |
| Tipos e preview | Badges de Tipo possuem largura uniforme e semântica própria. Aviso usa o simulador de popup; Conteúdo, Destaque e Para você usam o card administrativo neutro, inclusive no dark, dentro de um único contêiner auxiliar. |
| Acessibilidade | Texto a 200% mantém a altura tabular canônica sem overflow; o resumo visual da célula principal é reduzido nesse modo, mas título e mensagem completos permanecem no rótulo semântico. Reduced motion está fixado nos goldens; teclado, foco, hover, popup, retorno de foco, unauthorized e retry permanecem cobertos pela suíte focada. |
| Estados | Vazio, sem resultados e erro usam tile de criação em 375 px e faixa de criação em 768 px ou mais; unauthorized permanece isolado sem criação. |
| TDD e testes | RED confirmou linha divergente de 72 px, overflow de 8 px a 200% e card indevido em estados amplos; GREEN corrigiu as causas. O gate final conjunto Forms/Imports/Notices terminou 183/183. |
| Goldens Flutter reais | Quatorze goldens referenciados: light/dark em 375, 768, 1024 e 1440 px, texto a 200% em 375/1440 e estados vazio, sem resultados, erro e unauthorized. Todos foram abertos e inspecionados. |
| Inspeção visual | Verificados Nunito Sans, surface, criação responsiva, tabela/paginação, badges uniformes, preview neutro no dark, densidade em 1024, texto 200% e ausência de overflow ou imagem quebrada. |
| Analyzer e validador | Analyzer focado sem issues; validador administrativo verde sem ampliar allowlist; formatter e `git diff --check` verdes. |
| Limite honesto | Atividade e tela Flutter visual local concluídas para V4.22. Supabase, capability, tenant, publicação, audience freeze, receipts, cron/worker, remoto e E2E permanecem fora deste recorte e não foram promovidos. |
| Conhecimento capturado | `no-op`: a implementação materializa a spec canônica e `docs/knowledge/team/superadmin-notices-mvp.md`; nenhuma regra durável nova de produto, domínio ou permissão foi criada. |
| Próximo item | V4.23 — Circulares: diretório, composer e projeções, começando pelo índice Coelo UI e pelas baselines reais de Instituições/família Publicar/popup. |

## 16.92. V4.23 — Circulares implementadas localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V4.23 — Diretório, publicação e projeções de Circulares. |
| `action_id` afetado | Nenhum novo ID foi promovido. A taxonomia atual de 207 ações não possui ID próprio para o diretório administrativo ou o composer de Circulares; `principal.profile-view` permanece `local-green`. O total Flutter local permanece 86/207 para não inventar cobertura numérica. |
| Diretório | Nova superfície administrativa fail-closed com busca, contexto, tabs, loading, vazio, sem resultados, erro/retry e unauthorized. Mobile usa tile de criação, cards e paginação `[11, 20, 50, 100]`; 768/1024/1440 usam faixa de criação, `CoeloAdminResizableTable`, linhas 56/64 e paginação `[8, 20, 50, 100]`, literalmente como Instituições e sem toggle manual. |
| Publicar Circular | O composer usa `Sua publicação`, editor linear em compacto, preview explícito abaixo de 980 px e editor + preview lateral a partir de 980 px. O rodapé agora reutiliza `PrincipalPublicationActionFooter`: mantém Cancelar à esquerda, Salvar rascunho secundário e Publicar como única ação primária; em compacto, as três ações ficam em largura total e altura adaptativa. |
| Alcançabilidade | O menu de desenvolvimento expõe Circulares; `/dev/circulars` abre o diretório no shell persistente, sua faixa/tile de criação navega para `/dev/circulars/new`, e Cancelar devolve ao diretório. O composer usa `UnavailableCircularRepository`: salvar/publicar falham de forma explícita e seleção de arquivos informa indisponibilidade, sem simular persistência, mídia ou sucesso remoto. |
| Projeções | Perfil e feed mantêm a prévia ausente até ação explícita no web. O popup usa barreira, superfície neutra, corpo rolável, fechamento acessível, CTA e devolução comprovada do foco ao gatilho. Em compacto, o detalhe abre fullscreen sem AppBar/dock global e apresenta retorno contextual `‹ Circular`. O Principal não importa `coelo_ui_admin`. |
| Acessibilidade | Superfície interativa especializada cobre mouse, hover, foco, Enter e Espaço sem `InkWell` cru. Texto a 200% não corta mais os rótulos do rodapé; reduced motion é exercitado na matriz visual. |
| TDD e testes | RED→GREEN para diretório responsivo, estados, preview oculto, popup, foco, paginação por breakpoint e reachability real. A revisão independente adicionou Escape com retorno/foco no leitor, resize vivo da galeria, vídeo honestamente indisponível e remoção de setas em `1 de 1`; o gate final terminou 76/76. |
| Goldens Flutter reais | Diretório: dez goldens light/dark em 375/768/1024/1440 e texto 200% em 375/1440. Circulares Principal: dez goldens do composer na mesma matriz, três do leitor contextual compacto (light, dark e texto 200%), dois de perfil/feed e dois do popup web. |
| Inspeção visual | Todos os goldens novos e alterados foram abertos. Verificados surface, criação responsiva, tabela/paginação, composer, preview lateral, popup, dark mode, texto 200%, mídia/fixtures estáveis e ausência de overflow visível. A inspeção detectou e corrigiu o corte de texto no footer compacto antes do gate final. |
| Analyzer e validador | Analyzer focado sem issues; `validate_admin_visual_contracts.dart` verde com a allowlist canônica inalterada; formatter e `git diff --check` verdes. |
| Limite honesto | Atividade e superfícies Flutter visuais locais concluídas para V4.23. Repository produtivo, capability, autorização, tenant, Storage/R2, publicação remota, respostas, Supabase e E2E permanecem fora deste recorte e não foram simulados nem promovidos. |
| Conhecimento capturado | `no-op`: a implementação materializa `specs/037-principal-circulars.md`, a spec visual e o conhecimento já aprovado; nenhuma regra durável nova foi criada. |
| Próximo item | V5.24 — Acontece, em consolidação paralela com V5.25/V5.26 e o componente global de navegação Principal. |

## 16.93. V5.24 — Acontece implementado localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V5.24 — Acontece. |
| `action_id` afetado | `acontece.feed` permanece `local-green` com evidência visual e comportamental ampliada. `acontece.create`, `acontece.publish` e `acontece.remove` permanecem `blocked-decision`; esta unidade não promove commands nem backend. |
| Anatomia | Cabeçalho Principal com marca Coelo, chevron, notificações e avatar; Agora vem primeiro, sem “Ver tudo”, com tile Publicar agora e carrossel horizontal. O título discreto Acontece antecede o feed misto de publicações e Circulares, sem texto editorial antes da mídia. |
| Navegação global | `PrincipalGlobalNavigation` implementa Home, Para você, ação central Publicar no Agora, Momentos e Pesquisar; Mensagens permanece flutuante e Perfil no cabeçalho. O dock é compacto em 375–1440, afastado da viewport, com ação central 25% maior e centro exatamente sobre a borda superior 50/50. |
| Responsividade e estados | Mobile usa mídia dominante; tablet preserva densidade; desktop acrescenta somente o contexto auxiliar compacto. Loading, vazio, erro/retry e unauthorized permanecem distintos e sem fallback para dados demo quando um repository real falha. |
| TDD e testes | A suíte consolidada da onda V5.24–V5.26, incluindo router, terminou com 94/94 testes verdes após a correção de integração do dock. |
| Goldens Flutter reais | Dez evidências próprias do Acontece: light/dark em 375/768/1024/1440, 375 dark a 200% e hover do Agora. A matriz separada da Galeria pertence a V5.26 e não é contada novamente aqui. |
| Inspeção visual | Os dez arquivos foram abertos individualmente. Verificados surface, Nunito Sans, ordem Agora→Acontece, mídia real, dock 50/50, contexto desktop, dark mode, texto 200% e ausência de overflow visível. |
| Analyzer e gates | Analyzer focado sem issues; formatter e `git diff --check` verdes. O router liga explicitamente `onPublishNow` à rota de desenvolvimento dedicada, separada de Publicar no Acontece. |
| Limite honesto | Atividade e tela Flutter visual local concluídas. Feed/repositories produtivos, autorização, R2/Storage, comandos, remoto e E2E não foram simulados nem promovidos. |
| Conhecimento capturado | `no-op`: a tela materializa a spec visual e as projeções já aprovadas; nenhuma regra durável nova foi decidida nesta correção. |
| Próximo item | V5.25 — Visualizador do Agora. |

## 16.94. V5.25 — Visualizador do Agora implementado localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V5.25 — Visualizador do Agora. |
| `action_id` afetado | `agora.view` permanece `local-green` com evidência visual e comportamental ampliada. Criar/publicar/expirar permanecem `blocked-decision`. |
| Imersão | O viewer suspende shell, rail e dock. Mobile usa mídia edge-to-edge; 768 e 1024 usam quadro vertical seguro centralizado; 1440 usa mídia central com prévias laterais discretas. O breakpoint 1024 foi corrigido após inspeção visual para não antecipar o layout web. |
| Controles | Barras de progresso, autoria, tempo, contexto, som, opções e fechar permanecem sobre a mídia sem competir com ela. Audiência, resposta privada, curtir e compartilhar possuem alvos e semântica próprios; teclado cobre setas, espaço e Escape. |
| Honestidade | Responder/compartilhar usam callbacks injetados; quando ausentes, informam indisponibilidade sem declarar envio ou compartilhamento. Mídia remota indisponível não recebe fixture demo. |
| Retorno | O controle contextual visível `‹ Agora` prioriza `onClose`, depois retorno ao Acontece e só então `Navigator.maybePop`, preservando origem e foco quando o composition root fornece o callback. |
| Evidências | Treze goldens: mobile light/dark 375, tablet light/dark 768/1024, desktop light/dark 1440, texto 200% em 375/1440, resposta focada e preview hover. Todos foram abertos; os dois de 1024 foram regenerados e reinspecionados após a correção do breakpoint, e os estados finais confirmam ausência de header/dock. |
| Testes e analyzer | Suíte combinada inicial: 94/94 verde; o gate ampliado final de viewer + publishers + rotas terminou 223/223. Testes específicos comprovam 1024 sem shell/previews web, quadro de até 430 px, retorno contextual e restauração de foco. Analyzer focado sem issues. |
| Limite honesto | Viewer Flutter local concluído. Origem/deep link produtivos, tickets de mídia, autorização real, áudio/vídeo remoto, backend e E2E permanecem abertos. |
| Conhecimento capturado | `no-op`: nenhuma regra durável nova; implementação alinhada à spec e ao conhecimento já registrado. |
| Próximo item | V5.26 — Galeria do Acontece. |

## 16.95. V5.26 — Galeria do Acontece implementada localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V5.26 — Galeria do Acontece. |
| `action_id` afetado | Não existe ID separado para a Galeria na taxonomia atual; sua evidência integra `acontece.feed`, que permanece `local-green`. O total permanece 86/207. |
| Visualizador | Galeria fullscreen abre pela mídia, preserva proporção, permite anterior/próxima por botões e teclado, mostra contagem e fechamento acessível. |
| Ações | Compartilhar e salvar usam callbacks quando fornecidos; sem integração, apresentam indisponibilidade honesta e não simulam sucesso. |
| Evidência | Nove goldens Flutter reais: light/dark em 375/768/1024/1440 e 375 dark a 200%. Compacto usa fullscreen contextual; 768/1024/1440 usam popup modal com mídia protagonista, contagem, navegação e ações. Os nove foram abertos individualmente, sem imagem quebrada, overflow ou distorção. |
| Gates | Além da consolidação anterior de 94/94, o gate final Acontece/Galeria terminou 36/36; ArrowLeft/ArrowRight, Escape, fechamento e restauração de foco estão cobertos. Analyzer focado, formatter, validador administrativo e diff check verdes. |
| Limite honesto | Atividade e visualizador Flutter local concluídos. Download/compartilhamento/salvamento reais, mídia remota, autorização e E2E permanecem fora do recorte visual. |
| Conhecimento capturado | `no-op`: contrato já aprovado, sem decisão nova. |
| Próximo item | V5.27 — Publicar no Acontece, em consolidação na família Publicar Principal. |

## 16.96. V5.27/V5.31 — família Publicar implementada e P1 corrigidos localmente — 2026-08-31

| Campo | Estado |
|---|---|
| Unidade | V5.27 — Publicar no Acontece; V5.31A — Publicar em Momentos; V5.31B — Publicar no Agora. |
| `action_id` afetado | Nenhum ID foi promovido. `acontece.publish`, `momentos.publish` e `agora.publish` permanecem `blocked-decision`. A evidência Flutter local não comprova autorização, persistência, Storage/R2 ou resultado após reload. |
| Contexto seguro | Construtores produtivos de Acontece e Agora agora exigem contexto explícito. Fixtures são acessíveis somente por `.demo`, eliminando fallback silencioso para tenant/instituição de demonstração; trocas continuam isoladas e fail-closed. |
| Mídia persistida | Acontece renderiza bytes ou URL assinada opcional; Momentos produtivo vazio não injeta fixture demo e distingue vídeo de imagem/fonte indisponível. Imagens usam `BoxFit.cover` e preservam proporção. No Agora, vídeo válido possui representação própria; bytes inválidos e URL quebrada mostram `Mídia indisponível`, sem asset demo. Nenhum endpoint ou backend foi inventado. |
| Crop e capa do Agora | O repository hidrata `crop_scale`, `crop_x`, `crop_y` e `cover_position`. O preview aplica escala e alinhamento persistidos; alterar escala preserva deslocamentos; vídeo apresenta indicação visual da posição da capa. A extração remota de frame continua fora do recorte. |
| Anatomia compartilhada | Acontece, Momentos e Agora usam `PrincipalPublicationFrame`, navegação, footer e cabeçalho Principal compartilhados, sem importar `coelo_ui_admin` ou widgets administrativos. O viewer Agora permanece fullscreen fora do shell; somente o composer permanece no shell persistente. |
| Estados e retry | Acontece trata `conflict` com recarga explícita; Momentos e Agora distinguem failure, unauthorized e conflict e repetem a operação original sem manter wizard travado. |
| TDD e testes | RED→GREEN comprovou construtores `.demo`, estados honestos/retry, URL/bytes/vídeo persistidos, indisponibilidade, hidratação de crop/capa e preservação de deslocamento. Publishers terminaram 119/119; o gate combinado com Para Você e rotas terminou 172/172; a revisão V5 final encerrou 107/107 focados. |
| Goldens e inspeção | Quarenta goldens referenciados cobrem light/dark, 375/768/1024/1440, texto 200%, hover, vazio/failure, mídia persistida/indisponível e crop/capa: 11 Acontece, 14 Momentos e 15 Agora. Os estados críticos foram abertos em resolução original; não há tofu, demo produtiva, distorção ou overflow visível. |
| Analyzer e validador | Analyzer focado sem issues. `validate_admin_visual_contracts.dart` passou com a allowlist canônica inalterada; formatter aplicado aos arquivos do recorte. |
| Limite honesto | Atividade e três composers Flutter visuais concluídos localmente. Integração remota, autorização/RLS, upload/Storage/R2, processamento de vídeo/capa, publicação real, reload e E2E continuam pendentes e não foram promovidos. |
| Conhecimento capturado | Projeções internas de Acontece, Momentos e Agora sincronizadas com os invariantes de contexto explícito, mídia persistida e edição local; fontes canônicas permanecem as specs registradas no frontmatter. |
| Próximo item | V5.28–V5.30 seguem sob a frente paralela responsável; esta correção não alterou essas superfícies. |

## 16.97. V5.28 — Para Você implementado localmente — 2026-08-31

| Campo | Estado |
|---|---|
| `action_id` afetado | `principal.for-you` permanece `local-green`; pacote Principal executável, dados produtivos, autorização e E2E não foram promovidos. |
| Implementação | Hierarquia aprovada de saudação/contexto, protagonista, atalhos, editorial, resumo do dia e contexto atual; surface, insets e dock global canônicos. |
| Retorno e foco | Agora e Momentos abrem por navegação empilhada; fechar devolve à origem e restaura o foco. O hero permanece integralmente alcançável acima do dock após scroll seguro. |
| Responsividade | 375/768/1024/1440, light/dark e texto 200%; o RED de 72 px no hero 768/200 foi corrigido por geometria responsiva. |
| Evidência | Treze goldens referenciados e inspecionados; a revisão final V5 terminou 107/107 testes focados, analyzer/validador/diff verdes. |
| Limite honesto | Preview Flutter visual local no host previsto pela stage spec. `apps/principal` executável é ownership separado e não foi declarado concluído aqui. |

## 16.98. V5.29 — Visualizador de Momentos implementado localmente — 2026-08-31

| Campo | Estado |
|---|---|
| `action_id` afetado | `momentos.view` permanece `local-green`; criar/publicar/remover permanecem nos estados anteriores. |
| Implementação | Fullscreen sem cabeçalho, shell ou dock; retorno `‹ Momentos`, foco restaurado, mídia dominante, autoria/contexto, legenda, prova social e ações. |
| Iconografia e mídia | Glyphs proporcionais com peso óptico uniforme, estados ativos laranja e alvos mínimos. Vídeo e imagem são distinguidos; ausência de player real gera indisponibilidade honesta. |
| Evidência | Onze goldens referenciados e inspecionados na matriz responsiva, dark/light, 200% e hover; revisão final V5 sem P0/P1 residual no estágio local. |
| Limite honesto | Mídia/autorização produtivas, app Principal executável e E2E continuam fora desta promoção. |

## 16.99. V5.30 — Perfil completo do Principal implementado localmente — 2026-08-31

| Campo | Estado |
|---|---|
| `action_id` afetado | `principal.profile-view` permanece `local-green`; `principal.profile-edit` continua `blocked-decision`. |
| Implementação | Capa panorâmica, avatar integral, identidade, contexto, estatísticas, tabs Acontece/Momentos/Circulares/Sobre, feed editorial e contexto auxiliar desktop. |
| Responsividade | 375/768/1024/1440, light/dark e texto 200%; métricas refluem em uma coluna no compacto e sem ellipsis. |
| Evidência | Doze goldens referenciados e inspecionados; Nunito Sans, surface, mídia sem tofu e dock responsivo confirmados. |
| Limite honesto | Repositories, autorização, perfil produtivo, pacote executável e E2E não foram promovidos. |

## 16.100. Revisão corretiva V5.24–V5.31 — 2026-08-31

| Campo | Estado |
|---|---|
| Navegação global | Labels respeitam 200% sem clamp; a caixa central foi reconciliada aos 68 px canônicos, CTA 54 px (12,5% maior) e cruzamento 50/50. Header usa `surface`, sombra do dock é sutil e o ativo usa laranja. |
| Correções | Retorno/foco de Agora e Momentos; CTA do hero alcançável; conflict Acontece com recarga; estados failure/unauthorized/conflict/retry; vazio produtivo sem demo; vídeo válido separado de mídia indisponível; overflow do composer Momentos incluído no scroll correto. |
| Evidência | Gates intermediários 119/119 publishers, 172/172 combinado e 107/107 revisão final. Três goldens 375/200 finais de Acontece, Para Você e Perfil foram atualizados seletivamente e inspecionados; analyzer integral, validador visual e diff check verdes. |
| Estado | Nenhum ID promovido além do máximo registrado. `acontece.publish`, `momentos.publish` e `agora.publish` permanecem `blocked-decision`; total Flutter local permanece 86/207. |
| Limite de pacote | A stage spec autoriza preview local no Superadmin. A futura materialização executável em `apps/principal` permanece sob ownership separado, atribuído sem sobreposição à branch `codex/operations-completion`; este recorte não declara produto Principal concluído. |

## 16.101. Gate final do recorte V4.19–V5.31 — 2026-08-31

| Campo | Estado |
|---|---|
| Recorte | As 14 unidades V4.19–V5.31 estão implementadas e revisadas como superfícies Flutter visuais locais no host autorizado pela stage spec. Isso não promove app Principal executável, backend, integração remota ou E2E. |
| Testes consolidados | 688/688 testes focados de Forms, Imports, Comunicações, Circulares e todas as superfícies Principal do recorte passaram no último gate consolidado. `coelo_ui_admin` passou 110/110; `coelo_api` passou 14/14. |
| Goldens finais | Cinco divergências residuais foram reproduzidas e inspecionadas antes da atualização seletiva: dois Para Você e um Perfil refletiam o dock final aprovado em texto a 200%; dois Publicar no Agora divergiam em 40 pixels de antialias da borda/crop. Somente esses cinco masters foram atualizados, reabertos e reexecutados; Para Você 2/2, Perfil 1/1 e a suíte golden Publicar no Agora 15/15 passaram. |
| Análise estática | `flutter analyze` integral de `apps/superadmin`, `dart analyze` de `packages/coelo_ui_admin` e `packages/coelo_api`: sem issues. |
| Validador visual | `apps/catalog/tool/validate_admin_visual_contracts.dart` passou com a allowlist canônica inalterada. |
| Conhecimento | Os dois gates de `coelo-knowledge` passaram; fontes canônicas foram atualizadas antes das projeções duráveis. |
| Revisão independente | Revisões separadas encerraram os P1 de estados/autorização/criação V4.19–V4.22, foco/Escape/galeria V4.23 e dock/retorno/conflito/mídia/200% V5.24–V5.31. Nenhum P0/P1 conhecido permanece dentro do estágio visual local. |
| Regressão externa | A suíte global havia exposto overflow de 181 px em `/dev/conversations` a 375 px/200% no teste de shell persistente. A família Conversas não pertence a V4.19–V5.31 e não foi alterada para mascarar o problema; permanece registrada para a frente operacional. Goldens de Auth, Help Center e Support modificados como artefatos de falha também não integram esta entrega. |
| Status honesto | Atividade do recorte e Flutter visual local concluídos. `accepted`, `verified`, app Principal executável, Supabase/RLS/R2, autorização produtiva, persistência, reload remoto e E2E continuam dependentes de seus próprios contratos e evidências. |
### OPERATIONS-WAVE — famílias operacionais — 2026-08-31

| Família | `action_id` | Estado preservado | Evidência desta onda | Limite explícito |
| --- | --- | --- | --- | --- |
| Pessoas | `people.list`, `people.create`, `people.edit`, `people.links`, `people.reload` | `people.create` e `people.edit` permanecem `local-green`; `people.list`, `people.links` e `people.reload` permanecem `audited`. | Suíte non-golden compartilhada de Pessoas/Unidades: 45/45 verde; analyzer focado sem issues. | Sem promoção de identidade produtiva, vínculos, persistência, autorização, reload remoto ou E2E. Os goldens não foram renovados porque o shell/navegação compartilhado diverge da referência e está em reconciliação concorrente. |
| Unidades | `units.list`, `units.filter`, `units.create`, `units.edit`, `units.status`, `units.error`, `units.access-denied`, `units.reload` | todos permanecem `local-green`. | Mesma suíte 45/45; `unit_routes_test.dart` 3/3 verde após alinhar as expectativas ao flyout canônico; analyzer focado sem issues. | Sem promoção de backend, RLS, tenant A/B, remoto ou E2E. `units.import`, `units.export` e `units.people-export` ficam fora desta onda e preservam seus bloqueios próprios; nenhum golden foi promovido. |
| Turmas | `groups.list`, `groups.create`, `groups.edit`, `groups.members` | todos permanecem `local-green` visual/Flutter; produção continua read-only/fail-closed para mutações. | Turmas 51/51, cards 5/5, `coelo_ui_admin` 110/110 e 34 goldens reais inspecionados; analyzers, formatter, validador, conhecimento e diff check verdes. | Sem promoção de repository produtivo, capability, Supabase/RLS, tenant A/B, remoto ou E2E. `groups.import` e `groups.export` ficam fora desta onda e permanecem `audited`/fail-closed. |
| Assiduidade / Chamada | `attendance.dashboard`, `attendance.create`, `attendance.mark`, `attendance.correct`, `attendance.finish` | todos permanecem Flutter `local-green`; sem promoção integrada. | 55 testes funcionais verdes; dois goldens Flutter verdes no Windows (contexto 375 light e marcação 1440 dark). O harness fixa 03/08/2026 e o código produtivo preserva `DateTime.now()` como default. | Sem promoção de RPC, RLS, tenant A/B, concorrência remota, auditoria, reload remoto ou E2E. O golden escuro usa o renderer Windows e não prova macOS/Linux. |
| Assiduidade / Exportar | `attendance.export` | Flutter `audited`; backend `fail-closed`; integrado `blocked-supabase`. | Nenhum worker, materializador, ticket/download, Storage ou prova E2E foi introduzido. | Permanece bloqueado até existir job real escopado e autorizado, arquivo sintético, expiração/revogação, DTO seguro, cleanup, negações, tenant A/B e E2E remoto. |
| Rotina Diária | `daily-routine.list`, `daily-routine.create`, `daily-routine.edit`, `daily-routine.apply`, `daily-routine.publish` | todos permanecem Flutter `local-green`; backend e integração continuam nos bloqueios já registrados. | 48 testes verdes e 4 skips justificados; 9 goldens Flutter atualizados e inspecionados; analyzer focado sem issues. Corrigidos o editor read-only sem footer vazio e os status textuais/localizados da tabela. | Cinco referências antigas ficam sem promoção: filtros de origem (2), review, dirty-exit e diálogo compartilhado V4.19/V4.20. Sem promoção de backend/RLS, tenant A/B, remoto ou E2E. |

Esta onda registra 28 `action_id`: 24 permanecem `local-green` e 4 permanecem `audited`, sem impacto incremental sobre os estados já consolidados. Formulários, Respostas, Arquivos de Formulários, Agenda e Eventos não fazem parte do ownership de implementação e não recebem alteração, evidência nova nem promoção neste bloco.

**Gates finais da onda:** Pessoas/Unidades 45/45 e rotas 3/3; Turmas 51/51, cards 5/5, `coelo_ui_admin` 110/110 e 34 goldens inspecionados; Assiduidade 57/57; Rotina Diária 48 aprovados e 4 skips justificados; `flutter analyze` global e analyzers focados sem issues; formatter sem delta; `git diff --check`, validador de contratos visuais do Catálogo e os dois gates de `coelo-knowledge` aprovados. O diff de Forms, Respostas e Agenda contra a base é vazio.

## 16.102. Consolidação das quatro frentes e dataset `/dev` — 2026-09-01

| Campo | Estado |
|---|---|
| Integração | V4/V5, famílias operacionais, Formulários/Agenda e fundação Supabase foram incorporados em uma worktree de consolidação sem alterar o remoto. |
| Formulários e Agenda | 22/22 ações do recorte permanecem `local-green` visual/Flutter; o handoff registrou 238/238 testes focados, incluindo Agenda 112/112, sem promover backend, autorização remota ou E2E. |
| Dataset `/dev` | 12 instituições; 1–4 unidades por instituição; 1–20 turmas por unidade; 30 atividades; 10 modelos de atividade; 400 pessoas com múltiplos vínculos; 6 modelos de rotina diária. |
| Consistência | Instituições, unidades, turmas e Pessoas usam a mesma hierarquia determinística. Produção mantém as mesmas superfícies e não recebe fixtures. |
| TDD | O novo contrato falhou primeiro com 15 instituições e somente 24 pessoas; após a correção, o gate de dataset, Instituições e Turmas terminou 20/20. Analyzer focado sem issues. |
| Limite honesto | O dataset prova somente navegação e comportamento local. Supabase remoto, RLS, autorização, persistência real e E2E continuam dependentes de gates próprios. |
| Conhecimento | Fonte canônica do router e projeção `superadmin-development-dataset` registram a escala e o isolamento produtivo. |

## 16.103. Regressão de transição da toolbar de Instituições — 2026-09-01

| Campo | Estado |
|---|---|
| Evidência no navegador | A navegação real `/dev/institutions` → demais famílias reproduziu `BoxConstraints(w=-6.0)` no `InstitutionDirectoryToolbar`, apesar dos gates focados anteriores. |
| Causa raiz | Durante a transição de rota, a largura intermediária do grupo de filtros podia ficar menor que `CoeloSpacing.space3`; a fórmula de duas colunas subtraía o espaçamento e produzia uma largura negativa. |
| Correção | A largura compacta dos filtros agora é limitada a `0.0`, preservando o layout aprovado nas larguras suportadas e mantendo constraints válidas nos frames transitórios. |
| Regressão | Teste dedicado reproduz a toolbar com 6 px de largura e rejeita qualquer `negative minimum width`; Instituições + rotas terminaram 62/62. As expectativas de rota também foram alinhadas ao isolamento canônico: `/dev` usa repository fake próprio e produção não é consultada. |
| Limite honesto | O ajuste corrige somente a validade do layout transitório e os contratos de teste locais; não promove integração remota ou E2E. |

## 16.104. Reconciliação final da matriz Flutter — 2026-09-01

| Campo | Estado |
|---|---|
| Base | A matriz consolidada contém 207 linhas e 207 `action_id` únicos. O estado foi recalculado diretamente das linhas atuais, sem somar snapshots de branches ou duplicar IDs. |
| Snapshots reconciliados | V4/V5 em `21e0ed09` registrava 86/207; Formulários/Agenda em `4beea0ec`, 100/207; a consolidação em `f3a3e504`, 96/207. Os números permanecem evidência histórica das respectivas branches, não totais atuais concorrentes. |
| Diferenças determinísticas | A comparação `4beea0ec` versus o consolidado encontrou exatamente oito estados distintos: seis ações de Agenda estavam `local-green` no handoff e `blocked-decision` no consolidado; `imports.list` e `notices.list` estavam `audited` no handoff, mas receberam evidência posterior V4/V5 e permanecem `local-green`. |
| Total atual | 105/207 `local-green` (50,72%); 61/207 `audited`; 37/207 `blocked-decision`; 2/207 `audited`/fail-closed; 2/207 `blocked-supabase`. Restam 102/207 fora de `local-green` (49,28%). |
| Formulários/Agenda | Os 22 IDs permanecem `local-green` visual/Flutter. Evidência do handoff: 238/238 testes combinados, Agenda 112/112, rotas/navegação 14/14, analyzer sem issues, validador/índice/conhecimento/diff verdes e 113 goldens únicos. Produção permanece fail-closed e backend/remoto/E2E continuam abertos. |
| Famílias operacionais | 28 IDs reconciliados: 24 `local-green` e 4 `audited`, com impacto incremental zero sobre a matriz já consolidada. Turmas, Assiduidade e Rotina receberam correções textuais para refletir os testes e goldens existentes sem declarar produção concluída. |
| Estado estrito | `verified` permanece 0/207. Fixture, golden, rota `/dev`, fake, teste local ou fail-closed continuam insuficientes para `verified`, Supabase ou E2E. |
| Validação documental | Frontmatter obrigatório, `action_count`, 207 linhas/207 IDs únicos, 14 colunas por linha, contagens por estado e diff restrito foram validados; `git diff --check` e os dois gates de `coelo-knowledge` passaram. O arquivo não contém links Markdown locais pendentes de resolução. |
| Limite | Nenhum código Flutter, backend, migration, remoto ou rastreador Supabase/integrado foi alterado nesta reconciliação documental. |

## 17. Histórico

| Data | Mudança |
|---|---|
| 2026-09-01 | Matriz Flutter reconciliada por 207 IDs únicos: 102 `local-green`, 64 `audited`, 37 `blocked-decision`, 2 `audited`/fail-closed e 2 `blocked-supabase`; seis ações de Agenda restauradas ao estado visual/local do handoff, preservando as promoções posteriores de `imports.list` e `notices.list`. `verified` permanece 0/207 e nenhum backend/E2E foi promovido. |
| 2026-09-01 | Corrigida a largura negativa transitória da toolbar de Instituições encontrada no navegador; regressão estreita adicionada e suíte combinada Instituições/rotas 62/62 verde. |
| 2026-09-01 | Consolidadas as quatro frentes e ampliado o `/dev` para 12 instituições, hierarquia completa de unidades/turmas, 30 atividades, 10 modelos, 400 pessoas e 6 rotinas; contrato TDD 20/20 e analyzer focado verdes, produção preservada sem fixtures. |
| 2026-08-31 | `OPERATIONS-WAVE` pós-rebase sobre `21e0ed09`: rastreador reconciliado manualmente preservando V4.19–V5.31 e os blocos operacionais; Turmas 51/51 e `coelo_ui_admin` 110/110 verdes, analyzers/validador/conhecimento/diff check aprovados. O golden de reporte de bug foi alinhado ao shell compacto aprovado e inspecionado; o diff de Formulários desta branch permanece vazio. |
| 2026-08-31 | Gate final V4.19–V5.31: 688/688 testes focados, 110/110 `coelo_ui_admin`, 14/14 `coelo_api`, analyzers e validador visual verdes; cinco goldens finais atualizados seletivamente após inspeção. A regressão externa de Conversas e os limites de app Principal/backend/E2E foram preservados sem promoção indevida. |
| 2026-08-31 | Revisões independentes V4/V5 corrigiram criação/unauthorized/estados e evidências V4.19–22, Escape/foco/1-de-1 em V4.23 e dock/retorno/conflito/vídeo/200% em V5.24–31. Commits focados: `057aad8f`, `08c7e31c`, `c4c984e1`, `50bf7b0c`; backend/E2E e app Principal executável não promovidos. |
| 2026-08-31 | Família Publicar V5.27/V5.31 fechada visualmente no Flutter local: contexto produtivo explícito, mídia persistida sem distorção, crop/capa Agora com round-trip, frame/cabeçalho Principal compartilhados, 159 testes da família e 36 goldens verdes/inspecionados; remoto, backend e E2E não promovidos. |
| 2026-08-31 | P1 visual/reachability de V4.23 fechado: Circulares ganhou rotas e menu de desenvolvimento reais, fluxo diretório→composer→cancelar e repository explicitamente indisponível; paginação de Circulares e Comunicações foi alinhada a Instituições (`11` cards/`8` tabela + `20/50/100`), o composer passou a reutilizar o footer da família Publicar e as células tabulares ficaram em linha única a 200%. Gates: 64/64 Circulares+rotas, 150/150 ampliado, 30 goldens afetados inspecionados, analyzer e validador verdes; backend/E2E não promovidos. |
| 2026-08-31 | V5.24–V5.26 implementados localmente: Acontece, dock global, Agora fullscreen e Galeria; 94 testes consolidados e 22 goldens inspecionados. O breakpoint 1024 do Agora foi corrigido para tablet; total permanece 86/207 e backend/remoto/E2E seguem abertos. |
| 2026-08-31 | V4.23 implementado como unidade Flutter visual local: diretório canônico, composer da família Publicar, preview lateral e popup com foco, 59 testes e 26 goldens referenciados; a taxonomia não possui ID próprio, então o total permanece 86/207 e backend/remoto/E2E seguem abertos. |
| 2026-08-31 | V4.22 implementado como unidade Flutter visual `local-green`: layout automático cards/tabela, criação canônica, linha 64 px, badges uniformes, preview tipado no desktop, 88 testes e 10 goldens inspecionados; commands/backend/remoto/E2E permanecem abertos. |
| 2026-08-31 | V4.21 implementado como unidade Flutter visual local: diretório/tabela/paginação canônicos, catálogo de oito entidades com indisponibilidade honesta, wizard completo, 24 testes e 24 goldens inspecionados; somente `imports.list` foi promovido, enquanto backend/remoto/E2E permanecem abertos. |
| 2026-08-31 | V4.20 implementado como unidade Flutter visual `local-green`: editor modular, operações protegidas, catálogo categorizado, Data, preview explícito, footer canônico, 29 testes e 14 goldens inspecionados; produção, remoto e E2E permanecem fail-closed. |
| 2026-08-31 | V4.19 implementado como unidade Flutter visual `local-green`: diretório canônico, flyout seguro, diálogo de agendamento, 38 testes focados, 10 goldens inspecionados, analyzers/validador/diff check verdes; composição produtiva, remoto e E2E permanecem abertos. |
| 2026-08-31 | `OPERATIONS-WAVE`: Turmas (`groups.list`, `groups.create`, `groups.edit`, `groups.members`) consolidaram evidência Flutter visual/local sem promoção indevida. Corrigidos unauthorized, failure/create, limpar no-results, semântica read-only, toggles administrativos, persistência fake de membros e harness de goldens; rotas produtivas de mutação continuam fail-closed. `groups.import`/`groups.export`, Supabase/RLS, tenant A/B, remoto e E2E não foram promovidos. |
| 2026-08-31 | `OPERATIONS-WAVE`: reconciliados 24 IDs de Pessoas, Unidades, Assiduidade/Chamada e Rotina Diária sem promoção de estado. Evidências: Pessoas/Unidades 45/45 non-golden, rotas de Unidades 3/3, Assiduidade 55 funcionais e 2 goldens Windows, Rotina 48 verdes/4 skips e 9 goldens inspecionados; analyzers focados e `git diff --check` verdes. `attendance.export` permanece `audited`/`fail-closed`/`blocked-supabase`; goldens compartilhados, produção, Supabase/RLS, tenant A/B, remoto e E2E continuam fora da evidência. Formulários/Respostas/Arquivos e Agenda/Eventos ficaram fora do ownership e não foram promovidos. |
| 2026-08-28 | Registrado o programa visual aprovado de 31 entregáveis em cinco ondas. Separadas as métricas de programa visual, Flutter local, Flutter verified e integração E2E; `0/207 E2E` deixa de representar o progresso Flutter. Nenhum código/backend foi alterado. |
| 2026-08-26 | `groups.import`/`groups.export`: removidos do formulário os dois botões e SnackBars que simulavam sucesso sem arquivo, gateway ou job. RED→GREEN focado 1/1 e suíte `group_form_page_test.dart` 8/8; analyzer focado e global sem erros/warnings. Estado máximo `audited`/fail-closed; fluxos reais de import/export, autorização, Storage, remoto e E2E continuam pendentes. |
| 2026-08-26 | `units.people-export`: removido o botão produtivo que apenas mostrava SnackBar sem gerar job, arquivo ou URL. RED focado reproduziu a ação falsa; GREEN focado 1/1 e suíte `unit_form_page_test.dart` 24/24. Estado máximo fail-closed/`blocked-decision`; funcional real exige capability e snapshot próprios de Pessoas escopados à unidade, backend/Storage, tenant A/B, revogação, cleanup, remoto e E2E. |
| 2026-08-26 | `units.access-denied`: pacote Flutter local omitiu toolbar/filtros/tabs/arquivos/criar/conteúdo/paginação no estado final `unauthorized`, preservando o `createAction` anterior. Handoff registrou 23 testes finais aprovados e esta frente executou uma suíte ampliada de 25 testes, todos aprovados; analyzer ficou em 0 erros/0 warnings/45 infos. Estado máximo `local-green`; pré-resposta, cache/revogação, tenant A/B, deep link, backend/RLS e E2E permanecem abertos. |
| 2026-08-26 | `units.export` HARDEN-EXPORT A+B: gateway Flutter passou a exigir `request_export` → `download` com job correlacionado, DTO/colunas/URL/TTL estritos; UI ganhou single-flight, idempotência controlada, opener injetável, expiração e busy acessível. Os dois arquivos diretos executaram 41 testes e todos passaram; analyzer ficou em 0 erros/0 warnings/45 infos e Catálogo externo manteve somente `superadmin.forms-response`. Estado máximo `audited/local-hardening`; produção `Unavailable`, decisões OQ-032/OQ-034, backend/remoto/E2E e `units.people-export` separado permanecem abertos. |
| 2026-08-26 | P0.5 Units `units.list`: patch de 1 linha forneceu `createAction`; 16 testes Units e 5 router Access passaram; analyzer chegou a zero erros/47 issues; quatro ações de estado adicionadas, totalizando 206 IDs; import/export/backend/goldens permaneceram intocados. |
| 2026-08-26 | P0.5 Access opção A: 3 arquivos preservados externamente com 12.539 bytes/manifesto idêntico; 2 testes router incompatíveis removidos da árvore; fake alinhado sem `isDemo/contextCount`; 9 testes passaram; Access 3→0 erros e global 4→1, bloqueado por Units; 2 router tests não compilaram por esse erro externo. |
| 2026-08-26 | P0.5 Access inventário: 3 erros ligados a testes untracked incompatíveis com composition root 503 e fake com `contextCount`; manifesto de 3 arquivos registrado sem mutação; `access-models.filter` adicionado por possuir UI real, enquanto delete permanece só como contrato futuro; correção aguarda checkpoint backend. |
| 2026-08-26 | P0.5 Forms `forms.edit`: teste dormant reconciliado com o componente catalogado por patch de 2 linhas; 24 testes non-golden passaram; erros globais 6→4 e Forms 2→0; catálogo manteve somente `superadmin.forms-response`; rota produtiva/create/publish/backend/goldens não promovidos. |
| 2026-08-26 | P0.5 Forms `forms.respond`: delta concorrente de 7 arquivos preservado externamente com 40.944 bytes e manifesto idêntico; teste canônico restaurado ao HEAD; 1 teste passou; erros globais 38→6 e Forms 34→2; catálogo manteve exatamente `superadmin.forms-response`; nenhum golden/backend/stage/commit. |
| 2026-08-26 | P0.5 Acompanhamento concluído: 24 legados preservados externamente com manifesto idêntico; erros globais 100→38 e Student Tracking 62→0; 22 testes canônicos passaram. |
| 2026-08-26 | P0.5 Acompanhamento: `f525a7f4` confirmado como contrato read-only canônico; 24 legados não rastreados manifestados; 22 testes canônicos e analyzer focado verdes; preservação externa aguarda coordenação. |
| 2026-08-26 | P1 isolado: 99 testes de Auth e 87 testes de shell passaram; analyzers focados verdes. Login/recovery/reset promovidos a `local-green`, sem conclusão de tela ou integração remota. |
| 2026-08-26 | Contratos parciais de Forms/Acompanhamento/Acesso mapeados; `units.import` e `units.export` marcados `blocked-supabase` porque o adapter existe, mas produção injeta gateways indisponíveis até handoff. |
| 2026-08-26 | Triagem pós-P0 agrupou os 100 erros em 62 de Acompanhamento, 34 de Forms, 3 de testes de acesso e 1 de Unidades; P0.5 de recuperação do snapshot registrado como próximo pacote seguro. |
| 2026-08-26 | Primeiro checkpoint de 60 min do P0: gates focados verdes, analyzer global com 174 diagnósticos; `forms.respond`, `students.list` e `units.list` marcados como regressões externas ao catálogo. |
| 2026-08-26 | P0 Intermediária retomada: `catalog.validate` reproduzido, Advanced Color Picker sincronizado após testes e análise, Forms Response preservado como bloqueio funcional e checkpoint seguro registrado. |
| 2026-08-26 | Criação do rastreador Flutter separado do backend e da prova integrada. |
| 2026-08-26 | Consolidação retomável em HEAD `447ac02c`: 37 famílias, estados por ação, commits/gates, resíduos, ETA e handoff integrado. |
| 2026-08-26 | Organização decisória: tabela geral cumulativa, definição B/I/A/C, matriz de 201 ações com nível aconselhado/estimativa/evidência, decomposição explícita das 12 ações de Instituições, dependências integradas fora de escopo e inventário do worktree concorrente; nenhum código ou backend alterado. |
| 2026-09-01 | Etapa 2/Auth: review independente de `36ae7c86` bloqueou integração porque uma sessão password-recovery era considerada autenticada e podia alcançar Home/rotas protegidas sem `authContext`; `auth.recover` e `auth.reset` foram rebaixadas para `in-progress`, total Flutter ajustado para 100/207. Correção e testes negativos recovery→Home/rota protegida são o primeiro gate (ETA local 1–2 h). Login/logout permanecem `local-green`; MFA permanece aberto/fail-closed; remoto/E2E não foram promovidos. O delta em `apps/catalog` também viola o recorte exclusivo Superadmin e deve preservar compatibilidade ou ser removido antes da integração. |
| 2026-09-01 | Etapa 2/Auth: `f280e291` corrigiu o bypass recovery, adicionou negativos de Home/Instituições/`/dev`/startup/runtime e passou 66/66 Auth/guards/router + 21/21 `coelo_auth`; `auth.recover` e `auth.reset` retornaram a `local-green`, total Flutter 102/207. A branch ainda não é integrável enquanto alterar `apps/catalog` fora do recorte e enquanto ledger/deploy/E2E remoto permanecerem abertos. |

## Checkpoint 2026-09-01 — Comunicações/Avisos e limite da Etapa 2

- `notices.list` mantém o teto `local-green`. O commit `ee8d3aff` adiciona as
  ações canônicas Importar/Exportar com indisponibilidade honesta, 20 fixtures
  `/dev` coerentes e paginação real em múltiplas páginas. Evidências locais:
  37/37 testes, analyzer focado e validador visual verdes; 13 goldens foram
  comparados e atualizados.
- Criar/Editar Aviso já reutiliza frame, navegação de etapas e rodapé canônicos;
  os testes responsivos, desktop e texto a 200% permaneceram verdes no pacote
  acima. Isso não comprova persistência produtiva, autorização ou reload.
- O recorte foi corrigido para somente `apps/superadmin` e pacotes/backend
  indispensáveis. `Coelo (Principal)` é uma superfície do menu do Superadmin;
  `apps/principal`, `apps/admin` e `apps/site` ficam fora da Etapa 2.
- Supabase remoto, RLS, tenant A/B e E2E continuam sem promoção. `verified`
  permanece 0/207.

## Checkpoint 2026-09-01 — Estruturas Superadmin por tela e contrato produtivo

- Commits preservados: `b0fb1293`, `d9232a94`, `0b20d76a`, `560ce79c`,
  `2d2ef3fc`, `51f845c2`, `49a52f6e`, `7e702447`, `2eb3985e` e `c249db2f`.
- Unidades e Turmas possuem adapters candidatos testados, mas produção continua
  `fail-closed`: os RPCs legados são people-based e não representam o ator
  interno nominal exigido pela OQ-043.
- Atividades/modelos representam escopo por Unidade; a migration candidata tem
  31 asserts pgTAP em revisão estática. Docker não respondeu, portanto não há
  replay nem promoção backend.
- Avaliações (`assessments.configure`, `entry`, `gradebook` e `closing`) têm UI
  `/dev` local, mas os 12 RPCs `superadmin_assessment_*` chamados pelo adapter
  não existem nas migrations; `7e702447` mantém as rotas produtivas fail-closed
  e 4/4 testes passaram.
- Shell mobile e rotas de Instituições/Unidades/Turmas/Atividades foram
  revalidados; 15 anexos e três QA estão preservados e manifestados. Flutter
  permanece 102/207 `local-green`, `verified` 0/207; remoto/E2E não mudaram.

## Checkpoint 2026-09-01 — Chat local reaberto por ordem e gate visual

- `5663042f` trouxe `DevelopmentChatRepository` determinístico, cinco conversas
  e 8/8 testes de busca/abertura/leitura/envio. Essa evidência permanece
  preservada, mas `chat.list/open/send` não são promovidos nesta consolidação:
  review encontrou ordenação dupla (`newest-first` + `reverse`/índice invertido)
  e sequência incoerente após envio.
- `465482c0` corrige o launcher duplicado na entrada `principal-chat` e passou
  126/126 testes funcionais, porém 14 goldens do conjunto ampliado continuam
  RED. Chat permanece `audited/in-progress` até teste com 2+ mensagens,
  pós-envio e reconciliação visual deliberada.
- Convites `/dev` também permanece em correção: `fetchOptions` ignorava escopo/
  busca/limite e `issue` aceitava profile/destinatário cross-institution.
- As nove referências de Comunicação continuam preservadas em `f6d44af9` e
  `ab484019`. Produção, remoto e E2E não foram promovidos.

## Checkpoint 2026-09-01 — Operações Flutter `/dev` concluída localmente

- Worktree `codex/finalizacao-telas-operacoes` limpa em `84759675`; Planos,
  Cardápios, Formulários, Importações e Agenda passaram 344/344 testes e analyzer
  sem issues. Contratos visuais e dois gates de conhecimento passaram.
- Planos/Cardápios/Importações fecharam diretórios responsivos, filtros,
  paginação, arquivos honestamente indisponíveis e fixtures vinculadas.
- Formulários separou criar/ver respostas, preservou reordenação, blocos,
  número/dinheiro e agendamento; rota produtiva não oferece criação falsa.
- Agenda fechou calendário/lista/wizard, perguntas curta/Sim-Não com título e
  IDs monotônicos, Solicitações/Aprovações e redirecionamento de Permissões para
  Perfis. Localização é prévia visual, não mapa/geocodificação real.
- Trinta referências foram preservadas com SHA-256 no commit `86e55dc7`.
  Estado máximo é Flutter `/dev` `local-green`; Supabase/remoto/E2E permanecem
  separados e nenhuma tela foi declarada produtiva.

## Checkpoint 2026-09-01 — Comunicação local após revisão seletiva

- `465482c0` remove launcher duplicado; `78ac0ae8` fixa ordem newest-first e
  pós-envio; `c2396f2a`/`2401282e` fecham 14 goldens Chat/launcher.
- `b0dd30a5` faz Convites `/dev` respeitar instituição/unidade/turma/busca/
  limite e rejeita profile/destinatário incompatíveis antes de mutar; 37/37
  testes passaram. `57b746a5` fechou 5/5 goldens do formulário.
- `chat.list/open/send` passam a Flutter `local-green`, levando o total a
  105/207. `chat.edit/attach/receipts/revoke` ficam `audited`; paginação total
  aguarda contrato RPC. Backend/remoto/E2E não foram promovidos.

## Checkpoint 2026-09-01 — Comunicação integrada seletivamente no `dev`

| Tela/subtela/ação | Passo realmente concluído | Estado e evidência | Primeiro passo pendente |
| --- | --- | --- | --- |
| Chat — lista — `chat.list` | Busca/fixtures integradas, launcher duplicado removido e ordenação newest-first corrigida. | Flutter `local-green`; lote pós-merge incluído em 301/301 testes verdes. | Paginação total e repository produtivo dependem do contrato RPC. |
| Chat — conversa — `chat.open` | Fluxo com 2+ mensagens, abertura/leitura e sequência visual revalidado. | Flutter `local-green`; goldens Chat integrados e verdes. | Provar autorização, persistência e reload remotos. |
| Chat — composer — `chat.send` | Ordem pós-envio corrigida e envio local revalidado. | Flutter `local-green`; regressão pós-merge verde. | Provar comando produtivo, auditoria, vínculo revogado e tenant A/B. |
| Chat — editar/anexar/receipts/revogar | Contratos e ausências auditados; nenhuma simulação produtiva adicionada. | `audited`/fail-closed. | Definir RPCs, capability, mídia privada, negativos e E2E. |
| Convites — diretório/detalhe/formulário | `/dev` passou a filtrar instituição/unidade/turma/busca/limite e rejeitar destinatário/profile cross-scope; goldens foram fechados. | Flutter local validado dentro do lote 301/301; produção continua indisponível. | Implementar e provar CRUD/RLS remoto e E2E. |
| Comunicações/Avisos — diretório/criar/editar | Código local previamente aprovado foi integrado sem regressão. | Flutter local preservado; analyzer global sem issues. | RPCs de gestão, `notice_events`, autorizado/negado, reload e E2E. |

- Consolidação seletiva em `dev` termina no commit `f516be71`; `flutter analyze`
  global não encontrou issues e `git diff --check` passou.
- `393fc7ff` (WIP Circulares), `d22a9b3d` (ownership Coelo Principal) e commits
  documentais já reconciliados foram deliberadamente excluídos. A worktree de
  Comunicação permanece preservada até a consolidação das frentes dependentes.
- Contagem permanece 105/207 Flutter `local-green` e 0/207 `verified`.

### Avisos — status remoto não resolvido fail-closed — `c5085746`

- O adapter produtivo não converte mais `published`, `archived` ou status
  desconhecido em draft; falha fechado até a OQ-038.
- Evidência ampliada: Notices Flutter 96/96, adapter 5/5, analyzer dos dois
  arquivos e worker Deno 2/2 verdes. Replay pgTAP não concluiu porque Docker CLI
  travou; foi interrompido sem resíduos `coelo_safe_*`.
- OQ-038, OQ-041 e Storage×R2 bloqueiam lifecycle/remoto.
- Nenhum contador Flutter, Supabase ou integrado foi promovido.

### Auth/Catalog — recovery fail-closed — `5e8d2655`

- Recovery/ausência de sessão normal não chama `CatalogAccessGateway`, não lê
  membership e não monta Home; após RPC, Auth é revalidada antes de publicar
  allowed. Review independente sem P0/P1; corrida P2 corrigida.
- Evidência: dois testes novos, `coelo_auth` 23/23, Superadmin Auth/router
  129/129 e analyzers verdes. Catalog full 138 passou e conserva uma RED textual
  histórica idêntica ao `dev`; nenhum delta visual.
- Estado local Auth não muda; falta integrar e executar remoto/E2E.

### Formulários — leituras produtivas compostas — `236f12cd`

- `forms.monitor`, `forms.responses`, `forms.response-detail` e `forms.files`
  chamam APIs produtivas com IDs reais e estados erro/negado; conteúdo estático
  foi removido. Gate de rotas fail-closed 7/7 e analyzer focado verdes.
- `forms.create/edit/publish/test/respond` continuam fail-closed por contexto,
  versão/request ID e contratos de occurrence/participation/anônimo.
- Sem sessão remota/E2E, nenhuma ação foi promovida no contador.

## Checkpoint 2026-09-01 — Coelo (Principal), `momentos.view` fullscreen

- **Tela/subtela:** Momentos, viewer imersivo ready, navegação vertical,
  controles, fechar/Escape, retorno contextual e restauração de foco.
- **Passo concluído:** `e1cf1be3` removeu o shell persistente e o aside do viewer,
  adotou rota top-level/fullscreen, mídia vertical cobrindo o viewport e fallback
  seguro para deep links.
- **Evidência:** verificação independente passou 28/28 testes focados e analyzer
  dos quatro arquivos afetados sem issues; worktree e `git diff --check` limpos.
- **Referência:** `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/momentos-responsive-reference.png`,
  preservada em `8f89d6d6` e inventariada em `cb6fa272`.
- **Estado:** `momentos.view` permanece Flutter `local-green`; a contagem geral
  não muda (105/207), pois o ID já estava contabilizado. Review independente,
  composição produtiva, backend/remoto e E2E continuam abertos; nenhum golden
  novo foi produzido ou alegado.
- **Review fechado:** `008c14c2` cobriu fechar/retornar também em configuração
  inválida, loading, failure, unauthorized e empty; o review independente foi
  aprovado sem achados. Gate final `momentos.view`: 38/38 testes, analyzer focal
  e diff-check verdes, bookkeeping `14ff3d50`. Flutter local está verificado no
  recorte funcional; validação visual manual/golden integrada continua aberta.

## Checkpoint 2026-09-01 — Circulares, menu/diretório/arquivos local

- `circulars.view`: menu movido para a hierarquia correta, diretório e ações
  Importar/Exportar preservados; 21/21 testes, analyzer focal, diff-check e
  review independente verdes.
- Commits preservados: `ebc0ac29` (referências/manifesto equivalentes a
  `f6d44af9`), `cb6763ed` (ações de arquivo equivalentes a `d22a9b3d`) e
  `52735a18` (hierarquia). `393fc7ff` está ausente e não é ancestral.
- `circulars.create` não é promovido: apenas o nó já existente foi mantido.
  Criar/editar/detalhe/publicar, callbacks reais de arquivo, backend/RLS,
  persistência/reload, remoto e E2E continuam abertos.
- Próximo recorte Flutter: Acontece, card `Publicar agora` com hover/foco/
  pressionar/abrir publicação, seguido por Perfil sem seguidores públicos;
  ETA local informada 35–50 min.

## Checkpoint 2026-09-01 — Acessos e Saúde/Cuidado, handoff `6e56d3e4`

| Tela/subtela | Passo realmente concluído | Estado máximo | Pendência explícita |
| --- | --- | --- | --- |
| Pessoas — diretório/filtros/paginação | Dataset vinculado e diretório `/dev` deduplicado com 462 pessoas. | Flutter local em revisão; matriz não promovida neste checkpoint. | Identidade produtiva, reload, import/export, 10 goldens e 2 expectativas legadas. |
| Pessoas — criar/editar/vínculos/mapa | Wizard local com vínculos de instituição/unidade/turma/criança e mapa aproximado. | `/dev` local; mutações produtivas fail-closed. | Geocodificação/endereço real, autorização, persistência e E2E. |
| Segurança — diretório/detalhe/criar/editar/revisar | 164 registros sintéticos ligados a 180 crianças; cards/tabela/wizard e golden Safety verdes. | Flutter local; `child-safety.suspend` não promovido. | Suspensão/revogação, lifecycle sensível, remoto e E2E. |
| Usuários internos — diretório/criar/editar | Lista e wizard quatro etapas locais; produção exibe indisponibilidade segura em vez de 404. | Flutter `/dev`; ações produtivas continuam `blocked-decision`. | Auth/Convites, RPCs, MFA, import/export e 23 goldens. |
| Perfis e permissões — Perfis/Modelos por app | Central única e edição direta locais; Principal permanece read-only quando não é modelo. | Flutter local em revisão. | OQ-044, produção, 20 goldens e prova integrada. |
| Modelos de perfil — listar/criar/editar/importar/exportar/duplicar | Adapter/composição candidata e UI local; toolbar ainda mantém duplicar/importar/exportar indisponíveis onde não há fluxo. | Flutter local parcial; integração produtiva bloqueada por P0 de identidade/realm backend. | Corrigir principal interno, autorização antes de lookup, anti-escalation cross-app e auditoria; depois replay e fechamento das ações indisponíveis. |
| Perfis de cuidado — lista/criar/editar | 147 perfis sintéticos entre 180 crianças e wizard responsivo. | `local-green` `/dev`; produção fail-closed. | OQ-003/OQ-040, backend/RLS, import/export e goldens. |
| Planos de medicação — lista/criar/editar | 32 planos sintéticos e CRUD local coberto. | Flutter `/dev`; produção fail-closed. | Base legal, autorização, backend/RLS, import/export e E2E. |

- Evidência do handoff: 152/152 testes críticos, gate funcional Acessos 259/259,
  Saúde 127/127 e analyzer global sem issues. A worktree está limpa.
- A dívida visual não foi ocultada: 59 comparações de golden divergem e três
  cenários antigos de Convites usam fixtures/keys obsoletas. Nenhum baseline foi
  aprovado em massa.
- Este checkpoint preserva o handoff sem aumentar a contagem 105/207 enquanto
  as revisões independentes e a integração seletiva não terminarem.

### Pessoas — detalhe/reload interno v2 — `d4a87af8`

- `people.links`/`people.reload`: o formulário produtivo chama
  `superadmin_person_detail_v2`, decodifica envelope estrito e converte sessão,
  permissão e MFA em unauthorized; payload inválido falha fechado.
- Evidência Flutter: 16/16 testes e analyzer focado verdes, diff limpo.
- Estado máximo atual: composição Flutter→RPC contratual local, sem promoção no
  contador. Falta replay pgTAP fresco; Docker está instalado, mas daemon sem
  privilégio permanece indisponível. Remoto recebeu zero mutações e não há E2E.
- `people.list/create/edit` continuam no legado people-based por ausência de spec
  interna aprovada de escrita; não confundir detalhe/reload com CRUD concluído.

### Review independente do handoff — promoção bloqueada

- **Progresso correto do recorte:** 12/31 `action_id` já estavam
  `local-green` no rastreador (38,71%); 19/31 permanecem abertos (61,29%). A
  branch não sustenta promoção adicional.
- **Action IDs oficiais que não podem ser omitidos:** Pessoas
  `people.list/create/edit/links/reload`; Segurança
  `child-safety.list/child/create/edit/suspend`; Perfis
  `access-profiles.list/create/detail/edit/assign/delete`; Modelos
  `access-models.list/filter/create/detail/edit/duplicate`; Usuários internos
  `internal-users.list/create/edit/suspend/mfa`; Saúde
  `health-care.list/create/detail/edit`; Medicação
  `medication.list/create/detail/edit/evidence`.
- **Visual:** 100/100 testes funcionais e validador passaram, mas cinco suítes
  golden terminaram `+1 -13`; diferenças chegam a 83–93% em Perfis mobile e
  47–48% em Usuários internos mobile. A dívida é material e impede conclusão UI.
- **Perfis/Modelos:** composição produtiva usa realm people-based; detalhe só é
  alcançável por deep link porque o diretório abre edição; multi-escopo vira
  filtro nulo e `totalCount` é fabricado como itens vistos + 1. Reter toda a
  fatia até corrigir realm, UX, filtro, paginação, OQ-044 e goldens.
- **Mapa:** `coelo_compact_address_map.dart` chama diretamente
  `tile.openstreetmap.org` e adiciona dependências somente para uma aproximação
  municipal. Não integrar até decidir provider, cache e privacidade.
- **Fixtures:** para 30 adultos responsáveis+equipe, a entrada de equipe pode
  sobrescrever instituições do responsável; corrigir preservação de escopo.
- **Componentes compartilhados:** `d4374e39`/`6e56d3e4` alteram
  `SuperadminFormFrame`/`CoeloStatePanel`; exigem regressão conjunta de Auth,
  Comunicação, Estruturas e Acessos antes de cherry-pick.
- **Primeira fatia candidata:** evidências/decisões, depois fixtures por domínio
  e Segurança infantil (`156332cb` + `b943a5fe`), mantendo
  `child-safety.suspend` pendente. Perfis/Modelos e mapa permanecem retidos.
