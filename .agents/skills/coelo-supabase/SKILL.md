---
name: coelo-backend
description: Use when a Coelo task involves Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Realtime, Cloudflare R2/Stream/Workers, Media Gateway, migrations, remote persistence, security, or backend completion.
metadata:
  source: "AGENTS.md; docs/agent/current-state.md; docs/agent/review-workflow.md; decisions/0032-mvp-private-media-r2.md; decisions/0041-owner-decisions-r14-mesa-20260916.md"
  status: "active"
  generated_at: "2026-09-14"
  updated_at: "2026-09-16"
---

# Coelo Back-end

Artefatos de execução, backups e snapshots não são contexto operacional;
consulte `docs/agent/artifact-cleanup-backlog-20260914.md` somente em tarefa de
limpeza autorizada.

Esta é a porta de entrada curta da skill. Não contém logs de rodada, prompts,
percentuais ou fila copiada. Estado e pendências ficam em
`docs/agent/current-state.md` e nos rastreadores apontados por ele.

## Fluxo

1. Leia `docs/agent/current-state.md` e `docs/agent/source-of-truth.md`.
2. Declare app/superfície, entidade, `action_id`, objetivo, incluído, fora de
   escopo, ordem, parada e evidência esperada.
3. Use `docs/agent/review-workflow.md` e
   `../coelo-flutter-supabase-review/references/review-scope.md`.
4. Leia o tracker BE somente na profundidade exigida: cabeçalhos/ações afetadas
   para correção localizada; integralmente para auditoria ampla ou conclusão.
5. Abra a migration, RPC, policy, contrato e teste afetados. Use a skill de
   Cloudflare/Wrangler somente quando o recurso realmente participar da ação.
6. Valide identidade, ator, tenant, ownership, hierarquia, escopo e negativa
   cross-tenant no servidor/RLS. Teste localmente antes de qualquer aplicação
   remota autorizada.

## Regras permanentes

Supabase/Cloudflare remoto do Coelo é produção. `service_role`, tokens e
segredos nunca entram no cliente, Git, logs ou resposta. Mídia nova do MVP usa
R2 privado conforme ADR 0032; Postgres guarda catálogo, permissões, vínculos,
ownership e auditoria. Stream não substitui o master. Importação/exportação
geral permanece adiada conforme ADR 0031, salvo a exceção explicitamente
definida para exportação de respostas de Formulários.

Backend `done` exige o pacote aplicável implementado, teste pgTAP/negativa
pertinente e aplicação/verificação remota quando o contrato da ação exigir.
Documentação, mock, migration local ou UI escondida não certificam produção.

Leitores de busca sobre dado pessoal (nome, @, e-mail, celular, CPF) seguem a
regra da ADR 0041: mínimo de caracteres por tipo antes de responder, escopo do
ator aplicado no servidor, auditoria, limite de taxa e resultado minimizado —
CPF nunca aparece em resultado de busca; a normalização (só dígitos) é do
backend. Negativa cross-tenant produtiva usa identidade sintética temporária
criada por função versionada sem grants públicos e revogada ao fim; nunca
credencial real. `ordem-de-aplicacao-producao.txt` só registra o que o ledger
remoto confirma; uma migration versionada e não aplicada fica anotada como
pendente, nunca dentro de um lote.

Versão defasada e conflito otimista sinalizam **SQLSTATE `PT409`**, nunca
`40001` (`serialization_failure`): o PostgREST reexecuta 40001 sem limite e
esgota o pool (incidente de 16/09/2026, OQ-047; lote 75 de 17/09 trocou os 175
raises restantes). Toda RPC nova usa `raise exception using errcode = 'PT409',
detail = '<FAMÍLIA>_STALE_VERSION'` (ou o código já existente da família);
wrappers de envelope tratam `PT409` ao lado de `23505`. Nenhuma migration
recria uma função com 40001.

Rito de produção (fixado na R15, 17/09/2026): dump de schema novo em
`Coelo-backups` com SHA-256 → espelho Docker próprio restaurado desse dump
(revogar `default privileges` de `postgres` em `public` antes da restauração
para a ACL ficar igual à produção; semear catálogos, pois o dump é schema-only)
→ pgTAP verde → `supabase db query --linked --workdir packages/coelo_database
-f migrations/<arquivo>` (caminho relativo ao workdir) → `supabase migration
repair --status applied <carimbo> --linked` (exige cópia em
`supabase/migrations/`) → `migration list --linked` → lote numerado na ordem
real de aplicação em `ordem-de-aplicacao-producao.txt` (sessões paralelas
conferem as branches `r15/*` antes de numerar). Edge Functions:
`supabase functions deploy <nome> --project-ref evvbomzejfijozbtgvpt --workdir
packages/coelo_database` só após teste local; versão e `verify_jwt` conferidos
por `functions list`. Autorização de produção é nominal do Owner por lote; o
classificador do executor pode negar `db query --linked` numa sessão e permitir
noutra — nunca contornar, registrar o comando no handoff.

Estado da Etapa 2 (backend): Após a Mesa R16 (ADR 0044, 17/09/2026): FE 198/199 (99,5%), BE 185/186 (99,5%), E2E 184/186 (98,9%), Owner 39/53 — 33 ações fora do MVP têm escopo `v1` e ficam fora dos denominadores; a Etapa 2 se mede pelo E2E do MVP e FE/BE seguem por code review e revisão tela a tela na Etapa 3. Corte anterior — Corte da R16 (17/09/2026, `dev` `37d762976`): FE 207/232, BE 185/219, E2E 184/186, Owner 39/53 (R15: +18 FE, +13 BE, +22 E2E, +18 Owner num dia). Fila vigente: `R16-pendencias.md`
(ADR 0043). Lotes 75–80 em produção e Edges `chat-media`, `child-safety-media` v2,
`meal-plan-media`, `meal-plan-image-cleanup`, `now-media`, `form-media` v23. Edge que
recebe o bearer do pg_cron precisa de `verify_jwt = false` e validar o bearer no
handler (`form-media`, `circular-media`); com o gateway ligado o worker recebe 401 e o
cron "sucede" sem efeito. Conta só de responsável não abre tela (OQ-048): provas de
responsável em produção usam PostgREST com a sessão dele.

## Coordenação e fechamento

Esta é uma skill folha. Só use `coelo-frontend-backend` quando o aceite da
tarefa atravessar FE e BE; a integrada coordena sem reativar esta skill em
ciclo. Não use a integrada para uma alteração BE independente.

O delivery gate em `../coelo-flutter-supabase-review/references/delivery-gate.md`
só é necessário quando o escopo incluir integração, publicação ou entrega
formal. Quando aplicável, execute com o relatório explícito:

```powershell
python docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json
```

Antes do fechamento, confira diff, testes, migration forward-only, ordem,
destino, skills no checkout final e estado remoto. Separe BE de FE/E2E. Use
`coelo-knowledge` para conhecimento durável; histórico, artefatos e backups
são proveniência, nunca requisitos atuais.
