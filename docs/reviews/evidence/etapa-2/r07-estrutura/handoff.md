---
title: "Handoff final — R07 · Estrutura"
source: "comunicacao/estrutura.json; deltas-r07-estrutura.json; fechamento formal C0"
status: "finalizado e transmitido ao coordenador"
generated_at: "2026-09-12"
timezone: "America/Sao_Paulo"
---

# R07 · Estrutura — handoff final

## Entrega

- Branch: `work/etapa2-r07-estrutura`.
- SHA publicado antes deste handoff: `a126e5485d0aeae8669f6e2fbced48c12025da58`.
- A branch estava limpa, sem arquivos untracked, sem alterações modificadas e sem stash; upstream estava sincronizado.
- A worktree não deve ser removida antes de o coordenador integrar e conferir este handoff.

## Feito e evidências

- Comunicação R07 registrada no `estrutura.json`, com revisão inicial, checkpoints, mini-revisão e bloqueios.
- Build QA release concluído: `flutter build web --release -t test_driver/qa_main.dart --dart-define-from-file=.env.local`; `build/web/main.dart.js` gerado.
- Avaliações: `flutter test test/features/assessments`, 43/43.
- Suíte conjunta de Estrutura: 1.200 testes executados; 10 falhas de golden já conhecidas/retidas. Goldens de Atividades não foram regravados porque P53 não foi respondida como A.
- Nenhum action_id foi promovido a verified/done/verified-e2e por esta R07: a rota real não ficou certificável porque T0 não foi gravado em `coordenacao.json` e Chrome/CDP isolado não ficou controlável.
- Deltas: `deltas-r07-estrutura.json`, zero entradas; nenhum pacote SQL novo.

## Pendências e primeiro gate

- `activities.assessment`: salvar/ativar a configuração na rota real; primeiro gate operacional é T0 registrado e Chrome/CDP controlável.
- `assessments.entry`, `assessments.gradebook`, `assessments.close`, `assessments.reopen`, `assessments.detail`: dependem do período criado e de aluno/turma sintéticos.
- `groups.members`, `groups.location`, estados de Instituições/Unidades, `locations.detail-links` e `activities.publish`: sem prova de rota real nesta janela.
- Goldens de Atividades: registrar até resposta P53=A; não regravar nesta frente.

## Dados e chaves

Nenhum dado sintético ou chave foi criado na R07. Foram apenas reutilizados os dados R06, mantidos até o fim da Etapa 2 (P42): `groups ea3986b7`, `institutions 190dd028`, `units f5284f2f`, `activity_locations 82e92854`, `activity_definitions 95b98978` e `2e45c8bd`, além dos demais nomes registrados no JSON. Nenhum valor de credencial, segredo ou chave foi incluído no handoff.

## R01–R07

Os handoffs dedicados de Estrutura disponíveis são R03, R04, R05 e R06. Não há arquivo dedicado `r01-estrutura` ou `r02-estrutura` em `docs/reviews/evidence/etapa-2`; a varredura R01–R06 registra os itens remanescentes e suas fontes consolidadas. Este handoff fecha a R07 e transmite explicitamente esses itens para a preparação da R08; não foi identificado outro WIP de Estrutura fora do JSON e dos handoffs citados.

Tudo foi transmitido no JSON, neste handoff, no delta-file e na branch publicada. A worktree pode ser removida somente depois da integração/conferência pelo C0; sua remoção posterior não perde conteúdo.
