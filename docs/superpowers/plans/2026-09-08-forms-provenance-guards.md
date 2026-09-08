---
source: "Coordenador, reserva F-AUTHOR03-SAFE e numeração 20260908054000 em 2026-09-08; crosswalk 8cde3915"
status: "candidate-prepared-sql-execution-pending"
generated_at: "2026-09-08"
---

# Dois reparos nominais de Forms

Root único writer; subagente somente read-only. Eng1 é o único executor SQL/Docker.
Não habilitar publicação nem decidir realm de gestão pós-publicação.

1. Comparar fontes efetivas de G e do trigger de imutabilidade.
2. Criar candidato forward-only no nome reservado, após F-AUTHOR01:
   G remove somente a coluna inexistente; trigger compara os dois creators
   com IS DISTINCT FROM. Não tocar wrappers, grants, triggers, XOR ou FKs.
3. Preparar fixture rollback-only com transições válidas, creators reais,
   controles dos dois realms, SQLSTATE exato e snapshot pós-negação.
4. Revisar estaticamente delta exato, escopo, fixture e hashes; handoff central.
5. Eng1, após manifesto nominal revisado, executa RED e GREEN local, captura
   metadados antes/depois, regressões e cleanup. Esse passo continua pendente.

Estimativa de preparação: 15–25 minutos. Execução depende da fila nominal Eng1.
Critério de parada da fatia: candidato revisado e entregue, sem promovê-lo a
SQL GREEN ou E2E. Escopo integral de Formulários e Cuidado permanece ativo.
