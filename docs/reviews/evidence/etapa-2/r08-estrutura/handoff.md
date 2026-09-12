---
fonte: R08-prompts.md, R08-plano.md, R08-backlog.md e comunicacao/estrutura.json
status: parcial; em andamento
data: 2026-09-12
rodada: E2-R08-20260912
---

# Handoff parcial — G1 Estrutura

## Entregue e publicado

- `Criar modelo` de Atividades agora usa `SuperadminFormActionFooter` ancorado; o fluxo mantém Cancelar, Anterior, Continuar e Criar modelo.
- Teste focal: `flutter test test/features/activities/presentation/activity_directory_page_test.dart --concurrency=1` — 22/22 PASS, PID 35588, exit 0. Trata-se de prova FE focal, não E2E.
- Contrato mínimo de fixture de Avaliações registrado para G5/C0; G5 publicou a fixture transacional `53b9c6d29`, com rollback, turma, vínculos, aluno, período ativado e diário com uma linha.
- Manifest dos 45 PNGs A preparado: 31 Atividades, 12 detalhes de Unidade/Turma e 2 Instituições. Ainda não houve comparação ou regravação sem slot Flutter.

## Próximo primeiro gate

Com Chrome/runtime concedido por C0, usar a fixture para salvar e ativar configuração em `activities.assessment`, confirmar o período aberto e então executar `assessments.entry`, `assessments.gradebook`, `assessments.close`, `assessments.reopen` e `assessments.detail` com reload e negativa de escopo. Não promover estado sem essa prova.

## Em aberto

- Avaliações e `activities.assessment`: aguardam runtime/Chrome; a fixture local não é evidência remota.
- `groups.members`: prova real de adicionar/remover vínculo sintético, reload e negação cruzada.
- `groups.location`: o RPC/repositório possui contrato local, mas o formulário de Turmas não tem consumidor produtivo; avaliar a menor ligação autorizada após o gate de Avaliações.
- 45 PNGs A: comparar e regravar somente na fila Flutter.
- `institutions.status/files/error/access-denied`, `units.error/access-denied`, `activities.publish` e `institutions.locations-map`: seguem pelos gates do backlog, sem novos IDs.

## Commits da frente nesta abertura

- Código do rodapé: `a7ebeccf8` (reconciliado na base; SHA reescrito na rebase da worktree).
- Evidências/checkpoints atuais: `54479a237` e ancestrais na branch `work/etapa2-r08-estrutura`.
- Nenhum SQL, segredo, dado real ou delta de estado foi criado por G1 nesta abertura.
