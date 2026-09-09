---
title: "Etapa 2 — painel de certificação por tela e subtela"
source: "docs/reviews/inventario-etapa-2.json; docs/reviews/coelo-flutter-pendencias.md; docs/reviews/coelo-supabase-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md"
status: "histórico do dev local — superado como retrato geral pelo fechamento R01"
generated_at: "2026-09-09"
---

# Etapa 2 — apps/superadmin

> Atualização posterior: checkout e regras consolidados na branch Git dev;
> worktrees R01 retiradas de operação. Ver [recibo da consolidação](2026-09-09-consolidacao-git.md).
> Os estados de sincronização local descritos abaixo são históricos.

**Este painel é histórico do `dev` local, não a situação global mais recente.**
A leitura posterior encontrou a base integrada `e2-c00` e seu
[fechamento R01](C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/reports/R01-fechamento-20260909.md).
Esse fechamento registra FE 2/219 (apenas duas ações adiadas), FE ativo 0/194,
BE 0/212 e E2E ativo 0/187. Use o
[painel integrado por tela](C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/reports/R01-painel-por-tela.md)
e os rastreadores da mesma base. As linhas abaixo preservam o snapshot original
e não devem sobrescrever estados mais recentes nem ordenar reimplementação.

Snapshot do inventário de 2026-09-08, com base histórica 19b8f574; leitura local em 09/09/2026. Inclui o menu Coelo (Principal) no Superadmin. Admin, Principal e Site ficam fora.

**E2E certificado conhecido: 0/187 = 0,00%; restante não certificado: 187/187 = 100,00%.** Não significa zero implementado. Há 219 ações e 38 famílias: 189 MVP (187 com backend e duas apenas cliente), cinco de shell, três no gate formal e 22 operações reais pós-MVP. Incluindo o gate formal, a base E2E conhecida é 190. Os totais FE/BE abaixo incluem todos os seus escopos aplicáveis e não se confundem com o MVP ativo.

**Testes do app: taxas atuais de aprovação, falha e cobertura do plano não calculáveis.** NC significa ausência de campanha consolidada por caso/revisão; não significa falha ou ausência de testes. Resultados históricos precisam de vínculo por action_id/test_id antes de agregação. Nenhum teste do app foi executado para gerar este painel.

**Cobertura de telas incompleta:** Circulares não tem mapeamento próprio fechado. `screen` combina tela/subtela e não possui menu estruturado para todos os IDs; os rótulos abaixo são preservados. Reconciliar essas lacunas antes de chamar a base de inventário completo do app.

Usar o [contrato de métricas](../superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md) e o [diagnóstico de entrega](2026-09-09-etapa-2-entrega-e-metricas.md). Este é um retrato datado; futuros checkpoints usam o inventário atualizado.

## Totais por família de telas

