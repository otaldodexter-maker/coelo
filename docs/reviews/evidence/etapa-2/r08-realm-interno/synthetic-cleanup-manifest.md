---
title: "R08 G5 — manifesto da futura limpeza realm/chat"
source: "R08-plano.md G5; orientação C0; seeds QA R04/R06"
status: "preview preparado; não executado; deleção proibida nesta rodada"
generated_at: "2026-09-12T11:10:17-03:00"
---

# Manifesto de limpeza futura

`packages/coelo_database/scripts/stage2-realm-chat-cleanup-manifest.sql` é uma
consulta de inventário, não um limpador. Ela abre transação read-only, usa CTEs
e uma allowlist exata dos sete e-mails QA R06 e das três instituições QA R04,
e termina em rollback.

O resultado planejado separa Auth, identidades/perfis/memberships internos,
pontes people-based, conversas, metadados de anexos e auditoria retida. Ele
também registra a ordem futura:

1. revogar sessões e banir/remover usuário pelo Auth Admin;
2. purgar objetos privados pelo worker nominal antes do catálogo de mídia;
3. remover dependências de chat/realm por IDs conferidos;
4. manter `audit.audit_logs` append-only e arquivar instituições ainda
   referenciadas, como no cleanup R04.

O script não lê senha, não imprime token/chave R2, não contém DML persistente e
não cobre sintéticos das outras frentes. A versão executável central depende da
allowlist final do C0 e só pode existir após o encerramento formal da Etapa 2.
Nada foi executado por G5.

Primeira validação G0 do commit `086a654c6`: falhou antes de qualquer consulta
ou mudança porque `CREATE TEMP TABLE AS` não é permitido em transação
read-only (exit 3). A versão seguinte substitui as quatro temporárias por CTEs;
essa falha não executou cleanup.

Rerun G0 de `c9662b0ff`: native 0, wrapper 0 e uma linha `ROLLBACK`. As nove
categorias retornaram contagem zero no espelho, sem e-mails, IDs ou segredos no
output e sem DML persistente. Isso valida a forma read-only do preview; não
autoriza nem executa a limpeza futura.
