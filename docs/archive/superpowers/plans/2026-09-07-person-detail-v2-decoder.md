---
title: "PERS-DETAIL-DTO01 — decoder da leitura existente"
source: "specs/046-superadmin-internal-person-detail-v2.md"
status: "local-verified"
generated_at: "2026-09-07"
---

# Contrato e recorte

Derivado do output exato da spec 046 aprovada. A chamada `fetchDetail` já usa
RPC interna v2, mas decodifica pelo parser legado permissivo. Objetivo: limitar
essa leitura ao envelope, campos e tipos contratados, conferir ID solicitado e
normalizar mensagens internas. Nenhuma regra de autorização será inferida no
cliente. O servidor continua autoridade para identidade, escopo e hierarquia.

Arquivos aprovados pelo coordenador: decoder novo `features/people/domain/person_detail_v2.dart`,
somente método `fetchDetail` do repository existente e testes nominais. Não
alterar listagem/filtros/escrita, parser global, router/composição ou banco.

## Provas e ordem

- [x] RED reproduzido via adapter: 22 negativos falham, três positivos passam.
- [x] Review read-only das expectativas contra spec 046.
- [x] Decoder e normalização do transporte no detalhe.
- [x] GREEN e regressão 108/108; analyzer e review final sem bloqueantes.

Review encontrou overflow de timestamp; três RED adicionais reproduzidos e
corrigidos antes da validação final. Evidência em
`docs/reviews/evidence/etapa-2/estruturas/2026-09-07-person-detail-v2-decoder.md`.

Estimativa local: 30–60 minutos. A rota de edição permanece bloqueada; não
destravá-la para aproveitar uma RPC exclusivamente de leitura.

## Compatibilidade ainda aberta

`suspended` é válido em `record_status`, mas não existe em `PersonStatus`.
Sem mudar o modelo/consumidores, essa ponte continuará indisponível para esse
estado. Não é payload malformado e não pode virar `inactive` ou `archived`.
Uma superfície read-only completa e suporte a todos os estados exigem pacote
próprio; este decoder não encerra Pessoas nem E2E.
