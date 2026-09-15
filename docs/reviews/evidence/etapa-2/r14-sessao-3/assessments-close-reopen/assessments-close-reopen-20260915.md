---
status: blocked-target
lifecycle: current
round: R14
session: 3
owner_items:
  - owner.r12-49
action_ids:
  - assessments.close
  - assessments.reopen
base: ee179b1e1474eef594a131b95f762df0dc41d647
environment: producao
recorded_at: 2026-09-15T12:46:00-03:00
---

# Assessments — fechar e reabrir

## Recorte e massa

- Rota real: `http://127.0.0.1:3016/assessments/closing` e
  `/assessments/closing/d2c945d8-3809-4d84-b836-2bc6da7c381d`.
- Diário reutilizado: `d2c945d8-3809-4d84-b836-2bc6da7c381d`.
- Hierarquia observada: instituição `Escola R04 Estrutura` → unidade
  `Unidade Centro R04` → turma `Turma R05 Estrutura` → período `R08 sintético`.
- Participante observado: `Crianca QA R04`; nenhum diário, participante ou
  vínculo novo foi criado.
- Servidor: `127.0.0.1:3016`; Chrome CDP: `9416`.

## Sequência observada no alvo CDP auxiliar

1. A fila de fechamento listou o diário existente com a hierarquia da turma e
   período, sem duplicação.
2. O lançamento existente foi aberto e enviado para fechamento pela etapa
   “Revisão e envio”; a tela retornou à fila.
3. No detalhe do mesmo diário, “Revisar” abriu o diálogo de justificativa.
   Confirmado com `R14 fechamento autorizado`; o histórico mostrou “Revisado”,
   versão 8 e “ator auditado”. Isto é a prova de `assessments.close`.
4. “Devolver” abriu o diálogo de reabertura. Confirmado com
   `R14 reabertura autorizada`; após reload, o histórico mostrou “Devolvido ao
   professor”, versão 9, justificativa e “ator auditado”. Isto é a prova de
   `assessments.reopen` e persistência.
5. O deep-link com UUID inexistente exibiu “Diário indisponível — Recarregue ou
   verifique sua permissão”, sem expor ou criar dados.

## Bloqueio de aceite

O alvo CDP `9416` usado para essa observação era uma instância separada da aba
visível do Chrome. A aba visível identificada como `829823611` permaneceu em
`http://127.0.0.1:3016/login`, com E-mail e Senha vazios e mensagens de
validação client-side. Por isso, esta captura não é promovida a prova de rota
real aceite: precisa ser repetida no mesmo alvo visível/autorizado. O Chrome
dedicado foi encerrado após a detecção; não houve nova tentativa de credencial.

## Evidências visuais

- [Fila do diário](assessment-closing-queue.png)
- [Revisão e envio](assessment-gradebook-review.png)
- [Detalhe após envio](assessment-submitted-detail.png)
- [Diálogo de revisão](assessment-close-dialog.png)
- [Revisado, versão 8](assessment-reviewed.png)
- [Diálogo de reabertura](assessment-reopen-dialog-final.png)
- [Reaberto após reload, versão 9](assessment-reopened-reload-final.png)
- [Deep-link inexistente negado](assessment-negative-missing.png)

## Testes e limites

- Direcionado: `flutter test test/features/assessments/assessment_entry_page_test.dart test/features/assessments/data/supabase_assessment_repository_test.dart test/app/router/assessment_routes_test.dart` — PASS, 29 testes; isto certifica apenas o código/teste local, não a rota visível.
- O teste de rota foi corrigido para informar `institutionId=institution-1`, que
  é obrigatório para a configuração retornar dentro do escopo; a alteração é
  somente de teste.
- Build usado na prova: `flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local --dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true` — PASS.
- A suíte SQL `superadmin_assessments_internal_v2_test.sql` foi executada no
  espelho antes da conclusão e parou por drift do ambiente: privilégios extras
  pré-existentes e fixture sem `people` para o follower
  `c0e10000-0000-4000-8000-000000000001`. Não foi mascarada nem corrigida com
  fixture, e nenhum SQL foi executado em produção. O contrato BE já estava
  publicado como `done` no corte R14; esta sessão não altera essa classificação.
