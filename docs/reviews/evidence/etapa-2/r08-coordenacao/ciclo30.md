---
source: R08 C0 base integrada
status: checkpoint
generated_at: 2026-09-12T11:34:59.470876-03:00
---

# Primeiro ciclo de integracao R08

Base de codigo: G1 rodape, G3 frame/Chamada, G7 Catalogo, CORS G4/G5. Flutter integrado: 121 PASS, 0 FAIL, 0 SKIP; 8 arquivos; terminal exit0, 59.2s. Log flutter-integrado-ciclo30.jsonl. Nao somar esses casos aos reruns das frentes. Flutter analyze global: No issues found, exit0, 74.8s.

Lote56: candidato 20260912140545 aplicado via CLI linked em producao (exit0), ledger version/name confirmado. Job coelo-now-publications-expire unico, ativo, */5, sweep(null::uuid,500). Nenhuma chave nova. Execucao do cron e UI ainda pendentes; sem promocao done/E2E.

Backups privados concluidos exit0 antes da aplicacao:

[
  {
    "arquivo": "C:\\Users\\adrie\\Documents\\Coelo-backups\\schema-producao-20260912-r08-lote56.sql",
    "bytes": 4136628,
    "sha256": "cbd51e737da96471307f1bddd75a89bba2d843d5e1088f66d2fdd89570b2cbc2"
  },
  {
    "arquivo": "C:\\Users\\adrie\\Documents\\Coelo-backups\\dados-producao-20260912-r08-lote56.sql",
    "bytes": 4231711,
    "sha256": "9f8c9ad6d3cc2c94f7efa088cf2fccf195ff49bcc89be4ac12d05c47e913b4ed"
  }
]

Dados: 364 COPY, marcador de dump completo. Esquema: 1232 funcoes e335 tabelas. Avisos de FKs circulares preservados; restauracao de dados requer procedimento de triggers conforme pg_dump. PITR false; ADR0034 Decisao8 autoriza backup logico nesta fase.

G0 prova local H09 6/6, consumidores Chat28+3, ACL88 e preflight20 em logs commitados. Nenhum dado sintetico ou chave criado por C0.

Metricas oficiais preservadas neste checkpoint; validacao documental nao certifica produto.
