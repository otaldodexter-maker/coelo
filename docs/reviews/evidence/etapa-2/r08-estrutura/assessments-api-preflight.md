---
fonte: apps/superadmin/lib/features/assessments/data/supabase_assessment_repository.dart; fixture G5 53b9c6d29
status: preflight somente leitura; aguardando ACK e Chrome
data: 2026-09-12
rodada: E2-R08-20260912
---

# Roteiro normal — Avaliações

## Recorte e limites

O roteiro usa somente a fixture sintética já preparada por G5/C0, pela sessão QA autorizada e pela rota normal do Superadmin. Não cria fixture, não usa IDs do pgTAP local como IDs de produção, não chama tabela diretamente e não altera inventário ou rastreadores.

## Ordem por `action_id`

1. `activities.assessment`: abrir a configuração da atividade exibida em `superadmin_assessment_context_options`; ler a configuração com `superadmin_assessment_configuration_read`; salvar o rascunho com `superadmin_assessment_save_configuration`; recarregar; ativar com `superadmin_assessment_activate_configuration`; recarregar e confirmar período `open` no contexto normal.
2. `assessments.entry` e `assessments.gradebook`: abrir o diário para a combinação atividade/turma/período retornada pelo contexto; confirmar a única linha sintética de aluno; salvar uma alteração mínima com `superadmin_assessment_save_gradebook`; recarregar a rota e confirmar o valor persistido.
3. `assessments.close`, `assessments.reopen` e `assessments.detail`: usar o mesmo diário e a transição oferecida pela UI; recarregar após cada transição e confirmar a trilha/estado apresentados pela rota normal.
4. Negativa: trocar para o ator/escopo sintético B preparado pela fixture e tentar abrir ou salvar a configuração/diário de A. Esperado: negação autorizada sem dados de A (`SAI_PERMISSION_DENIED` ou envelope equivalente).

## Critérios de aceite

- cada mutação retorna o estado autoritativo e sobrevive ao reload;
- o período ativado aparece aberto para o contexto QA A;
- diário contém aluno da fixture e não substitui IDs ou versões recebidos do servidor;
- escopo B não lê nem grava recurso de A;
- evidência final registra rota, ação, ambiente, data, estado antes/depois e resultado, sem segredo nem identificador real.

## Pré-condições de execução

- C0 concede Chrome/runtime e confirma qual contexto sintético está ativo no ambiente;
- a UI retorna a combinação da fixture em `superadmin_assessment_context_options`;
- nenhuma outra frente mantém Chrome aberto.

## Preflight de contrato concluído

Leitura de `SupabaseAssessmentRepository` confirmou que a rota normal usa: `superadmin_assessment_context_options`, `superadmin_assessment_configuration_read(target_activity, target_unit)`, `superadmin_assessment_save_configuration(request_id, configuration_id, expected_version, payload)` e `superadmin_assessment_activate_configuration(request_id, configuration_id, expected_version)`. Para o diário, usa `superadmin_assessment_save_gradebook`, `superadmin_assessment_gradebook_read` e `superadmin_assessment_closing_queue`; as transições seguem RPCs de comando com `request_id`, id e `expected_version`. O cliente recarrega configuração e diário após as mutações, portanto a prova pelo fluxo normal já observa o estado autoritativo sem chamar tabelas diretamente.

## Correção pelo preflight remoto G7

O preflight remoto somente leitura mediu uma assignment no contexto QA, mas `periods` vazio, `configuration_read` com `data:null` e `closing_queue` vazio. A fixture G5 é rollback no espelho, não dado materializado em produção. Portanto, este roteiro substitui a hipótese anterior:

1. selecionar a assignment medida pela rota normal;
2. criar configuração com `save_configuration(request_id, configuration_id:null, expected_version:0, payload)` e reler;
3. ativar com `activate_configuration(request_id, configuration_id, expected_version)` e reler `context_options`, exigindo período `open`;
4. só então criar diário com `save_gradebook(request_id, gradebook_id:null, expected_version:0, payload{activity_group_link_id,period_id,configuration_id,students:[]},reason:null)` e reler por `gradebook_read(target_gradebook)`;
5. substituir “close/reopen” pelos comandos reais `submit_gradebook`, `review_gradebook`, `return_gradebook` e, quando aplicável, `publish_gradebook`, cada um com `request_id`, `gradebook_id`, `expected_version` e motivo, seguido de releitura.

Nenhuma promoção ocorre antes de configuração, período e diário autoritativos; nenhum segredo ou ID medido foi registrado neste artefato.