| Família | IDs conhecidos | FE certificado | BE certificado aplicável | E2E ativo certificado | Testes atuais |
|---|---:|---:|---:|---:|---|
| auth | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/4 = 0,00% | NC |
| shell | 5 | 0/5 = 0,00% | Não aplicável | Não aplicável | NC |
| institutions | 13 | 0/13 = 0,00% | 0/13 = 0,00% | 0/11 = 0,00% | NC |
| units | 13 | 0/13 = 0,00% | 0/13 = 0,00% | 0/10 = 0,00% | NC |
| groups | 7 | 0/7 = 0,00% | 0/7 = 0,00% | 0/5 = 0,00% | NC |
| people | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| access_profiles | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| access_models | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| invites | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| activities | 7 | 0/7 = 0,00% | 0/7 = 0,00% | 0/7 = 0,00% | NC |
| assessments | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| students | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| attendance | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/5 = 0,00% | NC |
| daily_routine | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| agenda | 7 | 0/7 = 0,00% | 0/7 = 0,00% | 0/7 = 0,00% | NC |
| chat | 7 | 0/7 = 0,00% | 0/7 = 0,00% | 0/7 = 0,00% | NC |
| notices | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| forms_authoring | 7 | 0/7 = 0,00% | 0/7 = 0,00% | 0/7 = 0,00% | NC |
| forms_responses | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| forms_files | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| acontece | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/4 = 0,00% | NC |
| agora | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/4 = 0,00% | NC |
| momentos | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/4 = 0,00% | NC |
| principal_profile | 3 | 0/3 = 0,00% | 0/3 = 0,00% | 0/3 = 0,00% | NC |
| child_safety | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| health_care | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/4 = 0,00% | NC |
| medication | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| imports | 7 | 0/7 = 0,00% | 0/7 = 0,00% | Não aplicável | NC |
| profile_files | 6 | 0/6 = 0,00% | 0/6 = 0,00% | Não aplicável | NC |
| audit | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/3 = 0,00% | NC |
| support | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| account | 6 | 0/6 = 0,00% | 0/4 = 0,00% | 0/3 = 0,00% | NC |
| catalog | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/4 = 0,00% | NC |
| plans | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/5 = 0,00% | NC |
| meal_plans | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| internal_users | 5 | 0/5 = 0,00% | 0/5 = 0,00% | 0/4 = 0,00% | NC |
| error_pages | 6 | 0/6 = 0,00% | 0/6 = 0,00% | 0/6 = 0,00% | NC |
| locations | 4 | 0/4 = 0,00% | 0/4 = 0,00% | 0/4 = 0,00% | NC |

## Tela/subtela por ação

Estados declarados na fonte, sem nova certificação. O percentual de uma ação é binário (0/1 ou 1/1); o da tela usa a união dos seus IDs. A coluna Escopo distingue MVP, cliente apenas, gate formal e pós-MVP.

