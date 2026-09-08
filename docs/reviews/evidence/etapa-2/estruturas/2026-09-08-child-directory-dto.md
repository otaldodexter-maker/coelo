---
title: "CHILD-READ01 — DTO e requests locais"
source: "direção da coordenação em 2026-09-08; docs/superpowers/specs/2026-09-08-child-directory-read-contract.md"
status: "local-verified-contract-review-pending-no-sql-no-wiring"
generated_at: "2026-09-08"
---

# Ponto seguro

Contrato nominal candidato e DTO/requests puros em coelo_api/children.dart,
sem dependência Flutter, cliente HTTP ou alteração da spec046. Cinco campos
por contexto, pessoa separada, cursor opaco, limite20/1–50 e nenhum total.
Não foi criado gateway SQL, policy, capability, grant, UI, rota ou wiring.

## Evidência executada

- RED inicial: arquivo/tipos ainda ausentes, falha de compilação observada.
- RED runtime adicional: next_cursor repetia exatamente o par de entrada;
  guard de falta de avanço corrigido sem recalcular ordem/case do servidor.
- Revisão independente encontrou trim Unicode que excedia o contrato;
  teste com NBSP reproduziu RED e passou após preservar texto não vazio literal.
- 29 testes novos cobrem defaults, limites, cursor e orçamento UTF-8, shape,
  ID/filtro, página vazia/curta/final/com excedente, mesma pessoa em contextos
  distintos, imutabilidade, negações seguras e erros malformados sem PII.
- `dart test` no pacote coelo_api: 126 PASS, incluindo regressão existente.
- Analyzer dos três arquivos novos: zero issues.
- Dois gates de memória: PASS. No-op de projeção: contrato candidato não é
  conhecimento aprovado. Arquivo lock gerado pelo teste foi removido; nenhum
  lock preexistente foi alterado.

## Limites e próximos gates

Cursor p_after_name usa teto candidato8192 bytes UTF-8 derivado do orçamento
existente de filtros institucionais; não impõe limite cadastral. Nome de pessoa
acima desse teto continua intacto no DTO. Cursor acima dele falha sem truncar.
Essa escolha e o vetor físico de preflight permanecem explícitos para revisão.

Ordenação/collation, limit+1, escopo Owner/internal, AAL vigente, sessão,
auditoria, ACL, concorrência e persistência ainda exigem testes SQL futuros.
Busca, detalhe novo, hierarquia completa, transferências, revogações e comandos
não foram implementados. A linha de diretório por contexto não muda a bridge
flat do detalhe046. Não há action_id promovido ou evidência E2E nova.

Preparação entregue antes do checkpoint03:20 solicitado; estimativa45–90min
não substitui esse checkpoint. Coordenação recebe contrato/testes para revisão
antes de SQL/wiring e mantém os três rastreadores. Worktree exclusiva preservada.
