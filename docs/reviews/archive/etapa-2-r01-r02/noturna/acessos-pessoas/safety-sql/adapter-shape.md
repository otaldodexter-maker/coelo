---
source: "Safety v2 SQL projection; supabase_internal_child_safety_repository.dart; child_safety_response_decoder.dart"
status: "local-green; adapter remains inactive"
generated_at: "2026-09-09"
---

# Detalhe Safety: resposta incompleta nao significa ausencia de autorizacoes

`apps/superadmin -> Acessos -> Seguranca infantil -> detalhe -> child-safety.child`.
O SQL nominal sempre projeta `authorizations` como array. O adapter interno
validava identidade e contextos, mas o decoder compartilhado convertia campo
ausente, nulo ou objeto em lista vazia; linhas nulas ou vazias viravam registros
sem identidade. Isso poderia apresentar resposta incompleta como ausencia de
autorizacoes, mesmo sem ativacao produtiva atual.

Seis casos HTTP sinteticos reproduziram o problema antes da correcao:
campo ausente, null, objeto, lista com null, string e objeto vazio. Todos6F
porque o adapter retornou ChildSafetyRecord em vez de indisponibilidade.
O adapter agora exige array e linhas com id, child_context_id, unit_id e nome
nos tipos da projecao. Lista vazia explicita permanece valida. O decoder legado
nao mudou; nenhuma regra de autorizacao, SQL, bootstrap ou escrita foi ativada.

Prova atual: **41P/0F** no arquivo do adapter, incluindo7 casos novos (6 negativas
e1 autorizacao nominal preservando identidade/nome/unidade). Os34 casos anteriores
foram reexecutados por mudanca material do adapter; substituem evidencia historica
nessa superficie e nao sao somados duas vezes. Total do grupo agora395P/1F/120U.

Logs: `adapter-shape-red.txt`, `adapter-shape-green.txt`,
`adapter-shape-analyze.txt` (um lint de fixture corrigido),`adapter-shape-analyze-final.txt` (sem issues). Sem rede externa: MockClient e dados sinteticos.
SQL108 continua pendente da sequencia nominal, e o adapter continua inativo.
Nenhuma certificacao FE/BE/E2E. Memoria no-op: contrato existente preservado.
