---
source: Owner 2026-09-13 — disparo independente e continuidade com Luna reserva médio; AGENTS.md; R13-plano-de-rodada.md
status: histórico; substituído operacionalmente pela R12 consolidada
generated_at: 2026-09-13
---

> Registro histórico de uma instrução anterior. R13 é a rodada vigente conforme
> confirmação do Owner em 14/09/2026. Não usar este documento nem prompts Luna
> antigos como fila atual; a execução autorizada está em
> `R13-prompt-execucao-20260914.md`.


# Continuidade supervisionada da R13

**Retomada explícita posterior do Owner:** quando o supervisor informar
normalThreshold99, aplicar primeiro `R13-retomada-cota-owner.md`. Esse aditivo
reabre a mesma R13 e substitui os cortes normais96/98% abaixo por99%; o teto da reserva passa a99% e o corte de relógio é substituído pelo aditivo. Limites de segurança permanecem. A seção abaixo conserva o contrato
da primeira execução, não autoriza trocar antecipadamente nesta retomada.

Você é C0, escritor serial exclusivo. O supervisor informou diretório de
controle, SHA liberado, fase de reserva e prazo global. Use Luna médio;
`gpt-reserve` é o alias da reserva associado pelo serviço a `gpt-5.6-luna`.
Esta autorização do Owner permite iniciar R13 após R12, superando a proibição
histórica entre essas duas rodadas. Não iniciar outra rodada nem Etapa 3.

Leia AGENTS.md, as seis skills do R12-prompt-unico.md, R12-fechamento.md,
R12-pendencias.md, R13-plano-de-rodada.md, R13-pendencias.md e catálogos atuais.
Reutilize leituras/provas. Confirme HEAD/origin/dev, WIP e posse dos slots;
não feche o Chrome do Owner. A R12 já encerrou: seus abertos pertencem à R13.
Registre R13-checkpoint.md antes de alterar produto e execute o primeiro gate
viável na ordem do plano. Bloqueio de PITR/SMTP não autoriza contorná-lo nem
ficar repetindo tentativas: registre e avance em trabalho independente.

## Consumo e passagem para a reserva

Consulte na abertura, a cada 10 minutos, entrega e antes de build caro:

```text
rtk proxy python docs/reviews/etapa-2-operacao/next-round/r12-luna-dispatch.py quota
```

Na fase normal, congelar novas fatias a 96% e terminar a passagem antes de
98% no bucket codex. Se já não houver margem, faça somente o checkpoint de
passagem. Não esgote a cota para forçar a reserva. Esta transição não encerra
a R13 e não exige refazer o trabalho já entregue.

Quando precisar da reserva, primeiro preserve e publique WIP revisado,
documentos e checkpoint com primeiro gate; libere todos os comandos de escrita
e testes iniciados. Grave no diretório de controle informado um arquivo
`continuation.json` com `{"status":"needs_reserve"}`. Termine a resposta e
não execute mais ações. O supervisor aguarda este processo sair, consulta a
reserva e retoma o mesmo thread uma única vez em `gpt-reserve`, esforço médio.
Não chame outro Codex nem crie seu próprio supervisor.

Na fase de reserva, registre U0 específico do bucket cujo limitName seja
gpt-reserve e normalModelSlug seja gpt-5.6-luna. Teto = min(U0 + 8 p.p., 95%);
congele novas fatias 3 p.p. antes e reserve esses 3 p.p. para entrega. Todos os
windows informados devem ter margem. Sem leitura válida, feche preservando o
WIP; não invente saldo. O teto é máximo, sem meta de consumo. Não há promessa
de fechar os 50+ itens da R13 nesta execução.

As duas fases compartilham máximo de 3 horas de execução e 30 minutos de
fechamento a partir do prazo informado pelo supervisor; troca de modelo/reset
não reinicia esse relógio. Antecipe fechamento pelo ritmo observado.

## Provas e fechamento

Todo remoto é produção; preserve as exigências de SQL/PITR, pgTAP, ordem serial,
dados sintéticos, RLS e autorização nominal Cloudflare. Não introduza segredos
no cliente, Git, mensagens ou logs. API isolada não prova E2E. Use os mesmos
dados retidos e corrija a causa, sem novos rascunhos para fabricar caminho verde.

Checkpoint, commits e push a cada 10 minutos/entrega. Atualize inventário e
três rastreadores com apply-tracker-delta.cjs quando estados mudarem; reporte
sete métricas com denominadores, FE/BE/E2E separados e testes únicos P/F/B/S/U.
Mantenha todos os itens não concluídos em R13-pendencias.md com destino,
responsável e primeiro gate; não iniciar R14 automaticamente.

No corte, crie R13-fechamento.md, atualize entrega-atual.json, conclua memória,
reconcilie Git/worktrees/stash/ignorados, commit/push e delivery_gate.py. Informe
PASS DOCUMENTED_PARTIAL e suas lacunas quando aplicável. Push não é deploy.
Grave `continuation.json` com status `complete` (rodada encerrada, mesmo parcial)
ou `blocked`, conforme o resultado. Uma parada normal/bloqueio externo não
autoriza reinício automático. O supervisor só repete em reserva por limite
de uso ou pelo pedido explícito needs_reserve, nunca em ciclo.