| Tela/subtela na fonte | action_id | Escopo | FE | BE | E2E ativo | Testes |
|---|---|---|---|---|---:|---|
| Auth / Login | auth.login | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auth / Recuperar senha | auth.recover | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auth / Redefinir senha | auth.reset | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auth / Sair | auth.logout | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auth / MFA | auth.mfa | gate-formal-mvp | pending-verification | gate-formal-mvp | gate-formal-mvp | NC |
| Shell / Carregamento | shell.load | flutter-only | pending-verification | not-applicable | flutter-only | NC |
| Shell / Navegação | shell.navigate | flutter-only | pending-verification | not-applicable | flutter-only | NC |
| Shell / Troca de contexto | shell.switch-context | flutter-only | pending-verification | not-applicable | flutter-only | NC |
| Shell / Acesso negado | shell.unauthorized | flutter-only | pending-verification | not-applicable | flutter-only | NC |
| Shell / Recarregar | shell.reload | flutter-only | pending-verification | not-applicable | flutter-only | NC |
| Instituições / Diretório | institutions.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Filtros | institutions.filter | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Detalhe | institutions.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Instituição | institutions.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Instituição | institutions.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Ativar-desativar | institutions.status | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Arquivos | institutions.files | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Importar | institutions.import | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Instituições / Exportar | institutions.export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Instituições / Erro e retry | institutions.error | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Acesso negado | institutions.access-denied | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituições / Recarregar | institutions.reload | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Instituição / Mapa e locais | institutions.locations-map | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidades / Diretório | units.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidades / Filtrar | units.filter | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Unidade | units.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Unidade | units.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidades / Status | units.status | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidades / Importar | units.import | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Unidades / Exportar | units.export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Unidades / Erro | units.error | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidades / Acesso negado | units.access-denied | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidades / Recarregar | units.reload | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidade / Pessoas / Exportar | units.people-export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Unidade / Mapa e locais | units.locations-map | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Unidade / Copiar local | units.copy-institution-location | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Turmas / Diretório | groups.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Turma | groups.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Turmas / Detalhe-editar | groups.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Turmas / Membros | groups.members | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Turmas / Importar | groups.import | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Turmas / Exportar | groups.export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Turma / Local | groups.location | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Pessoas / Diretório | people.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Pessoa | people.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Pessoa | people.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Pessoas / Vínculos | people.links | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Pessoas / Recarregar | people.reload | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Perfis de acesso / Lista | access-profiles.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar perfil de acesso | access-profiles.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Perfil de acesso / Detalhe | access-profiles.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar perfil de acesso | access-profiles.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Perfis de acesso / Atribuir | access-profiles.assign | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Perfis de acesso / Excluir | access-profiles.delete | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Modelos de acesso / Lista | access-models.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Modelos de acesso / Filtrar | access-models.filter | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar modelo de acesso | access-models.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Modelo de acesso / Detalhe | access-models.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar modelo de acesso | access-models.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Duplicar modelo de acesso | access-models.duplicate | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Convites / Lista | invites.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Convite | invites.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Convite / Detalhe | invites.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Convite / Reenviar | invites.resend | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Convite / Revogar | invites.revoke | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Atividades / Diretório | activities.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Atividade / Wizard | activities.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Atividade / Detalhe | activities.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Atividade | activities.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Atividade / Publicar | activities.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Atividade / Avaliar | activities.assessment | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Atividade / Local | activities.location | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avaliações / Lançamento | assessments.entry | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avaliações / Diário | assessments.gradebook | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avaliações / Fechar | assessments.close | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avaliações / Reabrir | assessments.reopen | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avaliação / Detalhe | assessments.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Alunos / Acompanhamento | students.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Alunos / Vincular | students.link | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Alunos / Transferir | students.transfer | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Alunos / Editar | students.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Alunos / Revogar | students.revoke | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Assiduidade / Dashboard | attendance.dashboard | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Assiduidade / Nova chamada | attendance.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Assiduidade / Marcar | attendance.mark | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Assiduidade / Corrigir | attendance.correct | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Assiduidade / Concluir | attendance.finish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Assiduidade / Exportar | attendance.export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Rotina diária / Diretório | daily-routine.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Rotina | daily-routine.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Rotina | daily-routine.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Rotina / Aplicar | daily-routine.apply | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Rotina / Publicar | daily-routine.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agenda / Calendário | agenda.view | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agenda / Criar evento | agenda.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agenda / Detalhe | agenda.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agenda / Editar | agenda.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agenda / Solicitar | agenda.request | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agenda / Permissões | agenda.permissions | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Evento / Local | agenda.location | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Conversas | chat.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Abrir conversa | chat.open | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Enviar mensagem | chat.send | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Editar mensagem | chat.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Anexar arquivo | chat.attach | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Recibos | chat.receipts | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Chat / Revogar-remover | chat.revoke | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avisos / Diretório | notices.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Aviso | notices.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Aviso | notices.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avisos / Agendar | notices.schedule | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avisos / Publicar | notices.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Avisos / Arquivar | notices.archive | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulários / Diretório | forms.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Formulário | forms.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Visão geral | forms.overview | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Editar | forms.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Publicar | forms.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Testar | forms.test | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Pergunta Local interno | forms.location-question | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Respostas / Monitor | forms.monitor | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Responder Formulário | forms.respond | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Respostas / Lista | forms.responses | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Resposta / Detalhe | forms.response-detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Exportar respostas | forms.responses.export | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Formulário / Responder Local interno | forms.location-answer | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Arquivos de Formulários / Upload | forms.upload | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Arquivos de Formulários / Resolver | forms.resolve-file | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Arquivos de Formulários / Baixar | forms.download | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Arquivos de Formulários / Expirar | forms.expire-file | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Arquivos de Formulários / Excluir | forms.delete-file | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Acontece / Feed | acontece.feed | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Acontece / Criar | acontece.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Acontece / Publicar | acontece.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Acontece / Remover | acontece.remove | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agora / Visualizar | agora.view | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agora / Criar | agora.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agora / Publicar | agora.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Agora / Expirar | agora.expire | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Momentos / Visualizar | momentos.view | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Momentos / Criar | momentos.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Momentos / Publicar | momentos.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Momentos / Remover | momentos.remove | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Principal / Para Você | principal.for-you | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Principal / Perfil-circulares | principal.profile-view | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Principal / Editar perfil | principal.profile-edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Segurança infantil / Lista | child-safety.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Segurança infantil / Criança | child-safety.child | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Segurança infantil / Criar autorização | child-safety.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Segurança infantil / Editar autorização | child-safety.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Segurança infantil / Suspender | child-safety.suspend | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Perfis de cuidado / Lista | health-care.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar perfil de cuidado | health-care.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Perfil de cuidado / Detalhe | health-care.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar perfil de cuidado | health-care.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Medicação / Lista | medication.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Medicação / Criar | medication.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Medicação / Detalhe | medication.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Medicação / Editar | medication.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Medicação / Evidência | medication.evidence | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Importações / Hub | imports.list | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Importações / Nova | imports.create | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Importações / Upload | imports.upload | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Importações / Preview | imports.preview | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Importações / Confirmar | imports.confirm | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Importações / Status | imports.status | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Importações / Baixar | imports.download | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Arquivos de perfil / Importar | profile-files.import | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Arquivos de perfil / Preview | profile-files.preview | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Arquivos de perfil / Confirmar | profile-files.confirm | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Arquivos de perfil / Status | profile-files.status | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Arquivos de perfil / Exportar | profile-files.export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Arquivos de perfil / Baixar | profile-files.download | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Auditoria / Lista | audit.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auditoria / Filtrar | audit.filter | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auditoria / Detalhe | audit.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Auditoria / Exportar | audit.export | deferred-post-mvp | pending-verification | deferred-post-mvp | deferred-post-mvp | NC |
| Suporte / Criar | support.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Suporte / Tabela | support.table | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Suporte / Kanban | support.kanban | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Suporte / Detalhe | support.detail | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Suporte / Responder | support.reply | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Suporte / Encerrar | support.close | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Conta / Perfil | account.profile | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Conta / Configurações | account.settings | mvp | pending-verification | not-applicable | Cliente apenas | NC |
| Conta / Tema | account.theme | mvp | pending-verification | not-applicable | Cliente apenas | NC |
| Conta / MFA | account.mfa | gate-formal-mvp | pending-verification | gate-formal-mvp | gate-formal-mvp | NC |
| Conta / Sessões | account.sessions | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Conta / Sair | account.logout | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Catálogo / Lista | catalog.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Catálogo / Validar | catalog.validate | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Catálogo / Sincronizar | catalog.sync | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Catálogo / Publicar | catalog.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Planos / Diretório | plans.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Plano | plans.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Plano | plans.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Planos / Ativar | plans.activate | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Planos / Atribuir | plans.assign | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Cardápios / Diretório | meal-plans.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar Cardápio | meal-plans.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar Cardápio | meal-plans.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Cardápios / Criar modelo | meal-plans.model-create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Cardápios / Editar modelo | meal-plans.model-edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Cardápios / Publicar | meal-plans.publish | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Usuários internos / Lista | internal-users.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Criar usuário interno | internal-users.create | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Editar usuário interno | internal-users.edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Usuários internos / Suspender | internal-users.suspend | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Usuários internos / MFA | internal-users.mfa | gate-formal-mvp | pending-verification | gate-formal-mvp | gate-formal-mvp | NC |
| Erros / 403 | errors.403 | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Erros / 404 | errors.404 | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Erros / 409 | errors.409 | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Erros / 500 | errors.500 | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Erros / 503 | errors.503 | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Erros / Tentar novamente | errors.retry | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Locais / Diretório | locations.list | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Local / Criar e editar | locations.create-edit | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Local / Detalhe e vínculos | locations.detail-links | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
| Locais / Agendamento | locations.schedule | mvp | pending-verification | pending-verification | 0/1 = 0,00% | NC |
