---
title: "PERS-DETAIL-DTO01 — contrato local de Pessoas"
source: "specs/046-superadmin-internal-person-detail-v2.md"
status: "local-green-not-e2e"
generated_at: "2026-09-07"
---

# Resultado delimitado

Decoder específico da leitura v2: shape/tipos/UUID, ID solicitado, campos
nullable, ausência de PII extra/aliases legados, listas imutáveis e timestamp
sem normalização de valores impossíveis. Erros retornam apenas exceções
seguras do domínio. A validação cliente não autoriza ator/tenant/hierarquia.

Somente `fetchDetail` foi conectado ao novo decoder. Listagem, filtro, comandos,
parser legado, router e composição não foram modificados. O helper privado de
erros do detalhe, agora sem consumidor, foi removido. A rota produtiva de edição
continua bloqueada; nenhuma RPC de escrita foi habilitada.

## Evidência

- RED inicial: 22 falhas de contrato + três positivos válidos.
- Ampliação para 46 testes nominais do adapter: nulos, tipos/IDs, códigos
  seguros, envelope inconsistente, caminhos flat preenchidos e limite suspended.
- Review independente encontrou P2 no parse de timestamp: três RED adicionais
  para dia/hora/offset impossíveis; correção valida componentes antes do parse.
- Suíte nominal final tem 50 casos, incluindo data bissexta/fração/offset válido.
- Regressão final: 108/108 em sete arquivos (contrato novo, adapter existente,
  domínio, rota edit, view model, lifecycle VM e página de formulário).
- Analyzer focal: zero issues após ajuste de chaves de bloco.
- Review read-only independente (Mencius): P2 corrigido, nenhum bloqueante.
- Zero SQL, Docker, Supabase/Cloudflare remoto, alteração visual ou golden.

Teste anterior de erro read-only foi movido da leitura para `createDraft`:
preserva explicitamente a semântica dos writers legados intocados. O detalhe
read-only agora normaliza erro inesperado como indisponível. Fixture positiva
de detalhe usa UUID real sintético, em vez do antigo ID textual `person-1`.

## Primeiro gate aberto

`record_status.suspended` é legítimo no banco, porém não é representável pelo
`PersonStatus` legado. A ponte permanece indisponível nesse caso, com teste
explícito; não há conversão falsa nem alegação de suporte completo ao enum.
Modelo/consumidores completos exigem pacote posterior.

Também faltam superfície read-only produtiva, lifecycle de autorização,
backend nominal implantado, permitido/negado/revogado/tenant A/B e reload real.
O progresso E2E não é promovido. Gate de conhecimento: no-op, apenas cumprimento
do contrato canônico e limite técnico documentado, sem regra nova de produto.
