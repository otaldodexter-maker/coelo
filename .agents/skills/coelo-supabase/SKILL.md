---
name: coelo-backend
description: Use when a Coelo task involves Supabase, Postgres, Auth, RLS, RPCs, Edge Functions, Realtime, Cloudflare R2/Stream/Workers, Media Gateway, migrations, remote persistence, security, or backend completion.
metadata:
  source: "AGENTS.md; docs/agent/current-state.md; docs/agent/review-workflow.md; decisions/0032-mvp-private-media-r2.md"
  status: "active"
  generated_at: "2026-09-14"
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
