---
title: "R14 Bloco E — mídia privada, Conta e contratos de publicação"
source: "Owner na tarefa atual; docs/agent/current-state.md; docs/agent/source-of-truth.md; docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md; decisions/0032-mvp-private-media-r2.md; decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md"
status: "approved-design"
lifecycle: "current"
generated_at: "2026-09-15"
audience: "team"
---

# R14 Bloco E — desenho aprovado

## Objetivo

Fechar apenas os aceites executáveis do Bloco E, preservando a separação entre
famílias visuais, contratos de domínio e autoridade server-side. A entrega
local deve produzir código, migrations/Edge versionadas e provas reproduzíveis;
produção só poderá ser alterada por autorização nominal do Owner/coordenadora.

## Escopo e parada

1. `account.profile`: manter Dados pessoais e Meu acesso na composição aprovada
   em desktop, com rolagem interna limitada e busca; adicionar foto privada do
   owner.r12-46 por R2, catálogo/ownership/binding no Postgres, leitura
   autorizada, reload, remoção e negativa cross-tenant.
2. `chat.attach`: completar envelope `asset_id`, prepare/PUT/finalize/read por
   `chat-media`, ownership, tenant, auditoria, R2 privado, reload e negativas;
   a UI não pode declarar sucesso sem confirmação do servidor.
3. Acontece/Agora/Momentos: reutilizar os gateways R2/Stream já existentes,
   corrigindo somente lacunas comprovadas de publicação, expiração, remoção,
   leitura e escopo.
4. H10 preserva audiência integral; H11 somente permanece no MVP se a base
   existente demonstrar mais de 60% de implementação e testes, caso contrário
   fica documentado como V1. H04, H27/P54/H02 e gates avançam apenas quando
   houver `action_id`, contrato e prova concretos.

Ficam fora: Planos comerciais, reader de Planos, `plans.assign`,
`auth.recover/auth.reset`, allowlist de recovery, `owner.r12-18` e
`owner.r12-33` sem contrato e autorização explícitos, além de qualquer
aplicação remota não autorizada.

## Arquitetura

O Postgres continua sendo o plano de controle. Ativos novos usam catálogo
compatível com a ADR 0032, com identificação opaca, tenant/owner e binding
tipado; R2 privado guarda o master e o gateway emite tickets curtos somente
após reautorização. O cliente envia intenção e `asset_id`, nunca bucket,
object key, credencial ou permissão inferida.

As tabelas e RPCs existentes serão evoluídas forward-only, com crosswalk antes
de qualquer novo campo. `chat_attachment_metadata`, `now_media_assets`,
`moments_media_assets` e o catálogo compartilhado não serão duplicados nem
renomeados. Quando uma superfície já tiver contrato R2 válido, a correção será
no adapter/Edge/RPC causal, sem reconstrução de UI.

## Fluxos e segurança

Conta: preparar upload para a própria identidade, finalizar somente após bytes
e MIME reais conferidos, criar/atualizar binding de avatar, projetar apenas
metadados/ticket autorizado e revogar o binding no remove. Chat: criar a
mensagem/anexo somente após finalize confirmado; leitura consulta a conversa,
mensagem, owner, tenant e audiência no RPC antes de assinar GET. Publicações:
master R2 primeiro; Agora pode promover vídeo a Stream HOT por até 24 horas;
Momentos mantém R2 por padrão e não recebe janela inventada; remoção é soft e
auditada. Toda negativa deve ser fail-closed e não revelar existência.

## Verificação

Cada fatia segue TDD: teste vermelho específico, execução da falha, menor
implementação, teste verde e commit explícito. A prova registra FE, BE e E2E
separadamente, incluindo rota normal, persistência, reload, troca de sessão ou
contexto quando aplicável, tenant A/B, ID adulterado, ticket expirado/revogado,
erros de upload e ausência de vazamento em logs/capturas. Goldens protegem a
referência e não substituem backend ou E2E.

## Bloqueios conhecidos

O SHA de base informado pelo Owner (`a85ac01c4...`) não é o `origin/dev` atual
local (`ee179b1e...`); a branch foi criada no SHA informado e a divergência
fica registrada no handoff. Sem autorização nominal não haverá `supabase db
push`, deploy de Edge Function, alteração de bucket/Stream ou mutação em
produção. Se contrato ou action_id não puder ser demonstrado, a fatia termina
com diagnóstico, testes locais e sobra para R15.
