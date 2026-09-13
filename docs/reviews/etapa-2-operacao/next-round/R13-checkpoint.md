---
source: R13-luna-continuacao.md; R13-plano-de-rodada.md; R12-fechamento.md; R12-transferencia-final-R13.json; supervisor 32e2492208434a1dac9aa6adeae1ca04
status: passagem para reserva solicitada; nenhum produto alterado
generated_at: 2026-09-13
---

# R13 — checkpoint de abertura e passagem

## Contrato da rodada

- objetivo: retomar os abertos da R12 no recorte R13, preservando os três ajustes visuais já entregues e sem iniciar Etapa 3;
- incluído: 50 compromissos em `R13-owner-items.json`, com primeiro gate SQL/PITR e priorização independente posterior;
- fora de escopo: R12-07/41/43 já concluídos, Etapa 3, novos action_ids, deploy público, SQL/Cloudflare sem gate/autorização;
- ordem: SQL/PITR R12-51; depois configuração/publicação/diário/contadores; Conta/Auth; demais blocos por dependência;
- critério de parada: limite de uso/tempo, bloqueio externo ou fechamento formal R13; não iniciar R14;
- evidências esperadas: rota normal, persistência real, RLS cross-tenant quando aplicável, reload, testes únicos P/F/B/S/U, inventário/rastreadores sincronizados e delivery gate.

## Abertura

- disparo: `32e2492208434a1dac9aa6adeae1ca04`;
- controle: `C:\Users\adrie\Documents\Coelo-backups\r12-luna-dispatch\32e2492208434a1dac9aa6adeae1ca04`;
- posse liberada pela R12 no SHA `4ded9c567ef8415d62421b503a7e38c27ba53fa4`;
- checkout: `dev`, `HEAD=origin/dev=4ded9c567ef8415d62421b503a7e38c27ba53fa4`, limpo, sem worktrees adicionais;
- escritor: C0, serial exclusivo; nenhum Chrome do Owner foi fechado e nenhum runtime/teste foi iniciado;
- T0 UTC: `2026-09-13T15:51:56Z` (epoch aproximado `1789320716.591`); prazo global informado: `1789333240.0638936`;
- posse do supervisor: `running`, PID `11180`, conforme `status`.

## Cota e gate

- medição inicial normal: `codex` em `95%`, janela 10080 min, reset `1789820315`, sem créditos;
- reserva disponível medida separadamente: `gpt-reserve`/`gpt-5.6-luna` em `17%`, janela 10080 min, reset `1789460861`;
- fase de reserva informada: `False`;
- primeiro gate R13-51: bloqueado externamente pela exigência de PITR/backup atualizado e ordem serial; não há autorização para contornar, reaplicar ou fabricar prova;
- decisão operacional: com apenas 1 p.p. até o congelamento normal de novas fatias (`96%`), não iniciar correção de produto que não caberia nesta janela; preparar passagem para a reserva conforme R13-luna-continuacao.md.

## Estado e próximo passo

- código/WIP: nenhum arquivo de produto alterado; checkpoint é o único WIP desta abertura;
- itens R13: 50 preservados, nenhum estado FE/BE/E2E alterado;
- próximo passo da reserva: registrar U0 específico do bucket `gpt-reserve`, recalcular teto `min(U0 + 8 p.p., 95%)`, manter margem de 3 p.p. para entrega e executar o primeiro gate viável;
- não repetir suites verdes nem iniciar build caro antes de nova medição de cota.
