---
source: "R07 · Formulários, Cuidado e Rotina"
status: "handoff-final"
generated_at: "2026-09-12"
---

# Handoff R07 — Formulários, Cuidado e Rotina

## Entrega

- App autorizado: `apps/superadmin`; família visual da Publicação hospedada no Superadmin.
- Worktree: `C:/Users/adrie/Documents/Coelo.worktrees/e2-r07-formularios-cuidado-rotina`.
- Branch: `work/etapa2-r07-formularios-cuidado-rotina`.
- HEAD de código: `6bc005288`; HEAD final do handoff: `9e16e1361` (`docs(r07): reconciliar IDs canônicos de assiduidade`).
- O remoto da branch coincide com o HEAD local; worktree limpa, sem arquivos modificados, untracked ou stash.
- Comunicação: `docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado-rotina.json`, revisão 60.
- Deltas: `docs/reviews/evidence/etapa-2/r07-formularios-cuidado-rotina/deltas-r07-fcr.json`.

## Feito e evidências

- `attendance.mark`: `AttendanceCallPage` reconstruída sobre `PublicationSurface`, com segmentos P/F/A, Marcar todos presentes e observação por aluno. `attendance.finish`: resumo no web, rodapé com Concluir chamada e launcher de chat desligado. `attendance.correct`: estado concluído hospedado na nova superfície, com o diálogo/contrato existentes preservados. `attendance.create` não teve implementação alterada na R07; `AttendanceNewCallPage` ficou fora do delta.
- `forms.location-question` e `forms.location-answer`: cobertura local do editor/resposta; 150 testes aprovados.
- `daily-routine.edit/publish/list`: cobertura local selecionada; 38 testes aprovados.
- `child-safety.list` e `child-safety.child`: cobertura local de apresentação/contexto; 55 testes aprovados.
- Cliente de respostas de formulário: contrato tipado atualizado para `upload_url` e `required_headers`; teste de API de preparação de asset aprovado.
- Análise Dart do app Superadmin: `No issues found`.

Estados propostos permanecem separados: `attendance.mark`, `attendance.finish` e `attendance.correct` têm apenas `frontend/local-green`; não há certificação `verified-e2e` nova nesta R07. Pela regra R06, a reconstrução invalida a prova E2E anterior dessas ações até nova prova na rota real.

## Primeiro gate aberto e delta restante

1. Prova na rota real de `attendance.mark`, `attendance.finish` e `attendance.correct`, além das demais telas R07, com reload e negativas de autorização; o gate é de ambiente/verificação porque a worktree não tinha `.env.local` público disponível.
2. `forms.upload/resolve-file/expire-file/delete-file`: implementar o fluxo de question-image na tela (picker, PUT com cabeçalhos anunciados, finalize, resolve, expire e delete). Primeiro gate: cliente do editor; depois prova real com Media Gateway/R2.
3. Reconciliar os estados no checkout integrado e aplicar os deltas pelo coordenador; esta frente não editou dev, inventário ou rastreadores.

Estimativa do delta restante: uma fatia de cliente question-image e uma sessão de prova real por família; não foi convertida em horas porque depende do ambiente e da integração do coordenador.

## Dados e segredos

- Nenhum dado sintético novo foi criado na R07; os dados reutilizados de R06 e seus nomes/localizações estão registrados no JSON de comunicação.
- Nenhuma chave, credencial, bucket, provider ou segredo foi criado ou gravado. `COELO_FORMS_MEDIA_PROVIDER` não foi habilitado.
- O arquivo de credencial de QA permaneceu fora do Git e não foi reproduzido neste handoff.

## Continuidade documental

- R04: `docs/reviews/evidence/etapa-2/r04-formularios-cuidado-rotina/handoff-r04.md`.
- R05: `docs/reviews/evidence/etapa-2/r05-formularios-cuidado-rotina/handoff-r05.md`.
- R06: handoff registrado no JSON de comunicação e nos deltas/skills-deltas de R06.
- R07: este arquivo, o JSON de comunicação rev. 60 e `deltas-r07-fcr.json`.

Tudo que foi produzido nesta frente está transmitido pelo Git e pelos artefatos acima. A worktree pode ser removida pelo coordenador após a integração e a conferência do SHA, sem perda deste trabalho.
