---
source: R08 C0; entregas G0/G3/G5/G6/G8; ADR 0034
status: checkpoint
generated_at: 2026-09-12
---

# Ciclo 90 — base integrada e lote 57

Base testada `8809dafcd`: **422 PASS, 0 FAIL, 0 SKIP**, 11 arquivos,
63,811 s, native exit 0. Log `flutter-integrado-ciclo90.jsonl`.
Inclui Galeria/pergunta/resposta/DTO consumidor, Circulares e notificações H14.
Não é censo completo e não se soma aos reruns das frentes. Análise global
Flutter: sem issues, exit 0, 44,3 s (`analyze-ciclo90.log`).

Integrações por conteúdo: G3 `4c9f0375a`, SQL/fixtures G5 `684eea023`,
provas G0 `e2fcfaf8c`, H14/A+ G6 `b1b16e7c4`, recibos G8 `ef95af0f0`.
G1 foi retido na revisão por risco de duplicação no retry após criação parcial;
G4 Principal e smokes API aguardam o próximo lote integrado. G2 segue P51 real.
G7 preservou uma sessão preexistente e não executou revokeOthers ao detectar
três sessões; essa prova não fecha revogação.

## Lote 57 em produção

Versões `20260912140546`, `140547`, `140548`, `140549` aplicadas em uma
transação externa ordenada, com inserções no ledger na mesma transação.
Cada corpo foi preservado, retirando somente BEGIN/COMMIT externos para a
composição. SHA-256 do arquivo composto temporário:
`e41f1263c3c0b630c1b2563e51edd8a900212b8d1b7eaa484b3d30b7525214c7`.
CLI linked `db query` terminou exit 0; não houve ALTER TYPE nem aplicação parcial.

Preflight às 12:22:26 BRT: ator postgres, dependências presentes, ledger do
pacote vazio, FK antiga RESTRICT e zero bindings deleted a reconciliar.
Pós-prova às 12:25:14 BRT: quatro versões/names no ledger, FK NO ACTION
DEFERRABLE, trigger `form_media_unbind_deleted_question_v1` habilitado.
Authenticated pode authorize, não finalize; service_role pode finalize;
anon não pode delete. Consultas em `lote57-preflight.sql` e `lote57-verificacao.sql`.

Espelho G0: novos focais **9/9 + 7/7**, regressões finais **33/33 + 17/17 +
159/159**, todos ROLLBACK e native/wrapper 0. REDs e a expectativa antiga de
replay estão preservados no log G0; não contam como falhas atuais ou execuções
adicionais. Fixture final `684eea023`, candidatos até `3f494eb51`.

Backups privados completos pela CLI, ambos exit 0 antes da aplicação:

| Arquivo em Coelo-backups | Bytes | SHA-256 |
| --- | ---: | --- |
| schema-producao-20260912-r08-lote57.sql | 4136628 | cbd51e737da96471307f1bddd75a89bba2d843d5e1088f66d2fdd89570b2cbc2 |
| dados-producao-20260912-r08-lote57.sql | 4238181 | e04058c96a4a4f48a4d2bf313d10d76bc37a0856c4a2864ed331f958ecdc8145 |

Dump de dados contém 364 COPY e marcador final. Dump de esquema filtrado
pela CLI não contém esse marcador; sucesso nativo e conteúdo foram conferidos.
Avisos de FKs circulares permanecem: restauração de dados requer o procedimento
de triggers indicado por pg_dump. A dispensa de PITR pago e o backup lógico
seguem ADR 0034, Decisão 8, nesta fase sem cliente real.

## Memória, limites e incidente

Spec 028 e projeção de Conversas foram reconciliadas com a spec 050 já aprovada:
Principal tem UI própria e repository compartilhado. Divergência binding/asset
permanece em open-questions. Gate de memória: 64 artigos válidos; testes do
validador 12 PASS e 1 SKIP por symlink indisponível no host.

G6 executou delete de circular sintética no smoke, contrariando a retenção do
contrato comum. Circular `aa9e26a6-2874-4e19-ac79-a41f56c44468`, asset
`429f1bc4-f579-4179-9193-0e6304aa3e0f`. Novas mutações da frente foram suspensas;
impacto soft/hard e estado residual estão em medição somente leitura. Não há
restauração presumida. O incidente será mantido no fechamento.

Nenhum aceite FE verified, BE done ou E2E novo é concedido por este checkpoint.
Os smokes API e aprovações visuais têm métricas próprias. Chrome continua com
G0 e a entrada de texto impede o aceite pela UI. Rodada continua até o corte.
