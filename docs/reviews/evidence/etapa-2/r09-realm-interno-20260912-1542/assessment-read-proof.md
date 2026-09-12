---
source: docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json; docs/reviews/evidence/etapa-2/r08-ambiente-runtime/handoff.md; docs/reviews/evidence/etapa-2/r08-estrutura/assessments-api-execution-20260912.json
status: prova-remota-concluida-proposta-be
generated_at: 2026-09-12
---

# Avaliações — negativa real pela API normal

C0 revisão 97 autorizou G5 a ler os recursos sintéticos retidos, sem criar
dados/SQL. Consumidora G1, apps/superadmin → Estrutura → Atividades/Avaliações
→ `activities.assessment` e `assessments.detail`.

Em 12/09/2026 às 16:08:45 BRT, `assessment-read-probe.py` executou contra o
Supabase de produção com `qa-r06-realm`, login normal e logout exclusivamente
local. Exit0, 9 verificações PASS/0 FAIL, incluindo autenticação/logout; são
6 verificações do contrato de leitura e 1 de unidade inválida, não nove ações.
Saída sanitizada em `assessment-read-proof.json`; nenhum corpo de dado pessoal,
credencial, token ou URL assinada foi salvo. Nenhuma mutação de negócio.

| RPC / capacidade | Assinatura / envelope | Resultado |
| --- | --- | --- |
| superadmin_assessment_configuration_read / activities.read | target_activity uuid, target_unit uuid nullable → JSON ok/data | Anon401/42501; autorizado200/configuração retida; atividade inexistente200/ok/data:null; unidade inexistente200/ok/data:null |
| superadmin_assessment_gradebook_read / activities.read | target_gradebook uuid → JSON ok/data | Anon401/42501; autorizado200/diário retido; diário inexistente200/ok/data:null |

O retorno `ok/data:null` é o contrato de não enumeração, não erro HTTP.
As duas RPCs filtram instituição pelo contexto e validam `activities.read` no
servidor. O corpo de configuração vigente inclui a correção de ambiguidade
`20260912180100`; não houve edição dessas funções nesta tarefa.

## Reutilização e proposta por ação

- `activities.assessment`: propor BE `done` pela régua MVP combinada vigente:
  save/activate/releituras reais R08 (`35922525b`, configuração ativa v2),
  regressão pgTAP G0 R08 de `53b9c6d29` **52/52**, incluindo caso48 de negativa
  cross-tenant da mesma família, e negativas de acesso/não enumeração reais
  R09 acima. O arquivo pgTAP atual tem como última alteração `53b9c6d29`.
  Não houve segunda sessão real escopada em outra instituição nesta prova;
  não chamar o UUID inexistente de tenant real. A reutilização é a exceção
  MVP documentada nas skills, e não prova exaustiva nova. FE/E2E permanecem
  pendentes; C0 integra o delta BE proposto.
- `assessments.detail`: acesso e não enumeração provados, mas manter BE atual
  até a fixture atender ao aceite de turma/aluno/período. A leitura atual
  retornou **zero linhas de aluno**, logo não certificar o detalhe completo.
- `assessments.entry/gradebook`: nenhuma nota ou transição executada.

## Dependência concreta para G1/C0

O backend não monta o diário apenas a partir de membros de Turma.
`assessment_v2_initial_students` exige `activity_group_participants` ativo,
sem removed_at, ligado a `child_group_links`, `child_unit_links`,
`child_contexts` e `people` ativos, para a atribuição já retida.
O teste52 da R08 comprova a cadeia local com aluno; o snapshot produtivo atual
não tem linha de aluno. Isso não prova qual elo está ausente hoje.

Próximo pacote solicitado: autorizar diagnóstico read-only desses vínculos
sintéticos e definir autor da fixture; se houver correção, usar comandos reais
autorizados ou candidato G5 com posse de espelho G0 e aplicação C0. Depois
atualizar o diário existente conforme contrato, sem recriar configuração ou
período e sem lançar nota por G5 nesta autorização de leitura.

O runner possui verificação offline que rejeita falso401, envelope sem data
e vazamento de recurso; PASS, sem rede. Testes históricos não foram rerodados
nem somados aos nove checks atuais. JSON e referências verificados localmente.
Memória: no-op, apenas evidência/diagnóstico do recorte, sem regra nova.
