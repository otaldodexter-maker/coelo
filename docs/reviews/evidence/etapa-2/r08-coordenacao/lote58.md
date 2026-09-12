---
source: R08 C0; G0 14f323d8b; G5 e9a3dc18d; revisão G7; ADR 0034 Decisão 8
status: aplicado-em-producao
generated_at: 2026-09-12
---

# Lote 58 — retirada de Momentos

Defeito real: a publicação sintética do mesmo autor era publicada/lida, mas
withdraw_moment retornava 403. O template institution_admin não recebeu a
capability criada depois do seed. A migration 20260912140550 concede somente
esse grant e torna can_withdraw coerente com autoria e capability no escopo.

Espelho G0: RED comportamental 4 PASS/7 FAIL, rollback e wrapper 1.
Após aplicação local: estrutural 4/4, comportamental 11/11, regressões 23/23
e 30/30, **68 testes únicos PASS**, native/wrapper 0, fixtures rollback.
Uma tentativa de iniciar regressão falhou no parser PowerShell antes do SQL;
não foi contada como execução de testes. Log commitado pela G0.

Aplicação C0 via supabase db query linked às 12:49 BRT: exit 0.
Corpo e ledger na mesma transação. Preflight 12:48:42: postgres,
duas funções presentes, um template admin e uma capability ativa, ledger
vazio e nenhum grant admin. Pós-prova 12:49:45: ledger presente, grant único
admin allow/active/não revogado; reader sem grant; hint consulta capability;
authenticated execute=true, anon=false. Próximo lote: 59.

## Backups privados anteriores à aplicação

Ambos dumps CLI terminaram exit 0. Caminho base:
C:/Users/adrie/Documents/Coelo-backups.

| Arquivo | Bytes | SHA-256 |
| --- | ---: | --- |
| schema-producao-20260912-r08-lote58.sql | 4142325 | 4f85f5625587987fe496497727f762a126d98f4f2d4fd4985faf1757425c4ae7 |
| dados-producao-20260912-r08-lote58.sql | 5014133 | 76b5545794eceb97eaf524ea54de86b09c3c8205cf86c413f5a227a442bb65c0 |

Schema: 1233 CREATE OR REPLACE FUNCTION, 335 CREATE TABLE; formato filtrado
pela CLI sem marcador final pg_dump. Dados: 190 INSERT INTO, marcador final
presente. Avisos de FKs circulares preservados; restauração exige procedimento
de triggers adequado. Dispensa de PITR pago continua a decisão nominal vigente.

SQL Git LF: 9356f5e52c8d14b0c628540eceee35231c6baf0044efee04ac71c6f23d69a996.
Working copy CRLF: 671d901eccc4e9b6ba86b86ae8b05a5feb0c764ff38fedac65ba21d4733f778c.
Conteúdos normalizados comparados e idênticos.
Composição privada (ledger adicionado antes de COMMIT):
9c15637b0abfb914614e60b730d35cd412018c796e0ca0bf0004ae56db82356e, 5827 bytes,
composicao-producao-20260912-r08-lote58.sql.

A prova API da retirada da mesma publicação foi liberada ao G4 depois do
pós-check. Nenhuma nova fixture foi criada por C0. Sem certificação UI/E2E;
o delta de regressão permanece até a prova funcional corrigida.
