---
title: "Fronteiras de seguranca para publicacao do Catalogo Coelo"
source: "specs/013-ui-packages-componentization.md; packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql; auditoria da Task 9"
status: "open-production-blockers"
generated_at: "2026-07-24"
---

# Fronteiras de seguranca do catalogo

## O que a Task 9 protege

O app independente usa sessao propria, publishable key e uma consulta minima a
`platform_memberships`. A policy `platform_memberships_platform_read` delega a
decisao para `app_private.has_platform_permission('platform.read')`.

O bootstrap desabilita `detectSessionInUri`, portanto query string e fragmento
nao estabelecem sessao. O app nao implementa `window.postMessage` como canal de
credencial.

O cliente classifica:

- sem sessao: `unauthenticated`;
- sessao sem linha visivel: `denied`;
- sessao com linha visivel pela RLS: `allowed`;
- erro: `unavailable`.

Essa protecao controla a renderizacao e as consultas autenticadas. Ela nao
substitui autorizacao no host nem torna bytes estaticos privados.

## Bloqueadores antes de publicacao privada

### Host/edge

O build Flutter inclui `main.dart.js`, fonte, indice JSONL e demais assets antes
da execucao do gate. O endereco privado deve exigir autenticacao no host/proxy
antes de servir qualquer arquivo e definir uma politica de incorporacao com
`Content-Security-Policy: frame-ancestors` limitada as origens aprovadas.

`robots noindex` e o gate Flutter nao sao controles de confidencialidade.

O `gotrue` 2.26.0 sincroniza sessao entre abas por `BroadcastChannel` e nao
oferece opcao publica para desativar esse comportamento. Como o canal e limitado
a mesma origem, o catalogo deve ser publicado em origem propria, distinta do
Superadmin, com CSP restritiva. Isso preserva a sessao separada entre produtos.
Se a governanca futura proibir tambem a sincronizacao entre abas do proprio
catalogo, sera necessaria decisao explicita entre aguardar suporte upstream ou
manter um fork; nao sera criado monkey patch ou dependencia silenciosa.

### Permissoes do banco

A funcao atual `app_private.has_platform_permission(text)`:

- considera grants por papel e overrides `allow`;
- nao aplica precedencia para overrides `effect = 'deny'`;
- filtra `status = 'active'`, mas nao rejeita explicitamente membership com
  `revoked_at` preenchido;
- nao rejeita explicitamente grants por papel com `revoked_at` preenchido;
- concede permissoes ao papel `Owner` por regra ampla, cuja precedencia sobre
  `deny` ainda nao esta formalizada.

Esses comportamentos sao herdados pelo catalogo e precisam de hardening
aprovado antes da publicacao. A Task 9 nao altera migrations silenciosamente.

### Matriz SQL

Adicionar validacao de acesso real para:

- `anon` sem acesso;
- autenticado sem membership;
- membership sem `platform.read`;
- grant por papel;
- grant por papel revogado;
- override `allow`;
- override `deny`;
- membership suspensa;
- membership revogada;
- papel `Owner` com e sem `deny` explicito.

Os testes atuais confirmam existencia de RLS/policies/funcoes, mas nao exercitam
essa matriz completa.

## Etapa de fechamento

Esses itens devem ser resolvidos ou receber decisao formal antes de qualquer
deploy privado e antes de concluir a integracao de
`Governanca > Catalogo`. Eles nao autorizam deploy, mudanca de banco ou nova
infraestrutura nesta rodada.
