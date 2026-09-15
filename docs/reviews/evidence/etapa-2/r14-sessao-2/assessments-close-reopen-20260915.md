# R14 Sessão 2 — assessments.close/reopen

- Rota real: `/assessments/closing/d2c945d8-3809-4d84-b836-2bc6da7c381d`
- action_ids: `assessments.close`, `assessments.reopen`
- Diário reutilizado: `d2c945d8-3809-4d84-b836-2bc6da7c381d`
- Escopo comprovado: `Atividade R05 Estrutura (editada)` → `Turma R05 Estrutura` → período `R08 sintético` → `Criança QA R04`.

## Prova

1. A leitura inicial mostrou o diário completo e a ação de devolução/reabertura.
2. O motivo `Revisao R14 devolvida` foi confirmado pela rota real.
3. A tela mostrou `Devolvido ao professor`, versão 6, e toast `Fechamento atualizado.`
4. Após reload, o histórico e a mesma hierarquia permaneceram; nenhum diário,
   participante, vínculo ou registro de massa novo foi criado.

Capturas:

- [antes](capturas/assessments-close-reopen-before-20260915.png)
- [diálogo](capturas/assessments-reopen-dialog-20260915.png)
- [reaberto](capturas/assessments-reopened-20260915.png)
- [reaberto após reload](capturas/assessments-reopened-reload-20260915.png)

## Resultado

Fatia local/e2e comprovada; nenhuma migration nova foi necessária nesta fatia.
