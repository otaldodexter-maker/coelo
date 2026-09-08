---
title: "F-AUTHOR01 — fechamento nominal de coexistência"
source: "Fechamento técnico do Coordenador após 38041740; inventário efetivo Root e duas revisões read-only"
status: "static-reviewed-local-package-prepared"
generated_at: "2026-09-07"
---

# Contrato fechado e reserva

Pacote LOCAL reservado: `20260908030000_superadmin_internal_form_drafts_v2.sql`.
Sem edição de migration histórica, revoke global, ator People artificial,
mudança de require_forms_actor, MFA, Admin/Principal ou workers. SQL não executado.

Reader nominal usa `forms.manage` OU `forms.read` explicitamente: tenta manage;
somente negativa de capability permite tentar read, nunca falha de sessão ou
membership. Save exige manage. Diretório F-READ continua exigindo read.
Não é concessão implícita entre permissões.

Criação e edição limitadas a autoria interna real, status draft, first_published_at
nulo, published_version_id nulo, nenhuma versão publicada/superseded, nenhuma
application, occurrence ou file job. Verificação de edição sob lock da linha,
mesma instituição real e escopo autorizado. Reader não projeta aplicação.
População nova não tem entrada produtiva de publicar nesta fatia.

Receipt privado mantém snapshot sanitizado original do FormDefinition, não
recarrega versão posterior no replay. Sessão/capacidade/escopo e estado atual do
recurso são reautorizados antes do snapshot. Identidade interna, instituição,
recurso, expected_version e hash devem coincidir. Audit permanece fora do catch:
falha de append aborta escrita e receipt; erros internos não viram sucesso.

# Matriz de entrada e ponto da proteção

Fontes abaixo ficam em `packages/coelo_database/migrations/`; E/F também têm
cópia idêntica em `supabase/migrations/`. Inventário não prova estado remoto.

- A: `20260813155121_forms_commands_and_projections.sql`.
- B: `20260813155124_forms_jobs_notifications_and_exports.sql`.
- C: `20260813155126_forms_security_performance_closure.sql`.
- D: `20260813170001_forms_monitor_hierarchy.sql`.
- E: `20260820154638_forms_distribution_cardinality_limits.sql`.
- F: `20260825193120_final_review_forms_runtime_hardening.sql`.
- G: `20260901194209_forms_distribution_target_authorization.sql`.
- H: `20260820152528_forms_editor_application_capability_guard.sql`.

| Corpo efetivo | Fonte | Fechamento nominal antes de exposição/efeito |
| --- | --- | --- |
| form_list(jsonb) | A:596 | Predicado no WHERE de forms antes de agregação, cursor, limit, has_more; não filtrar JSON final. |
| form_get_editor(uuid) | H:1 | Predicado antes de definition/application projection; manter manage OR read e capability de aplicação. |
| form_get_overview(uuid) | A:701 | Guard antes da projeção e dos três counts. |
| form_save_draft(uuid,bigint,jsonb) | A:427 | Guard antes de receipt, novamente após FOR UPDATE antes de before_state. |
| form_publish(uuid,bigint,jsonb) | A:530 | Guard antes de receipt e após FOR UPDATE antes de validação/publicação. |
| form_duplicate(uuid,bigint,jsonb) | A:758 | Guard de origem antes de receipt e após lock antes de clone. |
| form_copy_or_move(uuid,bigint,jsonb) | A:784 | Guard da origem antes de receipt e após lock antes de move/clone. |
| form_archive_or_delete(uuid,bigint,jsonb) | A:832 | Guard antes de receipt e após lock antes de delete/archive. |
| form_clone(uuid,uuid,uuid) privado | A:721 | Defesa de origem antes de projeção/inserts, lock compatível; não confiar só no chamador. |
| form_request_export(uuid,bigint,jsonb,boolean) privado, duas entradas públicas | B:925 | Guard de form_id antes de receipt e lookup/efeito; ramo anonymous também. Zero respostas não impede job. |
| form_save_application(uuid,bigint,jsonb) | F:650; wrapper G:30 | Guard público antes do lookup de distribution_target, preservando checagens G; guard privado de form_id real antes de receipt. Application existente também resolve sua origem. |
| form_save_schedule(uuid,bigint,jsonb) | E:240; wrapper G:69 | Resolver application→form no wrapper antes de distribution_target e no privado antes de receipt; schedule existente conserva vínculo real. |
| form_remove_schedule(uuid,bigint,jsonb) | A:1009 | Resolver schedule→application→form antes de receipt; sem recurso não substituir replay histórico de remoção. |
| form_get_monitor(jsonb) | D:135 | Guard antes do lookup; zero occurrences ainda revela is_anonymous e métricas. |
| form_list_monitor_hierarchy(jsonb) | F:547 | Guard antes do lookup/ramificação, mesmo retorno vazio. |
| form_list_monitor_people(jsonb) | A:1182 | Guard antes do lookup/ramificação anonymous. |
| form_anonymous_participation_lookup(jsonb) | B:1041 | Guard antes do lookup e auditoria nominal de participação. |

