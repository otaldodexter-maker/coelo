---
source: migrations20260912140545/20260910190500; r08-coordenacao/lote56-cron-execucoes.md; now-api-manifest.json
status: disparador-comprovado-expiracao-desta-fixture-pendente
generated_at: 2026-09-12
---

# Agora — disparador, retenção e próxima prova

apps/superadmin → Coelo → Agora → expiração → agora.expire.
H09 tem disparador concreto em produção, aplicado por C0 no lote56:
`coelo-now-publications-expire`, pg_cron a cada cinco minutos, executando
`app_private.sweep_expired_now_publications(null::uuid, 500)`.

A migration `packages/coelo_database/migrations/20260912140545_now_publication_expiry_dispatch_v1.sql`
agenda o sweep que já existe. `docs/reviews/evidence/etapa-2/r08-coordenacao/lote56-cron-execucoes.md`
registra duas execuções automáticas succeeded em12/09/2026 às14:35 e14:40 UTC.
Isso comprova acionamento agendado, além do filtro de leitura por expires_at.
O job materializa estado/auditoria; **não apaga o master R2**. Os PNGs desta
prova não possuem cópia Stream. Não chamar essa evidência de remoção física.

A publicação R08 G4 `392ee49a-265b-42e3-9c5b-ed44a34028f8`, asset
`0451e371-7f79-4501-b439-7da426ca4019`, expira somente em
**13/09/2026 12:24:39 BRT** (15:24:39.452258 UTC). Esse horário está fora da
janela R08. A URL de leitura já expirou na prova API, mas isso não certifica
expiração de24h da publicação. C0 autorizou preservá-la até o prazo natural.

Próxima prova na continuidade coordenada, depois do vencimento: consulta pelo
reader normal e medição C0 do estado/auditoria da mesma publicação após um
ciclo do job, preservando master e registro. Não alterar expires_at, chamar
sweep manual ou publicar nova fixture para antecipar artificialmente o prazo.
UI/E2E desta expiração e negativa cross-tenant continuam não executadas.

`retained-r08-resources.json` reúne os IDs sintéticos desta rodada para evitar
novos uploads/criações por falta de contexto. É recibo operacional do executor,
não alteração do inventário oficial e não autorização de cleanup.