Guard novo, privado e nominal, somente para a população de rascunhos internos
nunca publicados; não é veto permanente por autoria. Não alterar projeção
compartilhada de definições, pois responder legítimo usa versões publicadas.
O predicado de exclusão NÃO inclui ausência de applications, occurrences ou
jobs: essas ausências são gates do novo authoring. Dependência inesperada não
pode fazer um rascunho protegido voltar a ficar visível ao legado.
Corpos efetivos serão republicados forward-only com guard localizado, sem
renomear implementações para atalhos que possam reter referências por OID.

Antes do receipt, negar existência de recurso protegido; NÃO exigir existência
de todo recurso. Replay legado válido de delete deve continuar funcionando após
remoção da linha. Rechecagem de mutations usa lock do recurso.
Em export e operações indiretas, resolver e bloquear a linha **Forms** antes
dos efeitos; manter locks de application/schedule existentes, que não substituem
o lock Forms. No wrapper G, a negativa do recurso protegido deve equivaler à
ausência na checagem existente, sem mensagem que revele autoria/instituição.

# Prova estrutural dos caminhos preservados

| Caminho | Por que não alcança a nova população sem quebrar os gates acima |
| --- | --- |
| form_list_file_jobs / authorize/redeem download | Exigem job/artefato/token do solicitante; novo draft não possui job e request_export estará bloqueado. Não inferir RPC pública de download: wrappers não encontrados. |
| form_list_responses / response_detail | Lista só respostas submitted, ou exige resposta existente; zero respostas é vazio indistinguível. |
| get_occurrence_for_response / open_response_draft / mutate_response | Exigem occurrence e participação elegível; não consultar autoria como audiência permanente. |
| generate_occurrences / generate_due_occurrences | B:326/441 exige application/schedule ativos, forms.status published e published_version_id não nulo. |
| reconcile_audience / metrics / reminders | Dependem de occurrence existente; não iniciam distribuição a partir de draft. |
| worker export snapshot/begin/complete/fail | Dependem de file job e lease; request bloqueado e ausência de jobs no novo recurso são indispensáveis. |

Nenhuma função de responder, participação, mídia ou worker muda por autoria.
No futuro publish nominal deve substituir esta barreira com autorização de
audiência aprovada; esta fatia não define esse fluxo.

# REDs antes da corretiva e replay exclusivo

Testes novos rollback-only: identidade sem People, seis quick polls incompletas,
integridade e IDs adversariais, read-only/manage-only, A/B, versão/replay exato,
revogações, audit obrigatório/rollback, portas legadas (incluindo pre-receipt),
listagem sem leaks de paginação, nenhum job/application/occurrence e controle
legado de delete/replay. RPCs como authenticated, TAP somente após RESET ROLE.
Review independente da matriz e do pacote antes de encaminhar hash a Eng1.

Escopo integral permanece: editor/publicação/distribuição, responder, monitor,
locais internos, imagens, XLSX/R2 e cuidado. Contrato e testes preparados não
comprovam integração nem produção. Gate de memória: sem nova decisão de produto.
